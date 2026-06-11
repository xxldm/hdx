# ADR 0013：Release workflow 凭据与 artifact 策略

- 日期：2026-06-09
- 状态：已接受

## 背景

ADR 0012 已确认：公开主仓库 GitHub Releases 是唯一公开发布入口；后端私有仓库先编译 native，并只通过 GitHub Actions artifact 临时交接给主仓库；主仓库不得 checkout 后端私有源码，也不得使用 `latest`。

主仓库 release dry-run workflow 已在 GitHub-hosted runner 实跑通过。下一步真实 release workflow 需要继续明确：

- 主仓库如何安全读取后端私有仓库 Actions artifact。
- 后端 Actions artifact 作为临时交接物应保留多久。
- 只更新 Web、后端、Desktop 或 App 中某一端时，是否允许从历史 Release 自动复用旧资产；后端 native 复用策略后续由 ADR 0014 单独替代第一版限制。
- 真实 Release 创建、上传和发布时如何避免用户看到半成品。

## 决策

### 跨仓库凭据

真实 release workflow 使用 GitHub App token 作为跨仓库自动化凭据，不使用 fine-grained PAT 或 classic PAT。

GitHub App 的权限是一套最大授权；虽然 installation token 可以请求权限子集，但持有 App private key 的 workflow 仍可能生成该 App 最大授权范围内的 token。为降低 private key 泄漏时的影响面，正式 tag-only 发布流程使用两个 GitHub Apps：

- `HDX Backend Actions Bot`：安装到后端私有仓库，用于主仓库触发后端 workflow 和读取后端 Actions artifact。权限为 `Actions: read`、`Actions: write`、`Metadata: read`，private key 只保存到公开主仓库 secrets；该 App 不授予 `Contents: read`，公开主仓库不得用它读取后端源码。
- `HDX Main Workflow Bot`：安装到公开主仓库，用于后端私有仓库在 native build 完成后触发主仓库 release assemble workflow。权限为 `Actions: write`、`Metadata: read`，private key 只保存到后端私有仓库 secrets，当前后端仓库 secret 名称为 `HDX_MAIN_WORKFLOW_APP_CLIENT_ID` 和 `HDX_MAIN_WORKFLOW_APP_PRIVATE_KEY`；该 App 不授予 `Contents: read`，后端仓库不再读取主仓库历史 Release asset。

主仓库创建、上传和发布 GitHub Release 时，优先使用主仓库 workflow 自己的 `GITHUB_TOKEN`，并在对应 job 中声明 `permissions: contents: write`。如果后续要求 Release 必须由 GitHub App 身份创建，不得把具备主仓库 `Contents: write` 的 App private key 放入后端私有仓库；应另行设计只保存在主仓库的发布 App 或继续使用主仓库 `GITHUB_TOKEN`。

GitHub App 的 client id、private key 和安装信息只能放在 GitHub Actions Secrets 或后续等价 secret store 中，不提交到仓库。实现前必须确认 GitHub App 安装范围、权限、secret 名称和 workflow 使用的 token 生成 action 版本。

当前主仓库提供最小验证 workflow `.github/workflows/check-release-app-token.yml`。该 workflow 只用于手动验证 `HDX Backend Actions Bot` 能以 `Actions: read/write` 权限访问后端私有仓库 Actions metadata，不申请 `Contents: read`，不读取或下载 Actions artifact，不创建 GitHub Release，不上传 asset，也不 checkout 后端私有源码。当前 workflow 使用 `HDX_RELEASE_APP_CLIENT_ID` 与 `actions/create-github-app-token@v3.2.0` 的 `client-id` 输入，避免使用已弃用的 `app-id` 输入。

### Actions artifact 保留期

后端私有仓库 native artifact 使用 `retention-days: 1`。

Actions artifact 只作为短期 CI 交接物，不作为长期发布存档。主仓库 GitHub Release 才是公开长期发布存档。后端 artifact 过期时，重新运行对应后端 commit 的 native build，不从 `latest` 或历史临时 artifact 猜测可用产物。

### Release 资产来源

当前策略是：除 ADR 0014 约束的后端 native asset 受控复用外，其他 Web、Desktop 和 App 资产不做跨 Release 自动复用。

