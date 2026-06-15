# release 契约

本目录保存 HDX 发布流程使用的可机读 JSON Schema。它们是 GitHub Releases 产物边界的执行契约，配合 `docs/adr/0012-github-releases-artifact-boundary.md` 使用。

本目录只定义数据形状和字段语义，不实现 GitHub Actions workflow。根仓库脚本使用 PowerShell 内置逻辑校验本目录使用到的 JSON Schema 子集，不引入外部 schema 校验依赖。

本地校验入口：

```powershell
pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1
```

默认校验：

- 本目录下的 schema 文件存在、可解析，且 `manifestKind` 与文件职责一致。
- 最小有效样例、schema 无效样例、sha256 不匹配样例和禁止文件扫描样例。

后续有真实 manifest 或候选发布包时，可以传入参数做严格 schema 校验、核心字段校验、真实文件 sha256/size 校验和禁止文件扫描：

```powershell
pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 `
  -BackendNativeManifestPath path/to/backend-native-manifest.json `
  -ReleaseManifestPath path/to/release-manifest.json `
  -BackendBuildPath path/to/backend-build.json `
  -BackendServicesManifestPath path/to/backend-services-manifest.json `
  -AssetRoot path/to/release-assets-or-package-root `
  -ScanPath path/to/backend-native-or-services-package
```

主仓库当前已有八个 release 资产整理或解析入口：

- `scripts/release-draft-minimal-assets.ps1`：消费后端私有仓库 Actions artifact，生成本次后端 native 来源为 `github-actions-artifact` 的最小 Release 资产。该脚本会为后端 native asset 写入 `backendNativeFingerprint`，供后续历史 Release asset 复用校验。
- `scripts/release-draft-reuse-backend-assets.ps1`：消费主仓库指定历史 Release 中已经公开的 `release-manifest.json`、`backend-native-manifest.json` 和后端 native asset。该脚本校验 fingerprint、sha256、size、历史构建上下文和禁止文件扫描后，生成本次后端 native 来源为 `historical-release-asset` 的最小 Release 资产。
- `scripts/release-assemble-backend-assets.ps1`：消费多个已下载的后端私有仓库 Actions artifact 目录，逐个复用后端 artifact 校验后，聚合生成统一 `backend-native-manifest.json`、`release-manifest.json`、`SHA256SUMS` 和多个后端 native Release asset。
- `scripts/release-assemble-historical-backend-assets.ps1`：消费多个已下载的历史主仓库 Release asset 目录，校验每个历史 asset 的显式 sha256/size、fingerprint、历史构建上下文和禁止文件扫描后，聚合生成当前版本的 `release-manifest.json`、`SHA256SUMS` 和多个复用后端 native Release asset。该脚本第一版要求多个来源来自同一个历史 Release，并覆盖历史 `backend-native-manifest.json` 记录的全部后端 native asset。
- `scripts/release-append-web-asset.ps1`：消费 Web node-server archive，把 Web asset 追加到 `release-manifest.json`，写入 `sources.web`，重算 `SHA256SUMS` 并复跑 Release manifest 校验。
- `scripts/package-desktop-release-assets.ps1`：消费 Tauri bundle 输出，把 Desktop 安装包、绿色包或 AppImage 整理为 Release 约定文件名；该脚本不修改 `release-manifest.json`。
- `scripts/release-append-desktop-assets.ps1`：消费 Desktop workflow 整理后的 Release asset 目录，把 Desktop installer、portable zip 或 AppImage 追加到 `release-manifest.json`，写入 `sources.desktop`，重算 `SHA256SUMS` 并复跑 Release manifest 校验。
- `scripts/release-resolve-backend-sources.ps1`：消费候选历史主仓库 Release asset 目录和 required assets 列表，校验 sha256/size、OpenAPI hash 和 backend native fingerprint 后，输出可直接交给主仓库 `release.yml` 的 `backend_sources_json`。当前只覆盖历史 Release asset 可复用路径，匹配失败时要求后续运行后端 native workflow。

本地回归入口 `scripts/check-desktop-release-asset-packaging.ps1` 使用 fixture 覆盖 Desktop asset 打包脚本，确认 Tauri bundle 目录中旧版本产物与当前版本产物共存时，脚本仍按当前 release version 精确选择 NSIS/AppImage。

