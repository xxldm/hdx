# 认证数据模型

本文档记录 `backend-auth-service` 当前服务端认证授权数据模型。日常判断认证下一步时先读 active 计划；只有修改 Flyway migration、实体模型、JDBC repository、OpenAPI 身份字段或权限后台时，再读本文。

## 事实源

- 运行时事实源是 `services/backend/backend-auth-service/src/main/resources/db/migration/` 下的 Flyway migration。
- 本文是结构化阅读入口，避免把字段清单塞回 active plan；如果 migration 变更，必须同步更新本文。
- 认证授权数据只面向服务端 PostgreSQL `auth` schema；`backend-all-in-one` / H2 本机模式不运行认证中心，也不维护这套 schema。
- OAuth2/Spring Authorization Server 官方表直接贴近框架 JDBC schema，不增加 HDX 自有软删除、时间审计或操作人审计字段。
- 自有用户、角色、权限、凭证、会话、签名密钥和审计表使用数字主键；令牌、密码和私钥只保存哈希或服务端私有材料，不能把明文凭证暴露给 Web/App。

## 表清单

### `auth.auth_user`

用途：用户主体和权限归属点，不直接保存 `username`、`email` 或 `phone`。

字段：

- `id`
- `display_name`
- `enabled`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

规则：

- `display_name` 只用于回显，不参与日志、审计、权限判断或业务规则。
- `enabled=false` 表示整个用户主体被禁用，该用户下所有登录标识都不能登录。

### `auth.auth_user_identity`

用途：用户登录标识。当前启用 `USERNAME`，后续可扩展 `EMAIL`、`PHONE`。

字段：

- `id`
- `user_id`
- `identity_type`
- `identifier`
- `normalized_value`
- `verified_at`
- `enabled`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束与索引：

- `user_id` 外键引用 `auth.auth_user(id)`。
- 未删除记录的 `identity_type + normalized_value` 唯一。
- `user_id` 索引用于按用户查询登录标识。
- `identity_type + normalized_value` 索引用于登录查询。

规则：

- `identifier` 保存原始标识，用于回显或排障。
- `normalized_value` 保存归一化查询值，用于唯一约束和登录查询。
- `verified_at` 表示登录标识已验证；邮箱和手机号登录启用时必须按该字段判断是否允许登录。
- `enabled=false` 只禁用某个登录标识，不等同于禁用整个用户。

### `auth.auth_role`

用途：角色定义。

字段：

- `id`
- `code`
- `name`
- `description`
- `enabled`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束：

- 未删除记录的 `code` 唯一。

规则：

- `code` 是角色稳定业务标识，不用于用户端展示。
- `name` 用于管理界面或排障回显。

### `auth.auth_permission`

用途：权限定义。

字段：

- `id`
- `code`
- `name`
- `description`
- `enabled`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束：

- 未删除记录的 `code` 唯一。

规则：

- `code` 是权限稳定业务标识，优先使用 `resource:action` 风格，例如 `tool:read`、`tool:write`、`user:manage`。
- `name` 用于管理界面或排障回显。

### `auth.auth_user_role`

用途：用户与角色关系。

字段：

- `id`
- `user_id`
- `role_id`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束与索引：

- `user_id` 外键引用 `auth.auth_user(id)`。
- `role_id` 外键引用 `auth.auth_role(id)`。
- 未删除记录的 `user_id + role_id` 唯一。
- `user_id` 索引用于按用户查询角色。
- `role_id` 索引用于按角色反查用户。

规则：

- 角色授予用户主体，不授予某个登录标识。

### `auth.auth_role_permission`

用途：角色与权限关系。

字段：

- `id`
- `role_id`
- `permission_id`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束与索引：

- `role_id` 外键引用 `auth.auth_role(id)`。
- `permission_id` 外键引用 `auth.auth_permission(id)`。
- 未删除记录的 `role_id + permission_id` 唯一。
- `role_id` 索引用于按角色查询权限。
- `permission_id` 索引用于按权限反查角色。

### `auth.auth_password_credential`

用途：第一方账号密码登录凭证。

字段：

- `id`
- `user_id`
- `password_hash`
- `password_updated_at`
- `enabled`
- `created_at`
- `updated_at`
- `deleted_at`
- `created_by`
- `updated_by`
- `deleted_by`

约束：

- `user_id` 外键引用 `auth.auth_user(id)`。
- 未删除记录的 `user_id` 唯一，当前每个用户主体只有一份启用中的密码凭证。

