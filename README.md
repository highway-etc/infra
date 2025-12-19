# infra

- docker-compose.dev.yml：本地开发一键拉起 Kafka / Zookeeper / MySQL / MyCat / Flink
- k8s/：生产环境 Helm/Manifests
- scripts/：初始化脚本（建库表、创建 topic 等）
- flink/：Flink 作业和依赖库

## 最近排查摘要

- docker compose 开发环境可正常拉起，`kafka-init` 容器会先多次重试，最终退出码 0 并确认已创建主题 `etc_traffic`。
- Flink 作业 TrafficStreamingJob / PlateCloneDetectionJob 已可通过 `flink run` 提交并保持 RUNNING。
- Kafka 可消费测试消息，但当前 MyCat 表 `etc_0.traffic_pass_dev` 仅落库 1 行，`/api/traffic` 返回 total=0，链路仍需补齐。
- PowerShell 版 `send_mock_data.ps1` 兼容性欠佳，推荐直接在 Kafka 容器内用 `kafka-console-producer` 发送 ASCII JSON。
- 新增脚本 `scripts/send_csv_batch.ps1`，可一次性把 `flink/data/test_data/*.csv` 通过临时 Python 容器推送到 Kafka。
- 新增一键脚本 `scripts/bluecat_oneclick.ps1`，默认构建 BlueCat 前后端镜像并依次拉起 compose、提交 Flink 作业、启动前后端容器。

## 一键启动（BlueCat 自用）

```powershell
# 在仓库根目录执行
cd infra\scripts
./bluecat_oneclick.ps1 -Tag latest
```

- 可选参数：`-SkipBuild` 跳过镜像构建，`-SkipFlinkSubmit` 跳过 Flink 作业提交。
- 输出：前端 <http://localhost:8088>，后端 Swagger <http://localhost:8080/swagger-ui.html>。

## 快速开始（本地）

1. 安装 Docker Desktop（WSL2）并启动
2. 在仓库根目录执行：

   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```

3. 核对服务：

   - Kafka: localhost:29092 (外部访问) / kafka:9092 (容器内访问)。若日志有连接失败重试但最终退出 0 属正常。
   - MySQL: localhost:3306 (root/rootpass)
   - MyCat: localhost:8066 (JDBC) / localhost:9066 (Admin)
   - Flink UI: <http://localhost:8081>
   - Prometheus: <http://localhost:9091>
   - Grafana: <http://localhost:3000> （默认账号 admin / admin）

4. 提交 Flink 作业（容器内）：

   ```powershell
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
   ```

   > 如果当前仅 1 个 TaskManager 且 4 个槽位，已默认把 `job.parallelism=2`。保持默认时两条作业都能获得槽位；如需更高并行度，请先扩容 TaskManager 或槽位。

5. 推送测试数据（批量 CSV 更省心）：

   - 一键批量：

   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/scripts/send_csv_batch.ps1
   ```

   （默认读取 `flink/data/test_data/*.csv`，使用临时 python:3.11-slim 容器运行 `push_kafka.py`）

   - 手动 producer（备用）：

   ```powershell
   docker exec -it kafka kafka-console-producer --broker-list kafka:9092 --topic etc_traffic
   # 在提示符下粘贴 ASCII JSON，每行一条；示例字段应与 Flink 作业预期 schema 对齐。
   ```

   - 发送后可用 `kafka-console-consumer` 验证，再在 MyCat 查询 `etc_0.traffic_pass_dev` 是否进数。

6. 打开监控：
   - Prometheus：<http://localhost:9090>（抓取 Flink 9250、Kafka Exporter 9308、MySQL Exporter 9104）。
   - Grafana：<http://localhost:3000>，默认 admin/admin；新增数据源指向 `http://prometheus:9090`。
   - 可导入社区 Dashboard：Flink、Kafka、MySQL（推荐 ID：
     - Flink: 12019
     - Kafka Exporter: 14011
     - MySQL: 7362）

## Flink 作业部署

详细的 Flink 作业部署和故障排查指南，请参阅 [FLINK_DEPLOYMENT.md](FLINK_DEPLOYMENT.md)

### 快速提交作业

```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink run \
  -d \
  -c com.highway.etc.job.TrafficStreamingJob \
  /opt/flink/usrlib/streaming-0.1.0.jar
```

```powershell
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
   ```

   ```powershell
   docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
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
