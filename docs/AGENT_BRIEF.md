# 智能体短入口

本文档是每次开工的低 token 入口。它只放当前仓库地图、必须先知道的规则和详细文档路由；不要把长过程日志写进这里。

## 开工顺序

1. 先读 `AGENTS.md`、本文档和 `docs/CONSTRAINTS.md`。
2. 用 `git status --short --branch` 看根仓库状态；涉及子模块时再分别看对应子模块状态。
3. 检查全部子模块状态时使用 `scripts/git-submodule-status.ps1`，不要在 Windows/Codex 环境里用 `git submodule foreach`。
4. 按本文档的“按需阅读路由”打开任务相关详细文档，不要默认通读所有 active plan 和 ADR。
5. 修改前确认是否需要本地计划；跨模块、跨多次提交、架构、安全、高风险或长期工作必须更新 `docs/plans/active/`。
6. 完成后按变更范围运行验证，并按根仓库与子模块分开提交。

## 仓库地图

- `services/backend/`：后端私有子模块；公开主仓库只保留交付和集成摘要。后端模块名、服务名、Nacos Data ID、OpenAPI 快照名和 release asset 名不敏感；Nacos、Redis、PostgreSQL 等外部工具可作为部署依赖公开出现。后端内部调用链、运行拓扑、迁移、基础设施接入方式、公共工具模块职责拆分、native 诊断和验证细节见 `services/backend/README.md` 与 `services/backend/docs/README.md`。后端 Codex 技能真实内容在 `services/backend/.codex/skills/`。
- `apps/web/`：Web 子模块，Nuxt 4、Nuxt UI、Pinia、Zod、pnpm；Web Online 通过 Nuxt server BFF 调后端。
- Web/Backend 子模块的 Codex 技能由根仓库 `.codex/skills/hdx-web-*` 和 `.codex/skills/hdx-backend-*` wrapper 暴露；wrapper 由 `scripts/sync-skill-wrappers.ps1` 统一生成，description 继承真实技能 description。
- `apps/desktop/`：Desktop 子模块，Tauri + Rust + Vite + TypeScript；Full 使用本机 sidecar，Online 连接远端服务。
- `apps/mobile/`：App 工程容器；后续 Android Kotlin + HarmonyOS NEXT ArkTS，首版 Online only。
- `packages/shared/`：跨端契约、OpenAPI 生成类型、release manifest schema 和常量说明；当前不是可安装包。
- `docs/`：根项目文档，覆盖除后端内部实现以外的入口、约束、ADR、计划、公开契约、部署配置和未归档讨论结论。文档分层边界见 `docs/DOCUMENTATION_BOUNDARY.md`。
- `services/backend/docs/`：后端项目文档，覆盖后端内部 ADR、计划、数据模型、接口草案、通知调度、治理、诊断和验证细节。

## 当前事实

- 后端、Web、Desktop、App、基础设施、公开许可和发布边界已有 ADR 约束；调整技术栈或职责前必须补 ADR。
- 公开主仓库历史按敏感路径裁剪；不要从公开仓库旧 refs 推回旧历史。
- 公开文档边界检查的通用入口在 `scripts/check-public-doc-boundary.ps1`；后端私有精确规则在 `services/backend/docs/config/public-doc-boundary-rules.psd1`，没有后端私有仓库权限时脚本会跳过该规则文件。
- 本机旧 `internal-docs` 子模块 Git 元数据已清理；清理前备份 bundle 见 `docs/plans/completed/2026-07-05-documentation-governance-and-migration.md`。
- `services/backend` 后续维持私有仓库；公开主仓库禁止提交后端源码快照、JAR/WAR、`.class` 或后端构建中间产物。
- 公开 Release 后端包只发布 native，不发布 JVM JAR/WAR、`.class` 或源码快照；JVM 只作为开发、测试、CI 或内部排障形态。
- 后端交付形态分为 Desktop Full 本机后端、服务端微服务部署和服务端单体部署；服务/模块名称可以在公开部署模板、OpenAPI 和 release 包中出现，具体依赖、调用链、配置加载细节和验证入口只在后端私有文档维护。
- 后端内部契约、模块职责拆分和调用关系不写入根仓库 `packages/shared/contracts`；根仓库 shared 只放多端公开契约和 release/schema 契约。
- Web 浏览器不直接访问后端；浏览器调 Nuxt server BFF，Nuxt server 保存敏感 token。
- Web 首页工具箱当前按桌面浏览器交互设计，不做手机 Web 专项适配；但关键操作仍需保留桌面宽度触摸输入的 tap 或显式入口兜底。
- Desktop WebView 不保存本机 token、access token 或 refresh token；Desktop Rust BFF 负责持有本机 sidecar token 或远端登录态。
- Desktop Full/Online 互相搬家只通过用户主动导入导出 `.hdxbak` 备份包，不做自动同步、迁移或合并；备份包不导出公开数据、token、会话、权限授予记录或治理记录。
- App 不复用 Tauri，不内置本机后端；首版只连接远端认证入口与业务入口。
- 用户数据持久化与同步边界见 ADR 0016：Web/Desktop Online 以后端为事实源，App 可弱网/无网暂存草稿后同步，Desktop Full 走本机数据库。
- Tauri app config 只管纯客户端配置；计时器运行状态是设备级状态，不跨设备同步。
- 错误响应以稳定 `code` 为跨端协议字段，后端中文 `message` 只是 fallback；UI 可以把多个 code 合并为粗粒度用户文案。

