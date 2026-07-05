# App 技术栈

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成并归档
- 计划来源：用户确认进入 App 技术栈决策，并确认移动端只保留 Online only 与离线缓存/草稿两阶段
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

确定 `apps/mobile` 第一阶段平台范围、技术栈、与 Desktop/后端/shared 的边界，以及移动端离线能力路线。

## 非目标

- 本轮不创建 Android 或 HarmonyOS NEXT 工程骨架。
- 本轮不选择移动端数据库、同步队列、冲突解决算法或加密存储实现。
- 本轮不实现移动端登录、推送、通知、文件、离线缓存或草稿。
- 本轮不规划移动端本机后端、Full 模式或完整离线业务引擎。

## repo 内范围

- `docs/adr/0009-mobile-native-online-first.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `apps/mobile/README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-app-technology-stack.md`

## 本地任务清单

- [x] 读取约束、架构、质量、Git、ADR 和计划规则。
- [x] 复核当前没有 App 技术栈 ADR，`apps/mobile` 仍是占位。
- [x] 新增 App 技术栈 ADR，记录 Android 原生与 HarmonyOS NEXT 原生路线。
- [x] 更新约束、架构、移动端 README 和总纲。
- [x] 运行文档质量门禁。
- [x] 归档本计划并提交推送。

## 验收标准

- App 技术栈不再处于未决策状态。
- Android 与 HarmonyOS NEXT 采用各自原生技术栈，不复用 Desktop Tauri shell。
- 移动端路线明确只有两阶段：首版 Online only，第二阶段离线缓存/离线草稿。
- 明确不规划移动端本机后端、Full 模式或完整离线业务引擎。
- 相关文档之间没有互相矛盾的旧状态。

## 验证方式

- `Get-Content -Encoding UTF8` 读取新增和更新的中文文档。
- `rg -n "App 当前阶段仍不绑定|App 技术栈|移动端本机后端|第三阶段" docs apps/mobile`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- HarmonyOS NEXT PC、平板、手机的具体工程结构、签名、发布和多设备适配验证仍需在创建工程骨架时确认。
- Android/HarmonyOS NEXT 的离线缓存、草稿、同步队列和冲突处理只是能力路线，具体存储与同步策略后续需要单独设计。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：新增 ADR 0009，确认 Android 原生 Kotlin + Jetpack Compose、HarmonyOS NEXT 原生 ArkTS + ArkUI，且 App 不复用 Desktop Tauri shell。
- 2026-06-08：确认移动端只保留首版 Online only 与第二阶段离线缓存/离线草稿，不规划移动端本机后端、Full 模式或完整离线业务引擎。
- 2026-06-08：已同步 `docs/CONSTRAINTS.md`、`docs/ARCHITECTURE.md`、`apps/mobile/README.md` 和后续事项总纲；当前状态改为“已完成并归档”。

## 验证结果

- 已执行 `Get-Content -Encoding UTF8` 读取新增 ADR、计划、架构、约束和 `apps/mobile/README.md`：通过。
- 已执行 `rg -n "App 当前阶段仍不绑定|技术栈.*尚未决定|第三阶段|完整离线版|移动端本机后端|本机 HTTP 后端" docs apps/mobile`：未发现 App 技术栈未决策的旧状态；命中项均为明确不规划移动端本机后端、Full 模式或完整离线业务引擎的新边界，或 Desktop/后端历史记录。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- Android 与 HarmonyOS NEXT 工程骨架尚未创建，工具链版本、目录结构和质量门禁入口需后续单独计划。
- 移动端离线缓存/草稿的数据范围、存储、同步队列、冲突处理和加密策略尚未设计。
- HarmonyOS NEXT PC、平板、手机多设备适配需要在工程骨架和 UI 原型阶段验证。

## 相关 commit

- 待记录。
