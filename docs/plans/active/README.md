# Active 计划索引

本索引用于降低开工时的文档读取成本。先读本文件判断任务归属，再按需打开具体 active plan；不要默认通读所有计划全文。

## 当前 active 计划

下表由各 active plan 顶部的 `active-plan-status` 状态块生成；不要手写编辑表格。

<!-- active-plan-index:start -->
| 计划 | 何时读取 | 当前状态 | 下一步 | 主要剩余风险 |
| --- | --- | --- | --- | --- |
| [2026-06-05-hdx-follow-up-roadmap.md](2026-06-05-hdx-follow-up-roadmap.md) | 需要判断总体后续顺序、步骤归属或跨计划状态时。 | 总纲进行中；认证与权限边界、部署发布仍有后续事项。第 9 步已完成真实 tag-only 预览发布和 Full Linux AppImage sidecar/API smoke。 | 第 9 步发布闭环中会触发后端 native 的验证先暂停；待 2026-06-25 GraalVM 25.1 发布并复测后再恢复。期间只做不触发编译的只读检查、文档和清理准备。 | 总纲不承载细节；具体实现和验证以对应 active plan、ADR 或 completed plan 为准。 |
| [2026-06-06-auth-permission-boundary.md](2026-06-06-auth-permission-boundary.md) | 认证、登录态、JWT、Redis 撤销、当前身份、错误码、用户/角色/权限相关任务。 | 账号密码登录、Web 登录页、当前身份、审计冷却、错误码和安全链 JSON 响应已实现。 | 按优先级补注册/找回密码、验证码/MFA、用户管理、OAuth2 client 管理或 JWK 运行期轮换。 | App 登录态未实现；生产开放账号密码登录前仍需补验证码、MFA、异常告警和更细限流。 |
| [2026-06-09-release-native-build-budget-and-reuse.md](2026-06-09-release-native-build-budget-and-reuse.md) | 后端 native artifact、GitHub Actions release start、历史 Release asset 复用、后端 resolver 相关任务。 | `v0.0.0-preview.5` 已验证 tag-only 预览发布和 Full Linux AppImage smoke；`v0.0.0-preview.6` 因 `core-service` native 停滞取消。已补超时/诊断，并在本机验证 baseline、`-Ob` 与线程限制；`-Ob` 和线程限制均不作为 release 默认方案。 | 暂停会触发后端 native 的 release 验证；待 2026-06-25 GraalVM 25.1 发布后，先复测 `backend-core-service` build report NPE。期间只做只读检查、文档和清理准备，不推新 preview/stable tag。 | 新增超时/诊断仍未在远端卡住场景验证；`-Ob` 不可作为 release 默认优化；后端 native 卡住风险解除前，stable 发布和完整安装包矩阵验证暂停。Windows services、旧 workflow、很旧 tag 入口和 App 发布闭环仍待后续处理。 |
| [2026-06-10-web-desktop-release-artifact-contract.md](2026-06-10-web-desktop-release-artifact-contract.md) | Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务。 | Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发、Windows 端到端验证、公开端资产检查和 `v0.0.0-preview.5` Full Linux AppImage smoke 均已通过。公开端检查 run `27600342351` 已验证不再上传临时 Actions artifact。 | 会触发后端 native 的 stable 正式 tag 验证和真实安装包矩阵验证先暂停；待 2026-06-25 GraalVM 25.1 复测后再恢复。期间只做不触发编译的只读检查、文档和清理准备。 | `v0.0.0-preview.5` 已证明新版 Full Linux AppImage 可启动本机后端并读取工作台数据；但后端 native 卡住风险解除前，完整 release 仍暂停 stable 验证和真实安装包矩阵。App 当前暂不进入发布闭环。 |
| [2026-06-16-web-toolbox-layout-grid.md](2026-06-16-web-toolbox-layout-grid.md) | 修改 Web 首页工具箱布局、模块组件接入、布局持久化或首页视觉风格时读取。 | Web 首页工具箱主体、桌面宽度触摸兜底、全局主题入口和 UI/UX 审计主要收口项已实现。工具箱 widget 注册契约已收口为中心静态 registry；Nuxt UI P2、`info` 语义色和 icon 命名统一已完成。 | 处理 Nuxt UI P3 剩余项：账号菜单语义复查。真实模块接入时继续按中心 registry 契约执行。 | 真实模块组件尚未接入；`auth.global.ts` 当前临时注释未登录跳转，不能带入正式认证闭环。Nuxt UI P3 完成前，账号菜单语义仍有一致性债。 |
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
