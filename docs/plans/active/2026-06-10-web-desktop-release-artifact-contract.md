# Web/Desktop 发布产物契约与打包入口

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：见下方 active plan 状态块。
- 计划来源：用户确认先整理 Web/Desktop 发布产物契约，再继续接入 release workflow
- 创建时间：2026-06-10
- 最后更新：2026-07-03（GraalVM 25.1.3 本机复测）

<!-- active-plan-status:start -->
- 何时读取：Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务。
- 当前状态：Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发、Windows 端到端验证、公开端资产检查和 `v0.0.0-preview.5` Full Linux AppImage smoke 均已通过。公开端检查 run `27600342351` 已验证不再上传临时 Actions artifact。
- 下一步：会触发后端 native 的 stable 正式 tag 验证和真实安装包矩阵验证仍需单独确认后恢复；GraalVM 25.1.3 本机复测已解除旧 build report NPE，但本计划不直接推 preview/stable tag。
- 主要剩余风险：`v0.0.0-preview.5` 已证明新版 Full Linux AppImage 可启动本机后端并读取工作台数据；GraalVM 25.1.3 已解除本机 build report NPE，但远端 release native、stable 验证和真实安装包矩阵仍未复验。App 当前暂不进入发布闭环。
<!-- active-plan-status:end -->

## 阅读指引

Web node-server 发布包、Desktop Online/Full asset、Desktop 静态 UI、Rust BFF 和 Tauri 打包读这里。认证语义、JWT/Redis 撤销和错误码读认证计划；后端 native 来源、复用和 release start/resolver 读 release native 计划。

## 目标

在继续改 `.github/workflows/release.yml` 之前，先确定 Web 与 Desktop 的发布产物形态、命名、hash、manifest 记录和最小打包入口，避免正式 release workflow 依赖未定稿的客户端打包假设。

## 非目标

- 本计划不直接实现完整 release publish。
- 本计划不接入安装器签名、公证、自动更新或 release notes。
- 本计划不创建 App Android/HarmonyOS NEXT 工程骨架。
- 本计划不改变后端 native artifact 交接边界。
- 本计划不把 Nuxt SSR Web 强行改为静态站。

## 当前事实

- Web 位于 `apps/web/`，采用 Nuxt 4 SSR + Nuxt server BFF；浏览器不直接访问后端，token 和敏感配置留在 Nuxt server 边界内。
- Web 当前已有 `pnpm build`，第一版 Release 产物形态已确认为 Nuxt SSR server bundle archive；因为存在 BFF/session/CSRF，不能按纯静态 `dist` 包处理。
- Web 运行时尊重 Nuxt/Nitro 设计，以环境变量为事实源；不在 Nuxt 应用内新增独立配置文件读取层。
- Web Linux tar 包和后续 Docker 镜像共用 `sh` 启动脚本；`apps/web` 已新增 `start.sh`、`start-web.mjs`、`scripts/web-config-loader.mjs`、`scripts/package-node-server.mjs` 和 `config.example.yml`。`start.sh` 调用 `start-web.mjs`，由 Node 启动器可选读取包根目录 `config.yml`，将配置注入当前进程临时环境变量后启动 `server/index.mjs`。
- Docker 镜像不要求 `config.yml` 文件存在，配置由容器环境变量注入；`start.sh` / `start-web.mjs` 仍负责默认值、关键变量校验和启动。
- Desktop 位于 `apps/desktop/`，采用 Tauri + Rust + Vite + TypeScript，已有 Full/Online flavor 配置和 `build:full`、`build:online` 脚本。
- Desktop 本地 dev 仍以只读状态面板和 capability 空壳作为首屏；发布包改为使用 Web `desktop-static` 静态 UI。
  Full 运行时已能复制已解压 `backend-full`、启动本机后端，并通过 Rust BFF command 访问本机后端。
  Online 已实现远端地址填写、用户级配置持久化、`/actuator/health` 连接检查和远端 Rust BFF 认证转发。
