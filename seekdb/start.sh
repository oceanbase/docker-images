#!/bin/bash

set -e

CONFIG_FILE="/etc/oceanbase/seekdb.cnf"

# Replace values in config file with environment variables if they are set

if [ -n "$DATAFILE_SIZE" ]; then
  sed -i "s|^datafile_size=.*|datafile_size=$DATAFILE_SIZE|" $CONFIG_FILE
fi

if [ -n "$DATAFILE_NEXT" ]; then
  sed -i "s|^datafile_next=.*|datafile_next=$DATAFILE_NEXT|" $CONFIG_FILE
fi

if [ -n "$DATAFILE_MAXSIZE" ]; then
  sed -i "s|^datafile_maxsize=.*|datafile_maxsize=$DATAFILE_MAXSIZE|" $CONFIG_FILE
fi

if [ -n "$CPU_COUNT" ]; then
  sed -i "s|^cpu_count=.*|cpu_count=$CPU_COUNT|" $CONFIG_FILE
fi

if [ -n "$MEMORY_LIMIT" ]; then
  sed -i "s|^memory_limit=.*|memory_limit=$MEMORY_LIMIT|" $CONFIG_FILE
fi

if [ -n "$LOG_DISK_SIZE" ]; then
  sed -i "s|^log_disk_size=.*|log_disk_size=$LOG_DISK_SIZE|" $CONFIG_FILE
fi

# Execute the main process
/usr/libexec/oceanbase/scripts/seekdb_systemd_start 

OBSERVER_CONFIG_FILE="/var/lib/oceanbase/etc/observer.config.bin"
for i in {1..10}; do
  echo "Loop iteration #$i"
  if [ -f "$OBSERVER_CONFIG_FILE" ]; then
    echo "File '$OBSERVER_CONFIG_FILE' found on attempt #$i."
    break
  fi
  sleep 1
done
obshell agent start --seekdb --base-dir=/var/lib/oceanbase

INITIALIZED_FLAG="/var/lib/oceanbase/.initialized"

if [ ! -f "$INITIALIZED_FLAG" ]; then
  # change password using obshell
  for i in {1..10}; do
    curl -X PUT "http://127.0.0.1:2886/api/v1/observer/user/root/password" -d "{\"password\":\"$ROOT_PASSWORD\"}" --unix-socket "/var/lib/oceanbase/run/obshell.sock"
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -eq 0 ]; then
      echo "Command succeeded on attempt #$i."
      break # Exit the loop if successful
    else
      echo "Command failed on attempt #$i (exit status: $EXIT_STATUS). Retrying in 1 seconds..."
      sleep 1
    fi
  done

  # Execute initialization scripts if INIT_SCRIPTS_PATH is set
  if [ -n "$INIT_SCRIPTS_PATH" ]; then
    echo "Executing initialization scripts from $INIT_SCRIPTS_PATH..."
    # Determine mysql connection options
    MYSQL_OPTS="-h 127.0.0.1 -P 2881 -u root"
    if [ -n "$ROOT_PASSWORD" ]; then
      MYSQL_OPTS="$MYSQL_OPTS -p$ROOT_PASSWORD"
    fi
 
    for sql_file in "$INIT_SCRIPTS_PATH"/*.sql; do
      if [ -f "$sql_file" ]; then
        echo "Executing $sql_file..."
        mysql $MYSQL_OPTS < "$sql_file"
        echo "Finished executing $sql_file."
      fi
    done
    echo "Initialization scripts execution complete."
  fi
 
 
  # Create the initialized flag file
  touch "$INITIALIZED_FLAG"
  echo "Initialization complete."
else
  echo "Already initialized. Skipping initialization."
fi

echo "Starting observer health check..."
while pgrep observer > /dev/null; do
  sleep 5
done

echo "Observer process not found. Exiting."
exit 1
