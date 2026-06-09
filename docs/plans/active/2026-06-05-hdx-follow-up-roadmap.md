# HDX 后续事项总纲

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：第 9 步发布与环境管理已完成公开许可、后端私有边界、GitHub Releases 产物边界、release manifest schema 设计、本地 release JSON Schema 校验和样例检查、主仓库 release dry-run workflow 骨架与 GitHub-hosted 实跑验证、真实 release workflow 凭据与 artifact 策略、GitHub App token metadata 验证、后端 `backend-full-linux-x64` native artifact 最小生产入口、主仓库后端 artifact 下载校验 GitHub-hosted 实跑验证、draft Release 最小闭环 GitHub-hosted 实跑验证，以及 PowerShell 7+ / `pwsh` 运行边界收口；当前等待真实完整 GitHub Release workflow、安装器签名、公证、自动更新、release notes 或版本号策略等后续小步。
- 计划来源：用户要求落实 “HDX 后续事项总纲”
- 创建时间：2026-06-05
- 最后更新：2026-06-09

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
- [x] 7. App 技术栈（已完成，详见 `docs/plans/completed/2026-06-08-app-technology-stack.md`）
- [x] 8. 缓存、对象存储、队列（已完成基础设施边界决策，见 `docs/adr/0010-cache-object-storage-queue-boundary.md`；Redis 认证撤销见 `docs/adr/0005-auth-revocation-redis.md`）
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
- 第 6 步 Desktop 集成设计已确认采用 Tauri + Rust、Windows + Linux 并列一阶段、一套代码双安装包；Local 包包含 all-in-one 且仅离线本地，Online 包不包含 all-in-one 且仅在线远程。
- 第 6 步 Desktop 已创建最小 Tauri/Vite/Rust 骨架；Local/Online 通过同一代码库内的构建脚本、Tauri 配置变体和 Rust feature 区分。
- 第 6 步 Desktop Rust 编译验证已补齐：当前环境可运行 `rustc`、`cargo` 与 `rustup`，Local/Online flavor `cargo check`、Tauri permission 列举和完整 Desktop 质量门禁均已通过。
- 第 7 步 App 技术栈已确认：Android 采用 Kotlin + Jetpack Compose；HarmonyOS NEXT 采用 ArkTS + ArkUI；App 不复用 Desktop Tauri shell；首版 Online only，第二阶段只做离线缓存/离线草稿，不规划移动端 all-in-one 或完整离线业务引擎。
- 第 8 步基础设施边界已确认：对象存储使用 S3-compatible 核心子集，默认本地/私有化候选 RustFS，后续可切云端 OSS/COS/OBS/S3。
- 第 8 步基础设施边界已确认：服务端/云端队列默认 RabbitMQ；业务代码通过端口、transactional outbox、消息 envelope 和幂等 consumer 隔离。
- 第 8 步基础设施边界已确认：Redis 是服务端基础设施；Desktop all-in-one 不内置 Redis/RabbitMQ，服务端反滥用能力默认禁用或 no-op，本地异步任务使用 H2 outbox + local worker。
- 第 9 步发布与环境管理的第一小步已确认：公开主仓库采用 Apache-2.0；后端仓库维持私有；公开主仓库禁止提交后端源码、JAR/WAR 和 `.class` 构建产物；后端 release 目标为 native executable archive。
- 第 9 步许可边界补充确认：除后端外，后续公开仓库统一 Apache-2.0；`apps/web` 与 `apps/desktop` 已在各自子仓库补齐 `LICENSE`、`NOTICE` 和 package `license` 字段；`apps/mobile` 当前仍为根仓库占位目录，后续拆为独立仓库时再补自身许可文件。
- 第 9 步 GitHub Releases 产物边界已确认：主仓库是唯一公开发布入口；后端私有仓库先编译 native，并只通过 GitHub Actions artifact 临时交接；主仓库 Release 公开 Web、Desktop Online、Desktop Full、后端 `backend-full` 和 `backend-services` 平台聚合包，以及后续 App Online 包；App 不内置后端；发布流程不使用 `latest`。
- 第 9 步 release manifest schema 已确认：`packages/shared/contracts/release/` 定义 `backend-native-manifest.json`、`release-manifest.json`、`backend-build.json` 和 `backend-services-manifest.json` 的 JSON Schema，后续 workflow 必须据此校验发布事实源、commit、OpenAPI hash 和 sha256。
- 第 9 步本地 release 校验脚本最小入口已确认：`scripts/release-manifest-check.ps1` 已接入 docs 质量门禁；后续已在该入口上补齐 JSON Schema 子集校验、样例检查和可选真实文件 sha256/size 校验。
- 第 9 步本地 release 校验已补齐 JSON Schema 子集校验和样例检查：`scripts/release-manifest-check.ps1` 当前默认校验 schema 文件、最小有效样例、schema 无效样例、sha256 不匹配样例和禁止文件扫描样例；传入 `-AssetRoot` 时可校验真实文件 sha256 与 `sizeBytes`。
- 第 9 步主仓库 release dry-run workflow 已确认并实跑通过：`.github/workflows/release-dry-run.yml` 支持手动输入 `version`、`root_ref` 和 `dry_run`，只演练输入校验、指定 root ref checkout、子模块指针记录、release manifest 校验和摘要输出；不初始化私有后端子模块、不下载后端 artifact、不创建 GitHub Release、不上传 asset、不使用跨仓库凭据；当前使用 `actions/checkout@v6.0.3`。
- 第 9 步真实 release workflow 凭据与 artifact 策略已确认：跨仓库自动化使用 GitHub App token；后端 Actions artifact `retention-days: 1`；第一版不自动复用历史 Release 资产；每个 Release 资产必须来自本次 workflow 构建，或来自明确指定 `run_id` 和 artifact name 的短期 Actions artifact；真实 Release 先创建 draft，资产上传和远端校验通过后再 publish。
- 第 9 步 GitHub App token 最小验证入口已新增并实跑通过：`.github/workflows/release-app-token-check.yml` 手动验证 GitHub App token 可读取后端私有仓库和公开主仓库 metadata；不读取或下载 Actions artifact、不创建 Release、不上传 asset、不 checkout 后端私有源码；当前使用 `HDX_RELEASE_APP_CLIENT_ID` 和 `client-id` 输入，切换后 GitHub-hosted run `27187218112` 已通过且未再出现 `app-id` 弃用提示。
- 第 9 步后端 native artifact 最小生产入口已在私有后端仓库新增并实跑通过：`backend-native-artifact.yml` 第一版只生产 `backend-full-linux-x64`，通过 `backend-all-in-one` native archive 与 `backend-native-manifest.json` 上传 Actions artifact，保留期 1 天；GitHub-hosted run `27188320676` 成功，artifact `hdx-backend-native-v0.0.0-artifact-test.2-linux-x64` 的 ID 为 `7500484195`，过期时间为 `2026-06-10T06:52:18Z`。
- 第 9 步主仓库后端 artifact 下载校验入口已新增并实跑通过：`.github/workflows/release-backend-artifact-check.yml` 使用 GitHub App token 读取指定后端 run artifact 列表并下载 artifact，`scripts/release-backend-artifact-check.ps1` 校验 manifest 上下文、sha256/size 和禁止文件扫描；GitHub-hosted run `27190000244` 已成功校验后端 artifact `7500484195`。
- 第 9 步 draft Release 最小闭环已新增并实跑通过：`.github/workflows/release-draft-minimal.yml` 使用 GitHub App token 下载后端 artifact、创建主仓库 draft Release、上传后端 native archive 与最小 manifest 资产，并从远端下载回校验 size 和 sha256；GitHub-hosted run `27191204936` 已成功创建测试 draft Release `v0.0.0-artifact-test.2`。
- PowerShell 脚本运行边界已收口：仓库内 `.ps1` 脚本要求 PowerShell 7+ / `pwsh`，不支持 Windows PowerShell 5.1；脚本中的中文输出、错误提示和帮助文本应直接写为可读中文；docs 质量门禁不再执行 BOM/转义专项检查。

