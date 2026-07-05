# Nacos 配置示例

本目录存放可提交的 Nacos Data ID 示例，只记录非密钥配置。

> 公开边界提示：Nacos、Redis、PostgreSQL 等可以作为部署者需要准备的外部工具公开出现。后端模块名、服务名和 Nacos Data ID 不作为敏感内容；本目录保留公开部署所需的 Nacos 模板。后续新增或调整内部调用方式、适配器位置、公共工具模块职责拆分、具体导入顺序或服务治理实现细节时，优先维护在后端私有文档和后端私有仓库配置模板中。

## 同步规则

- 修改本目录下的模板后，必须按模板原有层级和相邻位置同步真实 Nacos 服务器中对应 Data ID 的结构，不能简单追加到文件末尾。
- 新增配置项可以直接同步到真实 Nacos；完成后必须通知用户，并提示需要填写或确认的真实值。
- 修改或删除真实 Nacos 中已有配置项前，必须先征得用户同意，避免误删或覆盖真实环境值。
- 模板中的 URL、issuer、内网地址、服务地址、用户名等占位值不能自动猜测真实值；同步结构后必须提示用户手动修改。
- 智能体通过脚本或 Nacos OpenAPI 发布真实配置时，必须显式写发布操作人：优先写 `<NACOS_USERNAME>(codex bot)`；没有 `NACOS_USERNAME` 时回退为 `codex机器人`；不得只使用 `NACOS_USERNAME`、真实用户名或留空。临时同步脚本也必须遵守这一点，例如发布请求需要携带 Nacos 接受的操作人字段。
- 同步失败时必须记录失败的 Data ID、Group、Namespace、原因和后续处理方式。

## 使用方式

后端服务端 profile 通过 `spring.config.import` 从 Nacos 读取配置。当前公开模板包括公共数据库、公共 Redis、认证入口、业务入口和内部业务服务相关 Data ID；这些 Data ID 和服务名属于部署者需要知道的公开部署信息。具体导入顺序、内部调用关系和 profile 实现细节以后端私有文档为准。

- 默认 Group 为 `DEFAULT_GROUP`。
- Namespace 由启动环境变量 `NACOS_NAMESPACE` 指定；为空时使用 Nacos public namespace。

公共数据库 Data ID 只放共用的 PostgreSQL JDBC URL 和用户名，不放密码。模块 Data ID 在公共数据库 Data ID 之后导入，因此可以在模块 Data ID 中覆盖 `spring.datasource.url` 和 `spring.datasource.username`，用于单独数据库、单独账号或临时联调。

Group 和 Data ID 已有代码默认值，通常不需要写入本地环境文件。如需改名、隔离多套环境或复用同一启动脚本连接不同 Data ID，再通过环境变量覆盖。当前公开主仓库只保留已有兼容变量；后续新增后端覆盖项以后端私有文档为准。

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
