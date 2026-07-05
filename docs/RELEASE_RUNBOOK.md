# Release 操作手册

本文档记录 HDX 目标发布流程的日常人工操作和自动化边界。当前已存在正式 `release-start.yml` 和 `release.yml` 第一版，Web node-server asset、Desktop Online asset 与 Desktop Full asset 已接入 assemble。
Desktop Full 运行时 sidecar 已有最小启动闭环；Desktop Online/Full 发布包已改为静态 Web UI + Rust BFF，Online 已有远端配置、健康检查和远端认证转发。`v0.0.0-preview.5` 已验证真实 tag-only 预览发布和 Desktop Full/Linux 真实后端 AppImage sidecar/API smoke。App 当前仍只是后续想法，不进入本轮发布闭环；完整 tag-only 自动发布后续仍需补齐失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证。

## 目标

常规发版时，人工只需要在公开主仓库打并推送一个 release tag，其余步骤由 GitHub Actions 自动完成。

```text
人工推送主仓库 tag
  -> 主仓库启动 release
  -> 主仓库判断后端历史 Release asset 是否可复用
  -> 不可复用时后端私有仓库构建 native artifact
  -> 主仓库组装 Web/Desktop/后端资产
  -> draft Release
  -> 上传资产
  -> 远端回读校验
  -> publish Release
```

发布流程不得使用 `latest`。每次发布以主仓库 release tag 指向的 root commit 作为事实源。

## Tag 规则

tag 名称同时决定发布类型：

- `v1.2.3`：正式发布。`release-start.yml` 会触发 `release_mode=publish`，`release.yml` 远端校验通过后发布为普通 GitHub Release。
- `v1.2.3-rc.1`、`v1.2.3-beta.1`、`v1.2.3-preview.1`：预览发布。`release-start.yml` 同样触发 `release_mode=publish`，但 `release.yml` 会发布为 GitHub prerelease，并且不会标记为 Latest。
- 手动 `workflow_dispatch` 默认仍是 `release_mode=draft`，用于 dry-run、排障或重跑 assemble，不作为常规发布入口。

只有无 prerelease 后缀的 `v<major>.<minor>.<patch>` tag 才视为正式稳定版。带 `+build` metadata 但没有 `-prerelease` 后缀的 tag 仍按稳定版处理；不建议日常发版使用 build metadata。

## 当前状态

截至 2026-06-16：

- 已有 `check-*` 与 `debug-*` 手动验证 workflow。
- `.github/workflows/release-start.yml` 已提供正式 tag start 入口第一版：真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文，按 tag 形态区分正式发布与预览发布，先在主仓库尝试复用最新一个合格历史 Release 中的后端 native asset；复用成功时直接触发主仓库 `release.yml`，复用失败时才触发后端私有仓库 release resolver 运行 native build；手动入口默认 dry-run，并可在不触发后端、不创建 Release 的前提下预演历史复用判断。
- `.github/workflows/release.yml` 已提供正式 assemble 入口第一版，可接收后端来源 payload，构建 Web node-server asset、Desktop Online Windows/Linux asset 和 Desktop Full Windows/Linux asset，创建 draft Release、上传资产并远端回读校验 size、sha256、manifest 记录、必需资产和禁止文件规则；`release_mode=publish` 时远端校验通过后发布。
- 当前 `release.yml` 支持多个后端 Actions artifact 聚合，也支持从同一个历史主仓库 Release 复用多个后端 native asset；已接入 Web node-server、Desktop Online 和 Desktop Full 构建。App 当前不构建、不要求 asset，也不阻塞 publish。
  在资产上传、远端回读校验和可选 publish 成功后，workflow 会尽力删除已消费的主仓库临时 artifacts 和后端 native Actions artifacts；删除失败只作为清理告警处理，不阻塞已成功的 Release。
- Desktop Full 包内已携带同平台已解压 `backend-full` 和 `backend-build.json`，Desktop 侧已实现本机后端启动、健康检查、`/local/session` 读取和退出清理的最小闭环。
  Desktop Online/Full 发布包使用 Web `desktop-static` 静态输出和 Rust BFF；Online 已实现远端地址配置、健康检查、login/refresh/logout 和业务请求 Bearer 注入；`v0.0.0-preview.5` 已完成 Full Linux AppImage sidecar/API smoke，真实安装包矩阵验证仍待后续补齐。
