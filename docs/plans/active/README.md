# Active 计划索引

本索引用于降低开工时的文档读取成本。先读本文件判断任务归属，再按需打开具体 active plan；不要默认通读所有计划全文。

## 当前 active 计划

下表由各 active plan 顶部的 `active-plan-status` 状态块生成；不要手写编辑表格。

<!-- active-plan-index:start -->
| 计划 | 何时读取 | 当前状态 | 下一步 | 主要剩余风险 |
| --- | --- | --- | --- | --- |
| [2026-06-05-hdx-follow-up-roadmap.md](2026-06-05-hdx-follow-up-roadmap.md) | 需要判断总体后续顺序、步骤归属或跨计划状态时。 | 总纲进行中；认证与权限边界、部署发布仍有后续事项。第 9 步已完成真实 tag-only 预览发布和 Full Linux AppImage sidecar/API smoke。 | 按用户确认继续第 9 步发布闭环，优先做失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证。 | 总纲不承载细节；具体实现和验证以对应 active plan、ADR 或 completed plan 为准。 |
| [2026-06-06-auth-permission-boundary.md](2026-06-06-auth-permission-boundary.md) | 认证、登录态、JWT、Redis 撤销、当前身份、错误码、用户/角色/权限相关任务。 | 账号密码登录、Web 登录页、当前身份、审计冷却、错误码和安全链 JSON 响应已实现。 | 按优先级补注册/找回密码、验证码/MFA、用户管理、OAuth2 client 管理或 JWK 运行期轮换。 | App 登录态未实现；生产开放账号密码登录前仍需补验证码、MFA、异常告警和更细限流。 |
| [2026-06-09-release-native-build-budget-and-reuse.md](2026-06-09-release-native-build-budget-and-reuse.md) | 后端 native artifact、GitHub Actions release start、历史 Release asset 复用、后端 resolver 相关任务。 | `v0.0.0-preview.5` 已完成真实 tag-only 预览发布链路验证：Release Start、后端 resolver、主仓库 assemble/publish 均成功；Windows full native 在 `native-windows-ci` profile 下 30m52s 完成；Full Linux AppImage 已在本机 Ubuntu WSL 完成真实启动与 API smoke。`v0.0.0-preview.6` 已推送并触发发布链路，但由于后端 `core-service` native 编译长时间停滞，`backend-release-resolve.yml` 被取消；后端临时 artifacts 已删除，主仓库 `actions/artifacts` 仍为 `0`。公开端检查 run `27600342351` 仍验证不再上传检查 artifact。Actions cache 已按构建重新生成少量条目，低于默认 10 GB 上限，不是当前 storage 压力点。 | 先评估后端 native 复用/编译策略是否需要单独拆分 `core-service` 的约束，再决定是否重跑下一次 preview release；继续做失败 draft 人工清理演练、release artifact 上下文一致性收口、stable 正式 tag 验证和真实安装包矩阵验证；同时跟踪 GitHub Actions Node.js 20 弃用 warning。 | `v0.0.0-preview.1` 失败 draft 已保留用于排障，`v0.0.0-preview.2` 是测试 prerelease 且 Full Linux AppImage sidecar 已确认不可用，`v0.0.0-preview.3` tag start 已失败但未创建 Release，`v0.0.0-preview.4` 后端 resolver 未 finalize、未创建主仓库 Release。`v0.0.0-preview.5` 已证明后端修复进入真实 release native/AppImage 产物；`v0.0.0-preview.6` 说明后端 workflow-only 变更仍会触发保守 fingerprint 失配并拉起 native fallback，而 `core-service` native 在当前 runner 资源下会长时间停滞，需要单独处理。Actions artifact 删除失败不会阻塞已成功的 Release，但可能需要人工兜底清理；Windows services 包、旧 workflow 复现、很旧 tag 的 workflow 入口、stable 正式发布和安装包矩阵仍需后续设计或验证。App 当前暂不进入发布闭环。 |
| [2026-06-10-web-desktop-release-artifact-contract.md](2026-06-10-web-desktop-release-artifact-contract.md) | Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务。 | Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发、Windows 端到端验证、公开端资产检查和 `v0.0.0-preview.5` Full Linux AppImage 真实 sidecar/API smoke 均已通过；后端 Jackson 2/3 缺陷已确认随真实 release native/AppImage 修复。公开端检查 workflow run `27600342351` 已验证只在 job 内校验生成资产，不再上传临时 Actions artifact，主仓库 `actions/artifacts` 仍为 `0`。 | 继续失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式 tag 验证和真实安装包矩阵验证；同时跟踪 GitHub Actions Node.js 20 弃用 warning。 | `v0.0.0-preview.2` Full Linux AppImage 的 sidecar 已确认不可用，`v0.0.0-preview.3` tag start 已失败但未创建 Release，`v0.0.0-preview.4` 未 assemble 出主仓库 Release；`v0.0.0-preview.5` 已证明新版 Full Linux AppImage 可启动本机后端并读取工作台数据。完整 release 仍缺失败清理演练、stable 正式发布验证和真实安装包矩阵验证。App 当前暂不进入发布闭环。 |
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
