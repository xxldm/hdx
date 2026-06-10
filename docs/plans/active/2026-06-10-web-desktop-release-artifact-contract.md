# Web/Desktop 发布产物契约与打包入口

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：Web node-server archive、配置字段清单和启动边界已确认，Desktop build 尚未实测
- 计划来源：用户确认先整理 Web/Desktop 发布产物契约，再继续接入 release workflow
- 创建时间：2026-06-10

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
- Web Linux tar 包和后续 Docker 镜像共用 `sh` 启动脚本；`start.sh` 调用 `start-web.mjs`，由 Node 启动器可选读取包根目录 `config.yml`，将配置注入当前进程临时环境变量后启动 `server/index.mjs`。
- Docker 镜像不要求 `config.yml` 文件存在，配置由容器环境变量注入；`start.sh` / `start-web.mjs` 仍负责默认值、关键变量校验和启动。
- Desktop 位于 `apps/desktop/`，采用 Tauri + Rust + Vite + TypeScript，已有 Local/Online flavor 配置和 `build:local`、`build:online` 脚本。
- Desktop 当前仍是只读状态面板和 capability 空壳；Local 未打包或启动真实 `backend-all-in-one`，Online 未实现远端地址填写和持久化。
- 当前正式发布链路已有 `release-start.yml`、后端 resolver 和 `release.yml` draft assemble 第一片；仍缺 Web/Desktop/App 构建、正式 publish 和失败清理。

## 已确认结论

- Web 第一版 Release asset 采用 Nuxt SSR server bundle archive。
- Web asset 名称采用 Linux 友好的 `hdx-web-node-server-<version>.tar.gz`。
- 正式生产包禁止包含 sourcemap。
- Web 包只包含整理后的运行产物，不直接把默认 `.output` 原样当成发布标准。
- Web 发布包移除 `.output` 外层隐藏目录，把 `.output` 内的 `public/`、`server/` 和 `nitro.json` 整理到包根目录。
- Web Linux tar 包不新增 `config/` 目录；可选配置文件为包根目录下的 `config.yml`，示例文件为 `config.example.yml`。
- 包根目录新增 `start.sh` 和 `start-web.mjs`。`start.sh` 只作为 Linux/Docker 统一入口，实际配置读取、环境变量注入、关键变量校验和 Nuxt/Nitro server 启动由 `start-web.mjs` 完成。
- Docker 镜像同样使用 `start.sh` 作为入口，但不要求 `config.yml` 存在；Dockerfile、Compose、Kubernetes 或运行命令注入的环境变量是 Docker 场景的配置来源。
- 本地 dev 复用同一套配置 schema 和字段映射，使用 `config.local.yml` 作为本地配置文件；本地命令通过 Node runner 注入环境变量后再启动 Nuxt dev/build/preview。
- 配置优先级为环境变量 > `config.yml` / `config.local.yml` > 内置默认值。
- `start-web.mjs` 可以使用 YAML 解析依赖，但该依赖必须随 Web 发布产物一起打入包内，不能要求用户在部署机器上执行 `npm install`。
- 正式生产包不通过事后手工删除 sourcemap 来达成，而是在 Nuxt/Vite/Nitro 构建配置中关闭 sourcemap；打包脚本仍应检查最终包内不存在 `*.map` 作为保险。
- Linux 启动 smoke 可在本机 WSL 中执行；当前 WSL 已有 Node.js `v24.16.0`，Web node-server 包运行时不应再要求额外安装 npm 依赖。

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

## 待确认问题

- `start.sh` / `start-web.mjs` 的执行权限、YAML 依赖打包方式和 Linux/Docker 共用入口实现细节。
- Desktop 是否先实现 Online 包，Full 包只先固定命名与 manifest 边界。
- Desktop Windows/Linux 第一版 release asset 名称、目录结构和校验入口。
- Desktop Full 如何记录同平台 `backend-full` 来源，以及 sidecar 尚未实现时如何避免假装可用。
- `release-manifest.json` 是否需要新增 Web/Desktop asset 的固定字段，还是先沿用通用 `assets[]` 来源记录。

## 本地任务清单

- [x] 扫描 `apps/web` 的 build 命令、输出目录、运行时配置和当前质量门禁。
- [ ] 扫描 `apps/desktop` 的 Tauri 配置、flavor build 命令、bundle 输出和当前质量门禁。
- [x] 提出 Web 第一版发布产物契约。
- [x] 确认 Web 配置字段清单。
- [ ] 提出 Desktop Online 第一版发布产物契约。
- [ ] 提出 Desktop Full 第一版命名、manifest 和 sidecar 占位边界。
- [ ] 检查 `release-manifest.json` schema 是否需要扩展客户端 asset 元数据。
- [ ] 更新 ADR、架构文档、Release runbook 或本计划中的结论。
- [ ] 运行 docs 范围质量门禁。

## 验收标准

- Web 发布包不能再被模糊描述为静态包；必须明确 Nuxt SSR/BFF 的第一版交付形态。
- Desktop Online 与 Desktop Full 的第一版 asset 命名、平台矩阵、校验方式和 manifest 记录方式明确。
- 后续接入 `release.yml` 时，可以按本文结论实现构建 job，而不是在 workflow 中临时猜包结构。
- 尚未实现的能力必须明确标为未实现，尤其是 Desktop Full sidecar、本机 token、远端地址配置和自动更新。

## 验证结果

- 2026-06-10：在 `apps/web/` 普通权限运行 `pnpm build`，因 `pnpm` 读取 `C:\Users\zengl` 触发已知 Codex sandbox `EPERM` 失败；随后按权限规则用审批路径重跑同一命令通过。
- `pnpm build` 的默认输出为 Nuxt/Nitro `node-server`，生成 `.output/public`、`.output/server` 和 `.output/nitro.json`，预览入口为 `node .output/server/index.mjs`。
- 以上 build 输出只作为整理运行产物的输入；最终发布包使用整理后的 Nuxt SSR server bundle archive，不把默认 `.output` 原样当成发布标准。
- `.output` 当前包含 367 个文件，总大小 `13527589` bytes；包含 26 个 `.map` 文件。
- 最大产物为登录背景图 `.output/public/_nuxt/login-background.CpNlxion.bmp`，大小 `7056054` bytes。
- 构建保留上游 sourcemap warning、VueUse pure annotation warning、单个约 `522 kB` client chunk warning 和 Node `DEP0155` warning；当前不阻塞 build。
- `git -C apps/web status --short --branch` 显示 Web 子模块工作树干净。

## 剩余风险

- Web SSR bundle 发布后仍需要部署方式配合；本计划只解决 Release asset 契约，不解决自动部署。
- Desktop 打包可能暴露 Tauri bundler、平台依赖或 runner 环境问题，需要在后续实现切片中单独验证。
- Desktop Full sidecar 未实现前，不应发布让用户误以为可离线使用的 Full 安装包。
- App 仍不进入本计划，后续 App Online asset 需要单独计划。

## 相关 commit

- 待补。
