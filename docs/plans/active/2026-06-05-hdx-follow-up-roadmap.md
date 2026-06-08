# HDX 后续事项总纲

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：第 6 步 Desktop 集成设计、最小 Tauri 骨架与 Rust 编译验证已完成；后续等待确认 sidecar、本机 token、系统 capability 或 Win32 spike 的下一小步。
- 计划来源：用户要求落实 “HDX 后续事项总纲”
- 创建时间：2026-06-05
- 最后更新：2026-06-08

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
- [x] 6. Desktop 集成设计与骨架（已完成，设计见 `docs/plans/completed/2026-06-08-desktop-integration-design.md`，骨架见 `docs/plans/completed/2026-06-08-desktop-tauri-skeleton.md`，Rust 验证见 `docs/plans/completed/2026-06-08-desktop-rust-verification.md`）
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
- 第 6 步 Desktop 集成设计已确认首版采用 Tauri + Rust、Windows first、一套代码双安装包；Local 包包含 all-in-one 且仅离线本地，Online 包不包含 all-in-one 且仅在线远程。
- 第 6 步 Desktop 已创建最小 Tauri/Vite/Rust 骨架；Local/Online 通过同一代码库内的构建脚本、Tauri 配置变体和 Rust feature 区分。
- 第 6 步 Desktop Rust 编译验证已补齐：当前环境可运行 `rustc`、`cargo` 与 `rustup`，Local/Online flavor `cargo check`、Tauri permission 列举和完整 Desktop 质量门禁均已通过。

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
- 2026-06-05：开始第 2 步数据库迁移策略，已确认 Flyway/PostgreSQL/H2 范围，详细计划见 `docs/plans/completed/2026-06-05-database-migration-strategy.md`。
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
- 2026-06-07：复核 active 目录中已标记完成的历史计划，将后端 v1、Web Nuxt v1 和数据库迁移策略计划移动到 `docs/plans/completed/`，保留总纲与认证权限边界计划在 `active/`。
- 2026-06-07：复核 `docs/plans/completed/` 中的剩余风险和提交状态，将已由后续认证、Nacos、公共数据库、OpenAPI 和 Git 收口解决的历史风险更新为当前状态；仍保留 native-image、远端 CI、Desktop/App、正式生成器和运行时消费生成类型等未解决风险。
- 2026-06-08：收口 3 个小项：修正总纲第 2 步过期风险描述；复核 Web 中文文案源码未再发现 mojibake 乱码；修复并验证 `backend-auth-service` service profile 下 `/v3/api-docs` 无尾斜杠访问。
- 2026-06-08：开始第 6 步 Desktop 集成设计；新增 `docs/plans/active/2026-06-08-desktop-integration-design.md` 和 ADR 0008，记录 Tauri、Windows first、Local/Online 双安装包、一套代码和 Win32 wallpaper mode 边界。
- 2026-06-08：归档 Desktop 集成设计计划，进入 `docs/plans/active/2026-06-08-desktop-tauri-skeleton.md`，开始创建最小 Tauri 骨架和 Desktop 质量门禁入口。
- 2026-06-08：完成第 6 步 Desktop 最小 Tauri 骨架，归档 `docs/plans/completed/2026-06-08-desktop-tauri-skeleton.md`；当前等待确认第 7 步 App 技术栈或 Desktop 后续小步。
- 2026-06-08：补齐 Desktop Rust 编译验证，归档 `docs/plans/completed/2026-06-08-desktop-rust-verification.md`；当前等待确认第 7 步 App 技术栈或 Desktop 后续小步。

## 验证结果

- 已使用 `Get-Content -Encoding UTF8 -Path docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md` 验证中文内容读取正常。
- 已使用 `git status --short --branch` 验证本轮根仓库变更范围。
- 已使用 `git -C services/backend status --short --branch` 确认 `services/backend` 仍为 `main...origin/main [ahead 1]`，本轮未修改子模块内部文件。
- 已使用 `git -C services/backend push origin main` 推送子模块 `main`。
- 已使用 `git push origin main` 推送根仓库 `main`。
- 第 2 步已执行 `mvn validate`、`mvn test` 和 `mvn -Pnative package '-DskipTests' '-Dnative.skip=true'`，均通过。
- 计划归档审计已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- completed 计划风险复核已执行 stale 状态词扫描，确认不再保留“待提交”“尚未推送”“等待提交”“当前真实 Nacos 中”等已过期状态描述；并执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 3 个小项收口中已执行 Web mojibake 字符扫描，覆盖 `apps/web` 下 `*.vue`、`*.ts`、`*.js`、`*.json` 和 `*.md`，未发现 `�`、`Ã`、`Â`、`æ`、`ç`、`è`、`é`、`ä`、`å`、`ï¼`、`ã€`、`ï¿½` 等乱码特征。
- 3 个小项收口中已执行 `backend-auth-service` 临时 19082 service profile 实例验证：`/actuator/health` 返回 `200`，`/v3/api-docs` 返回 `200`，且 OpenAPI 内容包含 `/api/auth/login`、`/api/auth/refresh` 和 `/api/auth/logout`；临时实例已停止。
- 第 6 步 Desktop 集成设计已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 第 6 步 Desktop Tauri 骨架已执行 `pnpm install`、`pnpm run typecheck`、`pnpm run build:web`、`pnpm exec tauri --version`、`pnpm exec tauri dev --help`、`pnpm exec tauri build --help`、`pnpm exec tauri info`、`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope desktop -NoBuild`、`git -C apps/desktop diff --check` 和 `git diff --check`：骨架静态与前端验证通过。
- 第 6 步 Desktop Rust 验证已执行 `pnpm exec tauri info`、`cargo check --manifest-path src-tauri/Cargo.toml --features flavor-local`、`cargo check --manifest-path src-tauri/Cargo.toml --features flavor-online`、`pnpm exec tauri permission ls` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope desktop`：均通过。

## 剩余风险

- 第 3 步认证与权限边界仍有后续风险：desktop all-in-one 本机 token 与外部服务端登录态切换、持久 JWK、登录安全增强和 App 登录态尚未完成。
- 第 2 步真实 PostgreSQL 服务端 profile 启动已由后续认证/Nacos 联调覆盖；尚未单独运行完整 native-image 编译，详细风险见 `docs/plans/completed/2026-06-05-database-migration-strategy.md`。
- 第 5 步 OpenAPI 与 shared 层已建立 TypeScript 类型生成原型和 Web 只读类型对齐检查；尚未选择正式生成器、让 Web 运行时代码消费生成类型或确定 `packages/shared` 可安装包结构，这些作为后续独立事项处理。
- 第 6 步 Desktop 已创建 Tauri 工程骨架并补齐 Rust 编译验证；all-in-one sidecar 启动、本机 token 注入、真实自启动/通知/deep link/托盘、Win32 wallpaper mode spike、导入导出格式和正式品牌图标均未实现。

## 相关 commit

- `9b1ed6a 杂项：说明 Symphony 本地环境配置`（`services/backend`）
- `6b52844 杂项：添加 Symphony 本地环境示例`（根仓库）
- `f3a0459 杂项：记录 HDX 后续事项总纲`（根仓库）
- `9090455 功能：引入 Flyway 数据库迁移`（`services/backend`）
- `3a18291 功能：添加本地质量门禁脚本`（根仓库）
- `0267873 功能：添加 Web 契约类型对齐检查`（根仓库）
- `70a4b57 修复：放行认证服务 OpenAPI 端点`（`services/backend`）
