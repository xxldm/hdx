# Active 计划索引

本索引用于降低开工时的文档读取成本。先读本文件判断任务归属，再按需打开具体 active plan；不要默认通读所有计划全文。

## 当前 active 计划

下表由各 active plan 顶部的 `active-plan-status` 状态块生成；不要手写编辑表格。

<!-- active-plan-index:start -->
| 计划 | 何时读取 | 当前状态 | 下一步 | 主要剩余风险 |
| --- | --- | --- | --- | --- |
| [2026-06-05-hdx-follow-up-roadmap.md](2026-06-05-hdx-follow-up-roadmap.md) | 需要判断总体后续顺序、步骤归属或跨计划状态时。 | 总纲进行中；认证与权限边界、部署发布仍有后续事项。第 9 步已完成真实 tag-only 预览发布和 Full Linux AppImage sidecar/API smoke。 | 第 9 步发布闭环仍不自动恢复；后端内部 GraalVM/native、运行形态和 standalone 服务端单体实现记录已迁入后端私有文档。公开主仓库只保留 release 资产边界、复用策略和私有文档入口；standalone release artifact 接入和 native runtime smoke 后续单独切片，不推 preview/stable tag。 | 总纲不承载细节；具体实现和验证以对应 active plan、ADR 或 completed plan 为准。 |
| [2026-06-09-release-native-build-budget-and-reuse.md](2026-06-09-release-native-build-budget-and-reuse.md) | 后端 native release asset、GitHub Actions release start、历史 Release asset 复用、公开 release manifest 和发布验证相关任务。 | `v0.0.0-preview.5` 已验证 tag-only 预览发布和 Desktop Full Linux AppImage smoke；`v0.0.0-preview.6` 因后端 native 构建停滞取消。GraalVM 25.1.3 相关后端内部调整已收口到后端私有文档；公开仓库只记录 release 资产边界和复用策略。后端 Release 包已确认只发布 native，不发布 JVM/JAR/WAR/`.class`/源码包。 | 不自动恢复发布；standalone 服务端单体 release artifact 接入需要另行确认后再做。preview/stable tag、远端 release native 复验、stable 正式发布和真实安装包矩阵验证需要另行确认后再做。 | 新增 release 超时/诊断仍未在远端卡住场景复验；后端 native 构建资源占用仍可能波动。standalone 服务端单体 release artifact 接入和 native runtime smoke 仍待后续切片；stable 发布、完整安装包矩阵、Windows services、旧 workflow、很旧 tag 入口和 App 发布闭环仍待后续处理。 |
| [2026-06-10-web-desktop-release-artifact-contract.md](2026-06-10-web-desktop-release-artifact-contract.md) | Web node-server 发布包、Desktop Online/Full 资产、Tauri 打包、Desktop Rust BFF 相关任务。 | Web node-server、Desktop 静态 UI、Full sidecar、Online 远端认证转发、Windows 端到端验证、公开端资产检查和 `v0.0.0-preview.5` Full Linux AppImage smoke 均已通过。公开端检查 run `27600342351` 已验证不再上传临时 Actions artifact。 | 会触发后端 native 的 stable 正式 tag 验证和真实安装包矩阵验证仍需单独确认后恢复；GraalVM 25.1.3 本机复测已解除旧 build report NPE，但本计划不直接推 preview/stable tag。 | `v0.0.0-preview.5` 已证明新版 Full Linux AppImage 可启动本机后端并读取工作台数据；GraalVM 25.1.3 已解除本机 build report NPE，但远端 release native、stable 验证和真实安装包矩阵仍未复验。App 当前暂不进入发布闭环。 |
| [2026-06-16-web-toolbox-layout-grid.md](2026-06-16-web-toolbox-layout-grid.md) | 修改 Web 首页工具箱布局、模块组件接入、布局持久化或首页视觉风格时读取。 | 已按 ADR 0016 收口工作台布局、计时器预设、账号级用户偏好和日期倒计时节日数据。`docs/WORKBENCH_WIDGET_CONTRACT.md` 已明确 widget registry、layout、模块数据、模块配置和设备运行态边界；Web registry 已显式声明 timer 的账号级预设接口、设备级运行态，以及 date-countdown 的共享节日数据接口。节日管理员维护页已接入后端、Web、Desktop BFF 和 OpenAPI 契约；日期倒计时定位为人工维护的事件/节日数据，不自动维护调休或复杂日历规则。 | 继续接入新真实模块前，先按 `docs/WORKBENCH_WIDGET_CONTRACT.md` 判断模块数据归属，再决定是否新增独立后端契约；后续 todo、随手记等模块优先按独立模块 API、store/composable 和可选 `configRef` 接入，不把业务数据塞进 layout。若继续完善日期倒计时，优先处理人工维护体验、节日权限和 `holiday_key` 软删除复用策略。 | 日期倒计时当前依赖人工维护事件/节日数据，自动调休、农历推算和工作日历同步暂不进入当前范围。`holiday_key` 当前全局唯一，软删除后暂不复用。用户偏好目前按整体对象版本保存，低价值偏好冲突会在 Web 端基于服务器当前版本重试，高价值模块配置必须进入模块自己的记录级冲突模型。 |
| [2026-06-26-todo-rule-generated-tasks-and-notification-center.md](2026-06-26-todo-rule-generated-tasks-and-notification-center.md) | 查看 todo、日程事项、规则生成、候选池、通知中心、公开主页、公开流、协作事项的计划状态和文档路由时读取。 | 本文件保留 repo 级计划状态和公开摘要；后端权限矩阵、数据模型、接口草案、通知调度、治理和实现切片维护在 `services/backend/docs/plans/README.md`。 | 实现前先读本文；涉及后端内部实现时，再按任务读取 `services/backend/docs/plans/README.md` 中的权限、数据模型、接口、通知和实现切片草案。 | 公开摘要和后端实现草案需要保持事实源分工；后续不要把后端表结构、接口草案、通知调度、公开治理和审计细节回写到公开主仓库。 |
<!-- active-plan-index:end -->

## 读取建议

- 只需要下一步方向时，先读本索引、`docs/plans/follow-up/README.md` 和 `docs/AGENT_BRIEF.md`。
- 做认证或权限代码改动时，先读认证计划的“已确认决策”“剩余风险”和最近状态记录；改 migration、实体模型或 JDBC repository 时再读 `services/backend/README.md` 与 `services/backend/docs/README.md`。
- 做 release workflow 或 artifact 改动时，先判断是后端 native 复用问题还是 Web/Desktop 产物契约问题，再打开对应计划。
- 做 Desktop Online/Full 改动时，优先读 `apps/desktop/README.md` 和 Web/Desktop 发布产物计划；涉及认证边界再读认证计划。
- 完成任务后，先更新对应 active plan 顶部状态块，再运行 `scripts/sync-active-plan-status.ps1` 同步本索引；重复过程日志应收敛。

## 归档提醒

- 如果某个 active plan 的剩余风险已经全部关闭，应移动到 `docs/plans/completed/`，并把总纲和本索引同步更新。
- 如果某个 active plan 的主体工作已结束但仍有当前残留事项，应移动到 `docs/plans/follow-up/`，不能直接归入 completed。
- 如果计划持续变大，优先把历史验证记录压缩为摘要，或拆到 completed/history；active 文件只保留当前可执行信息。
