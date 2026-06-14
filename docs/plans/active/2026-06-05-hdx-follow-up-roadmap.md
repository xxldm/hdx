# HDX 后续事项总纲

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中；第 3 步认证与权限边界仍有后续风险，第 9 步部署、发布与环境管理已有 release start、release draft assemble、多后端 artifact 聚合、多历史 asset 复用、主仓库最新合格 Release 自动选择、后端 native build resolver、可选 assemble 回调。
  Web node-server asset、Desktop Online asset、Desktop Full asset 构建、Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF 也已接入；仍缺 App 构建、publish、失败清理、Desktop Full 真实安装包验证、Desktop Online 远端配置、签名/公证/自动更新、release notes 和版本号策略。
  Desktop Online 远端 Rust BFF 认证转发（登录/refresh/logout/业务请求 Bearer 注入）已实现；仍缺 App 构建、publish、失败清理、Desktop Full 真实安装包验证、签名/公证/自动更新、release notes 和版本号策略。
- 计划来源：用户要求落实 “HDX 后续事项总纲”
- 创建时间：2026-06-05
- 最后更新：2026-06-13（Desktop Online Rust BFF 认证转发）

## 目标

按“小步确认、小步计划、小步实现”的方式推进 HDX 后续工作。

本总纲只记录后续事项的顺序、当前状态、剩余风险和入口链接。每个步骤的背景、实现细节、验证命令、run id、artifact id 和提交记录由对应 ADR 或步骤计划保存。

## 非目标

- 本总纲不直接实施任何后续步骤。
- 本总纲不替代每个步骤自己的详细计划、ADR、验证记录或提交记录。
- 本总纲不复制 completed plan 的历史流水账；completed plan 作为历史审计保留。

## repo 内范围

- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- 进入具体步骤时，另行更新对应 active plan、ADR、代码、配置和验证入口。

## 总纲步骤

- [x] 1. 收口当前 Git 状态
- [x] 2. 数据库迁移策略
- [ ] 3. 认证与权限边界（进行中，详见 `docs/plans/active/2026-06-06-auth-permission-boundary.md`）
- [x] 4. 自动化质量门禁（详见 `docs/plans/completed/2026-06-07-automated-quality-gate.md`）
- [x] 5. OpenAPI 与 shared 层（详见 `docs/plans/completed/2026-06-07-openapi-shared-layer.md`）
- [x] 6. Desktop 集成设计与骨架（详见 Desktop 相关 completed plans 与 ADR 0008）
- [x] 7. App 技术栈（详见 `docs/plans/completed/2026-06-08-app-technology-stack.md` 与 ADR 0009）
- [x] 8. 缓存、对象存储、队列（详见 ADR 0005 与 ADR 0010）
- [ ] 9. 部署、发布与环境管理

## 步骤目标

### 1. 收口当前 Git 状态

目标：避免根仓库指向远端不存在的子模块 commit。

状态：已完成，历史记录保存在本计划 Git 历史和相关提交中。

### 2. 数据库迁移策略

目标：后续新增实体和表结构时有稳定迁移入口。

状态：已完成。PostgreSQL 为服务端事实源，H2 用于 desktop all-in-one、local 和测试；迁移工具为 Flyway。详见 `docs/plans/completed/2026-06-05-database-migration-strategy.md`。

### 3. 认证与权限边界

目标：明确 JWT issuer、权限模型、Web 登录态、desktop 本机 token 和各端身份传递边界。

状态：进行中。认证中心、Web BFF 登录态、Web 登录页、真实登录链路联调和统一当前身份接口已完成多个切片；剩余风险见 `docs/plans/active/2026-06-06-auth-permission-boundary.md`。

### 4. 自动化质量门禁

目标：让人工和智能体都有统一提交前检查入口。

状态：已完成最小本地脚本入口，详见 `docs/QUALITY.md` 与 `docs/plans/completed/2026-06-07-automated-quality-gate.md`。

### 5. OpenAPI 与 shared 层

目标：稳定 Web 与后端契约同步方式。

状态：已完成第一阶段。当前只生成 TypeScript 类型原型，不生成完整 API client，不升级根 pnpm workspace。详见 ADR 0006、ADR 0007 和 `docs/plans/completed/2026-06-07-openapi-shared-layer.md`。

