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
   - Flink UI: http://localhost:8081

## Flink 作业部署

详细的 Flink 作业部署和故障排查指南，请参阅 [FLINK_DEPLOYMENT.md](FLINK_DEPLOYMENT.md)

### 快速提交作业
```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink run \
  -d \
  -c com.highway.etc.job.TrafficStreamingJob \
  /opt/flink/usrlib/streaming-0.1.0.jar
```

## 关闭
```bash
docker compose -f docker-compose.dev.yml down -v
```
