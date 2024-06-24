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
import java.sql.SQLException;
import java.util.Properties;
import java.util.stream.Stream;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class OceanBaseCETest {

    private static final Logger LOG = LoggerFactory.getLogger(OceanBaseCETest.class);

    static Stream<Arguments> testOceanBaseCEArgs() {
        String host = Utils.getNonEmptyEnv("host");
        String port = Utils.getNonEmptyEnv("port");
        String sysUsername = Utils.getNonEmptyEnv("sys_username");
        String sysPassword = System.getenv("sys_password");
        String testTenant = Utils.getEnvOrDefault("test_tenant", "test");
        String testUsername = Utils.getNonEmptyEnv("test_username");
        String testPassword = System.getenv("test_password");

        return Stream.of(
                Arguments.of(true, host, port, "sys", sysUsername, sysPassword),
                Arguments.of(false, host, port, "sys", sysUsername, sysPassword),
                Arguments.of(true, host, port, testTenant, testUsername, testPassword),
                Arguments.of(false, host, port, testTenant, testUsername, testPassword));
    }

    @ParameterizedTest
    @MethodSource("testOceanBaseCEArgs")
    public void testOceanBaseCE(
            boolean useLegacyDriver,
            String host,
            String port,
            String tenantName,
            String username,
            String password) {

        LOG.info(
                "Testing with args: [useLegacyDriver: {}, host: {}, port: {}, username: {}, password: {}]",
                useLegacyDriver,
                host,
                port,
                username,
                password);

        String jdbcUrl = String.format("jdbc:mysql://%s:%s/test?useSSL=false", host, port);

        Properties props = new Properties();
        props.setProperty("user", username);
        if (password != null) {
            props.put("password", password);
        }

        Driver driver = Utils.getDriver(useLegacyDriver);
        try (Connection conn = driver.connect(jdbcUrl, props)) {
            LOG.info("Connected to OceanBase CE successfully");

            LOG.info("Version comment: {}", Utils.getVersionComment(conn));

            String tenant = Utils.getTenantName(conn);
            LOG.info("Tenant name: {}", tenant);
            Assertions.assertEquals(tenantName, tenant);

            checkClusterName(conn);
            checkRSList(conn);

            if ("sys".equals(tenantName)) {
                checkServerIP(conn);
            } else {
                Assertions.assertEquals(2, Utils.getTableRowsCount(conn, "user"));
            }
        } catch (SQLException e) {
            Assertions.fail(e);
        }
    }

    private void checkClusterName(Connection conn) {
        String clusterName = Utils.getClusterName(conn);
        LOG.info("Cluster name: {}", clusterName);
        Assertions.assertEquals(Utils.getEnvOrDefault("cluster_name", "obcluster"), clusterName);
    }

    private void checkServerIP(Connection conn) {
        String serverIP = Utils.getServerIP(conn);
        LOG.info("Server IP: {}", serverIP);
        Assertions.assertEquals(Utils.getEnvOrDefault("server_ip", "127.0.0.1"), serverIP);
    }

    private void checkRSList(Connection conn) {
        String rsList = Utils.getRSList(conn);
        LOG.info("RS List: {}", rsList);
        Assertions.assertEquals(Utils.getEnvOrDefault("rs_list", "127.0.0.1:2882:2881"), rsList);
    }
}
