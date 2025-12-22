# infra：一键化本地与准生产基础设施

为 ETC 全链路提供 Kafka/ZooKeeper、MySQL/MyCat、Flink、Prometheus/Grafana 及配套脚本的基础设施仓库，支持开箱即用的演示与开发。

## 组成与端口

- Kafka/ZooKeeper：9092（内网）、29092（外网）、2181
- MySQL：3306（root/rootpass）
- MyCat：8066（数据端口）、9066（管理端口），逻辑库 highway_etc
- Flink：JobManager 8081，TaskManager 若干；Prometheus 指标端口 9250-9260
- 监控：Prometheus 9091、Grafana 3000、Kafka Exporter 9308、MySQL Exporter 9104
- 网络：默认 bridge 名 infra_etcnet，前后端容器需加入此网络才能解析 mycat/kafka

## 目录结构

- docker-compose.dev.yml：本地一键拉起所有依赖
- flink/：usrlib（挂载实时作业 jar）、extra-lib（外部依赖 jar）、appconf（application.properties）
- mycat/conf：server.xml/schema.xml/rule.xml（三分片规则已就绪）
- scripts/：PowerShell 与 Shell 工具（推数、savepoint、一键启动等）
- prometheus/prometheus.yml：监控抓取配置
- sql/：初始化库表脚本（MySQL 将自动执行）

## 极速体验（5 步）

1) 启动依赖

```bash
docker compose -f docker-compose.dev.yml up -d
```

1) 构建实时/后端

```powershell
mvn -f ../streaming/pom.xml -DskipTests clean package
mvn -f ../services/pom.xml  -DskipTests clean package
```

将生成的 streaming-0.1.0.jar 放入 infra/flink/usrlib。
3) 提交 Flink 作业

```powershell
docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
```

1) 批量推送测试数据（默认限速）

```powershell
powershell -ExecutionPolicy Bypass -File infra/scripts/send_csv_batch.ps1
```

参数：Broker kafka:9092、Topic etc_traffic、DataDir infra/flink/data/test_data、ChunkSize 500、PauseMs 1200、MaxTotal 5000（0 不限）、-DryRun 仅预览。
5) 快速验证

```powershell
docker exec -it mycat mysql -hetc-mysql -uetcuser -petcpass -e "use highway_etc; select count(*) from traffic_pass_dev;"
curl.exe -s "http://localhost:8080/api/overview?windowMinutes=60"
```

## 一键脚本（bluecat_oneclick）

```powershell
cd infra/scripts
./bluecat_oneclick.ps1 -Tag latest [-SkipBuild] [-SkipFlinkSubmit] `
  [-IngestChunkSize 500 -IngestPauseMs 1200 -IngestMaxTotal 5000]
```

- 功能：构建 etc-services / etc-frontend 镜像，启动 compose，提交 Flink 作业，按限速推送数据。
- 结果：前端 <http://localhost:8088，后端> Swagger <http://localhost:8080/swagger-ui.html。>
- 新增接口：
  - `/api/congestion` 拥堵指数（基于实时通行量推算 CCI、占有率、健康度）
  - `/api/device-health` 设备健康（心跳、可用率、错误率）
  - `/api/revenue/forecast` 收入预测（基于车型分布估算收入并输出预测值）
  - `/api/alerts/overspeed` 与 `/api/alerts/stalled` 新增高速场景告警（基于近期车流轻量推断）

## 监控与排查

- Prometheus：已抓取 Flink/Kafka/MySQL 指标；Grafana 默认账号 admin/admin，可导入常用 Dashboard（Flink 12019、Kafka Exporter 14011、MySQL 7362）。
- Flink 日志：`docker exec -it flink-jobmanager tail -n 200 /opt/flink/log/flink--jobmanager-0.log`
- 查看/取消作业：`flink list` / `flink cancel <jobId>`（容器内执行）。

## 组合运行前后端（可选）

```powershell
docker run --rm -p 8080:8080 --network infra_etcnet etc-services
docker run --rm -p 8088:80   --network infra_etcnet etc-frontend
```

后端根路径自动跳转 Swagger，前端 Nginx 同域反代 /api。

## 数据健康与清理

- Kafka 日志保留默认 24h（KAFKA_LOG_RETENTION_HOURS），可按需在 docker-compose.dev.yml 中调整，避免长时间堆积。
- 服务侧内置定时清理（maintenance.retention-days 默认 3 天，maintenance.cleanup-interval-ms 默认 30 分钟），定期删除历史 traffic_pass_dev / stats_realtime / alert_plate_clone，保持 MyCat 分片瘦身。
- 实时仿真：`python infra/scripts/generate_mock_stream.py --bootstrap localhost:29092 --rate 80 --clone-rate 0.1 --focus-prefix 苏` 覆盖全国省份、语义化车型、自动套牌触发，UTF-8 中文安全。

## 关停与清理

```bash
docker compose -f docker-compose.dev.yml down -v
```

如需优雅停作业，使用 scripts/savepoint_and_stop.ps1；恢复用 resume_from_last_savepoint.ps1。

## 常见问题

- MyCat 连接失败：使用 MySQL 5.7 客户端；账号 etcuser/etcpass；确认容器加入 infra_etcnet。
- Flink 作业反复重启：多为 JDBC 配置或表结构不匹配，检查 application.properties 与 MyCat 分片表。
- 推数太快导致积压：调整 send_csv_batch.ps1 的 ChunkSize/PauseMs，或设置 -MaxTotal 以限量演练。
