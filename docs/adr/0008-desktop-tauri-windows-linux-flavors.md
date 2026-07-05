# ADR 0008：Desktop 采用 Tauri 与 Windows/Linux 双平台 Full/Online 安装包

- 日期：2026-06-08
- 状态：已接受
- 修订：2026-07-05 使用公开交付名称；后端模块名/服务名不敏感，数据库、认证实现、职责拆分和调用关系以后端私有文档为准。

## 背景

HDX 需要 desktop 客户端承载两类场景：

- 离线本机使用：随客户端带 Desktop Full 本机后端，使用本机数据库和本机固定身份。
- 在线远程使用：不带本机后端，连接远端认证入口与业务入口，使用服务端账号登录。

项目已确认：

- Desktop Full 本机后端只服务本机 sidecar 场景，通过随机本机 token 保护 HTTP 请求。
- Desktop Full 本机模式不运行服务端认证中心，默认使用固定本机身份。
- 远程服务端模式走自建认证中心、Web BFF 登录态、JWT 和 Redis 会话撤销。
- Web 浏览器代码不得直接持有本机 token、access token 或 refresh token。
- Desktop 第一阶段需要同时覆盖 Windows 与 Linux。Windows 需要调用 Win32 API，包括类似壁纸软件的桌面窗口嵌入能力；自启动、通知、URL scheme、托盘、配置目录和导入导出作为通用 desktop capability 在 Windows 与 Linux 上逐项落地。

## 决策

Desktop 第一阶段采用 **Tauri + Rust**，平台范围为 **Windows + Linux 并列一阶段**。

Desktop 只有一套代码，位于 `apps/desktop/`。Full/Online 只作为构建 flavor 和安装包差异存在，不复制两套 desktop 项目。

产物分为两个安装包：

- `HDX Desktop Full`
  - 包含 Desktop Full 本机后端 sidecar/native exe。
  - 仅支持离线/本地模式。
  - 不登录，不连接远端认证中心。
  - 使用本机数据库。
  - 使用固定本机身份。
  - 本机 token 只允许由 Tauri/Rust 主进程读取，并在 Rust BFF command 边界内使用；不得暴露给 WebView 浏览器代码。
- `HDX Desktop Online`
  - 不包含 Desktop Full 本机后端。
  - 仅支持在线远程模式。
  - 用户填写远端地址。
  - 走远端认证入口与业务入口登录和访问业务 API。
  - 数据保存在远端服务端。

通用 desktop 能力必须抽象为 capability，例如自启动、通知、deep link、托盘、配置目录、导入导出。Windows 与 Linux 在第一阶段并列实现或验证这些 capability；macOS 不进入第一阶段，后续如需支持再单独决策。

Win32 API 只能在 Rust 层封装，前端 WebView 只能调用受控 Tauri command。禁止前端传入任意 Win32 API 名称、任意命令行或未校验路径。

类似壁纸软件的桌面嵌入能力定义为 **Windows-only wallpaper mode**：

- 该能力可以使用 Win32 API，例如查找 `Progman`/`WorkerW`、获取 Tauri 窗口 `HWND`、`SetParent`、`SetWindowLongPtrW`、`SetWindowPos`。
- 该能力必须单独做 spike 验证，覆盖 Explorer 重启、多显示器、DPI 缩放、焦点和任务栏行为。
- 该能力不承诺跨平台；Linux/macOS 不需要提供等价功能。Linux 第一阶段只覆盖通用 desktop capability 和 Full/Online flavor，不包含 wallpaper mode。

Full/Online 切换策略：

- 不在同一个运行时里随时切换 Full 和 Online。
- 用户切换模式时安装另一个 flavor。
- 首版只提供手动导入/导出数据。
- 后续如果检测到另一个 flavor 已安装，只能提示用户可导入数据，不得静默读取或迁移对方数据。
- 导入包必须包含版本号、来源模式、导出时间、数据 schema 版本和校验摘要；具体 `.hdxbak` 格式、版本兼容、导出范围和不导出公开数据规则见 ADR 0018。

## 影响

- `apps/desktop/` 后续可以引入 Tauri、Rust、Tauri 官方插件、Windows API 绑定和 Linux 平台适配。
- 自启动、通知和 deep link 优先使用 Tauri 官方插件或稳定社区插件；缺口再用 Rust/平台 API 补齐。
- Windows-only 能力必须通过条件编译或 capability 层隔离，避免污染通用 desktop 代码。
- Linux 平台能力必须同样通过 capability 层隔离，避免把 Linux 桌面环境差异泄漏到 WebView 前端。
- Full flavor 打包流程需要包含 Desktop Full 本机后端 sidecar/native exe；Online flavor 必须验证不包含该 sidecar。
- Desktop 发布、签名、安装器、自动更新和跨平台打包仍归第 9 步“部署、发布与环境管理”单独设计。
- 持久化 JWK、登录限流和服务端生产安全硬化仍是认证后续风险；Online flavor 生产可用前必须补齐对应能力。

## 备选方案

- Electron：Node 生态成熟，桌面插件丰富，但 Win32 深度能力常需要 native addon/ffi，应用体积和安全边界更难收束。
- 一套安装包内运行时切换 Full/Online：用户体验更灵活，但会混合同一客户端内的本机管理员身份、远程用户身份、本机 token、远程 token 与数据源，安全边界和排障成本更高。
- 两套 desktop 代码：短期分离清楚，但长期会重复维护 UI、系统能力、导入导出、窗口和托盘逻辑，违反本项目共享边界和维护成本约束。
- Web/PWA only：无法满足 Win32 API、自启动、桌面嵌入和本机后端 sidecar 管理需求。

## 后续实现记录

- 2026-06-13：Desktop 发布包方向收敛为静态 Web UI + Rust BFF，不为 Desktop 内置 Node/Nitro 子进程。
  Web Online 仍保持 Nuxt SSR/Nitro；Desktop 静态 UI 通过 Tauri command 调用 Rust BFF，Full flavor 的本机 token 只留在 Rust 主进程内。

## 验证方式

本 ADR 阶段只固定设计，不引入 Tauri 代码。通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。

本 ADR 特有检查：

- Full/Online 一套代码约束、Windows-only wallpaper mode 和 Tauri 决策在相关文档中可发现。
- 后续实施 Tauri 骨架时，必须补充：
  - Full flavor 不暴露本机 token 给 WebView 的验证。
  - Online flavor 不包含 Desktop Full 本机后端 sidecar 的打包检查。
  - Windows 与 Linux 两个平台的 Full/Online flavor 打包检查。
  - Win32 wallpaper mode spike 的手工验证记录。
  - 自启动、通知、deep link、托盘、配置目录和导入导出的 Windows/Linux 平台能力测试或手工复现步骤。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- Tauri 无法稳定满足 Windows-only wallpaper mode、Linux 通用 capability 或 sidecar 管理需求。
- Tauri 的 Windows/Linux 打包、签名、自动更新或 WebView 兼容性无法满足首版发布。
- Full/Online 双安装包造成不可接受的用户迁移成本，需要改为运行时切换。
- 项目决定第一阶段不再包含 Linux，或要求 macOS 同步进入第一阶段。
