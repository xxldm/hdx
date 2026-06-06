# Nacos 配置示例

本目录存放可提交的 Nacos Data ID 示例，只记录非密钥配置。

## 使用方式

后端服务端 profile 通过 `spring.config.import` 从 Nacos 读取配置：

- `backend-core-service` 和 `backend-auth-service` 默认先可选读取公共数据库配置 `hdx-database.yml`。
- `backend-core-service` 默认读取 `hdx-core-service.yml`。
- `backend-auth-service` 默认读取 `hdx-auth-service.yml`。
- `backend-gateway` 默认读取 `hdx-gateway.yml`。
- 启用 JWT 会话撤销时，相关服务可选读取公共 Redis 配置 `hdx-redis.yml`。
- 默认 Group 为 `DEFAULT_GROUP`。
- Namespace 由启动环境变量 `NACOS_NAMESPACE` 指定；为空时使用 Nacos public namespace。

公共数据库 Data ID 只放共用的 PostgreSQL JDBC URL 和用户名，不放密码。模块 Data ID 在公共数据库 Data ID 之后导入，因此可以在模块 Data ID 中覆盖 `spring.datasource.url` 和 `spring.datasource.username`，用于单独数据库、单独账号或临时联调。

如需修改 Data ID 或 Group，通过环境变量覆盖：

- `HDX_NACOS_DATABASE_DATA_ID`
- `HDX_NACOS_CORE_DATA_ID`
- `HDX_NACOS_AUTH_DATA_ID`
- `HDX_NACOS_GATEWAY_DATA_ID`
- `HDX_NACOS_REDIS_DATA_ID`
- `HDX_NACOS_GROUP`

## 密钥边界

这些示例不得包含真实密码、API Key、证书、令牌或私钥。

部署时仍通过环境变量或部署平台 Secret 注入：

- `HDX_POSTGRES_PASSWORD`
- `HDX_AUTH_POSTGRES_PASSWORD`：可选，认证服务专用数据库密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_CORE_POSTGRES_PASSWORD`：可选，核心服务专用数据库密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_REDIS_PASSWORD`
- `NACOS_USERNAME`
- `NACOS_PASSWORD`

如果未来决定把密钥也托管到 Nacos，必须先新增 ADR，说明权限、加密、审计、备份和轮换策略。
