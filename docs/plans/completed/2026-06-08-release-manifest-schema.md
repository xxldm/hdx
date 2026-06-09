# Release Manifest Schema 设计

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成；2026-06-09 已由后续小步补齐 release manifest JSON Schema 子集校验和样例检查
- 计划来源：用户确认在 GitHub Releases 产物边界后，先定义 manifest schema
- 创建时间：2026-06-08
- 最后更新：2026-06-09

## 目标

为 HDX release 流程定义可机读的 JSON Schema 和说明文档，让后续后端私有仓库 CI、主仓库 release workflow、Desktop Full 打包和后端微服务聚合包使用同一组发布契约。

本轮完成后应明确：

- 后端私有仓库交给主仓库的 `backend-native-manifest.json` 数据形状。
- 主仓库 Release 总清单 `release-manifest.json` 数据形状。
- Desktop Full 内置的 `backend-build.json` 数据形状。
- 后端微服务聚合包内部的 `backend-services-manifest.json` 数据形状。
- 每个 manifest 如何绑定 version、root commit/ref、OpenAPI hash、backend commit、asset sha256 和禁止使用 `latest` 的发布事实源。

## 非目标

- 本轮不实现 GitHub Actions workflow。
- 本轮不实现 JSON Schema 校验脚本。
- 本轮不修改后端私有仓库、Web、Desktop 或 App 代码。
- 本轮不引入 npm、Maven、Python 或其他新的 schema 校验依赖。
- 本轮不决定安装器签名、公证、自动更新、release notes 或版本号策略细节。

## repo 内范围

- `packages/shared/contracts/release/README.md`
- `packages/shared/contracts/release/backend-native-manifest.schema.json`
- `packages/shared/contracts/release/release-manifest.schema.json`
- `packages/shared/contracts/release/backend-build.schema.json`
- `packages/shared/contracts/release/backend-services-manifest.schema.json`
- `packages/shared/contracts/README.md`
- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/ARCHITECTURE.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-release-manifest-schema.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 release manifest JSON Schema 文件。
- [x] 新增 release contract README，说明字段语义和使用边界。
- [x] 更新 shared contracts 索引、ADR 0012、架构和总纲。
- [x] 运行 JSON 解析和文档质量门禁。
- [x] 归档计划并准备根仓库提交推送范围。

## 验收标准

- `packages/shared/contracts/release/` 下存在 4 个 schema 文件，且都是合法 JSON。
- README 说明 4 个 manifest 的生产者、消费者、存放位置和校验边界。
- ADR 0012 不再把 schema 定义描述为待办，而是引用 release contract 目录。
- 总纲记录第 9 步 release manifest schema 已完成，剩余风险转为 workflow 实现、真实校验脚本和安装器策略。
- 不修改任何子模块内部文件。

## 验证方式

- `Get-Content -Encoding UTF8` 读取新增 README、ADR、架构和计划。
- PowerShell `ConvertFrom-Json` 解析 4 个 schema 文件。
- `rg -n "backend-native-manifest|release-manifest|backend-build|backend-services-manifest|JSON Schema|latest" packages/shared/contracts/release docs README.md`
- `git diff --check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 风险与阻塞

- schema 对样例 manifest 的约束效果已由 2026-06-09 后续小步补齐验证，覆盖最小有效样例、schema 无效样例、sha256 不匹配样例和禁止文件扫描样例。
- 后续 workflow 仍需接入真实 GitHub Actions artifact 下载、发布上下文一致性、Release 上传和跨包 sha256 对齐。
- schema 已允许 `v<major>.<minor>.<patch>` 携带 prerelease 和 build metadata；正式版本号策略、tag 规则和 release notes 仍需后续单独确认。

## 状态记录

- 2026-06-08：创建计划并开始实施。
- 2026-06-08：新增 `packages/shared/contracts/release/`，定义 `backend-native-manifest.json`、`release-manifest.json`、`backend-build.json` 和 `backend-services-manifest.json` 的 JSON Schema。
- 2026-06-08：更新 release 契约说明、shared 索引、shared 根说明、ADR 0012、架构、质量门禁和后续事项总纲。
- 2026-06-08：完成 JSON 解析和 docs 质量门禁验证，计划归档到 `docs/plans/completed/`。
- 2026-06-09：后续小步已补齐 release manifest JSON Schema 子集校验、可选 `-AssetRoot` sha256/size 校验和最小正反例样例；原“未提供样例”和“未验证 schema 对样例约束效果”风险已解决。

## 验证结果

- 已执行 PowerShell `ConvertFrom-Json` 解析 4 个 schema 文件，均为合法 JSON。
- 已执行 `rg -n "backend-native-manifest|release-manifest|backend-build|backend-services-manifest|JSON Schema|latest" packages/shared/contracts/release docs README.md packages/shared/README.md packages/shared/contracts/README.md`：可检索到 4 个 manifest、JSON Schema、禁止 `latest` 和相关文档入口。
- 已执行 `git diff --check`：通过；仅提示 Windows 行尾规则转换，不是空白错误。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，包含文档 UTF-8、子模块状态、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- 本轮定义的 schema 已有本地脚本校验和样例检查；后续 workflow 仍需把该校验接入真实 GitHub Actions artifact、Release asset 和 Desktop Full 打包产物。
- 当前本地脚本覆盖 release schema 使用到的 JSON Schema 子集，不是通用 JSON Schema 引擎；schema 后续如引入新关键字，需要同步扩展脚本或重新评估外部校验器。
- 正式版本号策略、tag 规则、release notes、安装器签名、公证和自动更新仍需后续单独确认。

## 相关 commit

- 根仓库提交会随本轮收口完成；最终提交号以仓库 Git 日志和本轮最终回复为准。
