# 公开许可与后端私有边界

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成并归档
- 计划来源：用户确认不采用 GPL-3.0，公开部分采用 Apache-2.0，后端维持私有且不让后端源码/JAR 流入主仓库
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

确定 HDX 公开仓库许可、公私仓库边界和后端发布产物保密边界：公开主仓库采用 Apache-2.0；后端仓库维持私有；公开主仓库禁止提交后端源码、JAR/WAR 和后端构建中间产物。

## 非目标

- 本轮不迁移或公开/私有化任何 GitHub 仓库。
- 本轮不修改 `services/backend` 子模块源码或仓库可见性。
- 本轮不实现 GitHub Actions release 流水线。
- 本轮不重命名后端 `backend-all-in-one` 模块。
- 本轮不设计完整商标政策或商业授权文本。

## repo 内范围

- `LICENSE`
- `NOTICE`
- `.gitignore`
- `docs/adr/0011-public-license-and-backend-private-boundary.md`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CONSTRAINTS.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-public-license-backend-private-boundary.md`

## 本地任务清单

- [x] 读取约束、架构、质量、Git、ADR 和计划规则。
- [x] 复核当前根仓库没有 LICENSE/NOTICE，现有 ADR 编号到 0010。
- [x] 新增 Apache-2.0 LICENSE、NOTICE 和许可边界 ADR。
- [x] 更新 README、架构、约束、总纲和误提交防护规则。
- [x] 运行文档验证。
- [x] 归档本计划并提交推送。

## 验收标准

- 根仓库有 Apache-2.0 `LICENSE`。
- 根仓库 `NOTICE` 明确 HDX 品牌/图标/官方发布标识不随 Apache-2.0 授权给混淆使用。
- ADR 明确后端私有、后端源码/JAR/WAR 不进入公开主仓库、后端 release 目标为 native executable archive。
- 当前用户可见命名优先记录为 Full；代码级 `backend-all-in-one` 暂不在本轮重命名。
- `.gitignore` 有 JAR/WAR/class 防误提交规则。

## 验证方式

- `rg -n "Apache-2.0|Apache License|后端.*私有|JAR|WAR|Full|backend-all-in-one|native executable" LICENSE NOTICE README.md docs .gitignore`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- Apache-2.0 不禁止商用或转售；本轮通过后端私有、native-only、品牌保留和官方来源提示降低盗卖便利性，而不是建立复杂法律授权体系。
- `apps/web`、`apps/desktop`、`apps/mobile` 是独立子仓库，后续公开前也需要各自补齐许可证和 NOTICE。
- 后端私有仓库、后端 native release 和 Desktop Full 是否公开分发仍需第 9 步发布设计继续确认。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：新增根仓库 Apache-2.0 `LICENSE` 和 `NOTICE`，记录 HDX 品牌/图标/官方发布标识不随 Apache-2.0 授权给混淆使用。
- 2026-06-08：新增 ADR 0011，确认公开主仓库 Apache-2.0、后端私有、公开主仓库禁止后端源码/JAR/WAR/`.class` 和构建中间产物、后端 release 目标 native executable archive。
- 2026-06-08：确认用户可见本地完整模式后续称 Full；当前 `backend-all-in-one` 模块名不在本轮重命名，代码级迁移后续单独计划。
- 2026-06-08：已同步 README、架构、约束、总纲和 `.gitignore`；当前状态改为“已完成并归档”。

## 验证结果

- 已执行 `rg -n "Apache-2.0|Apache License|后端.*私有|JAR|WAR|Full|backend-all-in-one|native executable|\\.class|\\.jar|\\.war" LICENSE NOTICE README.md docs .gitignore`：命中项覆盖 `LICENSE`、`NOTICE`、ADR 0011、README、约束、架构、总纲、本计划和 `.gitignore`；历史 `backend-all-in-one` 命中保留为既有模块名或历史上下文。
- 已执行 `git diff --check`：通过；仅保留 Git for Windows CRLF 提示。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- Apache-2.0 不禁止商用或转售；本轮选择简单许可，并用后端私有、native-only、品牌保留和官方来源提示降低盗卖便利性。
- `apps/web`、`apps/desktop`、`apps/mobile` 是独立子仓库，后续公开前仍需分别补齐许可证和 NOTICE。
- 后端 private release、后端 native 包是否进入公开 GitHub Releases、Desktop Full 是否公开分发后端 native 包，仍需第 9 步发布设计继续确认。
- 现有代码模块名 `backend-all-in-one` 暂未重命名；后续如要改为 Full，需要单独计划并覆盖后端、Desktop sidecar、文档和质量门禁。

## 相关 commit

- 本计划提交由 Git 历史体现，不在同一提交中回写自身 hash，避免递归提交。
