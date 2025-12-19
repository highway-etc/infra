# infra

- docker-compose.dev.yml：本地开发一键拉起 Kafka / Zookeeper / MySQL / MyCat / Flink
- k8s/：生产环境 Helm/Manifests
- scripts/：初始化脚本（建库表、创建 topic 等）
- flink/：Flink 作业和依赖库

## 快速开始（本地）

1. 安装 Docker Desktop（WSL2）并启动
2. 在仓库根目录执行：

   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```

3. 验证：

   - Kafka: localhost:29092 (外部访问) / kafka:9092 (容器内访问)
   - MySQL: localhost:3306 (root/rootpass)
   - MyCat: localhost:8066 (JDBC) / localhost:9066 (Admin)
   - Flink UI: <http://localhost:8081>

   1. 向 Kafka 推送模拟数据（默认容器名 `kafka`，主题 `etc_traffic`）：

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ./scripts/send_mock_data.ps1 -N 200
   ```

   - 脚本会在 `kafka` 容器内调用 kafka-console-producer，acks=all，生成最新时间戳与 station_id（100~109）。
   - 若想改 broker/topic，使用 `-Broker` / `-Topic` 参数；容器名不同时用 `-KafkaContainer` 指定。
   - 运行后可用 MyCat 检查新数据是否写入 etc_0 / etc_1，或在 Flink UI 观察吞吐。

## Flink 作业部署

详细的 Flink 作业部署和故障排查指南，请参阅 [FLINK_DEPLOYMENT.md](FLINK_DEPLOYMENT.md)

### 快速提交作业

```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink run \
  -d \
  -c com.highway.etc.job.TrafficStreamingJob \
  /opt/flink/usrlib/streaming-0.1.0.jar
```

### 组合使用前端/后端（可选）

- 在项目根按 README（services/frontend）构建镜像后，可在 infra 同一网络下运行：

```powershell
docker run --rm -p 8080:8080 --network infra_etcnet etc-services
docker run --rm -p 8088:80   --network infra_etcnet etc-frontend
```

- 后端根路径将自动跳转到 Swagger UI；前端默认同域反代到后端。

## 关闭

```bash
docker compose -f docker-compose.dev.yml down -v
```