- 后端私有仓库 `.github/workflows/backend-release-resolve.yml` 已收缩为 native build resolver：只按输入的 `backend_commit` 构建后端 native Actions artifact，并可在构建成功后回调主仓库 `release.yml` assemble；它不读取主仓库历史 Release。
- 本手册描述目标流程；当前已具备“只推 tag 触发 publish/prerelease”的自动化路径，且已用 `v0.0.0-preview.5` 完成预览发布全链路验证。
- 跨仓库凭据、artifact 交接、历史 Release asset 复用和失败 draft 保留边界见 ADR 0013 与 ADR 0014。
- 安装器代码签名、公证、自动更新运行时接入、release notes 和版本号策略仍待单独确认；Tauri updater 静态 JSON 与 `release-manifest.json` 的清单边界已在 release 契约中确认。

## 目标 workflow

### 主仓库 release start

触发条件：

```yaml
on:
  push:
    tags:
      - 'v*'
```

职责：

- 校验 tag 名称和版本号。
- 确认 tag 指向的 root commit 存在。
- checkout tag 对应的 root commit。
- 读取 `services/backend`、`apps/web`、`apps/desktop` 和后续 `apps/mobile` 的子模块指针。
- 通过 `scripts/openapi-snapshot-hash.ps1` 计算 OpenAPI snapshot hash。
- 生成 `releaseIntentId`，推荐格式为 `<version>:<rootCommit>`。
- 只检查最新一个合格已发布主仓库 Release，判断后端 native asset 是否可复用；规则排除 draft、当前版本、`latest` 和 smoke/test tag，不排除 prerelease。
- 复用成功时直接触发主仓库 release assemble workflow。
- 复用失败时触发后端私有仓库 release resolve workflow 运行 native build。

当前第一版限制：

- 手动 `workflow_dispatch` 可以通过 `historical_release_tag` 指定历史 Release；留空时仍只检查最新一个合格已发布 Release。
- 手动 `workflow_dispatch` 默认 `dry_run=true`，会验证上下文计算并预演后端来源判断，但不会触发主仓库 release assemble，也不会触发后端 resolver。
- `services/backend` 子模块 commit 不要求等于后端仓库当前 `main`。主仓库 release start 不持有后端源码读取权限，也不调用后端 commit API；后端 workflow 文件可以从后端 `main` 启动，但后端源码 checkout 和 native build 必须锁定输入的 `backend_commit` 并在 checkout 后校验。

### 后端 release resolve

触发方式：

- 由主仓库自动触发。

输入：

- `version`
- `root_ref`
- `root_commit`
- `backend_commit`
- `openapi_hash`
- `required_assets_json`
- `release_intent_id`

职责：

- checkout 指定 `backend_commit`，不按后端仓库当前 `main` 打包源码。
- 根据 `required_assets_json` 计算 native build scope 和 artifact name。
- 调用 `backend-native-artifact.yml` 运行后端 native build。
- 上传 `retention-days: 1` 的 Actions artifact，并生成 `backend_source_mode=github-actions-artifact`。
- 如果 `trigger_release_assemble=true`，使用 `HDX Main Workflow Bot` 的 `Actions: write` token 触发主仓库 release assemble workflow。

当前第一版限制：

- 后端 release resolve 不读取主仓库历史 Release，不 checkout 主仓库发布工具，也不需要主仓库 `Contents: read` GitHub App 权限。
- 后端 workflow 控制平面仍从后端仓库 `main` 的 workflow 文件启动；源码和 manifest 必须锁定输入的 `backend_commit`。

### 主仓库 release assemble

触发方式：

- 由后端私有仓库自动触发。
- 当前第一版 `release.yml` 仍保留 `workflow_dispatch` 手动入口，用于排障或重跑 assemble。

输入：

- `version`
- `root_ref`
- `root_commit`
- `backend_commit`
- `backend_source_mode`
- `backend_sources_json`
- `release_intent_id`
- `release_mode`：`draft` 或 `publish`，手动入口默认 `draft`；tag start 路径传 `publish`

职责：

