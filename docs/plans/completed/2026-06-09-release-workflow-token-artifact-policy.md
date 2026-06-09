# Release Workflow Token And Artifact Policy

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成，随本轮提交归档
- 计划来源：用户确认新增 ADR 0013，记录真实 Release workflow 的 GitHub App token、artifact 保留期和资产来源策略
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

新增 ADR 0013，明确真实 GitHub Release workflow 的凭据、跨仓库 artifact 读取、Actions artifact 保留期、资产来源和 draft 发布策略。

本轮完成后应具备：

- ADR 0013 记录使用 GitHub App token，不使用 fine-grained PAT。
- ADR 0013 记录后端私有 Actions artifact `retention-days: 1`。
- ADR 0013 记录第一版不做跨 Release 旧资产复用。
- ADR 0013 记录每次 Release 的资产必须来自本次 workflow 构建，或明确指定 `run_id` 的短期 Actions artifact。
- ADR 0013 记录真实 Release workflow 先创建 draft，上传和校验通过后再 publish。
- README、架构、约束、ADR 0012 和总纲同步最新状态。

## 非目标

- 本轮不实现真实 GitHub Release workflow。
- 本轮不创建 GitHub App，不配置 GitHub Secrets。
- 本轮不实现后端 native CI、artifact 下载、Release 创建或 asset 上传脚本。
- 本轮不处理安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/ARCHITECTURE.md`
- `docs/CONSTRAINTS.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-09-release-workflow-token-artifact-policy.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 ADR 0013。
- [x] 同步 README、架构、约束、ADR 0012 和总纲状态。
- [x] 运行文档验证。
- [x] 归档计划并提交推送。

## 验收标准

- ADR 0013 明确 GitHub App token 是跨仓库自动化凭据。
- ADR 0013 明确后端 Actions artifact 保留 1 天，过期重建，不作为长期发布存档。
- ADR 0013 明确第一版不自动复用历史 Release 资产。
- ADR 0013 明确所有 Release 资产来源必须可追溯到本次 workflow 或显式 `run_id` artifact。
- ADR 0013 明确 draft Release 到 publish 的边界。
- 现有文档不再把真实 Release workflow 的凭据和 artifact 策略列为待决策。

## 验证方式

- `rg -n "ADR 0013|GitHub App token|retention-days|draft|run_id|fine-grained PAT|跨 Release|latest" docs README.md`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- 本轮只做设计记录，不验证真实 GitHub App 权限或跨仓库 artifact API。
- GitHub App 创建、安装范围、secret 命名和 workflow action 版本仍需在实现前按 GitHub 当前能力确认。
- 真实 workflow 的失败清理、手动 publish 审批和 release notes 仍需后续小步确认。

## 状态记录

- 2026-06-09：创建计划，开始新增 ADR 0013。
- 2026-06-09：新增 ADR 0013，并同步 README、架构、约束、ADR 0012 和总纲状态。
- 2026-06-09：完成文档验证并归档计划。

## 验证结果

- `rg -n "ADR 0013|GitHub App token|retention-days: 1|run_id|draft|fine-grained PAT|跨 Release|latest" docs README.md`：通过，确认 ADR 0013、入口文档、架构、约束、ADR 0012 和总纲均可检索到关键策略。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可读、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- `git diff --check`：通过，仅提示部分文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。

## 剩余风险

- 本轮只做设计记录，没有创建 GitHub App、配置 secrets 或验证真实跨仓库 artifact 下载。
- GitHub App 具体名称、安装范围、secret 命名和 token 生成 action 版本仍需在实现前确认。
- 真实 workflow 的失败清理、手动 publish 审批、release notes、签名、公证和自动更新仍需后续小步确认。

## 相关 commit

- 本计划随本轮提交 `文档：新增发布凭据与制品策略` 归档；具体哈希以 Git 历史为准。