- Desktop Windows 当前可生成 `HDX Desktop Online.exe`、`HDX Desktop Full.exe` 和 Online NSIS 安装包；NSIS 已配置 `SimpChinese`、`English` 和语言选择器。当前安装包未签名。
- Desktop Windows NSIS 安装包显式配置为当前用户安装；Windows WebView2 Runtime 使用 Tauri `webviewInstallMode` 的 `embedBootstrapper` 检查和引导安装。
- Desktop 当前没有独立配置模板。客户端运行配置后续由应用首启/设置页写入用户级 app config，并由 Rust 侧做 schema 校验；安装包和绿色包共用同一用户级配置位置。
- 当前正式发布链路已有 `release-start.yml`、主仓库历史后端 asset 复用判断、后端 native build resolver 和 `release.yml` draft assemble 第一片。
  Web node-server asset、Desktop Online asset、Desktop Full asset、Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF 已接入。
  Desktop Online 认证转发闭环已实现；`.github/workflows/check-public-release-assets.yml` 已验证公开端 Web、Desktop Online 和 Desktop Full Linux 合成后端资源 AppImage 打包路径。
  `release.yml` 已接入 stable/preview 发布渠道和 `release_mode=publish`；`v0.0.0-preview.5` 已通过真实 tag-only 预览发布和 Full Linux AppImage sidecar/API smoke。仍缺失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证。App 当前暂不进入发布闭环。

## 已确认结论

- Web 第一版 Release asset 采用 Nuxt SSR server bundle archive。
- Web asset 名称采用 Linux 友好的 `hdx-web-node-server-<version>.tar.gz`。
- `apps/web` 使用 `node scripts/package-node-server.mjs --version <version>` 生成 Web node-server tar 包；脚本默认先 build，本地调试可传 `--skip-build`。主仓库 workflow 直接调用 Node 脚本，避免 pnpm script 参数转发把 `--` 作为业务参数传给打包脚本。
- 公开 Web Release 包禁止包含 client/public sourcemap；server sourcemap 可保留在 `server/` 运行产物内，用于 Node SSR/BFF 报错定位。
- Web 包只包含整理后的运行产物，不直接把默认 `.output` 原样当成发布标准。
- Web 发布包移除 `.output` 外层隐藏目录，把 `.output` 内的 `public/`、`server/` 和 `nitro.json` 整理到包根目录。
- Web Linux tar 包不新增 `config/` 目录；可选配置文件为包根目录下的 `config.yml`，示例文件为 `config.example.yml`。
- 包根目录新增 `start.sh` 和 `start-web.mjs`。`start.sh` 只作为 Linux/Docker 统一入口，实际配置读取、环境变量注入、关键变量校验和 Nuxt/Nitro server 启动由 `start-web.mjs` 完成。
- Docker 镜像同样使用 `start.sh` 作为入口，但不要求 `config.yml` 存在；Dockerfile、Compose、Kubernetes 或运行命令注入的环境变量是 Docker 场景的配置来源。
- 本地 dev 复用同一套配置 schema 和字段映射，使用 `config.local.yml` 作为本地配置文件；本地命令通过 Node runner 注入环境变量后再启动 Nuxt dev/build/preview。
- 配置优先级为环境变量 > `config.yml` / `config.local.yml` > 内置默认值。
- `start-web.mjs` 可以使用 YAML 解析依赖，但该依赖必须随 Web 发布产物一起打入包内，不能要求用户在部署机器上执行 `npm install`。
- 正式生产包不通过事后手工删除 client/public sourcemap 来达成，而是在 Nuxt/Vite/Nitro 构建配置中关闭 client sourcemap；打包脚本仍应检查 `public/` 下不存在 `*.map`。
- Linux 启动 smoke 可在本机 WSL 中执行；当前 WSL 已有 Node.js `v24.16.0`，Web node-server 包运行时不应再要求额外安装 npm 依赖。
- Desktop 第一版正式 Release 需要同时提供 Online 与 Full；Full 打包资产可以先进入 draft assemble 验证。
  只有在真实安装包/AppImage 端到端验证、Desktop 静态 UI 与 Rust BFF 启动闭环完成后，Full 才能作为用户可用产物发布。
