# Nacos 配置示例

本目录存放可提交的 Nacos Data ID 示例，只记录非密钥配置。

## 使用方式

后端服务端 profile 通过 `spring.config.import` 从 Nacos 读取配置：

- `backend-core-service` 默认读取 `hdx-core-service.yml`。
- `backend-auth-service` 默认读取 `hdx-auth-service.yml`。
- `backend-gateway` 默认读取 `hdx-gateway.yml`。
- 默认 Group 为 `DEFAULT_GROUP`。
- Namespace 由启动环境变量 `NACOS_NAMESPACE` 指定；为空时使用 Nacos public namespace。

如需修改 Data ID 或 Group，通过环境变量覆盖：

- `HDX_NACOS_CORE_DATA_ID`
- `HDX_NACOS_AUTH_DATA_ID`
- `HDX_NACOS_GATEWAY_DATA_ID`
- `HDX_NACOS_GROUP`

## 密钥边界

这些示例不得包含真实密码、API Key、证书、令牌或私钥。

部署时仍通过环境变量或部署平台 Secret 注入：

- `HDX_POSTGRES_PASSWORD`
- `NACOS_USERNAME`
- `NACOS_PASSWORD`

如果未来决定把密钥也托管到 Nacos，必须先新增 ADR，说明权限、加密、审计、备份和轮换策略。