历史复用入口当前不重命名复用的后端 native asset。原因是历史 `backend-native-manifest.json` 会记录原始 archive 文件名；若要把复用 archive 改成新版本文件名，需要先设计 manifest rewrite 和对应校验规则。

## 文件职责

- `backend-native-manifest.schema.json`：约束后端私有仓库 CI 上传到 GitHub Actions artifact 的 `backend-native-manifest.json`。
- `release-manifest.schema.json`：约束公开主仓库 GitHub Release 中的 `release-manifest.json`。
- `backend-build.schema.json`：约束 Desktop Full 包内的 `backend-build.json`，用于追溯内置后端来源。
- `backend-services-manifest.schema.json`：约束 `backend-services` 平台聚合包内部的 `backend-services-manifest.json`。

## 生产者与消费者

| manifest | 生产者 | 消费者 | 存放位置 |
| --- | --- | --- | --- |
| `backend-native-manifest.json` | 后端私有仓库 native CI | 主仓库 release workflow | GitHub Actions artifact 临时交接包内 |
| `release-manifest.json` | 主仓库 release workflow | 用户、部署者、后续校验脚本 | 主仓库 GitHub Release asset |
| `backend-build.json` | 主仓库 Desktop Full 打包流程 | Desktop Full 运行时、排障人员、校验脚本 | Desktop Full 安装目录或资源目录 |
| `backend-services-manifest.json` | 后端私有仓库 native CI | 服务端部署者、校验脚本 | `backend-services` 压缩包内部 `manifest/` 目录 |

## 字段规则

- `schemaVersion` 当前固定为 `1.0`。
- `version` 必须使用 `v<major>.<minor>.<patch>` 形态，可以携带 prerelease 或 build metadata。
- `root.ref` 和所有文件名不得使用 `latest`；发布事实源必须是主仓库 release tag 或 root commit。
- `root.commit`、子模块 commit 和后端 commit 均使用 40 位小写 Git SHA。
- sha256 字段均使用 64 位小写十六进制。
- `openapiSnapshotHash` 表示参与本次发布的 OpenAPI 快照集合 hash，后续 workflow 实现时必须由主仓库和后端 CI 使用同一算法生成。
- `backendNativeManifest.source.type` 显式记录 `backend-native-manifest.json` 的来源：本次后端 Actions artifact 使用 `github-actions-artifact`，历史主仓库 Release asset 复用使用 `historical-release-asset`。
- `githubActionsArtifacts` 用于记录多个后端 Actions artifact 聚合时每个 backend asset 对应的 workflow run、run attempt、artifact name 和可选 artifact id。
- `assets[].source.githubActions` 用于记录单个 backend asset 来自哪个后端 Actions artifact。
- `assets[].source.type=historical-release-asset` 只允许用于 `backend-full` 或 `backend-services`，并必须记录历史 release tag、历史 asset 名称、sha256、size、历史 release manifest sha256、历史构建 root/backend/OpenAPI 上下文和 `backendNativeFingerprint`。
- `assets[].kind` 优先使用发布物粒度：`web-node-server`、`desktop-installer`、`desktop-portable`、`desktop-appimage`、`desktop-updater-manifest`、`desktop-update-signature`、`backend-full`、`backend-services`、`android-online`、`harmonyos-online` 或 `metadata`。旧值 `web`、`desktop-online` 和 `desktop-full` 仅作为兼容入口保留，后续正式生成逻辑不应继续新增。
- `assets[].flavor` 用于区分 Desktop `online` 与 `full`；`assets[].packaging` 用于区分 `tar.gz`、`zip`、`nsis`、`appimage`、`tauri-updater-json`、`tauri-updater-signature` 等发布包形态；`assets[].channel` 用于区分 `stable`、`preview`、`nightly` 或 `manual`。
- `desktop-updater-manifest` 表示 Tauri v2 updater 使用的静态 JSON 文件。它不是 `release-manifest.json` 本身，而是由 Release asset、`.sig` 文件和发布上下文生成的小型更新入口。
- Tauri updater JSON 的 Release asset 文件名不得包含 `latest`；稳定版建议使用 `HDX.Desktop.Online_stable.json` / `HDX.Desktop.Full_stable.json`。客户端 endpoint 可以使用 GitHub `/releases/latest/download/<file>` 指向当前稳定 Release。
- `assets[].updater.format` 当前固定为 `tauri-v2-static-json`，`signatureRequired` 固定为 `true`。Tauri updater 签名与 Windows 安装包代码签名不是同一件事：首版 Windows 安装包可以未签名，但自动更新 artifact 仍必须有 Tauri updater signature。
- `backendNativeFingerprint.algorithm` 当前固定为 `hdx-backend-native-fingerprint-v1`；它记录后端 commit、artifact kind、platform、服务列表、OpenAPI hash、打包脚本版本、Java/GraalVM 版本、Maven native profile、native-image 参数、Spring AOT、RuntimeHints、reachability metadata 和 native metadata 输入。
- `backend-full` 表示 Desktop Full 使用的本地完整后端 native archive。
- `backend-services` 表示服务端微服务部署用平台聚合包；Release asset 不按微服务拆分，微服务粒度记录在 `backend-services-manifest.json` 的 `services` 字段中。