- Desktop Windows 同时发布 NSIS 安装包和绿色 zip 包；Linux 第一版优先发布 AppImage。
- Desktop Release asset 文件名统一使用无空格命名。
- Desktop Windows 首版允许未签名；release notes 需要提示 Windows SmartScreen 或系统安全提示风险。
- Desktop 绿色包包含可运行程序、`README`、`LICENSE`、`NOTICE` 和 release manifest 摘要；不包含另一套默认配置模板。
- `release-manifest.json` 作为 Release 总账，记录所有 Web/Desktop/后端 asset 的 sha256、size、来源、platform、flavor、packaging 和 channel；Tauri updater 使用的静态 JSON 作为 `desktop-updater-manifest` asset 记录在总账中，但不直接复用 `release-manifest.json` 作为客户端 updater endpoint。
- Tauri updater JSON 按 Desktop flavor/channel 分开生成，例如 `HDX.Desktop.Online_stable.json` 与 `HDX.Desktop.Full_stable.json`；文件名不使用 `latest`，客户端 endpoint 可以使用 GitHub `/releases/latest/download/<file>` 指向当前稳定 Release。

## Desktop 第一版 Release asset 命名

| 平台 | Flavor | 产物 | 命名 |
| --- | --- | --- | --- |
| Windows x64 | Online | NSIS 安装包 | `HDX.Desktop.Online_windows-x64_<version>_setup.exe` |
| Windows x64 | Online | 绿色包 | `HDX.Desktop.Online_windows-x64_<version>_portable.zip` |
| Windows x64 | Full | NSIS 安装包 | `HDX.Desktop.Full_windows-x64_<version>_setup.exe` |
| Windows x64 | Full | 绿色包 | `HDX.Desktop.Full_windows-x64_<version>_portable.zip` |
| Linux x64 | Online | AppImage | `HDX.Desktop.Online_linux-x64_<version>.AppImage` |
| Linux x64 | Full | AppImage | `HDX.Desktop.Full_linux-x64_<version>.AppImage` |

说明：

- `<version>` 使用 release tag 对应版本，不包含空格。
- Release asset 的应用名前缀保留 `HDX.Desktop.Online` / `HDX.Desktop.Full` 的大小写与点分隔；应用名、平台、版本和包类型使用 `_` 分组，平台内部继续使用 `windows-x64` / `linux-x64`。
- 绿色包不是另一套配置模型，只是免安装交付形态；远端地址、本机模式状态和用户偏好仍写入用户级 app config。
- Linux 如后续 AppImage 在 WebKitGTK 或桌面集成上出现不可接受兼容问题，再补 `.deb` / `.rpm`，不在第一版默认增加包型。

## Web 配置字段清单

| 配置字段 | 环境变量 | 必填 | 默认值 |
| --- | --- | --- | --- |
| `server.host` | `NITRO_HOST` | 否 | `0.0.0.0` |
| `server.port` | `NITRO_PORT` | 否 | `3000` |
| `backend.gatewayBaseUrl` | `NUXT_BACKEND_BASE_URL` | 否 | `http://localhost:18080` |
| `backend.authBaseUrl` | `NUXT_AUTH_BASE_URL` | 否 | `http://localhost:18082` |
| `auth.sessionSecret` | `NUXT_AUTH_SESSION_SECRET` | 生产必填 | 无安全默认值 |
| `auth.cookieSecure` | `NUXT_AUTH_COOKIE_SECURE` | 否 | 生产 `true`，开发 `false` |
| `auth.sessionCookieName` | `NUXT_AUTH_SESSION_COOKIE_NAME` | 否 | `hdx_web_session` |
| `auth.csrfCookieName` | `NUXT_AUTH_CSRF_COOKIE_NAME` | 否 | `hdx_csrf` |
| `auth.csrfHeaderName` | `NUXT_AUTH_CSRF_HEADER_NAME` | 否 | `X-HDX-CSRF` |
| `auth.sessionMaxAgeSeconds` | `NUXT_AUTH_SESSION_MAX_AGE_SECONDS` | 否 | `604800` |
| `auth.refreshSkewSeconds` | `NUXT_AUTH_REFRESH_SKEW_SECONDS` | 否 | `60` |
| `localBackend.tokenHeader` | `NUXT_BACKEND_LOCAL_TOKEN_HEADER` | 否 | 无 |
| `localBackend.token` | `NUXT_BACKEND_LOCAL_TOKEN` | 否 | 无 |