ADR 0014 已替代本 ADR 早期“后端 native 一律不复用历史 Release asset”的第一版限制。

每次 Release 的所有资产都必须在 `release-manifest.json` 中明确列出，并满足以下任一来源：

- 来自本次主仓库 release workflow 构建。
- 来自明确指定 `run_id` 和 artifact name 的短期 GitHub Actions artifact。
- 后端 native asset 在 backend native fingerprint 完全匹配时，可以来自明确指定的历史主仓库 Release asset；具体约束见 ADR 0014。

即使某一端代码没有变化，只要该端资产进入本次 Release，也必须为本次 Release 提供明确、可校验的资产来源；可以重建同一 commit 的产物，但不能按“某端没更新”推断可跳过校验。后端 native 历史 Release asset 复用必须显式记录来源 release tag、asset name、sha256、size 和 fingerprint，不能使用 `latest`。

### Tag-only 触发与 release payload

常规发版目标是人工只在公开主仓库推送 release tag，其余步骤自动完成。主仓库 release start workflow 由 tag push 触发，读取 root commit、子模块指针和 OpenAPI hash 后，先在主仓库判断最新一个合格历史 Release 中的后端 native asset 是否可复用；复用成功时直接触发主仓库 release assemble workflow，复用失败时才使用 `HDX Backend Actions Bot` 通过 `workflow_dispatch` 触发后端私有仓库 release resolve workflow 运行 native build。

主仓库 release tag 对应的 root commit 是事实源。后端源码版本由该 root commit 中的 `services/backend` 子模块 gitlink 决定；release start 不要求该 `backend_commit` 等于后端仓库当前 `main`，也不持有后端 `Contents: read` 权限去调用后端 commit API。后端 release resolve 和 native build workflow 可以使用后端 `main` 上的 workflow 文件作为控制平面，但必须显式 checkout 输入的 `backend_commit`，并在 checkout 后校验实际 HEAD 与输入一致。

历史主仓库 Release asset 复用判断由主仓库 release start 完成。主仓库使用自身 `GITHUB_TOKEN` 读取公开主仓库 Release asset，并用 `scripts/release-resolve-backend-sources.ps1` 校验历史 `release-manifest.json`、`backend-native-manifest.json`、必需 asset 的 sha256/size、OpenAPI hash 和 backend native fingerprint。后端 release resolve workflow 只负责在复用不可用时按输入的 `backend_commit` 重新构建后端 native，并使用 `HDX Main Workflow Bot` 的 `Actions: write` token 通过 `workflow_dispatch` 触发主仓库 release assemble workflow。

主仓库 release assemble workflow 至少接收以下由上游自动生成的 payload；这些字段不是常规人工输入：

- `version`
- `root_ref`
- `root_commit`
- `backend_commit`
- `backend_source_mode`：`github-actions-artifact` 或 `historical-release-asset`
- `backend_sources_json`
- `release_intent_id`

后续如果 Web、Desktop 或 App 改为独立构建 workflow，也应按同一模式显式传入对应组件的 `run_id`、artifact name 和 commit。所有输入都禁止使用 `latest`。

`backend_sources_json` 是正式 `release.yml` 的后端 native 来源描述，避免把每个平台和每种后端包拆成大量 workflow input。该 JSON 必须显式列出每个后端 native asset 的 `kind`、`platform` 和来源字段：

- `github-actions-artifact` 来源必须包含后端仓库、后端 workflow `run_id`、artifact name 和后端 commit。
- `historical-release-asset` 来源必须包含历史主仓库 Release tag、历史 asset name、sha256、size、历史 `release-manifest.json` 和历史 `backend-native-manifest.json` 来源。
- `backend-full` 的 Windows/Linux asset 是 Desktop Full 打包的默认必需输入。
- `backend-services-linux-x64` 是微服务部署包的默认必需输入。
- `backend-services-windows-x64` 保持可选；只有显式要求发布 Windows services 包时才构建、校验、上传并写入 `release-manifest.json`。

### 第一版 `release.yml` job 设计

本节只定义正式 workflow 的设计边界；实现前不得把半成品正式发布 workflow 放入仓库。