### 6. Desktop 集成设计

目标：让 `apps/desktop` 从占位进入可实施设计和最小骨架。

状态：已完成第一阶段设计、Tauri 骨架和 Rust 验证。Windows + Linux 并列一阶段；Full/Online 为同一代码库的构建 flavor 和安装包内容差异；Windows-only wallpaper mode 需要单独 spike。详见 ADR 0008。

### 7. App 技术栈

目标：让 `apps/mobile` 从占位进入可实施设计。

状态：已完成第一阶段技术路线。Android 采用 Kotlin + Jetpack Compose；HarmonyOS NEXT 采用 ArkTS + ArkUI；首版 Online only，第二阶段只规划离线缓存/离线草稿。详见 ADR 0009。

### 8. 缓存、对象存储、队列

目标：在需要基础设施时有清晰边界，不让业务代码直接散落 SDK 调用。

状态：已完成基础设施边界。服务端使用 Redis、S3-compatible 对象存储和 RabbitMQ；对象存储默认本地/私有化候选 RustFS；Desktop all-in-one 通过 H2 outbox + local worker 降级，不内置 Redis/RabbitMQ。详见 ADR 0005 和 ADR 0010。

### 9. 部署、发布与环境管理

目标：形成可重复发布路径。

已完成或已确认：

- 公开主仓库 Apache-2.0、后端私有和禁止后端源码/JAR/WAR/`.class` 进入公开仓库，详见 ADR 0011。
- GitHub Releases 产物边界、后端 native artifact 临时交接、release manifest schema、本地 release 校验脚本、dry-run / check / debug 验证 workflow、GitHub App token 策略、后端 native 构建额度和历史 Release asset 复用策略，详见 ADR 0012、ADR 0013、ADR 0014 和 release 相关 completed plans。
- 正式 `release.yml` 第一版 draft assemble 骨架，支持多个后端 native Actions artifact 聚合或从同一个历史主仓库 Release 复用多个后端 native asset，已接入 Web node-server asset、Desktop Online asset 和 Desktop Full asset 构建，创建并远端校验 draft Release；完整能力仍需后续扩展。
- 正式 `release-start.yml` 第一版 tag start 骨架，真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文，先在主仓库判断后端历史 Release asset 是否可复用；复用成功时直接触发 `release.yml`，复用失败时触发后端私有仓库 release resolver 运行 native build；手动入口默认 dry-run。
- 后端私有仓库 `backend-release-resolve.yml` 已收缩为 native build resolver：按输入的 `backend_commit` 构建后端 native Actions artifact，并可显式回调主仓库 `release.yml` assemble；历史 Release asset 复用判断不再放在后端仓库。
- tag-only 日常发布操作手册，详见 `docs/RELEASE_RUNBOOK.md`。
- PowerShell 7+ / `pwsh` 运行边界已收口，详见 `docs/AGENT_WORKFLOW.md`。

仍未完成：

- App 构建、publish、失败清理、Desktop Full 真实安装包验证和 Desktop Online 远端配置闭环的完整自动链路。
- `backend-services-windows-x64` 真实发布验证。
- 安装器签名、公证、自动更新、release notes 和版本号策略。

## 操作规则

每一步都单独走：

1. 先确认意图和取舍。
2. 再列该步骤的详细计划。
3. 计划确认后再实现。
4. 实现后提交、验证、记录剩余风险。

## 历史明细入口