## 当前重点

- 认证边界：账号密码登录、refresh/logout、服务端会话撤销能力、Web 登录页、当前身份接口、错误码契约和安全链 JSON 错误已实现。
- 认证剩余风险：尚未实现注册、找回密码、验证码、MFA、用户管理、OAuth2 client 初始化/管理、JWK 多实例刷新和 RETIRED key 清理策略。
- Desktop：Full sidecar 最小闭环已实现；Online 已有远端地址保存、健康检查、远端登录、refresh、logout 和业务请求 Bearer 注入，token 不暴露给 WebView。
- Release：`v0.0.0-preview.5` 已验证 tag-only 预览发布和 Full Linux AppImage sidecar/API smoke；后端 native 交付边界已确认，服务端单体 artifact 尚未接入 release。后端 native/AOT 细节、依赖裁剪和验证流水账只在后端私有文档维护。当前未恢复 preview/stable tag 或远端 release native 验证，App 暂不进入发布闭环。
- 文档体量控制：active plan 只记录当前状态、关键决策、验证摘要和剩余风险；历史过程日志应归档或收敛，避免无限增长。

## 按需阅读路由

- 通用硬规则：`docs/CONSTRAINTS.md`。
- 架构职责、依赖方向或技术栈：`docs/ARCHITECTURE.md`，再读相关 ADR。
- 质量门禁、测试和提交前检查：`docs/QUALITY.md`。
- 命令权限、PowerShell、提权失败处理：`docs/AGENT_WORKFLOW.md`。
- Git 提交、推送、子模块指针：`docs/GIT.md`。
- 本地计划规则：`docs/plans/README.md`；进行中计划先读 `docs/plans/active/README.md`，再读 `docs/plans/follow-up/README.md`，然后按需打开具体计划。
- 认证、权限、登录态、错误码：先读本文“当前重点”、`docs/ARCHITECTURE.md`、`docs/ENVIRONMENT.md` 和 `docs/adr/0005-auth-revocation-redis.md`；涉及后端实现、迁移、会话撤销、JWK 或测试细节时再读 `services/backend/README.md` 与 `services/backend/docs/README.md`。
- 认证数据模型、`auth` schema、migration 和表字段：先读 `services/backend/README.md` 与 `services/backend/docs/README.md`；根仓库不再保留认证表结构入口。
- 后端实现、模块职责拆分、调用关系、运行拓扑、数据库迁移、基础设施适配、native/AOT 诊断或后端验证：先读 `services/backend/README.md` 与 `services/backend/docs/README.md`。根仓库只保留公开摘要和必要模块/服务名，不复制后端私有细节。
- 后端 Entity、Repository、migration、JPA/JDBC、乐观锁、软删除和数据库访问风格：先使用 `.codex/skills/hdx-backend-data-access/SKILL.md`，再读 `docs/BACKEND_DATA_ACCESS.md` 和后端私有文档入口。
- 用户数据持久化和跨端同步公开边界：`docs/adr/0016-user-data-persistence-and-sync-boundary.md`。现有后端表审计和迁移细节走 `services/backend/README.md` 与 `services/backend/docs/README.md`；根仓库不再保留后端表审计入口。
- 工具箱 widget registry、模块配置、设备运行态和 layout 边界：`docs/WORKBENCH_WIDGET_CONTRACT.md`，再按需读 `docs/plans/active/2026-06-16-web-toolbox-layout-grid.md`。
- Todo、日程事项、规则生成、通知中心、公开主页、公开流或协作事项：计划状态和公开摘要读 `docs/plans/active/2026-06-26-todo-rule-generated-tasks-and-notification-center.md`；尚未归档的公开讨论结论读 `docs/discussions/README.md`；涉及权限矩阵、数据模型、接口草案、通知调度、公开治理、同步规则或实现切片时读 `services/backend/docs/plans/README.md` 后再按需打开具体文档。
- Release、后端 native artifact、GitHub Actions 产物复用、后端 standalone/local/services 交付边界：先读 `docs/plans/active/README.md`。
  公开交付边界读 `docs/adr/0017-backend-native-delivery-and-standalone-boundary.md`、`docs/RELEASE_RUNBOOK.md`、`docs/plans/active/2026-06-09-release-native-build-budget-and-reuse.md` 或 `docs/plans/active/2026-06-10-web-desktop-release-artifact-contract.md`；后端内部实现和验证细节读 `services/backend/docs/README.md`。
