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

import com.oceanbase.clogproxy.client.LogProxyClient;
import com.oceanbase.clogproxy.client.config.ClientConf;
import com.oceanbase.clogproxy.client.config.ObReaderConfig;
import com.oceanbase.clogproxy.client.exception.LogProxyClientException;
import com.oceanbase.clogproxy.client.listener.RecordListener;
import com.oceanbase.oms.logmessage.DataMessage;
import com.oceanbase.oms.logmessage.LogMessage;
import java.sql.Connection;
import java.sql.Driver;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

public class LogProxyCETest {

    private static final org.slf4j.Logger LOG =
            org.slf4j.LoggerFactory.getLogger(LogProxyCETest.class);

    static Stream<Arguments> testLogProxyCEArgs() {
        // non-null env vars
        String observerIP = Utils.getNonEmptyEnv("observer_ip");
        String logProxyIP = Utils.getNonEmptyEnv("oblogproxy_ip");
        String logProxyPort = Utils.getNonEmptyEnv("oblogproxy_port");
        String username = Utils.getNonEmptyEnv("username");
        String password = Utils.getNonEmptyEnv("password");

        return Stream.of(
                Arguments.of(observerIP, logProxyIP, "2983", username, password),
                Arguments.of(observerIP, "127.0.0.1", logProxyPort, username, password));
    }

    @ParameterizedTest
    @MethodSource("testLogProxyCEArgs")
    public void testLogProxyCE(
            String observerIP,
            String logProxyIP,
            String logProxyPort,
            String username,
            String password)
            throws InterruptedException {

        LOG.info(
                "Testing with args: [observerIP: {}, logProxyIP: {}, logProxyPort: {},  username: {}, password: {}]",
                observerIP,
                logProxyIP,
                logProxyPort,
                username,
                password);

        ObReaderConfig obReaderConfig = new ObReaderConfig();

        Properties props = new Properties();
        props.setProperty("user", username);
        props.setProperty("password", password);

        Driver driver = Utils.getDriver(false);
        try (Connection conn = driver.connect("jdbc:mysql://" + observerIP + ":2881/test", props)) {
            obReaderConfig.setRsList(Utils.getRSList(conn));
            obReaderConfig.setTableWhiteList(Utils.getTenantName(conn) + ".*.*");
        } catch (SQLException e) {
            Assertions.fail(e);
        }

        obReaderConfig.setUsername(username);
        obReaderConfig.setPassword(password);
        obReaderConfig.setStartTimestamp(0L);
        obReaderConfig.setWorkingMode("memory");

        ClientConf clientConf =
                ClientConf.builder()
                        .transferQueueSize(1000)
                        .connectTimeoutMs((int) Duration.ofSeconds(30).toMillis())
                        .maxReconnectTimes(0)
                        .ignoreUnknownRecordType(true)
                        .build();

        LogProxyClient client =
                new LogProxyClient(
                        logProxyIP, Integer.parseInt(logProxyPort), obReaderConfig, clientConf);

        BlockingQueue<LogMessage> messageQueue = new LinkedBlockingQueue<>(2);
        AtomicBoolean started = new AtomicBoolean(false);
        CountDownLatch latch = new CountDownLatch(1);

        client.addListener(
                new RecordListener() {
                    @Override
                    public void notify(LogMessage message) {
                        switch (message.getOpt()) {
                            case HEARTBEAT:
                                LOG.info(
                                        "Received heartbeat with checkpoint {}",
                                        message.getCheckpoint());
                                if (started.compareAndSet(false, true)) {
                                    latch.countDown();
                                }
                                break;
                            case BEGIN:
                                LOG.info("Received transaction begin: {}", message);
                                break;
                            case COMMIT:
                                LOG.info("Received transaction commit: {}", message);
                                break;
                            case INSERT:
                            case UPDATE:
                            case DELETE:
                            case DDL:
                                try {
                                    messageQueue.put(message);
                                } catch (InterruptedException e) {
                                    throw new RuntimeException("Failed to add message to queue", e);
                                }
                                break;
                            default:
                                throw new IllegalArgumentException(
                                        "Unsupported log message type: " + message.getOpt());
                        }
                    }

                    @Override
                    public void onException(LogProxyClientException e) {
                        LOG.error(e.toString());
                    }
                });

        client.start();

        if (!latch.await(30, TimeUnit.SECONDS)) {
            Assertions.fail("Timeout to receive heartbeat message");
        }

        String ddl = "CREATE TABLE t_product (id INT(10) PRIMARY KEY, name VARCHAR(20))";
        try (Connection conn = driver.connect("jdbc:mysql://" + observerIP + ":2881/test", props);
                Statement statement = conn.createStatement()) {
            statement.execute(ddl);
            statement.execute("INSERT INTO t_product VALUES (1, 'meat')");
        } catch (SQLException e) {
            Assertions.fail(e);
        }

        while (messageQueue.size() < 2) {
            Thread.sleep(1000);
        }

        LogMessage first = messageQueue.take();
        Assertions.assertEquals(DataMessage.Record.Type.DDL, first.getOpt());
        Assertions.assertEquals(ddl, first.getFieldList().get(0).getValue().toString());

        LogMessage second = messageQueue.take();
        Assertions.assertEquals(DataMessage.Record.Type.INSERT, second.getOpt());
        Assertions.assertEquals("t_product", second.getTableName());

        Map<String, String> fieldMap =
                second.getFieldList().stream()
                        .filter(f -> !f.isPrev())
                        .collect(
                                Collectors.toMap(
                                        DataMessage.Record.Field::getFieldname,
                                        f -> f.getValue().toString()));
        Assertions.assertEquals(2, fieldMap.size());
        Assertions.assertEquals("1", fieldMap.get("id"));
        Assertions.assertEquals("meat", fieldMap.get("name"));

        try (Connection conn = driver.connect("jdbc:mysql://" + observerIP + ":2881/test", props);
                Statement statement = conn.createStatement()) {
            statement.execute("DROP TABLE t_product");
        } catch (SQLException e) {
            Assertions.fail(e);
        }

        client.stop();
    }
}
