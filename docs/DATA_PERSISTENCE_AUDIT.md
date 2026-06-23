# 后端数据表持久化审计

- 日期：2026-06-23
- 范围：`services/backend/backend-core` 与 `services/backend/backend-auth-service` 当前 Flyway migration 和对应 JPA 访问模型。
- 依据：ADR 0016、`docs/AUTH_DATA_MODEL.md`、`docs/ARCHITECTURE.md` 后端数据访问边界。
- 后续新增或修改后端数据访问代码时，先按 `docs/BACKEND_DATA_ACCESS.md` 的准入规则判断 JPA/JDBC、`@Version`、软删除和手写查询边界。

## 结论

当前不建议为了 ADR 0016 立即大改历史 migration。现有表里一部分是官方框架 schema 或安全流程表，本来就不适合套普通用户业务表字段；另一部分是早期业务表，后续继续扩展管理 API、用户数据同步或冲突处理时需要按 ADR 0016 迁移。

后续新增 HDX 自建、用户可感知、可修改、可删除或可同步的业务表，默认直接使用 ADR 0016 的 `version`、时间审计、`*_by_user_id` 和表内软删除字段，不再复制历史 `created_by` / `updated_by` 命名。

## backend-core

### `tool_definition`

当前状态：

- 表保存工具目录定义，字段包含 `tool_key`、显示名、描述、启用状态和创建/更新时间。
- 当前 API 已有列表和创建入口，因此它不是纯粹的代码内静态 registry。
- 表缺少 `version`、`created_by_user_id`、`updated_by_user_id`、软删除和“未删除记录唯一”语义。

审计结论：

- 如果后续仍作为可由后台或管理界面维护的工具目录表，应迁移为 ADR 0016 业务表。
- 如果真实模块接入后改成代码中心 registry 或构建期静态目录，应移除或收缩写 API，并把它记录为系统参考表例外。

建议优先级：P1。真实模块 registry 接入前先定性，避免工具定义同时存在“代码注册”和“数据库管理”两套事实源。

### `holiday`

当前状态：

- 表保存日期倒计时使用的节日定义，当前有公开只读列表和后台维护 API。
- 表已有 `version` / JPA `@Version`、`created_by_user_id`、`updated_by_user_id`、`deleted`、`deleted_at`、`deleted_by_user_id` 字段。
- 普通公开读取过滤 `enabled=true` 和 `deleted=false`；后台读取、更新和删除过滤 `deleted=false`。
- 后台更新和删除会比较客户端基础版本；冲突返回 `409`、稳定错误码、冲突元数据和服务器当前节日记录。
- 当前唯一约束仍是全局 `holiday_key`，软删除后的 key 不能复用。

审计结论：

- 节日定义已经按 ADR 0016 的普通业务表路径实现，可作为后续简单后台维护表的参考。
- 当前不支持软删除 key 复用是有意的保守边界；如果以后用户需要重建同 key 节日，再单独设计跨 PostgreSQL/H2 的“未删除记录唯一”策略。
- 农历节日、调休和复杂日历规则尚未进入模型，后续扩展前需要重新审计字段和冲突语义。

建议优先级：P2。当前固定公历节日维护能力已够用；复杂日历规则和 key 复用等需求明确后再迁移。

### `workbench_layout`

当前状态：

- 表保存工作台布局整体快照，一位 actor 一份布局，`workbench_layout_widget` 是其从属明细。
- `layout_version` 已作为布局协议版本暴露为 `schemaVersion`，记录级乐观锁使用 `record_version` / JPA `@Version`。
- 表已有 `created_by_user_id`、`updated_by_user_id`、`deleted`、`deleted_at`、`deleted_by_user_id` 字段；普通读取已通过 Repository 派生查询过滤 `deleted=false`。
- 保存时先比较客户端 `baseVersion` 与当前记录版本，冲突返回 `409`、稳定错误码、冲突元数据和服务器当前布局。
- `actor_type` / `actor_subject` 仍是早期身份抽象；ADR 0016 后，远端用户数据应优先使用稳定用户 ID，Desktop Full 使用保留本机用户 ID。
- 当前唯一约束仍是 `(actor_type, actor_subject)`，还没有表达“未删除记录唯一”。`backend-core` 迁移脚本当前要求 PostgreSQL/H2 兼容，PostgreSQL partial unique index 不能直接进入共用 migration。

审计结论：

- 工作台布局是账号级用户数据，已经完成记录版本、冲突响应和普通读取软删除过滤的第一轮对齐。
- 布局是天然整体对象，由父表保存整体 `version` 并做整体冲突检查，不要求每个 widget 明细行独立冲突。
- 下一轮应处理稳定用户 ID 边界，以及跨 PostgreSQL/H2 的“未删除记录唯一”迁移策略。

建议优先级：P1。继续推进账号级用户数据时，先补稳定用户 ID 边界；如果开放删除/重建布局功能，再优先补未删除唯一约束策略。

### `workbench_layout_widget`

当前状态：

- 明细行只属于某个 `workbench_layout`，由父布局整体保存时重建。
- 表没有自己的版本、审计和软删除字段，外键使用 `ON DELETE CASCADE`。