## 校验边界

当前 `scripts/release-manifest-check.ps1` 已覆盖：

- schema JSON 解析和 `manifestKind` 职责检查。
- 本目录 schema 使用到的 JSON Schema 子集校验，包括 `type`、`required`、`additionalProperties`、`properties`、`items`、`minItems`、`uniqueItems`、`minLength`、`minimum`、`enum`、`const`、`pattern`、`not`、本地 `$ref` 和 `date-time`。
- manifest 核心语义校验，包括版本、`latest` 禁止、Git commit 和 sha256 格式。
- 传入 `-AssetRoot` 时的真实文件 sha256 和 `sizeBytes` 校验。
- 传入 `-ScanPath` 时的后端源码、JAR/WAR、`.class`、`target/classes` 和构建中间目录禁止扫描。
- `examples/` 下的最小有效样例、schema 无效样例、sha256 不匹配样例和禁止文件扫描样例。

后续 workflow 实现时必须至少校验：

- `backend-native-manifest.json` 的 `version`、`root.ref`、`root.commit`、`openapiSnapshotHash` 与主仓库发布上下文一致。
- `release-manifest.json` 中所有 asset 的 sha256 与真实上传文件一致。
- `desktop-updater-manifest` asset 的 sha256 与真实 Tauri updater JSON 一致；其 `updater.targets[]` 只引用同一 Release 中存在且已签名的 Desktop 安装包或 AppImage。
- Tauri updater JSON 中的 `version`、平台 key、下载 URL 和 signature 内容必须由 release workflow 从已生成 asset 与 `.sig` 文件派生，禁止手写。
- Desktop Full 内置 `backend-build.json` 中的 `archiveSha256` 与公开 Release 中对应 `backend-full` asset 的 sha256 一致。
- `backend-services-manifest.json` 中 `files` 列表覆盖压缩包内应被追踪的二进制和配置示例；`manifest/SHA256SUMS` 覆盖除自身外的包内文件。manifest 自身不写入 `files`，避免自引用 hash。
- 后端 native archive 和 `backend-services` 聚合包不得包含后端源码、JAR/WAR、`.class`、`target/classes` 或后端构建中间目录。

ADR 0014 允许后端 native 输入未变化时复用历史主仓库 Release 中已经公开的后端 native asset。

当前 `release-manifest.schema.json`、样例、`scripts/release-manifest-check.ps1`、`scripts/release-assemble-backend-assets.ps1`、`scripts/release-assemble-historical-backend-assets.ps1`、`scripts/release-resolve-backend-sources.ps1` 和 `scripts/release-draft-reuse-backend-assets.ps1` 已能记录并校验：

- 多个后端 Actions artifact 聚合时的逐资产来源。
- 多个历史主仓库 Release asset 复用时的逐资产来源。
- 指定历史主仓库 Release 可复用时的 `backend_sources_json` 生成。
- 历史 release tag、asset name、sha256 和 size。
- backend native fingerprint。
- 历史后端 asset 构建来源。
- 当前发布事实源与历史后端 asset 构建 `root.commit` 的区别。

`.github/workflows/debug-release-draft-reuse-backend.yml` 提供手动最小 draft 复用闭环。完整真实 release workflow 仍需后续把后端 artifact 新建分支、历史 asset 复用分支、Web/Desktop Online/Desktop Full/App 构建和正式 publish 串成统一发布链路。