正式 tag-only 发布第一版采用以下自动触发方式：

- 公开主仓库 release tag push 触发主仓库 release start。
- 主仓库 release start 先尝试历史后端 native asset 复用；成功时直接通过 `workflow_dispatch` 触发主仓库 release assemble，并传入 `backend_source_mode=historical-release-asset` 和 `backend_sources_json`。
- 历史复用不可用时，主仓库 release start 通过 `workflow_dispatch` 触发后端 release resolve 运行 native build。
- 后端 release resolve 在 native build 成功后通过 `workflow_dispatch` 触发主仓库 release assemble，并传入 `backend_source_mode=github-actions-artifact` 和 `backend_sources_json`。
- 维护者可以保留手动 `workflow_dispatch` 作为排障或重跑入口，但常规发版不要求人工填写 `backend_sources_json`。
- 主仓库不得自行查找后端 `latest` run、latest artifact 或 latest Release。

第一版主仓库 release assemble job 图：

```text
validate-inputs
  -> prepare-root-context
  -> resolve-backend-native
  -> build-web
  -> build-desktop-online
  -> build-desktop-full
  -> build-app-online
  -> assemble-release-assets
  -> create-draft-release
  -> upload-release-assets
  -> verify-remote-release
  -> publish-release
```

依赖和并行规则：

- `validate-inputs` 拒绝空版本、`latest`、缺失后端来源、重复 asset、非法平台和不匹配的 `backend_source_mode`。
- `prepare-root-context` checkout 指定 `root_ref`，记录 root commit、子模块指针、OpenAPI snapshot hash 和 release manifest schema 版本。
- `resolve-backend-native` 只处理后端 native 输入，不构建后端源码；该 job 根据 `backend_source_mode` 选择下载后端 Actions artifact 或历史主仓库 Release asset，并统一输出已校验的后端 native 资产目录。
- `build-web`、`build-desktop-online` 和后续 `build-app-online` 只依赖 `prepare-root-context`；App 在工程可打包前不进入第一版实现。
- `build-desktop-full` 依赖 `resolve-backend-native`，并且每个平台只能内置同平台 `backend-full` archive；生成的 `backend-build.json` 必须与 Release 中公开的 `backend-full` asset sha256 一致。
- `assemble-release-assets` 下载所有前序 job 产物，生成 `release-manifest.json` 和 `SHA256SUMS`，并运行 release manifest、sha256、size、OpenAPI hash 和禁止文件扫描。
- `create-draft-release` 只能在本地全部资产校验通过后运行。
- `upload-release-assets` 上传资产后，`verify-remote-release` 必须从远端 Release 下载 `release-manifest.json`、`SHA256SUMS` 和全部 asset，重新校验清单、sha256 和 size。
- `publish-release` 只能在远端校验通过后运行。

权限和凭据规则：

- workflow 默认权限使用只读；需要跨仓库触发 workflow 或读取后端 artifact 时，在对应 step 附近生成短期 GitHub App token。
- 主仓库读取历史主仓库 Release asset 使用自身 `GITHUB_TOKEN` 和 `contents: read`；该路径不需要跨仓库 GitHub App token。
- 读取后端私有仓库 artifact 的 token 不复用于主仓库 Release 写操作。
- 主仓库发布 Release、上传 asset 和 publish 使用主仓库 workflow 自己的 `GITHUB_TOKEN`，并只在对应 job 声明 `permissions: contents: write`。
- 主仓库正式发布 workflow 不 checkout 后端私有源码，不缓存后端私有源码，不上传后端源码相关日志、artifact 或 cache。
- 同一 `version` 使用 concurrency 串行化，避免两个 release run 同时写同一个 tag 或 draft。

### Draft 到 Publish

真实 release workflow 先生成并校验本地全部资产，再创建 draft GitHub Release。

上传全部资产后，workflow 必须校验远端 Release asset 清单、`SHA256SUMS` 和 `release-manifest.json`。只有校验通过后，才能把 draft 发布为正式 Release。

如果任一步骤失败：

