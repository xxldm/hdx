# 质量门禁

本文件定义 HDX 工具箱的最小质量要求。

## 本地质量门禁脚本

本地统一入口为根仓库脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope changed
```

常用范围：

- `-Scope changed`：默认值，根据 Git 改动选择文档、后端、Web 或 Desktop 检查。
- `-Scope docs`：检查关键文档 UTF-8 读取、PowerShell 脚本 UTF-8 with BOM 与中文可读性、根仓库空白错误、Release manifest 契约、OpenAPI 契约和 OpenAPI/Web 类型对齐。
- `-Scope backend`：检查后端子模块并运行 `mvn test`。
- `-Scope web`：检查 Web 子模块并运行 `pnpm test`、`pnpm typecheck`、`pnpm lint` 和 `pnpm build`。
- `-Scope desktop`：检查 Desktop 子模块骨架、空白错误；未使用 `-NoBuild` 时运行 TypeScript 和 Rust flavor 检查。
- `-Scope all`：按顺序运行文档、后端、Web 和 Desktop 检查。

轻量控制参数：

- `-NoBuild`：后端只检查 Maven 环境，Web 跳过 build，Desktop 跳过 TypeScript/Rust 编译；适合先验证脚本分支和基础环境。
- `-SkipBackend`：跳过后端检查。
- `-SkipWeb`：跳过 Web 检查。
- `-SkipDesktop`：跳过 Desktop 检查。

脚本约束：

- 脚本只覆盖本地常用质量门禁，不替代远端 CI。
- 仓库内 Git 跟踪的 `.ps1` 脚本必须使用 UTF-8 with BOM；脚本中的中文输出、错误提示和帮助文本应直接写为可读中文，不使用 `\uXXXX` 形式规避编码问题。
- 脚本不运行完整 native-image 编译。调整 `native-maven-plugin`、`--exclude-config`、Spring AOT、`RuntimeHints`、Hibernate enhance 或类初始化参数时，仍必须按 `docs/CONSTRAINTS.md` 和后端 README 单独验证 native 编译和健康检查。
- 脚本通过 `scripts/git-submodule-status.ps1` 检查子模块状态：优先执行 `git submodule status`，如果当前 Git for Windows 脚本环境失败，则自动使用 Git Bash fallback，最后退到 `git ls-files -s` 指针检查；同时仍分别使用 `git -C services/backend status --short --branch`、`git -C apps/web status --short --branch` 和 `git -C apps/desktop status --short --branch` 展示子仓库工作区状态。
- 如果 Maven、pnpm、Git 写操作或网络操作在普通权限下失败，按 `docs/GIT.md` 的权限失败重试规则处理。

## 提交前检查

任何代码或配置变更在提交前都应完成：

- 相关文档是否仍然准确。
- 新增边界数据是否已解析或校验。
- 新增行为是否有测试、脚本验证或清晰复现步骤。
- 是否引入了未记录的技术选型。
- 是否破坏 `docs/ARCHITECTURE.md` 中的依赖方向。
- 是否新增密钥、令牌、凭证、真实用户数据或敏感日志。
- 新增或修改 UI、日志、错误提示、命令行输出、通知、占位符、帮助文本等面向人类的显示文案时，是否优先使用中文；保留非中文时是否属于协议字段、代码标识符、标准错误码、第三方固定输出、外部原文引用或国际化备用语言。
- 是否遵守 `docs/GIT.md` 中的提交信息、原子提交、推送前检查和 Git 操作串行规则。
- 是否遵守 `docs/GIT.md` 中的智能体权限失败重试规则，避免同类命令反复普通权限失败造成无效 token 消耗。
- 如果存在 Symphony、Linear 等外部任务，是否已在本地计划、ADR、提交说明或相关文档中记录链接/编号；没有外部编号时是否写明“无”或“不适用”。
- 如果修改了 `docs/config/nacos/` 模板，是否已按模板层级和相邻位置同步真实 Nacos Data ID；新增项是否已通知用户确认真实值，修改或删除项是否已获得用户同意。
- 如果修改了 `.env.example` 或 `.env.symphony.example`，是否已按模板分组和相邻位置同步对应 `.env.local` 或 `.env.symphony.local` 文件结构；新增项是否已提示用户填写真实值，修改或删除项是否已获得用户同意。
- 如果存在本地 active 计划，当前状态、checkbox 或状态表、状态记录、验证结果和剩余风险是否已同步。
- 如果未创建本地计划，是否符合 `docs/plans/README.md` 的豁免条件，且最终回复是否说明变更范围、验证结果和剩余风险。
- 如果新增或修改 `.ps1` 脚本，是否已保存为 UTF-8 with BOM，且未新增 `\uXXXX` 中文转义。
- 如果根仓库更新了子模块指针，相关子模块 commit 是否已推送到各自远端并可获取。
- 是否已运行与变更范围相称的 `scripts/quality-gate.ps1` 范围；如未运行，是否说明替代验证和剩余风险。
- 如果改动 OpenAPI、后端公开路径、Web BFF 契约、`packages/shared/contracts/openapi/expected-paths.json`、`expected-schemas.json` 或 OpenAPI 快照，是否已运行 `scripts/openapi-contract-check.ps1`；如果后端 spec 发生预期变化，是否先运行 `scripts/openapi-refresh-snapshots.ps1` 并提交快照。
- 如果改动 OpenAPI 快照、`scripts/openapi-generate-types.ps1` 或 `packages/shared/generated/openapi/`，是否已运行 `scripts/openapi-generate-types.ps1 -Check`；如果生成结果预期变化，是否先运行 `scripts/openapi-generate-types.ps1` 并提交生成物。
- 如果改动 Web Zod schema、OpenAPI 生成类型或 `packages/shared/contracts/openapi/web-type-compatibility.ts`，是否已运行 `scripts/openapi-web-type-check.ps1`，确认 Web 手写类型和 OpenAPI 生成类型仍保持编译期兼容。
- 如果改动 `packages/shared/contracts/release/*.schema.json`、release manifest 示例或 release 校验脚本，是否已运行 `scripts/release-manifest-check.ps1`，并检查 ADR 0012 和 release 契约说明仍一致。

## 测试策略

- 共享契约优先单元测试和契约测试。
- 后台优先覆盖边界解析、业务规则、错误路径和权限规则。
- Web 优先覆盖关键交互、表单校验、状态流转和可访问性风险。
- App 优先覆盖平台适配、离线/弱网、权限和关键用户路径。
- 修复缺陷时应补充回归测试；暂时无法自动化时，记录手工复现步骤。

## 验证输出

完成一项实现后，应在结果中说明：

- 变更范围。
- 执行过的验证命令或步骤。
- 未能验证的内容。
- 剩余风险。

## 未来自动化方向

后续优先把以下约束继续编码为脚本、lint 或 CI：

- 文档语言与索引检查。
- 架构依赖方向检查。
- 边界解析覆盖检查。
- 文件大小和重复工具函数检查。
- 禁止密钥提交检查。
- 测试覆盖与关键路径回归检查。