## 验收标准

- 总纲存在于 `docs/plans/active/`，后续智能体可从仓库恢复推进顺序。
- 总纲只列顺序、目标和操作规则，不展开单步实现细节。
- 进入任一步骤前必须单独确认和单独计划。

## 验证方式

- 使用 PowerShell 7+ / `pwsh` 读取本文件，确认中文内容正常。
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
- 2026-06-06：因登出即时生效需求，提前确认 Redis 用于 JWT `sid` 会话撤销/黑名单；该决策记录在 `docs/adr/0005-auth-revocation-redis.md`，当时不代表对象存储或队列已决策；后续第 8 步已由 ADR 0010 补齐基础设施边界。
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
- 2026-06-08：开始第 6 步 Desktop 集成设计；新增 `docs/plans/active/2026-06-08-desktop-integration-design.md` 和 ADR 0008，记录 Tauri、Windows first、Local/Online 双安装包、一套代码和 Win32 wallpaper mode 边界；后续已修订为 Windows + Linux 并列一阶段。
- 2026-06-08：归档 Desktop 集成设计计划，进入 `docs/plans/active/2026-06-08-desktop-tauri-skeleton.md`，开始创建最小 Tauri 骨架和 Desktop 质量门禁入口。
- 2026-06-08：完成第 6 步 Desktop 最小 Tauri 骨架，归档 `docs/plans/completed/2026-06-08-desktop-tauri-skeleton.md`；当前等待确认第 7 步 App 技术栈或 Desktop 后续小步。
- 2026-06-08：补齐 Desktop Rust 编译验证，归档 `docs/plans/completed/2026-06-08-desktop-rust-verification.md`；当前等待确认第 7 步 App 技术栈或 Desktop 后续小步。
- 2026-06-08：完成第 7 步 App 技术栈；新增 ADR 0009，并归档 `docs/plans/completed/2026-06-08-app-technology-stack.md`，记录 Android 原生、HarmonyOS NEXT 原生、Online only first 和离线缓存/草稿两阶段。
- 2026-06-08：按用户要求将 Linux 纳入 Desktop 第一阶段，与 Windows 并列；ADR 0008 文件名和正文修订为 Windows/Linux 双平台 Local/Online 安装包，Windows-only wallpaper mode 边界不变。
- 2026-06-08：完成第 8 步缓存、对象存储与队列基础设施边界；新增 ADR 0010，记录 RustFS/S3-compatible、RabbitMQ、Redis 服务端用途和 all-in-one H2 outbox + local worker 降级策略。
- 2026-06-08：完成第 9 步第一小步“公开许可与后端私有边界”；新增 ADR 0011，记录公开主仓库 Apache-2.0、后端私有、后端不发布 JAR/WAR、用户可见本地完整模式后续称 Full。
- 2026-06-08：按用户确认补齐公开子仓库许可边界；`apps/web` 与 `apps/desktop` 统一 Apache-2.0，后端仓库继续保持私有且不随公开许可授权。
- 2026-06-08：完成第 9 步 GitHub Releases 产物边界；新增 ADR 0012，记录后端 native 只通过 GitHub Actions artifact 临时交接、主仓库 Release 公开后端 native archive、App Online only 和后端微服务平台聚合压缩包策略。
- 2026-06-08：完成第 9 步 release manifest schema 设计；新增 `packages/shared/contracts/release/`，记录 4 个发布 manifest 的 JSON Schema 与使用说明。
- 2026-06-08：完成第 9 步本地 release 校验脚本原型；新增 `scripts/release-manifest-check.ps1` 并接入 docs 质量门禁。
- 2026-06-08：完成 PowerShell 7+ / `pwsh` 运行边界收口；项目不再支持 Windows PowerShell 5.1，不再要求 `.ps1` UTF-8 with BOM，也不再把 `Get-Content -Encoding UTF8` 作为读取文档强制规则。
- 2026-06-09：补齐第 9 步本地 release JSON Schema 校验和样例检查；`scripts/release-manifest-check.ps1` 已覆盖当前 release schema 使用到的 JSON Schema 子集、可选 `-AssetRoot` sha256/size 校验、最小有效样例、schema 无效样例、sha256 不匹配样例和禁止文件扫描样例。
- 2026-06-09：新增第 9 步主仓库 release dry-run workflow 骨架；该 workflow 只演练校验入口和发布顺序，不执行真实发布、不下载后端 artifact、不初始化私有后端子模块。
- 2026-06-09：主仓库 release dry-run workflow 已在 GitHub-hosted runner 实跑通过；成功 run `27184350227` 使用 `version=v0.0.0-dry-run.4`、`root_ref=8e66341feb32e1ea42a920785b5cc0577ae19686`，所有步骤成功，且升级到 `actions/checkout@v6.0.3` 后不再出现 Node.js 20 弃用 annotation。
- 2026-06-09：新增 ADR 0013，确认真实 release workflow 使用 GitHub App token、后端 Actions artifact 保留 1 天、第一版不自动复用历史 Release 资产，并通过 draft Release 完成上传校验后再 publish。
- 2026-06-09：新增主仓库 GitHub App token 最小验证 workflow；该 workflow 只验证 GitHub App token 读取仓库 metadata，不执行真实发布、不读取后端 artifact；GitHub-hosted run `27186745870` 已通过。
- 2026-06-09：用户删除 `HDX_RELEASE_APP_ID` 后，主仓库 GitHub App token 最小验证 workflow 已切换为 `HDX_RELEASE_APP_CLIENT_ID` 和 `client-id` 输入；GitHub-hosted run `27187218112` 已通过，日志筛选未命中 `deprecated`。
- 2026-06-09：完成后端 native artifact 最小 CI；私有后端仓库提交 `4a869d5` 新增 `backend-full-linux-x64` 手动 workflow 与打包脚本，提交 `051760d` 修复 workflow 中 Maven `-D` 参数的 PowerShell 引用问题；GitHub-hosted run `27188320676` 已成功产出 artifact `7500484195`，并已下载到本地通过根仓库 release manifest 校验。
- 2026-06-09：完成主仓库后端 artifact 下载校验；新增本地校验脚本和手动 workflow，本地已用 run `27188320676` 产出的 artifact 校验通过，主仓库 GitHub-hosted run `27190000244` 已成功用 GitHub App token 下载并校验 artifact `7500484195`。
- 2026-06-09：完成 draft Release 最小闭环；新增最小 Release 资产整理脚本和手动 workflow，本地已用 run `27188320676` 产出的 artifact 生成并校验候选资产，主仓库 GitHub-hosted run `27191204936` 已成功创建测试 draft Release、上传资产并远端下载校验。