规则：

- 只保存密码哈希，不保存明文密码。
- 密码登录失败和冷却审计不应回滚凭证或会话事务之外的审计记录。

### `auth.auth_login_session`

用途：认证中心会话，承载 `sid`、客户端类型和撤销状态。

字段：

- `id`
- `sid`
- `user_id`
- `client_type`
- `created_at`
- `updated_at`
- `expires_at`
- `last_access_token_expires_at`
- `revoked_at`
- `revoked_by`
- `revoke_reason`

约束与索引：

- `user_id` 外键引用 `auth.auth_user(id)`。
- `sid` 唯一。
- `user_id` 索引用于按用户查询会话。

规则：

- 登出或 refresh token 复用风险事件会撤销当前 `sid`。
- gateway 负责检查 Redis 中的 `sid` 撤销记录；`backend-core-service` 不作为外部入口时不重复检查。

### `auth.auth_refresh_token`

用途：第一方登录 refresh token 轮换和复用检测。

字段：

- `id`
- `token_hash`
- `session_id`
- `issued_at`
- `expires_at`
- `consumed_at`
- `revoked_at`
- `replaced_by_token_id`

约束与索引：

- `session_id` 外键引用 `auth.auth_login_session(id)`。
- `replaced_by_token_id` 外键引用 `auth.auth_refresh_token(id)`。
- `token_hash` 唯一。
- `session_id` 索引用于按会话查询 refresh token。

规则：

- 只保存 refresh token 哈希，不保存明文 token。
- refresh token 被消费后会被新 token 替换；复用已消费 token 时撤销整个 `sid` 会话。

### `auth.auth_signing_key`

用途：认证中心 JWT 签名密钥持久化与轮换基础设施。

字段：

- `id`
- `key_id`
- `private_key_jwk`
- `status`
- `activated_at`
- `retired_at`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

约束与索引：

- `key_id` 唯一。
- `status` 索引用于读取 ACTIVE / RETIRED 密钥。
- `status = 'ACTIVE'` 的 partial unique index 保证最多只有一个 ACTIVE 密钥。

规则：

- 唯一 ACTIVE 密钥用于新 token 签发。
- ACTIVE + RETIRED 密钥共同出现在 `/oauth2/jwks` 供旧 token 验签。
- 运行期轮换管理接口尚未实现；后续接口必须保证 retire/activate 原子性并记录审计。
- `private_key_jwk` 是服务端私有材料，不得进入公开日志、前端、App 或 release 产物。

### `auth.auth_login_audit`

用途：账号密码登录审计和失败冷却统计。

字段：

- `id`
- `normalized_identifier`
- `user_id`
- `identity_id`
- `client_type`
- `success`
- `failure_reason`
- `client_ip`
- `user_agent`
- `attempted_at`

约束与索引：

- `user_id` 外键引用 `auth.auth_user(id)`，可为空以记录账号不存在。
- `identity_id` 外键引用 `auth.auth_user_identity(id)`，可为空以记录账号不存在。
- `normalized_identifier + attempted_at` 索引用于按账号标识统计失败窗口。
- `user_id + attempted_at` 索引用于后续按用户查询审计记录。

规则：

- 成功、账号不存在、密码错误和冷却拒绝都写入审计。
- 失败冷却当前按账号标识统计；IP、设备、验证码、MFA 和异常登录告警仍是后续风险。
- 日志和排障输出不得泄露完整凭证、access token、refresh token 或私钥上下文。

## OAuth2 官方表

以下表采用 Spring Authorization Server JDBC schema，字段以 `V2__create_oauth2_authorization_server_tables.sql` 和当前框架版本为准：

- `auth.oauth2_registered_client`
- `auth.oauth2_authorization`
- `auth.oauth2_authorization_consent`

规则：

- 不给官方表添加 HDX 自有软删除、时间审计或操作人审计字段。
- 后续如果需要管理 OAuth2 client 展示、启停或 HDX 审计信息，另建扩展表，不修改官方表结构。

## 维护要求

- 新增或修改 `auth` schema migration 时，先确认是否影响认证边界、OpenAPI、Web/App 显示或安全风险。
- 修改 migration、实体模型或 JDBC repository 后，必须同步本文和认证 active plan 的当前状态或剩余风险。
- 当前 active 计划只保留推进状态和风险；字段清单归本文，不再写回 `docs/plans/active/2026-06-06-auth-permission-boundary.md`。
