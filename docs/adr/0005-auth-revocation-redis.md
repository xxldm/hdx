# ADR 0005：JWT 会话撤销使用 Redis

- 日期：2026-06-06
- 状态：已接受

## 背景

HDX 服务端认证中心使用 JWT/OAuth2。JWT access token 是自包含令牌，如果资源服务只校验签名和过期时间，用户登出后旧 access token 在过期前仍然可以访问受保护接口。

用户确认 HDX 需要登出即时生效，并采用 “JWT + 撤销表/黑名单” 策略。Redis 已作为运行时基础设施准备就绪；本 ADR 只记录项目架构决策，不记录本机临时 Docker Compose 创建方式。

## 决策

- access token 继续使用 JWT。
- JWT 必须包含 `sid` claim，表示一次登录会话。
- 登出、强制下线、refresh token 重放或高风险会话失效时，认证中心把对应 `sid` 写入 Redis 撤销索引。
- Redis key 使用 `hdx:auth:revoked-session:<sid>`，其中 `hdx:auth` 可通过配置调整。
- 撤销记录必须设置 TTL，至少覆盖该会话下所有尚未过期 access token 的剩余有效期，并加少量时钟偏移缓冲。
- 资源访问必须经过 `backend-gateway`。gateway 在 JWT 基础校验通过后检查 Redis；如果 `sid` 已撤销，则拒绝请求。
- `backend-core-service` 当前不重复检查 Redis，前提是它不作为外部 API 入口暴露，不允许绕过 gateway 直接访问。
- Redis 不可用时，gateway 对受保护请求 fail-closed，返回 `503 Service Unavailable`，不得静默放行。
- `jti` 作为单 token 撤销粒度暂不实现；后续有单 token 撤销需求时再补充。

## 备选方案

- 只缩短 access token 有效期并撤销 refresh token：实现简单，但登出不是即时生效。
- 按 `jti` 拉黑单个 token：粒度更细，但一次登录会话可能经过 refresh 产生多个 access token，登出场景需要撤销整个会话，先用 `sid` 更直接。
- PostgreSQL 撤销表：功能可行，但 gateway 每次请求查关系数据库不适合作为高频认证路径。
- opaque token + introspection：撤销语义更集中，但会让每次资源访问依赖认证中心或 introspection 缓存，当前阶段复杂度更高。

## 影响范围

- `backend-auth-service` 后续负责在登出和高风险会话失效时写入 Redis 撤销记录。
- `backend-gateway` 负责读取 Redis 并拒绝已撤销 `sid`。
- `backend-core-service` 依赖 gateway 作为唯一外部资源入口。
- Nacos 示例增加公共 Redis Data ID；Redis 地址、端口、database 和 timeout 放 Nacos，密码通过环境变量或部署 Secret 注入。
- 环境文档增加 Redis 配置和密钥边界。

## 验证方式

- gateway 单元测试覆盖：
  - 未撤销 `sid` 放行。
  - 已撤销 `sid` 返回 `401`。
  - JWT 缺少 `sid` 返回 `401`。
  - Redis 查询失败返回 `503`。
- 后续 auth-service 实现登出后，需补集成验证：登录获取 JWT，登出写入 Redis 后，同一个 `sid` 的旧 JWT 访问 gateway 被拒绝。

## 回滚条件

- 业务确认不再要求登出即时生效，只接受短 access token 的时间窗口。
- 目标部署环境无法提供 Redis 或等效低延迟共享存储。

回滚时需移除 gateway 撤销检查、auth-service 撤销写入和 Redis 配置，并把策略退回为短 access token + refresh token 撤销。

## 后续事项

- 认证中心签发 access token 时加入 `sid` claim。
- 确认 access token 有效期、refresh token 有效期和撤销 TTL 缓冲。
- 实现 auth-service 登出接口和 Redis 撤销写入。
- Web BFF 登出时调用认证中心登出，并清理自身 session/cookie。