审计结论：

- 当前可以作为 ADR 0016 的从属明细表例外，由父布局承担审计和冲突。
- 如果以后 widget 行承载独立业务内容、独立删除历史或跨设备冲突，就不能继续把它视为纯明细。

建议优先级：跟随 `workbench_layout`，不单独迁移。

## backend-auth-service

### Spring Authorization Server 官方 OAuth2 表

涉及表：

- `auth.oauth2_registered_client`
- `auth.oauth2_authorization`
- `auth.oauth2_authorization_consent`

审计结论：

- 这些表是官方 JDBC schema，属于明确例外。
- 后续如果需要管理 OAuth2 client 的展示、启停、审计或软删除，应另建 HDX 扩展表，不直接改官方表。

### `auth_login_audit`

当前状态：

- 只追加登录成功、失败、冷却拒绝等审计记录。
- 表字段已经把操作者和来源作为业务字段表达，例如 `user_id`、`identity_id`、IP、UA 和失败原因。

审计结论：

- 追加型审计表是 ADR 0016 明确例外，不需要 `version`、`updated_by_user_id` 或软删除。

### `auth_login_session` 与 `auth_refresh_token`

当前状态：

- 两张表用于会话撤销、refresh token 轮换、复用检测和 CAS 风格状态更新。
- 状态字段包括 `revoked_at`、`revoked_by`、`consumed_at`、`replaced_by_token_id` 等。

审计结论：

- 这类安全流程表不是普通用户业务数据，不应为了形式统一强行套软删除和普通记录冲突模型。
- 如果后续加入“用户/管理员管理会话”的产品功能，撤销人字段可以评估迁移为 `revoked_by_user_id`，但仍以安全流程幂等和精确状态更新为优先。

### `auth_signing_key`

当前状态：

- 表保存 JWT 签名密钥，字段包括 `key_id`、私钥 JWK、`status`、激活和退役时间。
- 运行期轮换会退役旧 ACTIVE key 并创建新 ACTIVE key；`status` 与 `retired_at` 是密钥生命周期语义。
- 表有历史命名的 `created_by` / `updated_by`，没有 `version` 和软删除。

审计结论：

- 签名密钥是安全基础设施表，私钥材料敏感，不属于账号级用户数据。
- 不建议为它补普通业务软删除；密钥生命周期应继续由 ACTIVE / RETIRED 等状态表达。
- 如果后续扩展管理审计，可评估把操作人字段改为稳定用户 ID 命名，或记录为安全基础设施例外。

### 用户、身份、角色、权限和密码凭证表

涉及表：

- `auth.auth_user`
- `auth.auth_user_identity`
- `auth.auth_role`
- `auth.auth_permission`
- `auth.auth_password_credential`

当前状态：

- 表已有时间审计、`deleted_at`、历史 `created_by` / `updated_by` / `deleted_by` 字段。
- 唯一索引已按 `deleted_at IS NULL` 做“未删除记录唯一”，这个方向符合 ADR 0016。
- 表缺少记录级 `version`，也未使用 `*_by_user_id` 命名。

审计结论：

- 这些表属于认证域核心数据，不是跨端用户偏好，但后续如果提供用户管理、角色管理、密码管理等可变管理 API，就需要明确并发和审计规则。
- 历史字段可短期保留；下一次改 schema 或新增管理 API 时，应评估迁移到 ADR 0016 字段，或在认证数据模型里写明安全域例外。

建议优先级：P2。等真实用户/权限管理功能开始前处理，不阻塞当前工作台推进。

### `auth_user_role` 与 `auth_role_permission`

当前状态：

- 两张表保存业务事实型关联关系，已有时间审计、`deleted_at` 和历史操作人字段。
- 当前代码主要用于启动期确保初始管理员关系存在；尚未提供完整角色分配管理 API。
- 并发重复插入主要依赖 `WHERE deleted_at IS NULL` 的唯一索引兜底。

审计结论：

- 关联表不默认豁免。用户角色、角色权限这类关系本身有授权、撤销、审计价值，后续管理功能应按业务事实处理。
- 如果以后两个人同时修改同一个用户的角色集合，不能只靠当前“先查再插 + 唯一索引”逻辑表达冲突；需要记录级版本、集合整体版本，或幂等命令模型。

建议优先级：P2。角色/权限管理 API 开始前明确冲突模型和 ADR 0016 字段迁移。

## 后续优先级

1. P1：工作台布局继续推进前，设计 `workbench_layout` 的稳定用户 ID 和跨 PostgreSQL/H2 的未删除唯一约束策略。
2. P1：真实工具模块 registry 接入前，决定 `tool_definition` 是业务管理表还是系统参考表。
3. P2：`holiday` 后续如果支持软删除 key 复用、农历节日或调休规则，先重新审计唯一约束和模型边界。
4. P2：用户、角色、权限和关联表在新增管理 API 前，补齐版本与 `*_by_user_id` 迁移方案，或记录安全域例外。
5. P3：OAuth2 官方表、登录审计、会话、refresh token 和签名密钥保持例外，只在新增管理能力时重新审计。
