# infra
- docker-compose.dev.yml：本地开发一键拉起 Kafka / Zookeeper / MySQL / Redis / Flink
- k8s/：生产环境 Helm/Manifests
- scripts/：初始化脚本（建库表、创建 topic 等）

## 快速开始（本地）
1. 安装 Docker Desktop（WSL2）并启动
2. 在仓库根目录执行：
   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```
3. 验证：
   - Kafka: localhost:9092
   - MySQL: localhost:3306 (root/rootpass)
   - Redis: localhost:6379
   - Flink UI: http://localhost:8081

## 关闭
```bash
docker compose -f docker-compose.dev.yml down -v
```
