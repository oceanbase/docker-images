/*
 * Copyright 2024 OceanBase.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.oceanbase.test;

import java.sql.Connection;
import java.sql.Driver;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Utils {

    public static Driver getDriver(boolean legacy) {
        String className = legacy ? "com.mysql.jdbc.Driver" : "com.mysql.cj.jdbc.Driver";
        try {
            return (Driver) Class.forName(className).getDeclaredConstructor().newInstance();
        } catch (Throwable throwable) {
            throw new RuntimeException("Failed to load JDBC driver", throwable);
        }
    }

    public static String getNonEmptyEnv(String key) {
        String value = System.getenv(key);
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException("Environment variable '" + key + "' is required");
        }
        return value;
    }

    public static String getEnvOrDefault(String name, String defaultValue) {
        String env = System.getenv(name);
        return env == null ? defaultValue : env;
    }

    public static String getVersionComment(Connection connection) {
        return (String)
                query(
                        connection,
                        "SHOW VARIABLES LIKE 'version_comment'",
                        rs -> rs.next() ? rs.getString("VALUE") : null);
    }

    public static String getClusterName(Connection connection) {
        return (String)
                query(
                        connection,
                        "SHOW PARAMETERS LIKE 'cluster'",
                        rs -> rs.next() ? rs.getString("VALUE") : null);
    }

    public static String getTenantName(Connection connection) {
        return (String) query(connection, "SHOW TENANT", rs -> rs.next() ? rs.getString(1) : null);
    }

    public static String getServerIP(Connection connection) {
        return (String)
                query(
                        connection,
                        "SELECT svr_ip FROM oceanbase.__all_server",
                        rs -> rs.next() ? rs.getString(1) : null);
    }

    public static String getRSList(Connection connection) {
        return (String)
                query(
                        connection,
                        "SHOW PARAMETERS LIKE 'rootservice_list'",
                        rs -> rs.next() ? rs.getString("VALUE") : null);
    }

    @FunctionalInterface
    interface ResultSetConsumer {
        Object apply(ResultSet rs) throws SQLException;
    }

    static Object query(Connection connection, String sql, ResultSetConsumer resultSetConsumer) {
        try (Statement statement = connection.createStatement()) {
            ResultSet rs = statement.executeQuery(sql);
            return resultSetConsumer.apply(rs);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to execute sql: " + sql, e);
        }
    }
}
