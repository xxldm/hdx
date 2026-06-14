# Active 计划索引

本索引用于降低开工时的文档读取成本。先读本文件判断任务归属，再按需打开具体 active plan；不要默认通读所有计划全文。

## 当前 active 计划

| 计划 | 何时读取 | 当前状态 | 主要剩余风险 |
| --- | --- | --- | --- |
| `2026-06-05-hdx-follow-up-roadmap.md` | 需要判断总体后续顺序、步骤归属或跨计划状态时 | 总纲进行中；认证与权限边界、部署发布仍有后续事项 | 不承载细节；具体实现和验证看对应计划或 ADR |
| `2026-06-06-auth-permission-boundary.md` | 认证、登录态、JWT、Redis 撤销、当前身份、错误码、用户/角色/权限相关任务 | 账号密码登录、Web 登录页、当前身份、审计冷却、错误码和安全链 JSON 响应已实现 | 注册、找回密码、验证码、MFA、用户管理、OAuth2 client 管理、JWK 运行期轮换仍未实现 |
| `2026-06-09-release-native-build-budget-and-reuse.md` | 后端 native artifact、GitHub Actions release start、历史 Release asset 复用、后端 resolver 相关任务 | 后端 native 并行构建、历史复用、release start、release assemble 第一片已落地 | App 构建、正式 publish、失败清理、Linux/安装包真实验证等完整 release 闭环仍需补齐 |
| `2026-06-10-web-desktop-release-artifact-contract.md` | Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务 | Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发和 Windows 端到端验证已完成 | Linux AppImage 端到端验证、真实 release.yml 资产上传回读、App Online asset 仍待后续 |

## 读取建议

- 只需要下一步方向时，先读本索引和 `docs/AGENT_BRIEF.md`。
- 做认证或权限代码改动时，读认证计划的“已确认决策”“剩余风险”和最近状态记录；改 migration、实体模型或 JDBC repository 时再读 `docs/AUTH_DATA_MODEL.md`。
- 做 release workflow 或 artifact 改动时，先判断是后端 native 复用问题还是 Web/Desktop 产物契约问题，再打开对应计划。
- 做 Desktop Online/Full 改动时，优先读 `apps/desktop/README.md` 和 Web/Desktop 发布产物计划；涉及认证边界再读认证计划。
- 完成任务后，只把恢复上下文必需的事实、验证摘要和剩余风险写回对应计划；重复过程日志应收敛。

## 归档提醒

- 如果某个 active plan 的剩余风险已经全部关闭，应移动到 `docs/plans/completed/`，并把总纲和本索引同步更新。
- 如果计划持续变大，优先把历史验证记录压缩为摘要，或拆到 completed/history；active 文件只保留当前可执行信息。
