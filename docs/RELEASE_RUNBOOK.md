# Release 操作手册

本文档记录 HDX 目标发布流程的日常人工操作和自动化边界。当前已存在正式 `release.yml` 第一版，但只覆盖手动触发的主仓库 draft assemble 骨架；完整 tag-only 自动发布仍待后续实现。

## 目标

常规发版时，人工只需要在公开主仓库打并推送一个 release tag，其余步骤由 GitHub Actions 自动完成。

```text
人工推送主仓库 tag
  -> 主仓库启动 release
  -> 后端私有仓库解析后端 native 来源
  -> 主仓库组装 Web/Desktop/App/后端资产
  -> draft Release
  -> 上传资产
  -> 远端回读校验
  -> publish Release
```

发布流程不得使用 `latest`。每次发布以主仓库 release tag 指向的 root commit 作为事实源。

## 当前状态

截至 2026-06-10：

- 已有 `check-*` 与 `debug-*` 手动验证 workflow。
- `.github/workflows/release.yml` 已提供正式入口第一版，可手动接收后端来源 payload，创建 draft Release、上传资产并远端回读校验。
- 当前 `release.yml` 只支持单个后端 native asset 来源，不构建 Web、Desktop 或 App，不自动 publish。
- 本手册描述目标流程，不表示当前已经可以只推 tag 发版。
- 跨仓库凭据、artifact 交接、历史 Release asset 复用和失败 draft 保留边界见 ADR 0013 与 ADR 0014。
- 安装器签名、公证、自动更新、release notes 和版本号策略仍待单独确认。

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
- 计算 OpenAPI snapshot hash。
- 生成 `releaseIntentId`，推荐格式为 `<version>:<rootCommit>`。
- 触发后端私有仓库 release resolve workflow。

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

- checkout 指定 `backend_commit`。
- 计算 backend native fingerprint。
- 查找主仓库历史 Release 中是否存在完全匹配的后端 native asset。
- 如果匹配，生成 `backend_source_mode=historical-release-asset`。
- 如果不匹配，运行后端 native build，上传 `retention-days: 1` 的 Actions artifact，并生成 `backend_source_mode=github-actions-artifact`。
- 触发主仓库 release assemble workflow。

### 主仓库 release assemble

触发方式：

- 由后端私有仓库自动触发。
- 当前第一版 `release.yml` 暂时通过 `workflow_dispatch` 手动触发，用于验证 assemble 骨架；后续再接入后端自动触发。

输入：

- `version`
- `root_ref`
- `root_commit`
- `backend_commit`
- `backend_source_mode`
- `backend_sources_json`
- `release_intent_id`

职责：

- 校验 tag、root commit、backend commit 和 payload 一致。
- 拒绝 `latest`。
- 根据 `backend_source_mode` 下载后端 Actions artifact 或历史主仓库 Release asset。
- 校验后端 manifest、sha256、size、OpenAPI hash、backend native fingerprint 和禁止文件。
- 构建 Web。
- 构建 Desktop Online。
- 构建 Desktop Full，并内置同平台 `backend-full`。
- 后续 App 可打包后构建 App Online。
- 生成 `release-manifest.json` 和 `SHA256SUMS`。
- 创建 draft Release。
- 上传全部资产。
- 从远端 Release 回读全部资产并复验。
- 校验通过后 publish Release。

当前第一版限制：

- 只支持一个 `backend_sources_json.sources` 条目。
- 只创建并校验 draft Release。
- 不构建 Web、Desktop 或 App。
- 不自动 publish。

第一版 `github-actions-artifact` 来源示例：

```json
{
  "sources": [
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

第一版 `historical-release-asset` 来源示例：

```json
{
  "sources": [
    {
      "type": "historical-release-asset",
      "historicalReleaseRepository": "xxldm/hdx",
      "historicalReleaseTag": "v0.1.0",
      "historicalBackendAssetName": "hdx-backend-services-linux-x64-v0.1.0.tar.gz",
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

人工常规操作到此结束。

### 3. 观察自动化结果

依次观察：

- 主仓库 release start workflow。
- 后端私有仓库 release resolve workflow。
- 主仓库 release assemble workflow。

成功标准：

- GitHub Release 已 publish，不是 draft。
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
- 需要重跑同版本前，先处理失败 draft 和 tag 状态。
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
