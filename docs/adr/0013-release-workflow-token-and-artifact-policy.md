# ADR 0013：Release workflow 凭据与 artifact 策略

- 日期：2026-06-09
- 状态：已接受

## 背景

ADR 0012 已确认：公开主仓库 GitHub Releases 是唯一公开发布入口；后端私有仓库先编译 native，并只通过 GitHub Actions artifact 临时交接给主仓库；主仓库不得 checkout 后端私有源码，也不得使用 `latest`。

主仓库 release dry-run workflow 已在 GitHub-hosted runner 实跑通过。下一步真实 release workflow 需要继续明确：

- 主仓库如何安全读取后端私有仓库 Actions artifact。
- 后端 Actions artifact 作为临时交接物应保留多久。
- 只更新 Web、后端、Desktop 或 App 中某一端时，是否允许从历史 Release 自动复用旧资产。
- 真实 Release 创建、上传和发布时如何避免用户看到半成品。

## 决策

### 跨仓库凭据

真实 release workflow 使用 GitHub App token 作为跨仓库自动化凭据，不使用 fine-grained PAT 或 classic PAT。

GitHub App 作为 HDX 发布自动化身份，后续应安装到公开主仓库和后端私有仓库，并按步骤请求最小权限 token：

- 读取后端私有仓库 Actions artifact 时，只授予后端私有仓库所需的 Actions artifact 读取能力。
- 创建、上传和发布主仓库 GitHub Release 时，只授予公开主仓库所需的 Release/contents 写入能力。
- 不把同一个高权限 token 贯穿整个 workflow；后续实现应在需要的 step 附近生成短期 token，并避免写入日志、artifact、cache 或 release asset。

GitHub App 的 App ID、private key 和安装信息只能放在 GitHub Actions Secrets 或后续等价 secret store 中，不提交到仓库。实现前必须确认 GitHub App 安装范围、权限、secret 名称和 workflow 使用的 token 生成 action 版本。

### Actions artifact 保留期

后端私有仓库 native artifact 使用 `retention-days: 1`。

Actions artifact 只作为短期 CI 交接物，不作为长期发布存档。主仓库 GitHub Release 才是公开长期发布存档。后端 artifact 过期时，重新运行对应后端 commit 的 native build，不从 `latest` 或历史临时 artifact 猜测可用产物。

### Release 资产来源

第一版真实 release workflow 不做跨 Release 旧资产自动复用。

每次 Release 的所有资产都必须在 `release-manifest.json` 中明确列出，并满足以下任一来源：

- 来自本次主仓库 release workflow 构建。
- 来自明确指定 `run_id` 和 artifact name 的短期 GitHub Actions artifact。

这条规则适用于 Web、Desktop、后端和后续 App。即使某一端代码没有变化，只要该端资产进入本次 Release，也必须为本次 Release 提供明确、可校验的资产来源；可以重建同一 commit 的产物，但不能让 workflow 自动从历史 Release 中拿旧资产，也不能按“某端没更新”推断可跳过校验。

### 真实 release workflow 输入

第一版真实 release workflow 至少应显式输入或由上游触发上下文提供：

- `version`
- `root_ref`
- 后端 `run_id`
- 后端 artifact name
- 后端 commit

后续如果 Web、Desktop 或 App 改为独立构建 workflow，也应按同一模式显式传入对应组件的 `run_id`、artifact name 和 commit。所有输入都禁止使用 `latest`。

### Draft 到 Publish

真实 release workflow 先生成并校验本地全部资产，再创建 draft GitHub Release。

上传全部资产后，workflow 必须校验远端 Release asset 清单、`SHA256SUMS` 和 `release-manifest.json`。只有校验通过后，才能把 draft 发布为正式 Release。

如果任一步骤失败：

- 不得 publish Release。
- 如果失败前尚未创建 draft，则不创建 Release。
- 如果失败发生在 draft 创建后，draft 保留为未发布状态用于排障；后续是否自动清理失败 draft 另行决策。