字段校验规则：

- `auth.sessionSecret` 在生产必须存在，长度至少 32。
- `auth.sessionSecret` 不能等于示例值。
- `server.port` 必须是 `1..65535`。
- `backend.gatewayBaseUrl` 和 `backend.authBaseUrl` 必须是 `http://` 或 `https://` URL。
- `auth.sessionMaxAgeSeconds` 必须大于 0。
- `auth.refreshSkewSeconds` 必须大于等于 0。
- `localBackend.tokenHeader` 和 `localBackend.token` 要么都为空，要么都填写。

## 待实现问题

- Desktop Online 已实现远端地址填写、校验、用户级持久化和登录前连接检查第一片。
  本轮只保存 `authBaseUrl`、`gatewayBaseUrl` 和连接超时，并由 Rust 主进程检查两个远端 `/actuator/health`；登录后 access/refresh token 保存在 Rust 主进程内存，不暴露给 WebView。
- Desktop Full 已实现构建期解压 `backend-full`、运行时复制已解压资源、sidecar 启动、健康检查、`/local/session` 读取和退出清理。
  Desktop Rust BFF command 已接入 Web 静态 UI 所需的 session、runtime 和 tools API；Full flavor 通过 sidecar token 访问本机后端，但 token 不返回 WebView。
  Desktop Online 远端 Rust BFF 认证转发已实现；Full Linux AppImage sidecar/API smoke 已通过，真实安装包矩阵和桌面集成验证仍待后续补齐。
- Desktop Full sidecar 本轮采用构建期解压资源、运行时复制启动：发布校验仍以 `backend-full` archive 为事实源，但 Desktop Full 内置资源应携带已解压的 `bin/hdx-backend-full(.exe)` 与 `backend-build.json`，避免 Rust 运行时新增 zip/tar 解析依赖。
- Desktop Online Windows 绿色 zip 整理已抽出为 `scripts/package-desktop-release-assets.ps1` 并接入 release/check workflow，包含 exe、`README`、`LICENSE`、可选 `NOTICE` 和 `RELEASE.txt` 发布摘要；Desktop Full Windows 绿色包会额外携带 `backend/` 目录。
- Desktop Linux AppImage 需要在 Linux runner 上验证 Online/Full flavor 构建、启动和桌面集成。
- Release workflow 已把 Tauri 默认输出重命名为上述无空格 asset 名称，并为每个 asset 记录 sha256、size、platform、flavor、packaging 和来源 commit；Desktop Full 打包第一片额外校验并携带同平台 `backend-full` archive 与 `backend-build.json`。
- Release workflow 后续需要从 Desktop 安装包/AppImage 和 `.sig` 文件派生 Tauri updater JSON，禁止手写 updater URL 或 signature 内容。
- Release workflow 已接入 Web node-server asset、Desktop Online asset、Desktop Full asset 构建、stable/preview 发布渠道和 `release_mode=publish`。
  Desktop Online/Full release job 会额外构建 Web `desktop-static` 静态输出，并把 Tauri `frontendDist` 指向该目录。
  后续仍需做失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和 Desktop Full 真实安装包矩阵验证；App 当前暂不进入发布闭环。
