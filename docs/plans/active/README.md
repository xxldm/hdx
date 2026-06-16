# Active 计划索引

本索引用于降低开工时的文档读取成本。先读本文件判断任务归属，再按需打开具体 active plan；不要默认通读所有计划全文。

## 当前 active 计划

下表由各 active plan 顶部的 `active-plan-status` 状态块生成；不要手写编辑表格。

<!-- active-plan-index:start -->
| 计划 | 何时读取 | 当前状态 | 下一步 | 主要剩余风险 |
| --- | --- | --- | --- | --- |
| [2026-06-05-hdx-follow-up-roadmap.md](2026-06-05-hdx-follow-up-roadmap.md) | 需要判断总体后续顺序、步骤归属或跨计划状态时。 | 总纲进行中；认证与权限边界、部署发布仍有后续事项。 | 按用户确认继续第 9 步发布闭环，优先做真实 tag-only 发布链路验证、失败 draft 人工清理演练和真实安装包验证。 | 总纲不承载细节；具体实现和验证以对应 active plan、ADR 或 completed plan 为准。 |
| [2026-06-06-auth-permission-boundary.md](2026-06-06-auth-permission-boundary.md) | 认证、登录态、JWT、Redis 撤销、当前身份、错误码、用户/角色/权限相关任务。 | 账号密码登录、Web 登录页、当前身份、审计冷却、错误码和安全链 JSON 响应已实现。 | 按优先级补注册/找回密码、验证码/MFA、用户管理、OAuth2 client 管理或 JWK 运行期轮换。 | App 登录态未实现；生产开放账号密码登录前仍需补验证码、MFA、异常告警和更细限流。 |
| [2026-06-09-release-native-build-budget-and-reuse.md](2026-06-09-release-native-build-budget-and-reuse.md) | 后端 native artifact、GitHub Actions release start、历史 Release asset 复用、后端 resolver 相关任务。 | `v0.0.0-preview.3` 已触发但失败于 release-start 历史后端 asset 复用不可用后的 fallback 步骤；根因是内层 `pwsh` 非零退出码残留，已修复为 catch 后清理 `$LASTEXITCODE`。后端 Jackson 3 修复和门禁补强已在 `a7fc73b`。 | 推送 release-start fallback 修复后发布 `v0.0.0-preview.4`，等待后端 native build 与主仓库 assemble 完成，再在本机 Ubuntu WSL 做 release 后真实 Full Linux AppImage smoke。 | `v0.0.0-preview.1` 失败 draft 已保留用于排障，`v0.0.0-preview.2` 是测试 prerelease 且 Full Linux AppImage sidecar 已确认不可用，`v0.0.0-preview.3` tag start 已失败但未创建 Release；后端修复尚未经过新版真实 Linux native/AppImage 产物复测。Windows services 包、旧 workflow 复现和很旧 tag 的 workflow 入口仍需后续设计或验证。App 当前暂不进入发布闭环。 |
| [2026-06-10-web-desktop-release-artifact-contract.md](2026-06-10-web-desktop-release-artifact-contract.md) | Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务。 | Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发、Windows 端到端验证和公开端资产检查均已通过；`v0.0.0-preview.2` Full Linux AppImage 真实运行暴露后端 Jackson 2/3 缺陷，后端已修复并把静态检查和 all-in-one AOT/package smoke 固化到门禁。 | 发布包含后端修复与门禁补强的 `v0.0.0-preview.3`，在本机 Ubuntu WSL 做 release 后真实 AppImage smoke，复测 sidecar 启动、`/local/session` 和工作台数据加载；之后继续失败 draft 人工清理演练和安装包矩阵验证。 | `v0.0.0-preview.2` Full Linux AppImage 的 sidecar 已确认不可用；后端修复尚未进入真实 release native/AppImage 产物验证。完整 release 仍缺失败清理演练、stable 正式发布验证和真实安装包矩阵验证。App 当前暂不进入发布闭环。 |
<!-- active-plan-index:end -->

## 读取建议

- 只需要下一步方向时，先读本索引和 `docs/AGENT_BRIEF.md`。
- 做认证或权限代码改动时，读认证计划的“已确认决策”“剩余风险”和最近状态记录；改 migration、实体模型或 JDBC repository 时再读 `docs/AUTH_DATA_MODEL.md`。
- 做 release workflow 或 artifact 改动时，先判断是后端 native 复用问题还是 Web/Desktop 产物契约问题，再打开对应计划。
- 做 Desktop Online/Full 改动时，优先读 `apps/desktop/README.md` 和 Web/Desktop 发布产物计划；涉及认证边界再读认证计划。
- 完成任务后，先更新对应 active plan 顶部状态块，再运行 `scripts/sync-active-plan-status.ps1` 同步本索引；重复过程日志应收敛。

## 归档提醒

- 如果某个 active plan 的剩余风险已经全部关闭，应移动到 `docs/plans/completed/`，并把总纲和本索引同步更新。
- 如果计划持续变大，优先把历史验证记录压缩为摘要，或拆到 completed/history；active 文件只保留当前可执行信息。
