# Flink 作业部署指南（开发环境）

## 概览

本文档说明在开发环境中如何部署与运行 Flink 作业，并提供常见问题的中文解决方案。

## 前置条件

- 已安装 Docker Desktop（启用 WSL2）
- 机器可用内存不低于 8GB
- 已安装 Docker Compose

## 启动环境

1. 启动所有服务：

   ```powershell
   docker compose -f docker-compose.dev.yml up -d
   ```

2. 检查服务是否全部运行：

   ```powershell
   docker ps
   ```

   你应当能看到以下容器：
   - zookeeper
   - kafka
   - mysql
   - mycat
   - flink-jobmanager
   - flink-taskmanager

3. 打开 Flink UI：
   在浏览器访问 <http://localhost:8081>

## 部署 Flink 作业

### 方式一：使用 Flink CLI（推荐）

1. 将作业 JAR 放到主机目录 `infra/flink/usrlib/`（该目录通过 Compose 挂载到容器内 `/opt/flink/usrlib`）：

   - 若已构建生成 `streaming-0.1.0.jar`，将其复制到 usrlib：

     ```powershell
     Copy-Item ..\streaming\target\streaming-0.1.0.jar .\flink\usrlib\
     ```

   - 校验容器内是否可见该 JAR（避免“JAR file does not exist”错误）：

     ```powershell
     docker exec -it flink-jobmanager ls -l /opt/flink/usrlib
     ```

2. 提交作业（PowerShell 下不要使用 `\` 续行）：

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

### 方式二：使用 Flink Web UI

1. 打开 <http://localhost:8081>
2. 左侧选择 “Submit New Job”
3. 点击 “Add New” 上传 JAR 文件
4. 选择上传的 JAR
5. 在 Entry Class 填写：`com.highway.etc.job.TrafficStreamingJob`
6. 点击 “Submit”

## 监控作业

### 列出当前作业

```powershell
docker exec -it flink-jobmanager /opt/flink/bin/flink list
```

### 查看作业详情

在 Flink Web UI：<http://localhost:8081>

### 查看日志

```powershell
# JobManager 日志
docker logs flink-jobmanager