- Desktop Full/Online、导入导出和备份包：`apps/desktop/README.md`、`docs/adr/0008-desktop-tauri-windows-linux-flavors.md`、`docs/adr/0018-desktop-backup-import-export-boundary.md`，需要发布上下文时再读 release 计划。
- App：`apps/mobile/README.md`、`docs/adr/0009-mobile-native-online-first.md`。
- OpenAPI/shared 契约：`packages/shared/README.md`、`docs/adr/0006-openapi-and-shared-contract-boundary.md`、`docs/adr/0007-openapi-typescript-generation-strategy.md`。
- Nacos 配置：`docs/config/nacos/README.md` 和对应 `docs/config/nacos/*.yml` 模板。
- 环境变量：`docs/ENVIRONMENT.md`、对应 `.env.example` 或 `.env.symphony.example`。

## 常用命令

```powershell
git status --short --branch
pwsh -NoLogo -NoProfile -File scripts/git-submodule-status.ps1 -RepoRoot D:\Project\hdx
pwsh -NoLogo -NoProfile -File scripts/verify-changed.ps1
pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope changed
pwsh -NoLogo -NoProfile -File scripts/openapi-verify.ps1
```

后端：

```powershell
git -C services/backend status --short --branch
pwsh -NoLogo -NoProfile -File scripts/start-backend-services.ps1
pwsh -NoLogo -NoProfile -File scripts/check-backend-data-access.ps1 -ChangedOnly
pwsh -NoLogo -NoProfile -File scripts/backend-verify.ps1
pwsh -NoLogo -NoProfile -File scripts/backend-verify.ps1 -AotSmoke
pwsh -NoLogo -NoProfile -File scripts/backend-verify.ps1 -NoBuild
```

Web：

```powershell
git -C apps/web status --short --branch
pwsh -NoLogo -NoProfile -File scripts/start-web-dev.ps1 -StatusOnly
pwsh -NoLogo -NoProfile -File scripts/start-web-dev.ps1
pwsh -NoLogo -NoProfile -File scripts/web-verify.ps1
pwsh -NoLogo -NoProfile -File scripts/web-verify.ps1 -Build
```

Web pnpm 质量命令在 Codex Windows sandbox 中有已知普通权限 `EPERM`；运行 `scripts/web-verify.ps1` 或底层 pnpm 验证前，按 `docs/AGENT_WORKFLOW.md` 的权限规则直接走审批/提权，不再先普通权限试跑。
Web dev server 检查/启动也统一走 `scripts/start-web-dev.ps1` 并直接提权；不要用普通权限端口检测结果判断 3000 是否关闭，避免误起第二个 Nuxt 服务。`apps/web/scripts/web-dev-runner.mjs dev` 已做端口预检，目标端口占用时会失败，不再让 Nuxt 自动切到 3001。

Desktop：

```powershell
git -C apps/desktop status --short --branch
pnpm run typecheck
cargo check --manifest-path apps/desktop/src-tauri/Cargo.toml --features flavor-full
cargo check --manifest-path apps/desktop/src-tauri/Cargo.toml --features flavor-online
```

## 提交与推送

- 子模块改动先在子模块内提交并推送，再在根仓库提交子模块指针和根文档。
- 常见顺序：`services/backend`、`apps/web`、`apps/desktop`，最后根仓库。
- 可用 `scripts/git-commit-stack.ps1 -DryRun -StageAll ...` 先预览分仓库提交，再去掉 `-DryRun` 串行提交子模块和根仓库。
- 可用 `scripts/git-push-stack.ps1 -DryRun` 先预览分仓库推送，再去掉 `-DryRun` 串行推送子模块和根仓库。
- 推根仓库前确认子模块工作区干净，并确认根仓库记录的子模块 commit 已推送到各自远端。
- Git 写操作和网络操作通常需要审批/提权；同类权限失败不要反复普通权限重试。

## 配置同步提醒

- 修改 `docs/config/nacos/` 模板后，必须按模板层级和相邻位置同步真实 Nacos Data ID；新增项可直接补齐，修改或删除已有项先征得用户同意。
- 发布真实 Nacos 配置时操作人优先写 `<NACOS_USERNAME>(codex bot)`；没有 `NACOS_USERNAME` 时回退为 `codex机器人`。
- 修改 `.env.example` 或 `.env.symphony.example` 后，必须同步对应本地 `.env.local` 或 `.env.symphony.local` 的结构；新增变量提示用户填写真实值，修改或删除已有变量先确认。

## 文档写入节制

- 短入口只放可长期复用的当前事实和路由，不放长验证日志。
- active plan 顶部 `active-plan-status` 状态块是任务状态单一事实源；`docs/plans/active/README.md` 由脚本生成索引，其他文档不要复制细状态。
- active plan 正文只保留恢复上下文所需的信息：关键决策、最近有效验证、剩余风险和相关 commit。
- 命令踩坑、环境坑和可复用操作纪律写入 `docs/AGENT_WORKFLOW.md` 或自动化脚本，不写进 active plan。
- 重复验证只记录最后一次有效结果；普通命令输出不整段粘贴。
- 稳定长期决策进入 ADR 或架构文档；过期过程记录归档到 completed/history，而不是继续堆在 active plan。
