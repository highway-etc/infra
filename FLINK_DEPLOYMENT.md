# Flink Job Deployment Guide

## Overview
This guide explains how to deploy and run Flink jobs in the development environment.

## Prerequisites
- Docker Desktop with WSL2 enabled
- At least 8GB of available RAM
- Docker Compose

## Starting the Environment

1. Start all services:
   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```

2. Verify all services are running:
   ```bash
   docker ps
   ```
   
   You should see containers for:
   - zookeeper
   - kafka
   - mysql
   - mycat
   - flink-jobmanager
   - flink-taskmanager

3. Check Flink UI:
   Open http://localhost:8081 in your browser

## Deploying a Flink Job

### Method 1: Using the Flink CLI

1. Copy your JAR file to `flink/usrlib/`:
   ```bash
   cp your-streaming-job.jar flink/usrlib/
   ```

2. Submit the job:
   ```bash
   docker exec -it flink-jobmanager /opt/flink/bin/flink run \
     -d \
     -c com.highway.etc.job.TrafficStreamingJob \
     /opt/flink/usrlib/streaming-0.1.0.jar
   ```

   Parameters:
   - `-d`: Run in detached mode
   - `-c`: Specify the main class
   - Last argument: Path to your JAR file

### Method 2: Using the Flink Web UI

1. Open http://localhost:8081
2. Click "Submit New Job" in the left menu
3. Click "Add New" and upload your JAR file
4. Select the uploaded JAR
5. Enter the Entry Class: `com.highway.etc.job.TrafficStreamingJob`
6. Click "Submit"

## Monitoring Jobs

### List Running Jobs
```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink list
```

### View Job Details
Check the Flink Web UI at http://localhost:8081

### Check Job Logs
```bash
# JobManager logs
docker logs flink-jobmanager

# TaskManager logs
docker logs flink-taskmanager
```

## Stopping Jobs

### Cancel a Running Job
```bash
docker exec -it flink-jobmanager /opt/flink/bin/flink cancel <JOB_ID>
```

Get the JOB_ID from `flink list` or the Web UI.

## Troubleshooting

### Common Issues

#### 1. NoClassDefFoundError for Kafka Classes

**Error:**
```
java.lang.NoClassDefFoundError: org/apache/kafka/clients/consumer/OffsetResetStrategy
```

**Solution:**
Ensure all required dependencies are in `flink/extra-lib/`:
- kafka-clients-3.2.3.jar
- lz4-java-1.8.0.jar
- snappy-java-1.1.8.4.jar
- zstd-jni-1.5.2-1.jar

Check the dependencies:
```bash
docker exec -it flink-jobmanager ls -l /opt/flink/extra-lib
```

#### 2. ClassNotFoundException

**Cause:** Missing connector or driver JAR files

**Solution:**
1. Add the required JAR to `flink/extra-lib/`
2. Restart the Flink containers:
   ```bash
   docker compose -f docker-compose.dev.yml restart jobmanager taskmanager
   ```

#### 3. Job Submission Failed

**Cause:** Flink services not fully started

**Solution:**
1. Wait a few seconds after starting containers
2. Check service health:
   ```bash
   docker ps
   curl http://localhost:8081
   ```

#### 4. Connection Refused to Kafka/MySQL

**Cause:** Services not ready or network issues

**Solution:**
1. Verify all containers are running:
   ```bash
   docker ps
   ```

2. Check if Kafka topics exist:
   ```bash
   docker exec -it kafka kafka-topics --list --bootstrap-server kafka:9092
   ```

3. Test MySQL connection:
   ```bash
   docker exec -it mysql mysql -uroot -prootpass -e "SHOW DATABASES;"
   ```

### Restarting Services

Restart a specific service:
```bash
docker compose -f docker-compose.dev.yml restart <service-name>
```

Restart Flink only:
```bash
docker compose -f docker-compose.dev.yml restart jobmanager taskmanager
```

Complete restart:
```bash
docker compose -f docker-compose.dev.yml down
docker compose -f docker-compose.dev.yml up -d
```

## Checking Dependencies

### Verify Flink Classpath
```bash
docker exec -it flink-jobmanager env | grep FLINK_CLASSPATH
```

Should output:
```
FLINK_CLASSPATH=/opt/flink/extra-lib/*
```

### List Available Libraries
```bash
docker exec -it flink-jobmanager ls -lh /opt/flink/extra-lib
```

## Accessing Services

- **Flink Web UI:** http://localhost:8081
- **Kafka:** localhost:29092 (from host) or kafka:9092 (from containers)
- **MySQL:** localhost:3306 (root/rootpass)
- **MyCat:** localhost:8066 (JDBC), localhost:9066 (Admin)
- **Zookeeper:** localhost:2181

## Clean Up

Remove all containers and volumes:
```bash
docker compose -f docker-compose.dev.yml down -v
```

This will delete all data. Use with caution!

## Next Steps

- Initialize Kafka topics: `./scripts/init_kafka.sh`
- Check database initialization: Review SQL scripts in `sql/`
- Monitor job metrics via Flink Web UI
- View logs for debugging: `docker logs -f flink-jobmanager`