## 验证结果

- 已使用 PowerShell 7+ / `pwsh` 读取 `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`，验证中文内容读取正常。
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
- 第 8 步缓存、对象存储与队列基础设施边界已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 第 9 步第一小步公开许可与后端私有边界已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 公开子仓库 Apache-2.0 许可同步已执行 `rg -n "Apache-2.0|Apache License|backend|后端|license" apps/web apps/desktop docs/adr/0011-public-license-and-backend-private-boundary.md`、`git -C apps/web diff --check`、`git -C apps/desktop diff --check` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过；`diff --check` 仅提示 package.json 后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- 第 9 步 GitHub Releases 产物边界已执行 `rg -n "GitHub Releases|Actions artifact|backend-services|backend-full|latest|App 不内置后端|后端源码" docs README.md`、`git diff --check` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 第 9 步 release manifest schema 设计已执行 PowerShell `ConvertFrom-Json` 解析 4 个 schema 文件、`rg -n "backend-native-manifest|release-manifest|backend-build|backend-services-manifest|JSON Schema|latest" packages/shared/contracts/release docs README.md`、`git diff --check` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 第 9 步本地 release 校验脚本原型已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`、临时禁止文件扫描负例、`git diff --check` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- PowerShell 编码债务收口已执行 BOM 检查、`\uXXXX` 转义扫描、PowerShell AST 解析检查、`scripts/release-manifest-check.ps1`、`scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`、`git diff --check` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 第 9 步 release JSON Schema 校验补齐已执行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过，确认合法样例、sha256 匹配样例、schema 负例、sha256 不匹配负例和禁止文件扫描负例均按预期。
- 第 9 步 release JSON Schema 校验补齐已执行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -ScanPath packages/shared/contracts/release`：通过，确认样例目录不会污染 release 契约目录的禁止文件扫描。
- 第 9 步 release JSON Schema 校验补齐已执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认 docs 质量门禁已运行 release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查。
- 第 9 步主仓库 release dry-run workflow 已执行 workflow 静态边界扫描、`actionlint`、`scripts/release-manifest-check.ps1`、docs 质量门禁和 GitHub-hosted runner 实跑；成功 run `27184350227`，详细记录见 `docs/plans/completed/2026-06-09-release-dry-run-workflow.md`。
- 第 9 步真实 release workflow 凭据与 artifact 策略已新增 ADR 0013；本轮验证结果见 `docs/plans/completed/2026-06-09-release-workflow-token-artifact-policy.md`。
- 第 9 步 GitHub App token 最小验证 workflow 已执行 `actionlint`、docs 质量门禁和 GitHub-hosted runner 实跑；`app-id` 版本成功 run `27186745870`，切换为 `client-id` 后成功 run `27187218112`，详细记录见 `docs/plans/completed/2026-06-09-release-app-token-check.md`。
- 第 9 步后端 native artifact 最小 CI 已执行后端本地 dry-run、`actionlint`、`mvn validate`、PowerShell 引用修复验证、GitHub-hosted native run 和下载后 release manifest 校验；成功 run `27188320676`，详细记录见 `docs/plans/completed/2026-06-09-backend-native-artifact-ci.md`。
- 第 9 步主仓库后端 artifact 下载校验已执行本地脚本、`actionlint`、docs 质量门禁、空白检查和 GitHub-hosted run `27190000244`；详细记录见 `docs/plans/completed/2026-06-09-release-backend-artifact-check.md`。
- 第 9 步 draft Release 最小闭环已执行本地脚本、`actionlint`、docs 质量门禁、空白检查、GitHub-hosted run `27191204936` 和 draft Release 资产清单校验；详细记录见 `docs/plans/completed/2026-06-09-release-draft-minimal-workflow.md`。