- 不得 publish Release。
- 如果失败前尚未创建 draft，则不创建 Release。
- 如果失败发生在 draft 创建后，draft 保留为未发布状态用于排障，并在 run summary 中记录失败 job、已上传 asset 和建议清理命令；第一版不自动删除失败 draft，避免丢失排障证据。
- 重新运行同一 `version` 前必须先处理已存在的失败 draft/tag，第一版不提供自动覆盖已存在公开 Release 或失败 draft 的能力。

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
- 自动复用历史 Release 中未变更组件的资产：可以减少构建时间，但会显著增加 manifest 兼容性、资产追溯、回滚和安全校验复杂度；第一版不采用。后续仅针对后端 native 资产的受控复用已由 ADR 0014 重新决策。
- 直接创建公开 Release 并上传资产：流程短，但失败时用户可能看到半成品，不采用。
- 上传资产到后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库：与 ADR 0012 的临时交接边界冲突，不采用。

## 影响范围

- 后端私有仓库 native CI 必须设置 `retention-days: 1`，并输出主仓库可校验的 artifact name、run id、后端 commit、manifest 和 sha256。
- 主仓库真实 release workflow 后续需要按本文 job 设计使用 GitHub App token 触发后端 workflow、下载后端 artifact；历史主仓库 Release asset 由主仓库自身 `GITHUB_TOKEN` 读取；主仓库使用自身 `GITHUB_TOKEN` 创建、上传和发布 draft Release。
- `release-manifest.json` 必须能表达每个资产的来源、commit、sha256、size 和组件归属；后续按 ADR 0014 扩展后，还必须表达历史主仓库 Release asset 复用来源和 backend native fingerprint。
- `docs/adr/0012-github-releases-artifact-boundary.md` 保持产物边界事实源，本 ADR 补充真实 workflow 的凭据、artifact 保留期和资产来源策略。
- 安装器签名、公证、自动更新、release notes 和版本号策略仍需后续 ADR 或计划单独确认。

## 验证方式

通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。

本 ADR 特有检查：

- `GitHub App token`、`retention-days: 1`、`run_id`、`draft`、`fine-grained PAT`、`latest` 和跨 Release 旧资产复用策略在相关文档中可发现。

后续实现验证：

- 使用 `.github/workflows/check-release-app-token.yml` 验证 `HDX Backend Actions Bot` 可以用 `Actions: read/write` 权限访问后端私有仓库 Actions metadata，且不需要 `Contents: read`。
- 使用最小权限 GitHub App token 下载指定后端 `run_id` 的 artifact。
- 验证后端 artifact 过期后 workflow 失败信息明确指向“需要重跑后端构建”。
- 验证 workflow 不 checkout 后端私有源码。
- 验证不允许 `latest` 输入。
- 验证 `backend_sources_json` 中每个后端 native asset 的 kind、platform、来源、sha256、size、后端 commit、OpenAPI hash 和 backend native fingerprint 与实际资产一致。
- 验证 Desktop Full 的 `backend-build.json` 与 Release 中同平台 `backend-full` asset sha256 一致。
- 验证上传资产后，远端 draft Release 的 asset 清单、`SHA256SUMS` 和 `release-manifest.json` 一致。
- 验证失败时 Release 不会被 publish。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- 项目决定使用 fine-grained PAT、classic PAT 或其他非 GitHub App 凭据作为跨仓库发布凭据。
- 项目决定把后端 artifact 长期保存到 GitHub Actions artifact、后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库。
- 项目决定让非后端 native 资产也自动复用历史 Release 资产，或决定绕过 ADR 0014 的 backend native fingerprint 规则复用后端 native 资产。
- 项目决定真实 release workflow 直接发布公开 Release，而不经过 draft 校验。

## 后续事项

- 创建 `HDX Backend Actions Bot` 和 `HDX Main Workflow Bot`，确认安装范围、最小权限和 secrets 命名。
- 设计后端私有仓库 native CI：生成 artifact、manifest、sha256，设置 `retention-days: 1`，并触发主仓库 workflow。
- 主仓库真实 `release-start.yml` 已完成 tag start 第一片：
  - 真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文。
  - 先在主仓库尝试复用最新一个合格历史 Release 中的后端 native asset。
  - 复用成功时直接触发主仓库 `release.yml`。
  - 复用失败时触发后端私有仓库 release resolver 运行 native build。
  - 手动入口默认 dry-run。
