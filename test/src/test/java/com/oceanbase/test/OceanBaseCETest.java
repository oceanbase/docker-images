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
        // non-null env vars
        String serverIP = Utils.getNonEmptyEnv("server_ip");
        String clusterName = Utils.getNonEmptyEnv("cluster_name");
        String port = Utils.getNonEmptyEnv("port");
        String testTenant = Utils.getNonEmptyEnv("test_tenant");

        // nullable env vars
        String sysPassword = System.getenv("sys_password");
        String testPassword = System.getenv("test_password");

        return Stream.of(
                Arguments.of(true, serverIP, clusterName, port, "sys", "root", sysPassword),
                Arguments.of(false, serverIP, clusterName, port, "sys", "root", sysPassword),
                Arguments.of(
                        true,
                        serverIP,
                        clusterName,
                        port,
                        testTenant,
                        "root@" + testTenant,
                        testPassword),
                Arguments.of(
                        false,
                        serverIP,
                        clusterName,
                        port,
                        testTenant,
                        "root@" + testTenant,
                        testPassword));
    }

    @ParameterizedTest
    @MethodSource("testOceanBaseCEArgs")
    public void testOceanBaseCE(
            boolean useLegacyDriver,
            String serverIP,
            String clusterName,
            String port,
            String tenantName,
            String username,
            String password) {

        boolean slimMode = "127.0.0.1".equals(serverIP);

        LOG.info(
                "Testing with args: [useLegacyDriver: {}, server_ip: {}, cluster_name: {}, port: {}, username: {}, password: {}]",
                useLegacyDriver,
                serverIP,
                clusterName,
                port,
                username,
                password);

        String jdbcUrl = String.format("jdbc:mysql://127.0.0.1:%s/test?useSSL=false", port);

        Properties props = new Properties();
        props.setProperty("user", username);
        if (password != null) {
            props.put("password", password);
        }

        Driver driver = Utils.getDriver(useLegacyDriver);
        try (Connection conn = driver.connect(jdbcUrl, props)) {
            LOG.info("Connected to OceanBase CE successfully");

            Assertions.assertNotNull(Utils.getVersionComment(conn));

            Assertions.assertEquals(serverIP + ":2882:2881", Utils.getRSList(conn));
            Assertions.assertEquals(clusterName, Utils.getClusterName(conn));
            Assertions.assertEquals(tenantName, Utils.getTenantName(conn));

            if (!slimMode) {
                Assertions.assertNotNull(Utils.getConfigUrl(conn));
            }

            if ("sys".equals(tenantName)) {
                Assertions.assertEquals(serverIP, Utils.getServerIP(conn));
            } else {
                Assertions.assertEquals(2, Utils.getTableRowsCount(conn, "user"));
            }
        } catch (SQLException e) {
            Assertions.fail(e);
        }
    }
}