- 公开端资产检查 workflow 已接入 Web node-server、Desktop Online Windows/Linux asset 构建和 Desktop Full Linux AppImage 合成后端资源 smoke；GitHub-hosted run `27528781158` 已确认 Full Linux AppImage 合成资源 smoke 通过。
  同一 run 的 Windows Online 检查曾因 Rust target cache 中保留旧 NSIS 安装包而失败，根因是 `scripts/package-desktop-release-assets.ps1` 使用 `*setup.exe` 模糊匹配。
  脚本已改为按当前 release version 精确匹配 Tauri bundle，并由 run `27529656045` 确认 Web、Desktop Online Windows/Linux 和 Desktop Full Linux 全部通过。
- `v0.0.0-preview.2` Full Linux AppImage 已在本机 Ubuntu WSL 真实运行：补齐 WSL GUI/WebKit 依赖和 CJK 字体后 UI 可启动并显示中文，但本机后端启动暴露后端 Jackson 兼容缺陷；具体后端日志和修复记录以后端私有文档为准。
- `v0.0.0-preview.5` Full Linux AppImage 已在同一 Ubuntu WSL 真实运行并通过本机后端 sidecar/API smoke；WSL 环境仍有图形栈 warning，但未阻塞本次验证。具体本机后端响应细节以后端私有文档为准。

## 本地任务清单

- [x] 扫描 `apps/web` 的 build 命令、输出目录、运行时配置和当前质量门禁。
- [ ] 扫描 `apps/desktop` 的 Tauri 配置、flavor build 命令、bundle 输出和当前质量门禁。
- [x] 提出 Web 第一版发布产物契约。
- [x] 确认 Web 配置字段清单。
- [x] 实现 Web 本地/Release 共用配置 loader、启动入口和生产 client/public sourcemap 关闭。
- [x] 实现 Web `hdx-web-node-server-<version>.tar.gz` 打包脚本和包结构检查。
- [x] 扫描 `apps/desktop` 的 Tauri 配置、flavor build 命令、bundle 输出和当前质量门禁。
- [x] 提出 Desktop Online 第一版发布产物契约。
- [x] 提出 Desktop Full 第一版命名、manifest 和 sidecar 占位边界。
- [x] 检查 `release-manifest.json` schema 是否需要扩展客户端 asset 元数据。
- [x] 更新 ADR、架构文档、Release runbook 或本计划中的结论。
- [x] 将 Web node-server asset 接入正式 `release.yml` assemble。
- [x] 将 Desktop Online Windows/Linux asset 接入正式 `release.yml` assemble。
- [x] 将 Desktop Full Windows/Linux asset 接入正式 `release.yml` assemble。
- [x] 新增公开端 Web/Desktop Online release asset check workflow。
- [x] 新增公开端 Desktop Full Linux AppImage smoke，使用合成后端资源验证 Full AppImage 打包和内置资源路径。
- [x] 增强正式 `release.yml` 远端资产回读：下载 draft Release 资产后复验 size、sha256、manifest 记录和禁止文件规则。
- [x] 接入 Desktop asset stable/preview 渠道：正式 tag 写 `channel=stable`，prerelease tag 写 `channel=preview`。
- [x] 运行 docs 范围质量门禁。
- [x] 实现 Desktop Full sidecar 运行时最小闭环：定位内置后端资源、复制到用户数据目录、启动本机后端、健康检查、读取 `/local/session`、保持 token 不暴露给 WebView、退出清理。
- [x] 实现 Desktop 静态 Web UI + Rust BFF 第一片：Web store 调用 API adapter，Desktop Full Rust BFF 通过 sidecar token 访问本机后端，状态不序列化 token。
- [x] 实现 Desktop Online 远端配置第一片：Web 静态 UI 可填写远端地址，Rust 主进程校验、持久化并检查 `/actuator/health`。
- [x] 实现 Desktop Online 远端 Rust BFF 认证转发闭环：login/refresh/logout/业务请求 Bearer 注入，token 保存在 Rust 主进程不暴露给 WebView。

## 验收标准

