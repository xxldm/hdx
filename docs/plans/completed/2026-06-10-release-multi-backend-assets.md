# Release 多后端 native asset 聚合

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续补齐 release 多后端 native asset 聚合
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

让主仓库正式 `release.yml` 第一版可以从同一个后端 workflow run 的多个 Actions artifact 聚合默认后端发布资产，生成统一的 `backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。

默认目标资产为：

- `backend-full-linux-x64`
- `backend-full-windows-x64`
- `backend-services-linux-x64`
- 后续可选 `backend-services-windows-x64`

## 非目标

- 不实现历史 Release asset 多资产聚合；历史复用仍保持单资产路径。
- 不实现后端 release resolve 自动 fingerprint 匹配。
- 不触发新的后端 native-image 构建。
- 不实现 Web、Desktop、App 真实打包或正式 publish。

## repo 内范围

- `.github/workflows/release.yml`
- `scripts/release-assemble-backend-assets.ps1`
- `scripts/release-manifest-check.ps1`
- `packages/shared/contracts/release/`
- release 相关 ADR、runbook、workflow 索引和总纲计划

## 实施计划

- [x] 扩展 release 契约，记录多个后端 Actions artifact 的逐资产 provenance。
- [x] 新增多后端 Actions artifact 聚合脚本，复用既有后端 artifact 内容校验。
- [x] 更新 `release.yml`，允许 `backend_sources_json.sources[]` 在 `github-actions-artifact` 模式下包含多个来源。
- [x] 保持 `historical-release-asset` 模式第一版单来源限制。
- [x] 补齐有效样例和文档说明。
- [x] 运行 actionlint、release manifest 校验、docs 质量门禁和空白检查。

## 实现记录

- `release-manifest.json` 与 `backend-native-manifest.json` schema 新增 `githubActionsArtifacts`，用于记录多后端 Actions artifact 的逐来源 provenance。
- `release-manifest.json` 的 backend asset `source` 新增逐资产 `githubActions`，用于把每个后端 archive 追溯到对应 artifact。
- 新增 `scripts/release-assemble-backend-assets.ps1`，从已下载并解析到本地的多个后端 Actions artifact 生成统一的后端 native assets、`backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。
- `release.yml` 在 `github-actions-artifact` 模式下允许多个 `backend_sources_json.sources[]`，并要求来源类型一致、后端仓库一致、artifact 不使用 `latest`；`historical-release-asset` 模式继续限制单来源。
- release runbook、workflow 索引、架构文档、ADR 0013、ADR 0014 和 release contracts README 已同步当前状态。

## 验收标准

- 多个后端 Actions artifact 可以汇总到一个 Release asset 目录。
- 统一 `backend-native-manifest.json` 记录所有后端 native archive。
- `release-manifest.json` 中每个 backend asset 都保留对应 `githubActions` 来源、sha256、size、OpenAPI hash 和 backend native fingerprint。
- `release.yml` 不从后端或主仓库查找 `latest`。
- 历史 Release asset 多来源仍明确标记为未完成，不伪装完成。

## 验证结果

- 已执行 `actionlint .github/workflows/release.yml`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -Command '[scriptblock]::Create((Get-Content -LiteralPath "scripts/release-assemble-backend-assets.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-manifest-check.ps1" -Raw)) | Out-Null'`：通过。
- 已执行本地 fixture 聚合验证：通过，生成 2 个后端 native archive、`backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。

```powershell
pwsh -NoLogo -NoProfile -File scripts/release-assemble-backend-assets.ps1 -SourcesJsonPath target/release-assemble-test/sources.json -Version v0.1.0 -RootRepository xxldm/hdx -RootRef refs/tags/v0.1.0 -RootCommit 1111111111111111111111111111111111111111 -BackendRepository xxldm/hdx-backend -BackendCommit 2222222222222222222222222222222222222222 -OpenApiSnapshotHash aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -OutputDirectory target/release-assemble-test/assets -ExtractRoot target/release-assemble-test/extracted
```

- 已执行 `git diff --check` 与 `git diff --cached --check`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 归档备注

- GitHub-hosted 真实多 artifact run 仍需后续用实际后端 artifact 验证。
- OpenAPI snapshot hash 仍由调用方显式传入，统一计算入口需要后续单独收口。
- 多历史 Release asset 复用和自动 fingerprint 匹配仍未实现。

## 相关 commit

- 本提交：`功能：支持 release 多后端资产聚合`。
