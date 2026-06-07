# HDX 后续事项总纲

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：第 5 步 OpenAPI 与 shared 层已完成；已落地 OpenAPI TypeScript 类型生成原型和 Web 只读类型对齐检查，不生成完整 API client，详见 `docs/plans/completed/2026-06-07-openapi-shared-layer.md`。下一步等待进入第 6 步 Desktop 集成设计前单独确认。
- 计划来源：用户要求落实 “HDX 后续事项总纲”
- 创建时间：2026-06-05
- 最后更新：2026-06-07

## 目标

按“小步确认、小步计划、小步实现”的方式推进 HDX 后续工作。

本计划只记录后续事项的顺序、目标和推进规则，不展开每一步的实现细节。每进入一个步骤前，必须重新确认该步骤的需求、取舍、范围和验证方式，并为该步骤单独列计划。

## 非目标

- 本计划不直接实施任何后续步骤。
- 本计划不替代每个步骤自己的详细计划、ADR、验证记录或提交记录。
- 本计划不在未确认前固定数据库迁移、认证、CI、OpenAPI、desktop、App、缓存、对象存储、队列或部署方案。

## repo 内范围

- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- 后续每一步自己的计划、ADR、代码、配置和验证入口将在进入对应步骤时单独确定。

## 总纲步骤

- [x] 1. 收口当前 Git 状态
- [x] 2. 数据库迁移策略
- [ ] 3. 认证与权限边界（进行中，详见 `docs/plans/active/2026-06-06-auth-permission-boundary.md`）
- [x] 4. 自动化质量门禁（最小本地脚本入口已完成，详见 `docs/plans/completed/2026-06-07-automated-quality-gate.md`）
- [x] 5. OpenAPI 与 shared 层（已完成，详见 `docs/plans/completed/2026-06-07-openapi-shared-layer.md`）
- [ ] 6. Desktop 集成设计
- [ ] 7. App 技术栈
- [ ] 8. 缓存、对象存储、队列（Redis 已因认证撤销需求提前决策，见 `docs/adr/0005-auth-revocation-redis.md`）
- [ ] 9. 部署、发布与环境管理

## 步骤目标

### 1. 收口当前 Git 状态

先处理当前根仓库与 `services/backend` 子模块各自 ahead 1 的状态。

目标：避免根仓库指向远端不存在的子模块 commit。

### 2. 数据库迁移策略

决定 PostgreSQL/H2 的迁移工具、脚本目录、命名规则和验证方式。

目标：后续新增实体和表结构时有稳定迁移入口。

### 3. 认证与权限边界

决定 JWT issuer、权限模型、Web 登录态、desktop 本机 token 的职责划分。

目标：明确 HDX 是否只接外部认证服务，以及各端如何传递身份。

### 4. 自动化质量门禁

决定本地脚本、CI、密钥检查、文档检查、子模块检查、后端/Web 验证入口。

目标：让人工和 Symphony 都有统一提交前检查。

### 5. OpenAPI 与 shared 层

决定是否从后端 OpenAPI 生成 Web TypeScript client，以及 `packages/shared` 的第一批职责。

目标：稳定 Web 与后端契约同步方式。

### 6. Desktop 集成设计

决定 desktop 技术栈、all-in-one 后端启动方式、Web 嵌入方式、本机 session/token 获取方式。

目标：让 `apps/desktop` 从占位进入可实施设计。

### 7. App 技术栈

决定 App 平台范围、技术栈、与 shared/backend 的边界。

目标：让 `apps/mobile` 从占位进入可实施设计。

### 8. 缓存、对象存储、队列

根据真实业务需求逐项决策。

目标：不提前引入基础设施，但需要时有 ADR 约束。

### 9. 部署、发布与环境管理

决定服务端部署、Web 发布、desktop 分发、环境变量和密钥管理方式。

目标：形成可重复发布路径。

## 操作规则

每一步都单独走：

1. 先确认意图和取舍。
2. 再列该步骤的详细计划。
3. 计划确认后再实现。
4. 实现后提交、验证、记录剩余风险。

## 当前已知事实

- 第 1 步已按顺序收口：先推送 `services/backend`，再推送根仓库。
- `services/backend` commit `9b1ed6a 杂项：说明 Symphony 本地环境配置` 已推送到 `origin/main`。
- 根仓库 commit `6b52844 杂项：添加 Symphony 本地环境示例` 已推送到 `origin/main`。
- 根仓库 commit `f3a0459 杂项：记录 HDX 后续事项总纲` 已推送到 `origin/main`。
- 后续进入第 2 步前，需要单独确认数据库迁移策略的需求、取舍、范围和验证方式。
- 第 2 步已确认使用 Flyway，不支持 MySQL；PostgreSQL 为服务端事实源，H2 用于 desktop all-in-one/local/test；早期本地数据可清空重建。
- 第 2 步已完成：`services/backend` 已新增 Flyway ADR、`V1__create_tool_definition.sql`、运行时 `ddl-auto: validate` 配置、测试 Flyway 集成和 README 说明。
- 用户临时要求先推进环境配置与 Nacos 分层；该切片已完成，详细记录见 `docs/plans/completed/2026-06-05-environment-nacos-config-layering.md`。这不表示第 9 步“部署、发布与环境管理”已经完整完成。
- 第 3 步认证与权限边界已完成多个小切片：认证中心、Web BFF 登录态、Web 登录页和统一当前身份接口均已实现；仍保留 desktop 切换边界、持久 JWK、登录安全增强等后续风险。
- 第 5 步 OpenAPI 与 shared 层已完成，已确认契约事实源、生成范围和 shared 首批职责；当前已建立 OpenAPI TypeScript 类型生成原型、漂移检查和 Web 只读类型对齐检查，不生成完整 API client。