- Web 发布包不能再被模糊描述为静态包；必须明确 Nuxt SSR/BFF 的第一版交付形态。
- Desktop Online 与 Desktop Full 的第一版 asset 命名、平台矩阵、校验方式和 manifest 记录方式明确。
- 后续接入 `release.yml` 时，可以按本文结论实现构建 job，而不是在 workflow 中临时猜包结构。
- Desktop Online 远端 Rust BFF 认证转发已实现：登录、refresh 轮换、logout 撤销和业务请求 Bearer 注入闭环已在 Rust 主进程内完成，token 不暴露给 WebView。
- 尚未实现的能力必须明确标为未实现，尤其是真实安装包/AppImage 端到端验证和自动更新。

## 验证结果

- Web node-server 发布包：Web 测试、lint、Nuxt typecheck、SSR build、`package-node-server.mjs`、Windows Node smoke 和 WSL `start.sh` smoke 均已通过。
  最终 tar 包不包含 `.output/`、`.nuxt/`、`public/*.map`、`.env` 或链接项；包根包含 `public/`、`server/`、`nitro.json`、`start.sh`、`start-web.mjs`、`config.example.yml` 和运行所需 `yaml` 依赖。
  当前保留上游 sourcemap、VueUse pure annotation、chunk size 和 Node `DEP0155` warning，不阻塞。
- Desktop Online/Full 基础打包：TypeScript、Vite、Full/Online `cargo check`、Full/Online Rust 单测、Tauri Windows exe/NSIS、Linux AppImage 打包路径、图标集、当前用户安装和 WebView2 引导配置均已验证；`package-desktop-release-assets.ps1` 通过 fixture 覆盖 Windows Online、Linux Online 和 Windows Full 绿色包整理。
- Release/check workflow：`actionlint` 覆盖 `release.yml`、`check-public-release-assets.yml` 和 debug workflows；`release-append-web-asset.ps1`、`release-append-desktop-assets.ps1`、`check-desktop-release-asset-packaging.ps1` 和 release manifest schema/样例校验通过。
  `Check Public Release Assets` run `27291207098` 首次确认 Web node-server、Desktop Online Windows NSIS/portable 和 Linux AppImage 构建可用；后续 run `27457713493` 与 `27458336496` 确认 Desktop 静态 Web 输出、Rust cache 和 Windows/Linux Online 打包路径可用。
  Run `27528781158` 确认新增 Desktop Full Linux AppImage 合成资源 smoke 通过，但 workflow 总体因 Windows Online 打包脚本误选旧缓存 NSIS 产物失败；当前已补 `check-desktop-release-asset-packaging.ps1` fixture 覆盖旧缓存产物与当前版本产物共存场景，run `27529656045` 已确认全部 job 通过。
  Run `27600342351` 再次确认 Web node-server、Desktop Online Windows/Linux 和 Desktop Full Linux AppImage 全绿；该 workflow 不再上传临时 Actions artifact，主仓库 `actions/artifacts` 查询结果仍为 `0`。
  `v0.0.0-preview.2` 真实 tag-only 预览发布已成功 publish；Full Linux AppImage 在本机 Ubuntu WSL 可启动 UI，但本机后端 sidecar 暴露后端 Jackson 兼容缺陷。`v0.0.0-preview.5` 已确认后端修复进入真实 release native/AppImage 产物，并通过本机 WSL sidecar/API smoke。
- Desktop Full sidecar：Full flavor 已实现构建期解压 `backend-full`、运行时复制资源、启动本机后端、健康检查、读取本机 session 和退出清理；Rust 单测覆盖 entrypoint 校验和状态序列化不泄露 token。
  Windows 真实端到端验证通过：Full release exe 携带 `backend/`、`backend-build.json` 和静态 Web UI，sidecar 启动后 `/actuator/health`、`/local/session`、`/api/v1/runtime`、`/api/v1/tools` 和 `/api/v1/auth/current` 均符合预期，WebView 不暴露本机 token。
- Desktop Online 远端配置与认证转发：Online config command、远端 health 检查、Rust 主进程 token holder、login/refresh/logout 和业务请求 Bearer 注入均已实现并通过本地 Rust/Web 验证。
  Windows 真实端到端验证通过，用户在 Desktop Online 登录页填写 auth/gateway 地址并用账号密码登录成功进入应用；已修复 public session 时间字段与前端 zod schema 不匹配、logout 配置不可读时不清理本地 token 两个缺陷。
