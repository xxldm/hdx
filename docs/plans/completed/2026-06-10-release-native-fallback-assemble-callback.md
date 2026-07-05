# Release 后端 native fallback 与 assemble 回调

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续做后端 resolver 的 native build fallback 和回调主仓库 assemble
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

让后端 `backend-release-resolve.yml` 在历史 Release asset 不能复用时，能够进入后端 native build fallback，并在解析出后端来源后可回调主仓库 `release.yml` 继续 assemble。

## 非目标

- 不实现主仓库 tag push start workflow。
- 不把主仓库 `release.yml` 改成自动 publish。
- 不补 Web、Desktop、App 真实打包。
- 不改变后端 native artifact 的打包格式、manifest schema 或 Release asset 文件名规则。
- 不默认在手动排障时创建主仓库 draft Release；assemble 回调通过显式输入开启。

## 实施结果

- [x] 为 `backend-native-artifact.yml` 增加 `workflow_call` 入口，保留现有手动 `workflow_dispatch`。
- [x] 调整 `backend-release-resolve.yml`：历史复用失败不立即终止，而是输出失败原因和 fallback 上下文。
- [x] 增加 native build fallback job，复用后端 native artifact workflow，不复制 native-image 构建步骤。
- [x] 增加最终解析结果 job，统一上传 `backend-source-resolution-<version>` artifact。
- [x] 增加可选 assemble callback，触发主仓库 `release.yml`。
- [x] 更新 README、ADR、release runbook 和总纲状态。
- [x] 运行 actionlint、本地文档门禁和 GitHub Actions smoke。

## 验收记录

- 后端 commit：`58725b62525aa54d90230bf8830af10f13ee92c6`
- 主仓库 root commit：`68990cadb91c01554fba32de58c5739c11fe44ba`
- smoke 历史 prerelease：`v0.0.994-rc.1`
- smoke 当前发布版本：`v0.0.995-rc.1`
- 后端 resolver run：`27260467182`
- 主仓库 release assemble run：`27260510692`

后端 resolver smoke 使用 `trigger_release_assemble=true`、`allow_native_build_fallback=false`：

- `Resolve historical backend assets` 成功选择临时历史 prerelease。
- `Native build fallback` 按预期跳过。
- `Finalize backend source resolution` 成功上传 `backend-source-resolution-v0.0.995-rc.1`，并触发主仓库 `release.yml`。
- 下载的 resolver artifact 中，`backendSourceMode` 为 `historical-release-asset`，`historicalRelease.tag` 为 `v0.0.994-rc.1`。
- artifact 同时包含 `hdx-backend-full-linux-x64-v0.0.994-rc.1.tar.gz` 和 `hdx-backend-services-linux-x64-v0.0.994-rc.1.tar.gz` 两个历史 asset 来源。

主仓库 assemble smoke：

- `Validate release inputs` 通过。
- `Assemble draft release` 通过。
- 历史 Release asset 下载、历史复用来源资产生成、draft Release 创建、资产上传和远端 Release 资产校验均通过。
- 回调创建的 `v0.0.995-rc.1` draft Release 已删除；删除时 `--cleanup-tag` 返回 tag ref 不存在，复查确认 Release 已不存在。
- 临时历史 prerelease `v0.0.994-rc.1` 已删除并清理 tag。
- `gh release list --repo xxldm/hdx --limit 20 --json tagName,isDraft,isPrerelease` 最终返回空列表。

## 验证命令

- `actionlint services/backend/.github/workflows/backend-release-resolve.yml`
- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`
- `git -C services/backend diff --check`
- `git diff --check`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `pwsh -NoLogo -NoProfile -File scripts/release-assemble-backend-assets.ps1 ...`
- `gh workflow run backend-release-resolve.yml --repo xxldm/hdx-backend --ref main ...`
- `gh run watch 27260467182 --repo xxldm/hdx-backend --exit-status`
- `gh run watch 27260510692 --repo xxldm/hdx --exit-status`
- `gh run download 27260467182 --repo xxldm/hdx-backend --name backend-source-resolution-v0.0.995-rc.1 --dir target/release-fallback-callback-smoke/run-27260467182`

## 相关 commit

- 后端仓库：`58725b62525aa54d90230bf8830af10f13ee92c6`
- 主仓库中间记录：`68990cadb91c01554fba32de58c5739c11fe44ba`

## 剩余风险

- 本切片没有远端实跑 native-image fallback，以避免额外消耗私有仓库 Actions 额度；该路径已通过 actionlint、reusable workflow 接线和 payload 生成逻辑检查，后续真实发版或专门验证时再实跑。
- 主仓库 `release.yml` 仍只创建并校验 draft，不构建 Web/Desktop/App，也不自动 publish。
- 完整 tag-only release start 仍未实现；后续需要由主仓库 tag push 自动触发后端 resolver，并显式开启 `allow_native_build_fallback` 与 `trigger_release_assemble`。
