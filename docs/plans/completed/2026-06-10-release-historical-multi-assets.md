# Release 历史后端多资产复用

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意优先补齐 historical-release-asset 多资产复用
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

让主仓库 `release.yml` 在 `historical-release-asset` 模式下也能从历史主仓库 Release 同时复用多个后端 native asset，生成当前版本的 `backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。

默认目标资产包括：

- `backend-full-linux-x64`
- `backend-full-windows-x64`
- `backend-services-linux-x64`
- 后续可选 `backend-services-windows-x64`

## 非目标

- 不实现 tag-only 发布入口。
- 不实现后端来源自动解析或 fingerprint 自动匹配。
- 不触发新的后端 native-image 构建。
- 不接入 Web、Desktop、App 真实打包或正式 publish。

## repo 内范围

- `.github/workflows/release.yml`
- historical release asset 复用相关脚本
- `scripts/release-manifest-check.ps1`
- `packages/shared/contracts/release/`
- release 相关 ADR、runbook、workflow 索引和总纲计划

## 实施计划

- [x] 梳理现有 historical 单资产复用脚本、workflow 分支和 schema 表达。
- [x] 扩展 historical 输入，允许多个显式历史 Release asset 来源。
- [x] 新增聚合脚本，校验多个历史 asset 的 sha256、size、kind/platform、backend commit、OpenAPI hash 和 provenance。
- [x] 更新 `release.yml` historical 分支，下载多个历史 Release asset 并生成统一当前版本 manifest。
- [x] 补齐有效样例和文档说明。
- [x] 运行 actionlint、release manifest 校验、docs 质量门禁和空白检查。

## 实现记录

- 新增 `scripts/release-assemble-historical-backend-assets.ps1`，消费已下载的多个历史主仓库 Release asset 目录，生成当前版本的 `release-manifest.json`、`SHA256SUMS` 和复用后端 native assets。
- `release.yml` 的 `historical-release-asset` 分支允许多个 `backend_sources_json.sources[]`，下载每个历史后端 asset 以及对应历史 `release-manifest.json`、`backend-native-manifest.json` 后交给聚合脚本。
- historical 多来源第一版要求所有来源来自同一个历史主仓库 Release，并要求输入显式提供 `assetSha256` 和 `assetSizeBytes`。
- 聚合脚本要求 sources 覆盖历史 `backend-native-manifest.json` 记录的全部后端 native asset；不重写或重命名历史 backend native archive。
- 新增 `release-manifest-multi-historical-backend-native.json` 有效样例，覆盖当前版本复用历史版本多个后端 native asset 的 manifest 表达。
- release runbook、workflow 索引、架构文档、ADR 0013、ADR 0014、release contracts README 和总纲计划已同步当前状态。

## 验收标准

- historical 模式不再限制单个 `sources[]`。
- 多个历史后端 asset 必须显式指定 `historicalReleaseTag`、`historicalBackendAssetName`、`assetSha256` 和 `assetSizeBytes`，不能使用 `latest`。
- `release-manifest.json` 中每个 backend asset 都记录对应历史 Release asset 来源和原始后端构建来源。
- 不允许混用不一致的 backend commit、OpenAPI hash 或重复 kind/platform。
- 当前版本 manifest 仍以本次 root ref/root commit 为事实源。

## 验证结果

- 已执行 `actionlint .github/workflows/release.yml`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -Command '[scriptblock]::Create((Get-Content -LiteralPath "scripts/release-assemble-historical-backend-assets.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-assemble-backend-assets.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-manifest-check.ps1" -Raw)) | Out-Null'`：通过。
- 已执行本地 fixture 聚合验证：通过，使用 `target/release-assemble-test/assets` 作为历史 Release，复用 2 个后端 native asset，生成 `backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。

```powershell
pwsh -NoLogo -NoProfile -File scripts/release-assemble-historical-backend-assets.ps1 -SourcesJsonPath target/release-historical-assemble-test/sources.json -Version v0.1.1 -RootRepository xxldm/hdx -RootRef refs/tags/v0.1.1 -RootCommit 3333333333333333333333333333333333333333 -BackendRepository xxldm/hdx-backend -BackendCommit 2222222222222222222222222222222222222222 -OpenApiSnapshotHash aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -OutputDirectory target/release-historical-assemble-test/assets
```

- 已执行 `git diff --check` 与 `git diff --cached --check`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 剩余风险

- 真实 GitHub-hosted 多历史 asset 复用仍需后续用主仓库历史 Release 验证。
- 后端来源自动解析仍未实现，调用方仍需显式提供历史来源列表。
- 历史 asset 是否可复用的 fingerprint 自动匹配仍未实现。

## 相关 commit

- 本提交：`功能：支持 release 历史多资产复用`。