- 第 2 步：`docs/plans/completed/2026-06-05-database-migration-strategy.md`
- 第 4 步：`docs/plans/completed/2026-06-07-automated-quality-gate.md`
- 第 5 步：`docs/plans/completed/2026-06-07-openapi-shared-layer.md`
- 第 6 步：`docs/plans/completed/2026-06-08-desktop-integration-design.md`、`docs/plans/completed/2026-06-08-desktop-tauri-skeleton.md`、`docs/plans/completed/2026-06-08-desktop-rust-verification.md`、`docs/plans/completed/2026-06-08-desktop-linux-first-phase.md`
- 第 7 步：`docs/plans/completed/2026-06-08-app-technology-stack.md`
- 第 8 步：`docs/plans/completed/2026-06-08-infrastructure-cache-object-queue.md`
- 第 9 步：
  - `docs/plans/completed/2026-06-08-public-license-backend-private-boundary.md`
  - `docs/plans/completed/2026-06-08-github-releases-artifact-boundary.md`
  - `docs/plans/completed/2026-06-08-release-manifest-schema.md`
  - `docs/plans/completed/2026-06-08-release-manifest-check-script.md`
  - `docs/plans/completed/2026-06-09-release-dry-run-workflow.md`
  - `docs/plans/completed/2026-06-09-release-workflow-token-artifact-policy.md`
  - `docs/plans/completed/2026-06-09-release-app-token-check.md`
  - `docs/plans/completed/2026-06-09-backend-native-artifact-ci.md`
  - `docs/plans/completed/2026-06-09-release-backend-artifact-check.md`
  - `docs/plans/completed/2026-06-09-release-draft-minimal-workflow.md`
  - `docs/plans/completed/2026-06-09-backend-native-artifact-expanded.md`
  - `docs/plans/completed/2026-06-10-release-yml-first-slice.md`
  - `docs/plans/completed/2026-06-10-release-multi-backend-assets.md`
  - `docs/plans/completed/2026-06-10-release-historical-multi-assets.md`
  - `docs/plans/completed/2026-06-10-release-backend-source-resolver.md`
  - `docs/plans/completed/2026-06-10-release-latest-qualified-backend-reuse.md`
  - `docs/plans/completed/2026-06-10-release-native-fallback-assemble-callback.md`
  - `docs/plans/completed/2026-06-10-release-tag-start-workflow.md`

## 验收标准

- 总纲存在于 `docs/plans/active/`，后续智能体可从仓库恢复推进顺序。
- 总纲只列顺序、当前状态、剩余风险和入口链接，不展开单步实现细节。
- 进入任一步骤前必须单独确认和单独计划。

## 验证方式

- 通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。
- 本总纲更新时，至少运行 docs 范围质量门禁，确认入口文档、ADR 和计划仍可读取。

## 剩余风险

- 第 3 步认证与权限边界仍有后续风险：desktop all-in-one 本机 token 与外部服务端登录态切换、持久 JWK 已完成（密钥存储在 PostgreSQL，重启不再使 token 失效）、登录安全增强和 App 登录态尚未完成。
- 第 5 步 OpenAPI 与 shared 层尚未选择正式生成器、让 Web 运行时代码消费生成类型或确定 `packages/shared` 可安装包结构。
- 第 6 步 Desktop 的 all-in-one sidecar 最小启动、本机 token 读取、Rust BFF command 和退出清理已实现。
  Desktop 静态 Web UI 启动闭环、Desktop Online 远端配置、自启动/通知/deep link/托盘、Win32 wallpaper mode spike 和导入导出格式均未实现。
  Desktop Online 远端 Rust BFF 认证转发（登录/refresh/logout/业务请求）已实现。
- `apps/mobile` 当前仍不是独立子仓库；后续拆成公开仓库时需要补自身 Apache-2.0 `LICENSE`、`NOTICE` 和工程元数据许可声明。
- 第 9 步完整 tag-only GitHub Release workflow 仍缺 `backend-services-windows-x64`、App 真实打包、Desktop Full 真实安装包验证、Desktop Online 远端配置、完整 release artifact 上下文一致性、正式 publish、安装器签名、公证、自动更新、release notes 和版本号策略。
- 第 9 步当前子计划 `docs/plans/active/2026-06-10-web-desktop-release-artifact-contract.md` 已收口 Web/Desktop 发布产物契约、Desktop Full asset 打包第一片、Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF。
  后续继续补 App、publish、Desktop Online 远端配置和真实安装包验证。
  Desktop Online 远端 Rust BFF 认证转发已实现；后续继续补 App、publish 和真实安装包验证。

## 相关 commit

- 本总纲不维护跨步骤的完整 commit 清单；每个切片的 commit、run id、artifact id 和验证命令记录在对应步骤计划或 Git 历史中。