- 主仓库真实 `release.yml` 已完成第一版 draft assemble 骨架：
  - 支持手动输入多个后端 Actions artifact 聚合。
  - 支持从同一个历史主仓库 Release 复用多个后端 native asset。
  - 构建 Web node-server asset。
  - 构建 Desktop Online Windows/Linux asset。
  - 完成输入校验、root context 准备、release manifest 组装、draft Release、资产上传和远端校验。
- 后端私有仓库已完成 release resolve 第一片：
  - 按输入的 `backend_commit` checkout 后端源码。
  - 根据主仓库传入的必需后端资产列表计算 native build scope。
  - 调用 `backend-native-artifact.yml` 生产短期 Actions artifact。
  - 构建完成后可显式回调主仓库 `release.yml`。
  - 不再读取主仓库历史 Release，也不需要主仓库 `Contents: read` GitHub App 权限。
- 后续仍需补齐 Desktop Full/App 构建、publish 和失败清理。
- 后续单独确认安装器签名、公证、自动更新、release notes 和版本号策略。

## 实施记录

- 2026-06-10：新增 `.github/workflows/release.yml` 第一版。该版本是正式命名入口，但仍为 `workflow_dispatch` draft assemble 骨架；不 checkout 后端私有源码，不使用 `latest`，不构建 Web/Desktop/App，不自动 publish。
- 2026-06-10：`release.yml` 扩展为支持多个后端 Actions artifact 聚合；`backend_sources_json.sources[]` 可列出同一后端仓库、同一后端 workflow run 的多个 artifact。当时历史 Release asset 来源仍保持单资产限制。
- 2026-06-10：`release.yml` 扩展为支持多个历史主仓库 Release asset 复用；`historical-release-asset` 第一版要求多个来源来自同一个历史 Release，并覆盖历史 `backend-native-manifest.json` 记录的全部后端 native asset。
- 2026-06-10：新增 `scripts/release-resolve-backend-sources.ps1` 和后端私有仓库 `.github/workflows/backend-release-resolve.yml`，提供后端来源解析第一片：从指定历史主仓库 Release，或未指定时从最新一个合格已发布 Release，生成可交给主仓库 `release.yml` 的 `backend_sources_json`。
- 2026-06-10：`backend-release-resolve.yml` 增加可选 native build fallback 和可选主仓库 `release.yml` assemble 回调。手动排障默认不启用这两个开关，完整 tag-only release start 后续应显式开启。
- 2026-06-10：新增 `scripts/openapi-snapshot-hash.ps1` 和 `.github/workflows/release-start.yml`。`release-start.yml` 的真实 `v*` tag push 路径会计算 root commit、后端子模块 commit、OpenAPI snapshot hash 和默认后端必需资产，并触发后端 resolver；手动入口默认 dry-run。
- 2026-06-10：`release.yml` 接入 Web node-server asset 构建：只初始化根仓库锁定的 `apps/web` 子模块，不 checkout 后端私有源码；构建 `hdx-web-node-server-<version>.tar.gz` 后追加到 `release-manifest.json` 并重算 `SHA256SUMS`。Desktop/App 构建和自动 publish 仍待后续切片。
- 2026-06-10：`release.yml` 接入 Desktop Online asset 构建：Windows/Linux 分平台构建公开 `apps/desktop` 子模块，整理 Windows NSIS 安装包、Windows 绿色 zip 包和 Linux AppImage，通过 `scripts/release-append-desktop-assets.ps1` 追加 `sources.desktop` 与 Desktop Online assets，并重算 `SHA256SUMS`。Desktop Full、App、updater JSON 和自动 publish 仍待后续切片。
- 2026-06-11：职责边界收缩。历史 Release asset 复用判断迁回主仓库 `release-start.yml`；后端 `backend-release-resolve.yml` 只负责 native build 和可选回调主仓库 assemble。`HDX Backend Actions Bot` 与 `HDX Main Workflow Bot` 的最大权限均不再需要 `Contents: read`。