- 校验 tag、root commit、backend commit 和 payload 一致。
- 拒绝 `latest`。
- 根据 `backend_source_mode` 下载后端 Actions artifact 或历史主仓库 Release asset。
- 校验后端 manifest、sha256、size、OpenAPI hash、backend native fingerprint 和禁止文件。
- 构建 Web。
- 构建 Desktop Online。
- 构建 Desktop Full，并内置同平台 `backend-full`。
- App 当前暂不进入发布闭环；后续 App 有基础工程和打包入口后再单独接入 App Online。
- 从 Desktop 安装包/AppImage 和 Tauri `.sig` 文件生成 flavor/channel 专用 updater JSON，例如 `HDX.Desktop.Online_stable.json` 和 `HDX.Desktop.Full_stable.json`。
- 生成 `release-manifest.json` 和 `SHA256SUMS`。
- 创建 draft Release。
- 上传全部资产。
- 从远端 Release 回读全部资产，并复验 size、sha256、release manifest 记录和禁止文件规则。
- `release_mode=publish` 时，校验通过后 publish Release；预览 tag 发布为 GitHub prerelease。
- 成功路径尽力删除已消费的 Actions 临时 artifacts；Release 资产是长期事实源，Actions artifacts 只作为 workflow 交接使用。

当前第一版限制：

- `github-actions-artifact` 模式支持多个 `backend_sources_json.sources` 条目。
- `historical-release-asset` 模式支持多个 `backend_sources_json.sources` 条目，但第一版要求这些条目来自同一个历史主仓库 Release，并覆盖历史 `backend-native-manifest.json` 记录的全部后端 native asset。
- 历史 Release asset 复用判断由主仓库 release start 完成；未指定历史 tag 时只检查最新一个合格已发布 Release，不排除 prerelease。
- 后端 release resolve 只负责 native build fallback，并可通过 `trigger_release_assemble=true` 显式回调主仓库 `release.yml`；手动排障默认关闭，避免误创建 draft Release。
- 已构建 Web node-server asset、Desktop Online asset 和 Desktop Full asset。
- Desktop Full 包内已携带同平台已解压 `backend-full` 和 `backend-build.json`；本机后端启动、健康检查、`/local/session` 读取和退出清理已有最小闭环。
  Desktop Online/Full 发布包已改为静态 Web UI + Rust BFF；Online 已实现远端地址配置、健康检查、login/refresh/logout 和业务请求 Bearer 注入；`v0.0.0-preview.5` 已完成 Full Linux AppImage sidecar/API smoke，真实安装包矩阵验证仍待后续补齐。
- 不构建 App，不要求 App asset。
- 手动 `workflow_dispatch` 默认只保留 draft；真实 tag push 会传 `release_mode=publish`。

第一版 `github-actions-artifact` 多来源示例：

```json
{
  "sources": [
    {
      "type": "github-actions-artifact",
      "backendRepository": "xxldm/hdx-backend",
      "runId": 123456789,
      "runAttempt": 1,
      "artifactName": "hdx-backend-full-native-v0.1.0-linux-x64"
    },
    {
      "type": "github-actions-artifact",
      "backendRepository": "xxldm/hdx-backend",
      "runId": 123456789,
      "runAttempt": 1,
      "artifactName": "hdx-backend-full-native-v0.1.0-windows-x64"
    },
    {
      "type": "github-actions-artifact",
      "backendRepository": "xxldm/hdx-backend",
      "runId": 123456789,
      "runAttempt": 1,
      "artifactName": "hdx-backend-services-native-v0.1.0-linux-x64"
    }
  ]
}
```

第一版 `historical-release-asset` 多来源示例：

```json
{
  "sources": [
    {
      "type": "historical-release-asset",
      "historicalReleaseRepository": "xxldm/hdx",
      "historicalReleaseTag": "v0.1.0",
      "historicalBackendAssetName": "hdx-backend-full-linux-x64-v0.1.0.tar.gz",
      "assetSha256": "385875b7627f16e4a43293ef76e22665bdf6131bc1ebda1708b6d416c41177e0",
      "assetSizeBytes": 161,
      "backendRepository": "xxldm/hdx-backend"
    },
    {
      "type": "historical-release-asset",
      "historicalReleaseRepository": "xxldm/hdx",
      "historicalReleaseTag": "v0.1.0",
      "historicalBackendAssetName": "hdx-backend-services-linux-x64-v0.1.0.tar.gz",
      "assetSha256": "d1d245c11070d78478d598d73ab59ab312474931b1c5c1b16db1d22600362e39",
      "assetSizeBytes": 220,
      "backendRepository": "xxldm/hdx-backend"
    }
  ]
}
```