## 验收标准

- 总纲存在于 `docs/plans/active/`，后续智能体可从仓库恢复推进顺序。
- 总纲只列顺序、目标和操作规则，不展开单步实现细节。
- 进入任一步骤前必须单独确认和单独计划。

## 验证方式

- 使用 `Get-Content -Encoding UTF8` 读取本文件，确认中文内容正常。
- 使用 `git status --short --branch` 确认本轮只新增总纲计划文件。

## 风险与阻塞

- 各步骤尚未展开，不能据此直接实施技术选型或架构调整。

## 状态记录

- 2026-06-05：创建后续事项总纲，当前状态为“等待进入第 1 步前单独确认”。
- 2026-06-05：完成第 1 步 Git 状态收口，已先推送 `services/backend`，再推送根仓库；当前等待进入第 2 步前单独确认。
- 2026-06-05：开始第 2 步数据库迁移策略，已确认 Flyway/PostgreSQL/H2 范围，详细计划见 `docs/plans/active/2026-06-05-database-migration-strategy.md`。
- 2026-06-05：完成第 2 步数据库迁移策略；当前等待进入第 3 步认证与权限边界前单独确认。
- 2026-06-05：按用户临时要求完成环境配置与 Nacos 分层切片；完整第 9 步仍未展开，当前仍等待进入第 3 步前单独确认。
- 2026-06-06：开始第 3 步认证与权限边界；用户确认使用自建认证中心，且认证中心按独立 `backend-auth-service` 模块设计；详细计划见 `docs/plans/active/2026-06-06-auth-permission-boundary.md`。
- 2026-06-06：确认认证授权持久化只面向服务端 PostgreSQL；all-in-one/H2 不运行认证中心、不迁移认证表，默认使用固定本机管理员身份；Desktop 连接外部服务端时走服务端认证中心。
- 2026-06-06：因登出即时生效需求，提前确认 Redis 用于 JWT `sid` 会话撤销/黑名单；该决策记录在 `docs/adr/0005-auth-revocation-redis.md`，不代表对象存储或队列已决策。
- 2026-06-07：用户确认进入第 4 步自动化质量门禁；创建本地计划，范围为最小 PowerShell 本地脚本、质量文档和入口说明。
- 2026-06-07：完成第 4 步自动化质量门禁最小本地脚本入口：新增 `scripts/quality-gate.ps1`，更新 `docs/QUALITY.md` 和根 README，并将本地计划移动到 `docs/plans/completed/`。
- 2026-06-07：用户确认进入第 5 步 OpenAPI 与 shared 层；创建本地计划，当前先确认契约事实源、生成范围和 shared 首批职责。
- 2026-06-07：第 5 步新增 ADR 0007，确认 OpenAPI TypeScript 类型生成策略为第一阶段只生成类型，不生成完整 API client，不升级根 pnpm workspace。
- 2026-06-07：第 5 步新增无外部依赖 TypeScript 类型生成原型，从 OpenAPI 快照生成 `packages/shared/generated/openapi/`，并接入质量门禁漂移检查。
- 2026-06-07：第 5 步新增 Web 只读类型对齐检查，验证 Web Zod 推导类型与 OpenAPI 生成类型兼容。
- 2026-06-07：完成第 5 步 OpenAPI 与 shared 层收口，计划移动到 `docs/plans/completed/2026-06-07-openapi-shared-layer.md`；当前等待进入第 6 步 Desktop 集成设计前单独确认。

## 验证结果

- 已使用 `Get-Content -Encoding UTF8 -Path docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md` 验证中文内容读取正常。
- 已使用 `git status --short --branch` 验证本轮根仓库变更范围。
- 已使用 `git -C services/backend status --short --branch` 确认 `services/backend` 仍为 `main...origin/main [ahead 1]`，本轮未修改子模块内部文件。
- 已使用 `git -C services/backend push origin main` 推送子模块 `main`。
- 已使用 `git push origin main` 推送根仓库 `main`。
- 第 2 步已执行 `mvn validate`、`mvn test` 和 `mvn -Pnative package '-DskipTests' '-Dnative.skip=true'`，均通过。

## 剩余风险

- 第 3 步认证与权限边界仍有后续风险：desktop all-in-one 本机 token 与外部服务端登录态切换、持久 JWK、登录安全增强和 App 登录态尚未完成。
- 第 2 步尚未运行真实 PostgreSQL 服务端 profile 启动和完整 native-image 编译；详细风险见 `docs/plans/active/2026-06-05-database-migration-strategy.md`。
- 第 5 步 OpenAPI 与 shared 层已建立 TypeScript 类型生成原型和 Web 只读类型对齐检查；尚未选择正式生成器、让 Web 运行时代码消费生成类型或确定 `packages/shared` 可安装包结构，这些作为后续独立事项处理。

## 相关 commit

- `9b1ed6a 杂项：说明 Symphony 本地环境配置`（`services/backend`）
- `6b52844 杂项：添加 Symphony 本地环境示例`（根仓库）
- `f3a0459 杂项：记录 HDX 后续事项总纲`（根仓库）
- `9090455 功能：引入 Flyway 数据库迁移`（`services/backend`）
- `3a18291 功能：添加本地质量门禁脚本`（根仓库）
- `0267873 功能：添加 Web 契约类型对齐检查`（根仓库）
