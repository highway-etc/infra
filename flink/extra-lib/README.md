# Flink Extra Libraries

This directory contains additional JAR files that are required by the Flink jobs but are not included in the base Flink distribution.

## Required Dependencies

### Flink Connectors
- **flink-connector-kafka-3.0.2-1.18.jar** - Flink Kafka connector for reading/writing from Kafka
- **flink-connector-jdbc-3.1.2-1.18.jar** - Flink JDBC connector for database operations

### Kafka Client Dependencies
The Kafka connector requires the Apache Kafka client library:
- **kafka-clients-3.2.3.jar** - Apache Kafka client library (required by flink-connector-kafka)

### Kafka Client Runtime Dependencies
The Kafka client requires compression libraries:
- **lz4-java-1.8.0.jar** - LZ4 compression codec
- **snappy-java-1.1.8.4.jar** - Snappy compression codec
- **zstd-jni-1.5.2-1.jar** - Zstandard compression codec

### Database Drivers
- **mysql-connector-j-8.3.0.jar** - MySQL JDBC driver

## Version Compatibility

- Flink Version: 1.18.1
- Scala Version: 2.12
- Kafka Client Version: 3.2.3 (compatible with Kafka broker 2.8+)
- MySQL Connector Version: 8.3.0

## Docker Configuration

These libraries are mounted into the Flink containers via the `docker-compose.dev.yml` configuration:

```yaml
volumes:
  - ./flink/extra-lib:/opt/flink/extra-lib
environment:
  - FLINK_CLASSPATH=/opt/flink/extra-lib/*
```

This ensures that all JARs in this directory are available on the Flink classpath at runtime.

## Troubleshooting

If you encounter `NoClassDefFoundError` exceptions, verify that:

1. All required JAR files are present in this directory
2. The `FLINK_CLASSPATH` environment variable includes `/opt/flink/extra-lib/*`
3. The JAR versions are compatible with your Flink version (1.18.1)
4. For Kafka-related errors, ensure kafka-clients and its compression dependencies are present

## Adding New Dependencies

When adding new Flink connector dependencies:

1. Add the connector JAR to this directory
2. Check the connector's POM file for transitive dependencies
3. Add any required transitive dependencies that are not provided by Flink
4. Update this README with the new dependency information