- 根仓库质量门禁：相关阶段均运行过 `git diff --check`、子模块 diff check、`check-desktop-release-asset-packaging.ps1`、`quality-gate.ps1 -Scope docs -NoBuild`、`-Scope desktop -NoBuild` 和 `-Scope web -NoBuild`；普通权限下 pnpm/Cargo 写缓存或读取用户目录失败时按权限规则提权重跑通过。
- 逐次 CI 失败、临时 fixture 路径和完整命令输出不再保留在 active plan；可复用命令/环境踩坑沉淀到 `docs/AGENT_WORKFLOW.md` 或脚本。
## 剩余风险

- Web SSR bundle 发布后仍需要部署方式配合；本计划只解决 Release asset 契约，不解决自动部署。
- Web node-server 与 Desktop Online 静态 Web + Rust BFF 打包路径已通过 `check-public-release-assets.yml` 的 GitHub-hosted 公开端资产检查；Desktop Full Linux 合成后端资源 AppImage smoke 已在 run `27528781158` 通过。
  Run `27529656045` 已确认按版本精确选择 Tauri bundle 的打包脚本修复不会再被旧缓存 NSIS/AppImage 干扰。
  真实 `release.yml` 已包含远端 asset 回读、manifest 校验、stable/preview 渠道和 publish；`v0.0.0-preview.5` 已验证真实 tag-only 路径下的后端来源、manifest 汇总、publish/prerelease 和完整 assemble。
- Desktop Online 远端登录端到端交互验证已完成（Windows）：用户在 Desktop Online 登录页填写远端服务地址并使用账号密码登录成功，进入应用主界面；并修复了 Rust BFF session schema 与前端 zod schema 不匹配的缺陷。
  Rust BFF logout 已修复为无论配置是否可读都会清理本地内存 token。本轮未重新验证 WebView2 引导或真实远端服务连接；Full Linux AppImage 已做本机 sidecar/API smoke，但未覆盖桌面集成安装行为。
- Desktop Full sidecar 最小运行时闭环、Rust BFF 和真实安装包端到端验证已完成（Windows）；Linux Full AppImage 合成资源打包 smoke 已远端确认。真实 `v0.0.0-preview.2` Linux Full AppImage 已暴露后端 sidecar 启动缺陷，`v0.0.0-preview.5` 已在本机 Ubuntu WSL 通过真实 release AppImage sidecar/API smoke。
- App 当前暂不进入发布闭环，后续 App Online asset 需要等基础工程和打包入口明确后单独计划。

## 相关 commit

- `apps/web`：`80e164c` 功能：新增 Web 启动配置入口。
- `apps/web`：`e2f59f6` 构建：保留 Web 服务端 sourcemap。
- `apps/web`：`b7eb570` 构建：新增 Web node-server 打包脚本。
- `apps/web`：`e479bc3` 构建：兼容 Web 发布包 build metadata 版本。
- `apps/web`：`be49be5` 修复：物化 Web 发布包符号链接。
- `apps/web`：`a91d150` 修复：隔离 Desktop 静态输出目录。
- `apps/web`：`5d2c2ab` 修复：稳定复制 Desktop 静态资源。
- `apps/web`：`f02275d` 修复：避开 Desktop 静态输出套叠。
- `apps/desktop`：`738b23b` 构建：配置 Windows 安装器多语言。
- `apps/desktop`：`c3ae62e` 构建：收敛 Desktop Full flavor 命名。
- `apps/desktop`：`cd50e0f` 构建：补充 Tauri PNG 图标。
- 根仓库：`d09384c` 修复：稳定 Desktop 发布资产打包。
- `apps/desktop`：`4240f6c` 修复：补齐 Tauri 打包图标集。
- 根仓库：本次提交更新客户端子模块指针与本计划状态。
