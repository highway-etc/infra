# infra

- docker-compose.dev.yml：本地开发一键拉起 Kafka / Zookeeper / MySQL / MyCat / Flink
- k8s/：生产环境 Helm/Manifests
- scripts/：初始化脚本（建库表、创建 topic 等）
- flink/：Flink 作业和依赖库

## 最新变更（2025-12-20）

- MySQL 驱动与 MyCat 兼容：后端改用 `mysql-connector-java 5.1.49` 与旧式认证，JDBC URL 增加 `useSSL=false&serverTimezone=UTC`，消除了 `CLIENT_PLUGIN_AUTH is required` 报错。
- Dashboard 统计窗口改为以最新一条 `traffic_pass_dev` 的 `gcsj` 为锚点，再向前取窗口（默认 24h，前端传 60min），避免 MyCat 在 `MAX(timestamp)` 聚合上的兼容性问题导致总是 0。
- 数据流端到端打通：通过 MyCat 查询到近 150 万行，`/api/overview?windowMinutes=60` 返回非零指标；前端经 Nginx 反代同样可拿到数据。
- 数据发送脚本 `scripts/send_csv_batch.ps1` 支持安全限速，默认 `chunk=500 / pause=1200ms / max=5000`，并新增 `-DryRun` 便于演练；一键脚本默认也采用相同限速参数。
- 一键脚本 `scripts/bluecat_oneclick.ps1` 统一构建镜像名为 `etc-services` / `etc-frontend`，保持与手工启动命令一致。

## 一键启动（BlueCat 自用）

```powershell
# 在仓库根目录执行
cd infra\scripts
./bluecat_oneclick.ps1 -Tag latest
```

- 数据推送参数：`-IngestChunkSize`（默认 500）、`-IngestPauseMs`（默认 1200）、`-IngestMaxTotal`（默认 5000，0 表示不封顶），内部调用 `send_csv_batch.ps1`。
- 可选参数：`-SkipBuild` 跳过镜像构建，`-SkipFlinkSubmit` 跳过 Flink 作业提交。
- 输出：前端 <http://localhost:8088>，后端 Swagger <http://localhost:8080/swagger-ui.html>。

## 快速开始（本地）

1. 在仓库根目录启动基础设施：

   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```

2. 核对服务：Kafka localhost:29092 / kafka:9092，MySQL localhost:3306 (root/rootpass)，MyCat localhost:8066 / 9066，Flink UI <http://localhost:8081>，Prometheus <http://localhost:9091>，Grafana <http://localhost:3000> (admin/admin)。

3. 提交 Flink 作业（容器内）：

   ```powershell
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
   ```

   > 单 TM 4 槽位时并行度已调低，保持默认即可；若调高并行度，请先扩容 TaskManager 或槽位。

4. 批量推送测试数据（默认限速）：

   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/scripts/send_csv_batch.ps1
   ```

   参数：`-Broker kafka:9092`，`-Topic etc_traffic`，`-DataDir infra/flink/data/test_data`，`-ChunkSize 500`，`-PauseMs 1200`，`-MaxTotal 5000`（0 不限），`-DryRun` 不发送仅预览。备用手动方式：`docker exec -it kafka kafka-console-producer --broker-list kafka:9092 --topic etc_traffic`。

5. 验证链路：

   ```powershell
   docker exec -it mycat mysql -hetc-mysql -uetcuser -petcpass -e "use highway_etc; select count(*) from traffic_pass_dev;"
   curl.exe -s "http://localhost:8080/api/overview?windowMinutes=60"
   curl.exe -s "http://localhost:8088/api/overview?windowMinutes=60"
   ```

6. 打开监控：Prometheus <http://localhost:9090>（抓取 Flink 9250、Kafka Exporter 9308、MySQL Exporter 9104），Grafana <http://localhost:3000>；可导入 Dashboard：Flink 12019、Kafka Exporter 14011、MySQL 7362。

## Flink 作业部署

详细的 Flink 作业部署和故障排查指南，请参阅 [FLINK_DEPLOYMENT.md](FLINK_DEPLOYMENT.md)

### 快速提交作业

```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink run \
   -d \
   -c com.highway.etc.job.TrafficStreamingJob \
   /opt/flink/usrlib/streaming-0.1.0.jar

docker exec -it flink-jobmanager /opt/flink/bin/flink run \
   -d \
   -c com.highway.etc.job.PlateCloneDetectionJob \
   /opt/flink/usrlib/streaming-0.1.0.jar
```

   说明：

- `-d`：以后台模式提交
- `-c`：指定主类（Entry Class）
- 最后一个参数：容器内 JAR 的绝对路径，需确保文件存在

## 常用命令速查

在仓库根目录执行：

```powershell
# 打包 Flink 作业与后端
mvn -f streaming/pom.xml -DskipTests clean package
mvn -f services/pom.xml  -DskipTests clean package

# 提交两条作业（保持 job.parallelism 不超过槽位数）
docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar

# 查看/取消 Flink 作业
docker exec -it flink-jobmanager /opt/flink/bin/flink list
docker exec -it flink-jobmanager /opt/flink/bin/flink cancel <jobId>

# 查看 JobManager 日志排错
docker exec -it flink-jobmanager tail -n 200 /opt/flink/log/flink--jobmanager-0.log

# 通过 MyCat 快速查数
docker exec -it mycat mysql -hetc-mysql -uetcuser -petcpass -e "use highway_etc; select count(*) from traffic_pass_dev;"

# 批量推送测试数据
powershell -ExecutionPolicy Bypass -File infra/scripts/send_csv_batch.ps1
```

### 组合使用前端/后端（可选）

- 在项目根按 README（services/frontend）构建镜像后，可在 infra 同一网络下运行：

```powershell
docker run --rm -p 8080:8080 --network infra_etcnet etc-services
docker run --rm -p 8088:80   --network infra_etcnet etc-frontend
```

- 后端根路径将自动跳转到 Swagger UI；前端默认同域反代到后端。

### 监控组件

- kafka-exporter：暴露 Kafka 指标（端口 9308）。
- mysql-exporter：暴露 MySQL 指标（端口 9104）。
- prometheus：集中抓取上述指标（端口 9090）。
- grafana：仪表盘展示（端口 3000）。

## 关闭

```bash
docker compose -f docker-compose.dev.yml down -v
```