## 人工发版步骤

### 1. 发版前检查

确认：

- 所有代码和文档改动已经提交并推送。
- 主仓库 `main` 指向要发布的 root commit。
- 子模块指针已经更新并推送到各自远端。
- 目标版本号未发布过。
- 没有同名 tag 或同名 draft Release。
- 本轮不需要调整签名、公证、自动更新或 release notes 策略。

可选本地检查：

```powershell
git status --short --branch
git submodule status
pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild
```

真实发版前应以 CI 结果为准；本地检查只作为补充。

### 2. 打并推送 tag

在公开主仓库执行：

```powershell
git fetch --all --tags
git checkout main
git pull --ff-only origin main
git tag -a v0.1.0 -m "HDX v0.1.0"
git push origin v0.1.0
```

预览发布使用 prerelease tag，例如：

```powershell
git tag -a v0.1.0-rc.1 -m "HDX v0.1.0-rc.1"
git push origin v0.1.0-rc.1
```

人工常规操作到此结束。

### 3. 观察自动化结果

依次观察：

- 主仓库 release start workflow。
- 如果主仓库未复用历史后端 asset，再观察后端私有仓库 release resolve workflow。
- 主仓库 release assemble workflow。

成功标准：

- GitHub Release 已 publish，不是 draft。
- 正式 tag 发布为普通 GitHub Release；prerelease tag 发布为 GitHub prerelease，且不标记为 Latest。
- Release asset 清单符合版本预期。
- `release-manifest.json` 存在。
- `SHA256SUMS` 存在。
- `release-manifest.json` 中的 root commit 等于 tag commit。
- `release-manifest.json` 中的 backend commit 等于 root commit 锁定的 `services/backend` 子模块 commit。
- 如果后端来源为历史 Release asset，manifest 中必须记录历史 release tag、asset name、sha256、size 和 backend native fingerprint。

## 失败处理

### release start 失败

如果失败发生在主仓库 release start 阶段：

- 不会创建 GitHub Release。
- 检查 tag 名、root commit、子模块指针和发布凭据。
- 如果 tag 本身错误，确认未创建正式 Release 后再处理 tag。

### 后端 release resolve 失败

如果失败发生在后端阶段：

- 主仓库不会进入 release assemble。
- 检查后端 workflow 日志。
- 如果是 artifact 过期、runner 环境、GitHub Actions 临时失败，可以重跑后端 workflow。
- 如果需要修改代码，提交新 commit 后应发布新版本 tag，不应把已公开使用的 tag 移到新 commit。

### release assemble 在 draft 前失败

如果 draft 尚未创建：

- 不会产生 GitHub Release。
- 修复后可以重跑主仓库 release assemble 或重新触发 tag 流程。

### release assemble 在 draft 后失败

如果 draft 已创建但未 publish：

- 不得直接把失败 draft 改为 publish。
- 先阅读 run summary，确认失败 job、已上传 asset 和校验结果。
- 失败 draft 默认保留用于排障，workflow 不自动删除；失败路径上的 Actions 临时 artifacts 也可能保留到 1 天过期或人工清理。
- 需要重跑同版本前，先人工删除失败 draft；如果 tag 本身错误，再按 Git 规则处理 tag。
- 测试或失败 draft 清理后，应确认对应 tag/ref 状态符合预期。

## 禁止事项

- 不从主仓库 checkout 后端私有源码。
- 不用 `latest` 查找后端 run、artifact 或 Release。
- 不把后端源码、JAR/WAR、`.class`、`target/classes` 或后端构建中间产物上传到主仓库 Release。
- 不把具备主仓库 Release 写权限的长期凭据放入后端仓库。
- 不把 GitHub App private key、JWT、installation token 写入日志、artifact、cache 或 Release asset。
- 不用失败 draft 伪装正式发布。

## 参考

- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`
- `packages/shared/contracts/release/README.md`
- `.github/workflows/README.md`
