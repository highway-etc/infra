# 用 MySQL 5.7 客户端连接 MyCat，避免 MySQL 8 客户端与 MyCat 1.x 的认证兼容性问题。
# 使用方式示例：
#   ./scripts/mycat_client.ps1 -Command "select 1" -Database highway_etc
#   ./scripts/mycat_client.ps1 -Command "show tables" -Database highway_etc
#   ./scripts/mycat_client.ps1 -Command "select count(*) from traffic_pass_dev" -Database highway_etc

param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [string]$Database = "highway_etc",
    [string]$User = "etcuser",
    [string]$Password = "etcpass",
    [int]$Port = 8066,
    [string]$Host = "mycat",
    [string]$Network = "infra_etcnet"
)

# 以一次性容器运行 mysql:5.7 客户端，连接 MyCat。
# 注意：宿主机需已启动 docker-compose（mycat 容器在线）。

docker run --rm --network $Network mysql:5.7 `
  mysql -h$Host -P$Port -u$User -p$Password -D $Database -e "$Command"
