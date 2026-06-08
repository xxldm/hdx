# Desktop 集成设计

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：设计已确认，尚未实施 Tauri 代码。
- 计划来源：HDX 后续事项总纲第 6 步
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

让 `apps/desktop` 从占位进入可实施设计，明确 desktop 技术栈、Local/Online 安装包策略、all-in-one 后端启动方式、Web 嵌入方式、本机 token 边界、Win32 能力边界和数据导入导出策略。

## 非目标

- 本轮不创建 Tauri 工程或引入 Rust/npm 依赖。
- 本轮不实现 `backend-all-in-one` sidecar 启动。
- 本轮不实现 Windows wallpaper mode。
- 本轮不实现导入导出格式。
- 本轮不实现安装器、签名、自动更新或发布流水线。
- 本轮不处理持久化 JWK、登录限流、用户管理或 App 技术栈。

## repo 内范围

- `docs/adr/0008-desktop-tauri-windows-flavors.md`
- `docs/ARCHITECTURE.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-08-desktop-integration-design.md`
- `apps/desktop/README.md`

## 当前事实

- `apps/desktop/` 当前只有占位 README，尚未绑定技术栈。
- 后端已存在 `backend-all-in-one`，用于 desktop 本机集成，绑定 `127.0.0.1`，使用 H2，并通过随机本机 token 保护 HTTP 请求。
- Web 已支持 all-in-one 模式：通过私有 `NUXT_BACKEND_LOCAL_TOKEN_HEADER` 与 `NUXT_BACKEND_LOCAL_TOKEN` 进入固定本机 public session。
- 认证边界已确认：Desktop 内置本地服务时不登录，使用 `LOCAL_ADMIN:local-admin`；Desktop 连接外部服务端时走服务端认证中心。
- 用户已确认首版可以 Windows only，但自启动、通知、deep link 等通用能力需要保留后续 macOS/Linux 实现空间。
- 用户需要调用 Win32 API，并需要类似壁纸软件的桌面嵌入窗口能力。
- 用户确认 Local/Online 通过两个不同安装包区分，不在一个运行时内随时切换；切换时通过重新安装和手动导入导出数据完成。

## 已确认设计

- Desktop 第一阶段采用 Tauri + Rust，首版 Windows first。
- `apps/desktop` 只维护一套代码，不拆成 `desktop-local` 和 `desktop-online` 两个项目。
- Local/Online 仅作为构建 flavor、Tauri 配置变体和安装包内容差异存在。
- `HDX Desktop Local`：
  - 包含 `backend-all-in-one` sidecar/native exe。
  - 仅离线/本地模式。
  - 不登录，不连接远端认证中心。
  - 使用本机 H2 数据库。
  - 身份固定为 `LOCAL_ADMIN:local-admin`。
  - 本机 token 只允许在 Tauri/Rust 主进程和受控 Nuxt server 边界内流转，不暴露给 WebView 浏览器代码。
- `HDX Desktop Online`：
  - 不包含 `backend-all-in-one`。
  - 仅在线远程模式。
  - 用户填写远端地址。
  - 通过远端 `backend-auth-service` 与 `backend-gateway` 登录和访问业务。
  - 数据保存在远端服务端。
- 通用能力抽象为 desktop capability：自启动、通知、deep link、托盘、配置目录、导入导出。
- Windows-only wallpaper mode 单独做 Win32 spike，不承诺跨平台。
- Local/Online 切换通过安装另一个 flavor 和手动导入导出完成；后续检测到另一个 flavor 时只能提示，不静默迁移。

## 本地任务清单

- [x] 读取约束、架构、质量、Git、ADR 和计划规则。
- [x] 调研 `apps/desktop` 占位、后端 all-in-one、Web all-in-one、认证 desktop 边界和总纲第 6 步。
- [x] 与用户确认 Desktop 首版技术方向、Win32 能力、Local/Online 双安装包、一套代码约束和导入导出策略。
- [x] 新增 Desktop ADR。
- [x] 更新架构文档，记录 Desktop 第一阶段设计边界。
- [x] 更新 `apps/desktop/README.md`，让子模块入口反映当前设计。
- [x] 运行文档质量门禁。
- [x] 提交并推送本轮设计文档。

## 验收标准

- 后续智能体能从 ADR 和本计划恢复 Desktop 集成设计。
- 文档明确 Tauri + Rust + Windows first 的决策。
- 文档明确 Local/Online 是两个安装包和构建 flavor，不是两套代码。
- 文档明确本机 token 不得暴露给 WebView。
- 文档明确通用能力保留跨平台实现空间，wallpaper mode 是 Windows-only。
- 文档明确首版切换 Local/Online 依赖手动导入导出，不做静默自动迁移。

## 验证方式

- `Get-Content -Encoding UTF8 docs/adr/0008-desktop-tauri-windows-flavors.md`
- `Get-Content -Encoding UTF8 docs/plans/active/2026-06-08-desktop-integration-design.md`
- `Get-Content -Encoding UTF8 docs/ARCHITECTURE.md`
- `Get-Content -Encoding UTF8 apps/desktop/README.md`
- `rg -n "Tauri|Local|Online|wallpaper|Win32|一套代码|两个安装包" docs apps/desktop`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 风险与阻塞

- Tauri 和 Rust 依赖尚未引入，真实打包能力、插件兼容性和 Windows WebView2 行为仍需后续 spike 验证。
- Windows wallpaper mode 依赖 `Progman`/`WorkerW` 等桌面窗口实现细节，Windows 版本、Explorer 重启、多显示器和 DPI 缩放可能影响稳定性。
- Local flavor 依赖 `backend-all-in-one` native exe 打包；如后续 native 构建或签名失败，需要调整打包策略。
- Online flavor 生产可用前仍依赖持久化 JWK、登录安全增强和部署发布设计。
- 手动导入导出格式尚未设计，Local/Online 数据迁移仍是后续独立事项。

## 状态记录

- 2026-06-08：用户确认进入 Desktop 集成设计讨论。
- 2026-06-08：确认首版 Windows first，自启动、通知和 deep link 等通用能力保留后续 macOS/Linux 实现空间，桌面嵌入窗口作为 Windows-only 能力。
- 2026-06-08：确认 Local/Online 用两个安装包区分：Local 包包含 all-in-one 且仅离线本地；Online 包不包含 all-in-one 且仅在线远程。
- 2026-06-08：确认 Local/Online 是一套代码的两个构建 flavor，不复制两套 desktop 项目。
- 2026-06-08：新增 ADR 0008，记录 Tauri、Windows first、Local/Online 双安装包和 Win32 wallpaper mode 边界。

## 验证结果

- 已使用 `Get-Content -Encoding UTF8` 读取 ADR、本计划、架构文档和 `apps/desktop/README.md`，确认中文内容正常。
- 已执行 `rg -n "Tauri|Local|Online|wallpaper|Win32|一套代码|两个安装包" docs apps/desktop`，确认 Desktop 关键设计可从文档入口检索。
- 已执行 `git -C apps/desktop diff --check`：通过。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖关键文档 UTF-8 读取、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- Tauri 工程尚未创建。
- Local/Online 构建 flavor 尚未实现。
- 自启动、通知、deep link 尚未接入插件。
- Windows-only wallpaper mode 尚未做 Win32 spike。
- `backend-all-in-one` sidecar 启动、健康检查、`/local/session` 获取和本机 token 注入链路尚未实现。
- 导入导出格式、校验摘要、schema 版本和手动迁移 UX 尚未设计。

## 相关 commit

- 本计划设计提交由 Git 历史体现，不在同一提交中回写自身 hash，避免递归提交。
