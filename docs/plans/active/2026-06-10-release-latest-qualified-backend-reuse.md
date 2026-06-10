# Release 最新合格后端复用解析

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中
- 计划来源：用户确认只检查最新一个合格 Release；不排除候选 prerelease，按最后一个已发布 Release 优先复用
- 创建时间：2026-06-10

## 目标

让后端 release resolve workflow 在未显式传入历史 Release tag 时，自动选择最新一个合格主仓库 Release 进行后端 native asset 复用解析。

## 非目标

- 不扫描多个历史 Release。
- 不实现匹配失败后的 native-image 自动构建。
- 不回调主仓库 release assemble。
- 不改变 release manifest 或 backend native manifest schema。

## 实施计划

- [ ] 将 `backend-release-resolve.yml` 的 `historical_release_tag` 改为可选输入。
- [ ] 新增最新合格 Release 选择步骤：排除 draft、排除当前版本、排除 smoke/test tag，不排除 prerelease，按发布时间选择最新一个。
- [ ] 下载步骤改用解析后的历史 Release tag。
- [ ] 更新后端 README、ADR/计划文档，明确第一版只检查最新一个合格 Release。
- [ ] 运行 workflow 静态检查、本地文档检查和 GitHub Actions smoke。

## 验收标准

- 显式传入 `historical_release_tag` 时仍按指定 tag 解析。
- 不传 `historical_release_tag` 时，workflow 只选择一个最新合格 Release。
- 候选 Release 可以是 prerelease；正式版转正时优先复用上一版 prerelease 的后端 native asset。
- 找不到合格 Release 时，失败信息明确指向需要后续 native build 分支。

## 剩余风险

- 只检查最新一个合格 Release 可能错过更老但可复用的 Release；这会导致后续进入 native build 分支，属于成本风险，不是正确性风险。
