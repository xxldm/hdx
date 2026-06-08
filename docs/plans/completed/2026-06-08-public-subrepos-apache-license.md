# 公开子仓库 Apache-2.0 许可同步

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户确认除后端外，其余公开仓库统一 Apache-2.0
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

为后续公开的非后端子仓库同步 Apache-2.0 许可文件与 NOTICE，让根仓库、Web 子仓库和 Desktop 子仓库的公开许可边界一致。

## 非目标

- 本轮不修改后端私有仓库。
- 本轮不改变任一 GitHub 仓库的可见性。
- 本轮不实现 release CI。
- 本轮不为 `apps/mobile` 创建独立仓库；当前 `apps/mobile` 仍是根仓库占位目录，跟随根仓库 Apache-2.0。
- 本轮不设计完整商标政策或商业授权文本。

## repo 内范围

- `apps/web/LICENSE`
- `apps/web/NOTICE`
- `apps/web/package.json`
- `apps/desktop/LICENSE`
- `apps/desktop/NOTICE`
- `apps/desktop/package.json`
- `docs/adr/0011-public-license-and-backend-private-boundary.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-public-subrepos-apache-license.md`

## 本地任务清单

- [x] 检查根仓库和公开子仓库当前 Git 状态。
- [x] 确认 `apps/web` 与 `apps/desktop` 尚无 LICENSE/NOTICE。
- [x] 为 `apps/web` 与 `apps/desktop` 增加 Apache-2.0 LICENSE、NOTICE 和 package `license` 字段。
- [x] 更新根仓库 ADR 和总纲记录。
- [x] 运行相关验证。
- [x] 按子模块优先顺序提交推送，再提交推送根仓库。

## 验收标准

- `apps/web` 和 `apps/desktop` 均有 Apache-2.0 `LICENSE`。
- `apps/web` 和 `apps/desktop` 均有 NOTICE，说明 HDX 品牌/图标/官方发布标识不随 Apache-2.0 授权给混淆使用，后端源码和二进制不在子仓库许可范围内。
- `apps/web/package.json` 与 `apps/desktop/package.json` 均声明 `"license": "Apache-2.0"`。
- 根仓库 ADR 0011 记录公开子仓库许可已同步。
- 后端私有仓库不被修改。

## 验证方式

- `rg -n "Apache-2.0|Apache License|backend|后端|license" apps/web apps/desktop docs/adr/0011-public-license-and-backend-private-boundary.md`
- `git -C apps/web diff --check`
- `git -C apps/desktop diff --check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 风险与阻塞

- `apps/web` 和 `apps/desktop` 是独立子仓库，需要先分别提交推送，再更新根仓库子模块指针。
- Apache-2.0 不禁止商用或转售；防盗卖仍主要依赖后端私有、native-only、品牌保留和官方来源提示。
- `apps/mobile` 当前不是独立子仓库；后续如果拆成独立仓库，需要单独补 LICENSE/NOTICE。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：确认 `apps/web` 与 `apps/desktop` 是本轮需要补齐的独立公开子仓库；`apps/mobile` 当前仍是根仓库占位目录，不单独建仓。
- 2026-06-08：为 `apps/web` 与 `apps/desktop` 补齐 Apache-2.0 `LICENSE`、`NOTICE` 和 package `license` 字段。
- 2026-06-08：更新 ADR 0011 与后续事项总纲，记录公开子仓库许可已同步、后端仍不纳入公开许可。

## 验证结果

- 已执行 `rg -n "Apache-2.0|Apache License|backend|后端|license|HDX Web|HDX Desktop" apps/web apps/desktop docs/adr/0011-public-license-and-backend-private-boundary.md`：可检索到 Web/Desktop license 元数据、NOTICE 和 ADR 公开子仓库边界。
- 已执行 `git -C apps/web diff --check`：通过；仅提示 `package.json` 后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- 已执行 `git -C apps/desktop diff --check`：通过；仅提示 `package.json` 后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- 已执行 `git diff --check`：通过。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 剩余风险

- Apache-2.0 不禁止商用或转售；当前防盗卖主要依赖后端私有、native-only 发布边界、品牌保留和官方来源提示。
- `apps/mobile` 当前不是独立子仓库；后续如果拆成 Android/HarmonyOS 或其他独立公开仓库，需要补自身 Apache-2.0 `LICENSE`、`NOTICE` 和工程元数据许可声明。
- 后端 native archive 是否进入公开 GitHub Releases 仍需在后续发布/CI 设计中单独确认。

## 相关 commit

- `ea08f7d 文档：补充 Apache 许可边界`（`apps/web`）
- `5463475 文档：补充 Apache 许可边界`（`apps/desktop`）
