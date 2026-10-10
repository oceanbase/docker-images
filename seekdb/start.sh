#!/bin/bash

set -e

WAIT_FOR_SQL_READY_ATTEMPTS=600
WAIT_FOR_SERVICE_READY_ATTEMPTS=300
WAIT_INTERVAL_SECONDS=1
STOP_TIMEOUT="${SEEKDB_STOP_TIMEOUT:-30}"

CONFIG_FILE="/etc/seekdb/seekdb.cnf"
SEEKDB_BASE_DIR="/var/lib/seekdb"
INITIALIZED_FLAG="${SEEKDB_BASE_DIR}/.initialized"

SEEKDB_PID=""
CLEANING_UP=0

# Set or append key=value in seekdb.cnf (line may be absent in newer packages)
seekdb_set_cnf() {
    local key="$1"
    local value="$2"
    if [ -f "$CONFIG_FILE" ] && grep -qE "^${key}=" "$CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
}

# Escape a value for use inside a single-quoted SQL string literal.
sql_escape() {
    local s=$1
    s=${s//\'/\'\'}
    printf '%s' "$s"
}

# Run mysql as root. Pass the password as the first argument (may be empty).
mysql_root() {
    local password=$1
    shift
    if [ -n "$password" ]; then
        MYSQL_PWD="$password" mysql -h127.0.0.1 -P2881 -uroot --connect-timeout=2 "$@"
    else
        mysql -h127.0.0.1 -P2881 -uroot --connect-timeout=2 "$@"
    fi
}

cleanup() {
    if [ "$CLEANING_UP" -eq 1 ]; then
        return
    fi
    CLEANING_UP=1

    if [ -n "$SEEKDB_PID" ] && kill -0 "$SEEKDB_PID" 2>/dev/null; then
        # SeekDB's supported graceful stop signal (see seekdb_systemd_stop).
        kill -USR1 "$SEEKDB_PID" 2>/dev/null || true
        local elapsed=0
        while kill -0 "$SEEKDB_PID" 2>/dev/null && [ "$elapsed" -lt "$STOP_TIMEOUT" ]; do
            sleep 1
            elapsed=$((elapsed + 1))
        done
        if kill -0 "$SEEKDB_PID" 2>/dev/null; then
            echo "SeekDB did not stop within ${STOP_TIMEOUT}s, forcing shutdown"
            kill -KILL "$SEEKDB_PID" 2>/dev/null || true
        fi
        wait "$SEEKDB_PID" 2>/dev/null || true
        SEEKDB_PID=""
    fi
}

on_signal() {
    echo "Received termination signal, shutting down..."
    cleanup
    exit 0
}

ensure_seekdb_alive() {
    if [ -z "$SEEKDB_PID" ] || ! kill -0 "$SEEKDB_PID" 2>/dev/null; then
        wait "$SEEKDB_PID" 2>/dev/null || true
        echo "Seekdb process exited unexpectedly."
        exit 1
    fi
}

# True when the mysql client reached the server (auth success or Access denied).
sql_server_responding() {
    local password=$1
    local out rc
    out=$(mysql_root "$password" -e "SELECT 1" 2>&1) && return 0 || rc=$?
    if echo "$out" | grep -Eqi 'Access denied|ERROR 1045'; then
        return 0
    fi
    return 1
}

wait_for_sql_auth() {
    local password=$1
    local label=$2
    local i
    for i in $(seq 1 $WAIT_FOR_SQL_READY_ATTEMPTS); do
        ensure_seekdb_alive
        if mysql_root "$password" -e "SELECT 1" >/dev/null 2>&1; then
            echo "SeekDB SQL ready ($label) on attempt #$i."
            return 0
        fi
        if [ "$i" -eq "$WAIT_FOR_SQL_READY_ATTEMPTS" ]; then
            echo "Timeout waiting for SeekDB SQL readiness ($label)."
            exit 1
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "SeekDB is still not SQL-ready ($label)..."
        fi
        sleep $WAIT_INTERVAL_SECONDS
    done
}

# Wait until the server accepts TCP/SQL connections (success or Access denied).
wait_for_sql_server() {
    local i
    for i in $(seq 1 $WAIT_FOR_SQL_READY_ATTEMPTS); do
        ensure_seekdb_alive
        # Probe with empty password: wrong password still proves the server is up.
        if sql_server_responding ""; then
            echo "SeekDB SQL server is accepting connections on attempt #$i."
            return 0
        fi
        if [ "$i" -eq "$WAIT_FOR_SQL_READY_ATTEMPTS" ]; then
            echo "Timeout waiting for SeekDB SQL server to accept connections."
            exit 1
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "SeekDB SQL server is still not accepting connections..."
        fi
        sleep $WAIT_INTERVAL_SECONDS
    done
}

if [ -n "$DATAFILE_SIZE" ]; then
    seekdb_set_cnf datafile_size "$DATAFILE_SIZE"
fi

if [ -n "$DATAFILE_NEXT" ]; then
    seekdb_set_cnf datafile_next "$DATAFILE_NEXT"
fi

if [ -n "$DATAFILE_MAXSIZE" ]; then
    seekdb_set_cnf datafile_maxsize "$DATAFILE_MAXSIZE"
fi

if [ -n "$CPU_COUNT" ]; then
    seekdb_set_cnf cpu_count "$CPU_COUNT"
fi

if [ -n "$MEMORY_LIMIT" ]; then
    seekdb_set_cnf memory_limit "$MEMORY_LIMIT"
fi

if [ -n "$LOG_DISK_SIZE" ]; then
    seekdb_set_cnf log_disk_size "$LOG_DISK_SIZE"
fi

trap on_signal TERM INT
trap cleanup EXIT

# Prepare directories and clear stale runtime files so seekdb can start again
# against a persisted data directory after an unclean previous stop.
mkdir -p "${SEEKDB_BASE_DIR}/run" "${SEEKDB_BASE_DIR}/etc" "${SEEKDB_BASE_DIR}/store"
rm -f \
    "${SEEKDB_BASE_DIR}/run/daemon.pid" \
    "${SEEKDB_BASE_DIR}/run/daemon.sock" \
    "${SEEKDB_BASE_DIR}/run/obshell.pid" \
    "${SEEKDB_BASE_DIR}/run/obshell.sock" \
    "${SEEKDB_BASE_DIR}/run/seekdb.pid" \
    "${SEEKDB_BASE_DIR}/run/seekdb"

# seekdb_systemd_start exec's seekdb --nodaemon (foreground). Run it in the
# background so initialization can continue; keep PID for supervision.
# Do not start obshell — password and init use SQL directly.
/usr/libexec/seekdb/scripts/seekdb_systemd_start 2>/dev/null &
SEEKDB_PID=$!

if [ ! -f "$INITIALIZED_FLAG" ]; then
    echo "Fresh instance: waiting for empty-password SQL readiness..."
    wait_for_sql_auth "" "empty password"

    if [ -n "$ROOT_PASSWORD" ]; then
        ESCAPED_PASSWORD=$(sql_escape "$ROOT_PASSWORD")
        echo "Setting root password via ALTER USER..."
        # NO_BACKSLASH_ESCAPES so literal \n/\t in ROOT_PASSWORD are not
        # interpreted as escape sequences; must be same mysql session as ALTER.
        mysql_root "" -e "SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES'; ALTER USER 'root' IDENTIFIED BY '${ESCAPED_PASSWORD}';"

        if ! mysql_root "$ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
            echo "Failed to verify root password after ALTER USER. Initialization aborted."
            exit 1
        fi
        echo "Root password set and verified."
    else
        echo "ROOT_PASSWORD is empty; leaving root password unset."
    fi

    ACTIVE_PASSWORD="${ROOT_PASSWORD:-}"

    if [ -n "$SEEKDB_DATABASE" ]; then
        mysql_root "$ACTIVE_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$SEEKDB_DATABASE\`;"
        echo "Database $SEEKDB_DATABASE created."
    fi

    if [ -n "$INIT_SCRIPTS_PATH" ]; then
        echo "Executing initialization scripts from $INIT_SCRIPTS_PATH..."
        for sql_file in "$INIT_SCRIPTS_PATH"/*.sql; do
            if [ -f "$sql_file" ]; then
                echo "Executing $sql_file..."
                if [ -n "$SEEKDB_DATABASE" ]; then
                    mysql_root "$ACTIVE_PASSWORD" -D"$SEEKDB_DATABASE" < "$sql_file"
                else
                    mysql_root "$ACTIVE_PASSWORD" < "$sql_file"
                fi
                echo "Finished executing $sql_file."
            fi
        done
        echo "Initialization scripts execution complete."
    fi

    # Create the initialized flag only after successful password/init work.
    touch "$INITIALIZED_FLAG"
    echo "Initialization complete."
else
    echo "Already initialized. Waiting for SQL server, then verifying configured password..."
    wait_for_sql_server
    if ! mysql_root "${ROOT_PASSWORD:-}" -e "SELECT 1" >/dev/null 2>&1; then
        echo "Authentication failed with configured ROOT_PASSWORD for an existing data directory."
        echo "Refusing to reset the existing password. Check ROOT_PASSWORD and exit."
        exit 1
    fi
    echo "Existing instance authentication succeeded."
fi

# Execute command passed to docker run if present
if [ $# -gt 0 ]; then
    ACTIVE_PASSWORD="${ROOT_PASSWORD:-}"

    echo "Waiting for seekdb to be ready..."
    for i in $(seq 1 $WAIT_FOR_SERVICE_READY_ATTEMPTS); do
        ensure_seekdb_alive
        if mysql_root "$ACTIVE_PASSWORD" -e "show databases" >/dev/null 2>&1; then
            echo "seekdb is ready."
            break
        fi
        if [ "$i" -eq "$WAIT_FOR_SERVICE_READY_ATTEMPTS" ]; then
            echo "Timeout waiting for seekdb to be ready."
            exit 1
        fi
        sleep $WAIT_INTERVAL_SECONDS
    done

    MYSQL_EXTRA=()
    if [ -n "$SEEKDB_DATABASE" ]; then
        MYSQL_EXTRA+=(-D"$SEEKDB_DATABASE")
    fi

    echo "Executing sql: $*"
    mysql_root "$ACTIVE_PASSWORD" "${MYSQL_EXTRA[@]}" -e "$*"
    SQL_EXIT=$?
    cleanup
    trap - EXIT TERM INT
    exit $SQL_EXIT
fi

echo "Seekdb started"
echo "Waiting for SeekDB process (pid $SEEKDB_PID) to exit..."

# Drop EXIT trap before wait so a normal seekdb exit does not force cleanup twice.
trap - EXIT
set +e
wait "$SEEKDB_PID"
SEEKDB_EXIT=$?
set -e

echo "Seekdb process exited with code ${SEEKDB_EXIT}."
exit "$SEEKDB_EXIT"
