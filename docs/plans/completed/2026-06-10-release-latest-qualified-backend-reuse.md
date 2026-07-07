# Release 最新合格后端复用解析

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户确认只检查最新一个合格 Release；不排除候选 prerelease，按最后一个已发布 Release 优先复用
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

让后端 release resolve workflow 在未显式传入历史 Release tag 时，自动选择最新一个合格主仓库 Release 进行后端 native asset 复用解析。

## 非目标

- 不扫描多个历史 Release。
- 不实现匹配失败后的 native-image 自动构建。
- 不回调主仓库 release assemble。
- 不改变 release manifest 或 backend native manifest schema。

## 实施结果

- [x] 将 `backend-release-resolve.yml` 的 `historical_release_tag` 改为可选输入。
- [x] 新增最新合格 Release 选择步骤：排除 draft、排除当前版本、排除 `latest`、排除 smoke/test tag，不排除 prerelease，按发布时间选择最新一个。
- [x] 下载步骤改用解析后的历史 Release tag。
- [x] 更新后端 README、ADR/计划文档，明确第一版只检查最新一个合格 Release。
- [x] 运行 workflow 静态检查、本地文档检查和 GitHub Actions smoke。

## 验收记录

- 显式传入 `historical_release_tag` 时仍按指定 tag 解析；未传时走 `latest-qualified` 自动选择模式。
- GitHub Actions smoke 创建临时主仓库 prerelease `v0.0.997-rc.1`，触发后端 resolver 发布版本 `v0.0.998-rc.1`，未传 `historical_release_tag`。
- 后端 resolver run `27259131567` 通过，输出 artifact `backend-source-resolution-v0.0.998-rc.1`。
- artifact 中 `backendSourceMode` 为 `historical-release-asset`，`historicalRelease.tag` 为 `v0.0.997-rc.1`。
- artifact 中同时解析到 `hdx-backend-full-linux-x64-v0.0.997-rc.1.tar.gz` 和 `hdx-backend-services-linux-x64-v0.0.997-rc.1.tar.gz`。
- 临时 prerelease 和 tag 已通过 `gh release delete v0.0.997-rc.1 --repo xxldm/hdx --yes --cleanup-tag` 清理；`gh release list --repo xxldm/hdx --limit 20 --json tagName,name,isDraft,isPrerelease` 返回空列表。

## 验证命令

- `actionlint services/backend/.github/workflows/backend-release-resolve.yml`
- `git -C services/backend diff --check`
- `git diff --check`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `gh workflow run backend-release-resolve.yml --repo xxldm/hdx-backend --ref main ...`
- `gh run watch 27259131567 --repo xxldm/hdx-backend --exit-status`
- `gh run download 27259131567 --repo xxldm/hdx-backend --name backend-source-resolution-v0.0.998-rc.1 --dir target/release-latest-qualified-smoke/run-27259131567`

## 相关 commit

- 后端仓库：`9ea1ba8fbed6cacce038706fb30c376a0d967f99`
- 主仓库中间记录：`162abb82404f685f2403546c660ec35ac7d2826d`

## 归档备注

- 只检查最新一个合格 Release 可能错过更老但可复用的 Release；这会导致后续进入 native build 分支，属于成本风险，不是正确性风险。
- 后端 resolver 仍未实现 native build fallback 和回调主仓库 release assemble；这部分继续归入第 9 步正式 tag-only 发布链路。