# TaskManager 日志
docker logs flink-taskmanager
```

## 停止作业

### 取消运行中的作业

```powershell
docker exec -it flink-jobmanager /opt/flink/bin/flink cancel <JOB_ID>
```

`<JOB_ID>` 可在 `flink list` 或 Web UI 中查看。

## 常见问题（中文）

### 1）提交时报错：JAR 不存在（Could not get job jar… JAR file does not exist）

可能原因：

- JAR 没有复制到主机 `infra/flink/usrlib/`，或复制后 Docker 挂载未生效。
- 使用了 Linux Shell 的换行符 `\` 在 PowerShell 中提交，导致命令解析错误。

解决步骤：

- 先在主机复制 JAR 至挂载目录：

  ```powershell
  Copy-Item ..\streaming\target\streaming-0.1.0.jar .\flink\usrlib\
  ```

- 校验容器内文件是否存在：

  ```powershell
  docker exec -it flink-jobmanager ls -l /opt/flink/usrlib
  ```

- 使用单行命令提交（PowerShell 不使用 `\` 续行）：

  ```powershell
  docker exec -it flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
  ```

### 2）NoClassDefFoundError（如 Kafka 相关类）

错误示例：

```text
java.lang.NoClassDefFoundError: org/apache/kafka/clients/consumer/OffsetResetStrategy
```

解决：确保所需依赖位于 `flink/extra-lib/` 并被挂载到容器 `/opt/flink/extra-lib`：

- kafka-clients-3.2.3.jar
- lz4-java-1.8.0.jar
- snappy-java-1.1.8.4.jar
- zstd-jni-1.5.2-1.jar

校验依赖：

```powershell
docker exec -it flink-jobmanager ls -l /opt/flink/extra-lib
```

### 3）ClassNotFoundException（缺少连接器或驱动）

原因：缺失 Connector 或 JDBC 驱动 JAR。

解决：

1. 将所需 JAR 放入 `flink/extra-lib/`
2. 重启 Flink 容器：

   ```powershell
   docker compose -f docker-compose.dev.yml restart jobmanager taskmanager
   ```

若出现 `org.apache.flink.connector.kafka.source.KafkaSource` 找不到（KafkaSource 类缺失）：

- 优先方案：将以下 JAR 复制到容器内的 `/opt/flink/lib/`（客户端与服务端均可见）：

   ```powershell
   # 复制到 JobManager
   docker exec -it flink-jobmanager sh -lc "cp /opt/flink/extra-lib/flink-connector-kafka-3.0.2-1.18.jar /opt/flink/lib/; cp /opt/flink/extra-lib/kafka-clients-3.2.3.jar /opt/flink/lib/; cp /opt/flink/extra-lib/lz4-java-1.8.0.jar /opt/flink/lib/; cp /opt/flink/extra-lib/snappy-java-1.1.8.4.jar /opt/flink/lib/; cp /opt/flink/extra-lib/zstd-jni-1.5.2-1.jar /opt/flink/lib/"
   # 复制到 TaskManager
   docker exec -it flink-taskmanager sh -lc "cp /opt/flink/extra-lib/flink-connector-kafka-3.0.2-1.18.jar /opt/flink/lib/; cp /opt/flink/extra-lib/kafka-clients-3.2.3.jar /opt/flink/lib/; cp /opt/flink/extra-lib/lz4-java-1.8.0.jar /opt/flink/lib/; cp /opt/flink/extra-lib/snappy-java-1.1.8.4.jar /opt/flink/lib/; cp /opt/flink/extra-lib/zstd-jni-1.5.2-1.jar /opt/flink/lib/"
   # 重启 Flink
   docker compose -f .\infra\docker-compose.dev.yml restart jobmanager taskmanager
   ```

- 备选方案（持久化方式）：在 `FLINK_PROPERTIES` 中加入

   ```text
   pipeline.classpaths: /opt/flink/extra-lib/*
   ```

   该方式可确保用户代码类加载器在提交阶段与运行阶段均能访问 `extra-lib` 里的依赖。

### 4）作业提交失败（服务未完全启动）

解决：

1. 启动后稍等数秒
2. 健康检查：

   ```powershell
   docker ps
   curl http://localhost:8081
   ```

### 5）连接 Kafka/MySQL 被拒绝

原因：服务未就绪或网络异常。

解决：

1. 确认容器运行：

   ```powershell
   docker ps
   ```

2. 检查 Kafka 主题：

   ```powershell
   docker exec -it kafka kafka-topics --list --bootstrap-server kafka:9092
   ```

3. 测试 MySQL 连接：

   ```powershell
   docker exec -it mysql mysql -uroot -prootpass -e "SHOW DATABASES;"
   ```

### 6）MyCat 使用 mysql 客户端报 “Access denied for user 'etcuser'”

原因：MyCat 1.x 与 mysql:8.0 客户端握手兼容性不佳，mysql 8 客户端会被 MyCat 误判为密码错误。Flink 侧 JDBC 正常，因为驱动协商了兼容的认证方式。

解决：使用 mysql 5.7 客户端访问 MyCat（已提供脚本）。

```powershell
# 示例：查询 MyCat 逻辑库（需先 docker compose up）
./scripts/mycat_client.ps1 -Command "select count(*) from traffic_pass_dev" -Database highway_etc
./scripts/mycat_client.ps1 -Command "select count(*) from stats_realtime" -Database highway_etc
./scripts/mycat_client.ps1 -Command "select count(*) from alert_plate_clone" -Database highway_etc
```

如需临时一次性命令（不走脚本）：

```powershell
docker run --rm --network infra_etcnet mysql:5.7 mysql -hmycat -P8066 -uetcuser -petcpass -D highway_etc -e "select 1"
```

## 重启服务

重启指定服务：

```powershell
docker compose -f docker-compose.dev.yml restart <service-name>
```

仅重启 Flink：

```powershell
docker compose -f docker-compose.dev.yml restart jobmanager taskmanager
```

完整重启：

```powershell
docker compose -f docker-compose.dev.yml down
docker compose -f docker-compose.dev.yml up -d
```

## 依赖检查

### 校验 Flink CLASSPATH

```powershell
docker exec -it flink-jobmanager env | grep FLINK_CLASSPATH
```

预期输出：

```text
FLINK_CLASSPATH=/opt/flink/extra-lib/*
```

### 列出可用依赖

```powershell
docker exec -it flink-jobmanager ls -lh /opt/flink/extra-lib
```

## 服务访问

- Flink Web UI：<http://localhost:8081>
- Kafka：主机 `localhost:29092`（容器内使用 `kafka:9092`）
- MySQL：`localhost:3306`（root/rootpass）
- MyCat：`localhost:8066`（JDBC），`localhost:9066`（Admin）
- Zookeeper：`localhost:2181`

## 清理

删除所有容器与卷（谨慎使用）：

```powershell
docker compose -f docker-compose.dev.yml down -v
```

## 保存点并停止所有作业

```powershell
.\scripts\savepoint_and_stop.ps1
```

## 从最近保存点恢复两个作业

```powershell
.\scripts\resume_from_last_savepoint.ps1
```

## 发送 200 条模拟数据到 etc_traffic

```powershell
.\scripts\send_mock_data.ps1 -N 200
```

## 提示脚本无法运行

用管理员或当前会话执行一次

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## 后续步骤

- 初始化 Kafka 主题：运行 `./scripts/init_kafka.sh`
- 检查数据库初始化：查看 `sql/` 下的脚本
- 在 Flink Web UI 监控作业指标
- 持续查看日志进行排障：`docker logs -f flink-jobmanager`