## 剩余风险

- 第 3 步认证与权限边界仍有后续风险：desktop all-in-one 本机 token 与外部服务端登录态切换、持久 JWK、登录安全增强和 App 登录态尚未完成。
- 第 2 步真实 PostgreSQL 服务端 profile 启动已由后续认证/Nacos 联调覆盖；尚未单独运行完整 native-image 编译，详细风险见 `docs/plans/completed/2026-06-05-database-migration-strategy.md`。
- 第 5 步 OpenAPI 与 shared 层已建立 TypeScript 类型生成原型和 Web 只读类型对齐检查；尚未选择正式生成器、让 Web 运行时代码消费生成类型或确定 `packages/shared` 可安装包结构，这些作为后续独立事项处理。
- 第 6 步 Desktop 已创建 Tauri 工程骨架、补齐 Rust 编译验证，并已将用户指定的 `favicon3.ico` 复制为 Tauri Windows 图标；all-in-one sidecar 启动、本机 token 注入、真实自启动/通知/deep link/托盘、Win32 wallpaper mode spike 和导入导出格式均未实现。
- `apps/mobile` 当前仍不是独立子仓库；后续拆成公开仓库时需要补自身 Apache-2.0 `LICENSE`、`NOTICE` 和 package/工程元数据许可声明。
- 第 9 步发布产物边界、release manifest schema、本地 JSON Schema 校验、release dry-run workflow 骨架、GitHub-hosted dry-run 实跑、真实 release workflow 凭据与 artifact 策略、GitHub App token metadata 验证入口、后端 `backend-full-linux-x64` native artifact 最小 CI、主仓库后端 artifact 下载校验和 draft Release 最小闭环均已实跑通过；完整真实 GitHub Release workflow、`backend-services` 聚合包、Windows native artifact、完整 release artifact 上下文一致性、正式 publish、安装器签名、公证、自动更新、release notes 和版本号策略尚未实现。

## 相关 commit

- `9b1ed6a 杂项：说明 Symphony 本地环境配置`（`services/backend`）
- `6b52844 杂项：添加 Symphony 本地环境示例`（根仓库）
- `f3a0459 杂项：记录 HDX 后续事项总纲`（根仓库）
- `9090455 功能：引入 Flyway 数据库迁移`（`services/backend`）
- `3a18291 功能：添加本地质量门禁脚本`（根仓库）
- `0267873 功能：添加 Web 契约类型对齐检查`（根仓库）
- `70a4b57 修复：放行认证服务 OpenAPI 端点`（`services/backend`）
