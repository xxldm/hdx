# GitHub Releases 产物边界

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成；后续 release manifest schema 与本地校验脚本已补齐
- 计划来源：用户确认第 9 步发布产物、后端 native artifact 交接和 Release 资产粒度
- 创建时间：2026-06-08
- 最后更新：2026-06-09

## 目标

明确 HDX GitHub Releases 的完整打包流程、后端 native 交接方式、主仓库与私有后端仓库的 CI 边界，以及 Web、Desktop、App 和后端微服务产物的发布粒度。

完成后，后续智能体应能从 ADR 和本计划恢复以下事实：

- 主仓库 GitHub Releases 是唯一公开发布入口，但不负责自动部署。
- 主仓库 CI 不 checkout 后端私有源码。
- 后端私有仓库先编译 native，并只通过 GitHub Actions artifact 临时交接给主仓库。
- 主仓库 Releases 包含后端 native 产物，但只包含 native archive，不包含源码、JAR/WAR、`.class` 或构建中间产物。
- App 不内置后端，只发布 Online 客户端。
- 后端微服务支持独立部署，但 Release asset 按平台聚合为压缩包，微服务粒度保留在包内部。

## 非目标

- 本轮不实现 GitHub Actions workflow。
- 本轮不修改后端私有仓库。
- 本轮不实现 native 编译、安装器打包、签名、公证、自动更新或发布脚本。
- 本轮不引入 S3、RustFS、云 OSS、私有 artifact 仓库或后端 private release 作为 native 产物交接存储。
- 本轮不改变 App 技术栈或重新引入移动端本机后端/Full 模式。

## repo 内范围

- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/ARCHITECTURE.md`
- `docs/CONSTRAINTS.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-github-releases-artifact-boundary.md`

## 本地任务清单

- [x] 记录用户确认的发布产物和交接边界。
- [x] 新增 ADR 0012，固定 GitHub Releases 产物边界。
- [x] 更新架构、约束、README 和后续事项总纲。
- [x] 运行文档验证。
- [x] 将计划归档到 `docs/plans/completed/`。
- [x] 准备根仓库文档变更提交推送范围。

## 验收标准

- ADR 0012 明确主仓库不 checkout 后端私有源码，后端 native 只通过 GitHub Actions artifact 临时交接。
- ADR 0012 明确主仓库 Releases 包含后端 native archive。
- ADR 0012 明确 App 不内置后端，只发布 Online 客户端。
- ADR 0012 明确后端微服务通过平台聚合压缩包发布，包内部保留微服务部署粒度。
- 总纲和架构文档不再把本轮已确认的发布产物边界描述成待决策项。

## 验证方式

- `rg -n "GitHub Releases|Actions artifact|backend-services|backend-full|latest|App 不内置后端|后端源码" docs README.md`
- `git diff --check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 风险与阻塞

- 本轮只固定设计边界，不验证真实 GitHub Actions artifact 下载、repository dispatch、Release 上传或跨仓库 token 权限。
- 主仓库 Releases 公开后端 native 二进制后，用户可以下载和再分发 native 包；源码仍通过私有仓库边界保护。
- 后端微服务包内部服务清单会随后端模块演进变化，后续 workflow 实现时需要生成 manifest，避免文档和真实包内容漂移。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：新增 ADR 0012，确认 GitHub Releases 产物边界、后端 Actions artifact 临时交接、主仓库公开后端 native archive、App Online only 和后端微服务平台聚合压缩包策略。
- 2026-06-08：更新 ADR 0011、架构、约束、README、总纲和相关已归档计划，移除“后端 native 是否进入公开 Release 待确认”的旧状态。
- 2026-06-08：完成文档验证，计划归档到 `docs/plans/completed/`。
- 2026-06-09：后续已补齐 release manifest schema、本地 JSON Schema 子集校验、样例检查和可选 `-AssetRoot` sha256/size 校验；发布校验相关风险已收窄为真实 workflow 接入和真实 artifact 上下文一致性。

## 验证结果

- 已执行 `rg -n "GitHub Releases|Actions artifact|backend-services|backend-full|latest|App 不内置后端|后端源码" docs README.md`：可检索到发布入口、临时 artifact 交接、后端聚合包、不使用 `latest`、App 不内置后端和后端源码禁止项。
- 已执行 `rg -n "仍需第 9 步|是否公开分发|是否进入公开|需要.*发布设计继续确认|待确认.*native|后端 private release" docs README.md`：未发现未解决的“待确认”旧口径；匹配项均为 ADR 0012 对不采用后端 private release 的说明，或已由 ADR 0012 确认的历史状态更新。
- 已执行 `git diff --check`：通过；仅提示 Windows 行尾规则转换，不是空白错误。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，包含文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- 本轮只完成设计与文档，不实现真实 GitHub Actions workflow。
- 后端 native manifest schema、本地禁止文件扫描和可选 Release asset sha256/size 校验已实现；真实 GitHub Actions artifact 下载权限、跨仓库触发方式、真实 release artifact 上下文一致性和 Release 上传尚未实现。
- 安装器签名、公证、自动更新、release notes 和版本号策略仍需后续单独确认。

## 相关 commit

- 根仓库提交会随本轮收口完成；最终提交号以仓库 Git 日志和本轮最终回复为准。
