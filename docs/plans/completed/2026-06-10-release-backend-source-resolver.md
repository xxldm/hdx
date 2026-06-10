# Release 后端来源解析

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续实现后端来源解析切片
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

补齐发布链路中“后端 native 来源从哪里来”的解析层，让后续 tag-only 发布不再依赖人工手写完整 `backend_sources_json`。

## 非目标

- 不在本切片实现完整 tag-only 发布。
- 不在本切片接入 Web、Desktop 或 App 真实打包。
- 不改变后端 native-image 的构建产物格式。
- 不 publish Release；仍保持 draft assemble 边界。

## repo 内范围

- 主仓库 release 相关脚本和文档。
- 后端私有仓库 release resolve workflow 入口。
- release 相关 ADR、runbook、workflow 索引和总纲计划。

## 实施结果

- [x] 梳理 ADR 0013/0014 中的 release start、backend release resolve 和 release assemble 边界。
- [x] 确认 resolver 的最小输入、输出和落点。
- [x] 实现一个可本地验证的最小 resolver 切片，优先覆盖历史 Release asset 复用结果生成。
- [x] 为无法复用历史资产的情况输出明确的后端 native build 后续条件。
- [x] 更新文档，避免把 resolver 描述成完整 tag-only 自动发布。
- [x] 运行相关 workflow、script 和 docs 验证。

## 实现记录

- 新增 `scripts/release-resolve-backend-sources.ps1`，从指定历史主仓库 Release 目录解析后端 native 来源，校验 `release-manifest.json`、`backend-native-manifest.json`、资产 sha256、size、kind、platform、root commit、backend commit 和 OpenAPI snapshot hash，并生成可供当前 `release.yml` 消费的 compact `backend_sources_json`。
- 新增后端私有仓库 `.github/workflows/backend-release-resolve.yml`，支持手动输入 release 版本、root/backend 提交、OpenAPI hash、候选历史 Release tag 和 required assets，下载候选主仓库 Release asset 后调用主仓库 resolver，并上传 `backend-source-resolution-<version>` artifact，保留期 1 天。
- 后端 resolver workflow 只覆盖“指定历史 Release asset 复用”的第一片，不自动搜索历史版本、不触发 native-image、不回调主仓库 assemble。
- 更新 `docs/ARCHITECTURE.md`、`docs/RELEASE_RUNBOOK.md`、ADR 0013、ADR 0014、release contracts README 和总纲计划，明确当前能力与未完成边界。

## 验证记录

- `actionlint services/backend/.github/workflows/backend-release-resolve.yml`
- `pwsh -NoLogo -NoProfile -Command '[scriptblock]::Create((Get-Content -LiteralPath "scripts/release-resolve-backend-sources.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-assemble-historical-backend-assets.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-manifest-check.ps1" -Raw)) | Out-Null'`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/release-resolve-backend-sources.ps1 -HistoricalAssetRoot target/release-assemble-test/assets -RequiredAssetsJsonPath target/release-resolve-test/required-assets.json -Version v0.1.1 -RootRepository xxldm/hdx -RootRef refs/tags/v0.1.1 -RootCommit 3333333333333333333333333333333333333333 -BackendRepository xxldm/hdx-backend -BackendCommit 2222222222222222222222222222222222222222 -OpenApiSnapshotHash aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -OutputPath target/release-resolve-test/backend-source-resolution.json`
- `git -C services/backend diff --check`
- `git -C services/backend diff --cached --check`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 剩余风险

- `backend-release-resolve.yml` 尚未在 GitHub Actions 上跑真实手动任务。
- 历史 Release 仍由人工指定；自动搜索可复用历史 Release 需要后续切片。
- 匹配失败后尚未自动触发后端 native-image workflow。
- 后端 resolver 尚未用 GitHub App token 回调主仓库正式 assemble。
- 如果主仓库 Release 不是公开可读，后端 workflow 下载候选历史 Release asset 时需要补 GitHub App token。

## 相关 commit

- 后端私有仓库：`1325207122030068624dbc3dd22720c3ba4bdb34`（功能：添加后端来源解析入口）
- 主仓库：本完成计划所在提交。