### 后置事项

本 ADR 不决定以下事项：

- 安装器签名、公证和自动更新。
- release notes 生成方式。
- 版本号策略。
- GitHub App 的具体名称、安装 ID、secret 命名和 token 生成 action 版本。
- 真实 workflow 的完整 YAML、失败重试和人工审批 UI。

## 备选方案

- 使用 fine-grained PAT：配置较快，但凭据仍绑定个人账号，生命周期和审计边界不如 GitHub App 清晰，不采用。
- 使用 classic PAT：权限过宽，泄漏影响面大，不采用。
- 使用默认 `GITHUB_TOKEN` 跨仓库读取后端 artifact：默认 token 不适合作为跨仓库私有 artifact 读取凭据，不采用。
- 后端 Actions artifact 保留 7 天或更久：能降低重建频率，但扩大临时 artifact 暴露窗口；本项目将主仓库 Release 作为长期存档，因此不采用。
- 自动复用历史 Release 中未变更组件的资产：可以减少构建时间，但会显著增加 manifest 兼容性、资产追溯、回滚和安全校验复杂度；第一版不采用。
- 直接创建公开 Release 并上传资产：流程短，但失败时用户可能看到半成品，不采用。
- 上传资产到后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库：与 ADR 0012 的临时交接边界冲突，不采用。

## 影响范围

- 后端私有仓库 native CI 后续需要设置 `retention-days: 1`，并输出主仓库可校验的 artifact name、run id、后端 commit、manifest 和 sha256。
- 主仓库真实 release workflow 后续需要使用 GitHub App token 下载后端 artifact，并使用最小权限创建、上传和发布 draft Release。
- `release-manifest.json` 必须能表达每个资产的来源、commit、sha256、size 和组件归属。
- `docs/adr/0012-github-releases-artifact-boundary.md` 保持产物边界事实源，本 ADR 补充真实 workflow 的凭据、artifact 保留期和资产来源策略。
- 安装器签名、公证、自动更新、release notes 和版本号策略仍需后续 ADR 或计划单独确认。

## 验证方式

本轮文档决策验证：

- 使用 PowerShell 7+ / `pwsh` 读取本 ADR、ADR 0012、架构、约束、README 和总纲。
- 使用 `rg` 检查 `GitHub App token`、`retention-days: 1`、`run_id`、`draft`、`fine-grained PAT`、`latest` 和跨 Release 旧资产复用策略是否可发现。
- 执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。

后续实现验证：

- 使用最小权限 GitHub App token 下载指定后端 `run_id` 的 artifact。
- 验证后端 artifact 过期后 workflow 失败信息明确指向“需要重跑后端构建”。
- 验证 workflow 不 checkout 后端私有源码。
- 验证不允许 `latest` 输入。
- 验证上传资产后，远端 draft Release 的 asset 清单、`SHA256SUMS` 和 `release-manifest.json` 一致。
- 验证失败时 Release 不会被 publish。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- 项目决定使用 fine-grained PAT、classic PAT 或其他非 GitHub App 凭据作为跨仓库发布凭据。
- 项目决定把后端 artifact 长期保存到 GitHub Actions artifact、后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库。
- 项目决定第一版真实 release workflow 自动复用历史 Release 资产。
- 项目决定真实 release workflow 直接发布公开 Release，而不经过 draft 校验。

## 后续事项

- 创建 GitHub App，确认安装范围和最小权限。
- 设计后端私有仓库 native CI：生成 artifact、manifest、sha256，设置 `retention-days: 1`，并触发主仓库 workflow。
- 设计并实现主仓库真实 release workflow：输入校验、GitHub App token 生成、artifact 下载、manifest 校验、资产构建、draft Release、资产上传、远端校验和 publish。
- 后续单独确认安装器签名、公证、自动更新、release notes 和版本号策略。
