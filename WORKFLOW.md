---
tracker:
  kind: linear
  endpoint: https://api.linear.app/graphql
  api_key: $LINEAR_API_KEY
  project_slug: hdx-44dde4471027
  active_states:
    - Todo
    - In Progress
    - Merging
    - Rework
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
polling:
  interval_ms: 5000
workspace:
  root: D:\Project\symphony-workspaces\hdx
hooks:
  timeout_ms: 300000
  after_create: |
    if [ -d .git ]; then
      git submodule update --init --recursive || true
      exit 0
    fi

    git clone --recurse-submodules https://github.com/xxldm/hdx.git .
    git submodule update --init --recursive || {
      git clone https://github.com/xxldm/hdx-backend.git services/backend
      git clone https://github.com/xxldm/hdx-web.git apps/web
      git clone https://github.com/xxldm/hdx-desktop.git apps/desktop
    }
  before_run: |
    git status --short || true
  after_run: |
    git status --short || true
  before_remove: |
    git status --short || true
agent:
  max_concurrent_agents: 1
  max_concurrent_agents_by_state:
    Todo: 1
    In Progress: 1
    Merging: 1
    Rework: 1
  max_turns: 8
  max_retry_backoff_ms: 300000
codex:
  command: PATH="/e/soft/codex-cli/node_modules/.bin:$PATH" codex app-server -c "windows.sandbox=\"unelevated\"" -c "model_provider=\"$SYMPHONY_CODEX_MODEL_PROVIDER\"" -c "model=\"$SYMPHONY_CODEX_MODEL\"" -c "model_providers.$SYMPHONY_CODEX_MODEL_PROVIDER.name=\"$SYMPHONY_CODEX_PROVIDER_NAME\"" -c "model_providers.$SYMPHONY_CODEX_MODEL_PROVIDER.base_url=\"$SYMPHONY_CODEX_BASE_URL\"" -c "model_providers.$SYMPHONY_CODEX_MODEL_PROVIDER.wire_api=\"$SYMPHONY_CODEX_WIRE_API\"" -c "model_providers.$SYMPHONY_CODEX_MODEL_PROVIDER.requires_openai_auth=$SYMPHONY_CODEX_REQUIRES_OPENAI_AUTH"
  approval_policy: on-request
  approvals_reviewer: auto_review
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
    writableRoots:
      - D:\Project\symphony-workspaces\hdx
    networkAccess: true
    excludeTmpdirEnvVar: false
    excludeSlashTmp: false
  turn_timeout_ms: 1800000
  read_timeout_ms: 30000
  stall_timeout_ms: 120000
server:
  port: 4321
observability:
  dashboard_enabled: true
  refresh_ms: 1000
  render_interval_ms: 16
---

你正在处理 Linear ticket `{{ issue.identifier }}`：{{ issue.title }}。

{% if attempt %}
续跑上下文：

- 这是第 {{ attempt }} 次重试，因为 ticket 仍处于活跃状态。
- 从当前 workspace 状态继续，不要从零开始重做已经完成的调查或验证，除非新改动需要重新验证。
- 如果 ticket 仍处于活跃状态，只有在缺少必需权限、密钥、工具或需求时才提前停止。
{% endif %}

Issue context：

- Identifier: {{ issue.identifier }}
- Title: {{ issue.title }}
- Current status: {{ issue.state }}
- Labels: {{ issue.labels }}
- URL: {{ issue.url }}

Description:

{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

## 总指令

1. 这是无人值守的 Symphony 编排会话。不要要求人类执行普通后续动作；只有真正外部阻塞时才停止。
2. 只能因为缺少必需认证、权限、密钥、工具或需求而提前停止。被阻塞时，必须写入 workpad，并按状态流处理。
3. 最终消息只报告已完成动作和阻塞项，不写泛泛的用户下一步建议。
4. 只在当前 issue 的隔离仓库副本内工作，不触碰 workspace 之外的项目路径。
5. 仓库内项目文档默认使用中文；Workpad 标题和正文默认使用中文；引用外部原文、协议字段、代码标识符、命令、路径、日志和错误输出可以保留原文。

## 前置条件：Linear 工具

- 必须能通过 Linear MCP 或注入的 `linear_graphql` 工具访问 Linear。
- 开始前先用 `linear_graphql` 按明确 ticket ID 读取 issue 当前状态、描述、标签、评论、父子 issue、关联 issue、项目和负责人信息。
- 如果 Linear 工具不可用，停止并在最终消息中说明需要配置 Linear 工具；不要改代码。

## 默认工作姿态

- 先确定 ticket 当前状态，再进入对应状态流程。
- 每个任务都先打开或创建跟踪 workpad 评论，并在开始新实现前把它更新到最新。
- 实现前优先投入计划和验证设计。
- 先复现：修改代码前必须捕获当前行为、失败信号或可验证现状，并写入 workpad。
- 保持 ticket 元数据、状态、检查清单、验收标准和链接准确。
- 使用一个持久 Linear 评论作为进度事实源，不发布额外的完成摘要评论。
- 如果 issue 描述或评论中包含 `Validation`、`Test Plan` 或 `Testing`，必须转写到 workpad 的验收/验证清单并执行，不能降级为可选项；转写说明用中文，原始命令、字段名和错误输出保留原文。
- 发现有意义但超出范围的改进时，另建 Backlog Linear issue，不扩大当前 scope。新 issue 必须有清楚标题、描述、验收标准、同项目归属、与当前 issue 的 `related` 关系；如果依赖当前 issue，还要使用 `blockedBy`。
- 只有满足对应质量门槛时才移动状态。
- 自主端到端推进，除非被缺失需求、密钥、权限或工具阻塞。
- `blocked-access escape hatch` 只能用于真实外部阻塞，并且要先尝试文档化 fallback。

## Token 消耗与重试控制

- Workpad 使用“摘要 + 索引”结构：只保留当前计划、验收状态、验证摘要、最新 blocker、PR/commit、本地计划路径和最近检查戳；完整排障细节写入 `docs/plans/active/`，完成后移动到 `docs/plans/completed/`。
- Workpad 必须包含 `详情位置`，指向本地计划文件；不要把完整命令输出、长日志或重复失败历史反复粘贴到 Linear。每个 blocker 在 workpad 保留一句可判断严重性的中文摘要，并引用本地计划路径。
- 权限失败重试预算遵循 `docs/GIT.md` 的“智能体权限失败重试规则”，该规则适用于 Symphony、Codex Desktop、Codex CLI 和其他在本仓库工作的智能体；不要把它当作 Symphony 专用规则。
- 在 Symphony workpad 中只写权限失败的中文摘要和 `详情位置`；首次失败、历史证据、提权结果和 blocker 细节写入本地计划。已知会失败的同类命令直接走自动审批提权，提权后仍失败则写 blocker，不循环重试。
- Git 网络命令防挂：`git push`、`git fetch`、`git ls-remote`、`gh` 命令如果缺少凭据、触发交互式认证或疑似挂在 `git-askpass` / `git-remote-https`，必须快速失败并写 blocker；不要等待不可见登录窗口。
- 无新增信息即停止：如果分支已推送、PR 已存在、无新 Linear 评论/附件、无新 PR comments/reviews/checks、head SHA 未变，则只做一次轻量 workpad 摘要更新并停止本轮；禁止连续写入“续作 N 审计”重复段落。
- 重复读取控制：首轮必须读取 HDX 仓库入口文档；续作时如果 `HEAD`、`WORKFLOW.md` 和入口文档未变化，只读取 workpad 摘要、本地计划文件和本轮相关文件。Workpad 或本地计划记录“入口文档已读 @ shortSha”；关键文档或 `HEAD` 变化时强制重读。

## 相关能力

- `linear`：与 Linear 交互。
- `linear_graphql`：通过 Symphony 管理的 Linear 凭证执行 GraphQL 查询和 mutation。
- `commit`：生成干净、逻辑单元清晰的提交。
- `push`：流程需要发布分支、更新 PR 或推进状态时可以使用；推送前必须确认目标 remote、目标分支、工作树状态、验证结果和敏感信息检查。
- `pull`：交接前同步最新 `origin/main`。
- `land`：当 ticket 到达 `Merging` 时，必须打开并遵循 `.codex/skills/land/SKILL.md`；不要直接调用 `gh pr merge`。

## 状态地图

- `Backlog`：不属于本 workflow 范围；不要修改，等待人类移动到 `Todo`。
- `Todo`：排队状态；主动工作前立即移动到 `In Progress`。
- `Todo` 特例：如果已经有关联 PR，按反馈/返工循环处理，先完整扫描 PR feedback，处理或明确反驳，重新验证，再回到 `Human Review`。
- `In Progress`：正在实现；继续执行流程。
- `Human Review`：PR 已附加并验证，等待人类审批；不要编码或改 ticket 内容。
- `Merging`：人类已批准；执行 `land` skill 流程，不要直接 `gh pr merge`。
- `Rework`：评审要求改动；按完整返工流程重新计划和实现。
- `Done`：终态；不再执行。

## Step 0：确定 ticket 状态并路由

1. 用明确 ticket ID 获取 issue。
2. 读取当前 state。
3. 按状态进入流程：
   - `Backlog`：不修改 issue 内容或状态，停止并等待人类移动到 `Todo`。
   - `Todo`：立即更新为 `In Progress`，再确保 `## Codex 工作台` bootstrap 评论存在，然后进入执行流程。
   - `In Progress`：从当前 workpad 评论继续执行流程。
   - `Human Review`：等待并轮询决策或评审更新，不做代码改动。
   - `Merging`：打开并遵循 `.codex/skills/land/SKILL.md`，不要直接调用 `gh pr merge`。
   - `Rework`：进入返工流程。
   - `Done`：什么都不做并关闭。
4. 检查当前分支是否已有 PR，以及 PR 是否已关闭：
   - 如果分支 PR 已 `CLOSED` 或 `MERGED`，本轮不要复用旧分支实现。
   - 从 `origin/main` 创建新分支，并作为新 attempt 重新进入执行流程。
5. 对 `Todo` ticket，启动顺序必须严格为：
   - `update_issue(..., state: "In Progress")`
   - 查找或创建 `## Codex 工作台` bootstrap 评论
   - 再开始分析、计划和实现
6. 如果状态和 issue 内容不一致，先在 workpad 简要记录，再走最安全流程。

## Step 1：开始或继续执行

1. 查找或创建单一持久 scratchpad 评论：
   - 搜索现有评论中的 marker header：优先 `## Codex 工作台`，兼容旧评论 `## Codex Workpad`。
   - 忽略已 resolved 评论，只复用活跃/未 resolved 评论。
   - 找到则复用，不创建新 workpad 评论。
   - 找不到则创建一个 workpad 评论，后续所有进度都更新这个评论。
   - 记录 workpad comment ID，只向这个 ID 写进度。
2. 如果从 `Todo` 进入，本步骤开始前 issue 应已是 `In Progress`。
3. 立即同步 workpad：
   - 勾选已经完成的项。
   - 扩展或修正计划，使其覆盖当前 scope。
   - 确认 `验收标准` 和 `验证` 与任务仍匹配。
4. 在 workpad 写入或更新层级计划；如果本轮存在复杂失败处理、权限失败、跨多次续作、验证缺口或需要完整排障记录，必须创建或更新 `docs/plans/active/` 本地计划，并在 workpad 写明 `详情位置`。
5. workpad 顶部必须包含一个紧凑环境戳代码块：
   - 格式：`host:path@shortSha`
   - 示例：`devbox-01:/home/dev-user/code/symphony-workspaces/HDX-32@7bdde33bc`
   - 不要包含 Linear 已能推导的 metadata，例如 issue ID、状态、分支、PR link。
6. 在同一评论中加入明确的验收标准、TODO checklist、`详情位置` 和最近检查戳。
   - 如果涉及用户可见变化，验收标准必须包含端到端用户路径。
   - 如果触及 App/Web/后台行为，加入对应运行或交互路径检查。
   - 如果 ticket 描述/评论包含 `Validation`、`Test Plan` 或 `Testing`，把它们转写到 workpad 的 `验收标准` 和 `验证`，作为必选 checkbox；清单描述用中文，原始命令、字段名和错误输出保留原文。
7. 对计划做一次 principal-style self-review，并把修正写回 workpad。
8. 实现前捕获具体复现信号：workpad 只写中文摘要和本地计划路径；完整命令、失败输出摘要、重试路径、提权结果、剩余风险和下一步 unblock 条件写入本地计划。
9. 代码编辑前同步最新 `origin/main`，并在 workpad `备注` 写入同步证据：
   - 合入来源
   - 结果：`clean` 或 `conflicts resolved`
   - 同步后的 `HEAD` short SHA
   - 如果普通权限已在同一 workspace 失败过，直接按权限失败重试预算走提权路径，并在本地计划引用历史失败。
10. 压缩上下文后进入执行。

## PR feedback sweep protocol

当准备移动到 `Human Review` 前必须执行完整 sweep；ticket 已有关联 PR 时，只有 PR head SHA 变化、出现新的 PR comment/review/check 更新时间，或当前 workpad/本地计划没有最近 sweep 证据时，才执行完整 sweep。其他续作只做轻量状态检查并引用最近 sweep 结果。

1. 从 issue link/attachment 找到 PR number。
2. 收集所有反馈渠道：
   - 顶层 PR comments：`gh pr view --comments`
   - inline review comments：`gh api repos/<owner>/<repo>/pulls/<pr>/comments`
   - review summaries/states：`gh pr view --json reviews`
3. 每条 actionable reviewer comment 都视为阻塞，直到满足其一：
   - 已通过代码、测试或文档更新解决。
   - 已在对应 thread 回复明确、有依据的 pushback。
4. 把每个反馈项和处理状态写入 workpad 计划/checklist。
5. 因反馈产生改动后重新运行验证并推送更新；推送前必须确认目标分支、工作树状态、验证结果和敏感信息检查。
6. 重复扫描，直到没有未处理 actionable comments。
7. 如果仓库没有 CI checks，记录一次 `no checks reported` 即可；除非 PR head SHA 或 checks 状态发生变化，不要在续作中重复轮询 `gh pr checks`。

## Blocked-access escape hatch

仅在缺少必需工具、认证或权限，且无法在会话内解决时使用。

- GitHub 不是默认 blocker。必须先尝试 fallback：其他 remote/auth 模式、继续本地验证和可交接流程。
- GitHub access/auth 不可用时，不要直接移动到 `Human Review`，除非所有 fallback 已尝试并写入 workpad。
- 非 GitHub 的必需工具缺失，或必需非 GitHub 认证不可用时，可移动到 `Human Review`，并在 workpad 写简短 blocker brief：
  - 缺什么。
  - 为什么阻塞必需验收或验证。
  - 人类需要做的精确 unblock 动作。
- brief 要短、具体、可执行；不要在 workpad 之外额外发顶层评论。

## Step 2：执行阶段

1. 确认当前 repo 状态：branch、`git status`、`HEAD`，并确认 kickoff pull sync 已记录。
2. 如果 issue 仍是 `Todo`，先改为 `In Progress`；否则保持当前状态。
3. 读取现有 workpad，把它当作活跃执行 checklist。
   - 当 scope、风险、验证方式或实际任务变化时，及时编辑 workpad。
   - 如果 workpad 指向本地计划，优先读取本地计划恢复完整排障上下文。
4. 按层级 TODO 实现，并持续保持 workpad 最新：
   - 勾选完成项。
   - 新发现事项加入合适位置。
   - 保持父子结构。
   - 每个有意义里程碑后更新摘要：复现完成、代码改动完成、验证运行、反馈处理等；完整细节写入本地计划。
   - 不要让已完成工作在计划中保持未勾选。
5. 执行 scope 所需验证：
   - 必须执行 ticket 提供的 `Validation` / `Test Plan` / `Testing`。
   - 优先给出直接证明改动行为的目标证明。
   - 可临时做本地验证改动来验证假设，但必须在提交前还原。
   - 临时验证步骤和结果必须用中文摘要写入 workpad 的 `验证` 或 `备注`；完整命令、路径、日志和错误输出写入本地计划。
6. 重新检查所有验收标准并补齐缺口。
7. 每次尝试 `git push` 前，必须运行 scope 所需验证并确认通过；如果失败，先修复并重跑。
8. 如果创建 PR：
   - 将 PR URL 附加到 Linear issue，优先用 attachment/link；不可用时才写入 workpad。
   - 确保 GitHub PR 带有 `symphony` label。
9. 将最新 `origin/main` 合入当前分支，解决冲突并重跑检查。
10. 更新 workpad 最终 checklist 和验证记录：
   - 勾选已完成的 `计划` / `验收标准` / `验证`。
   - 在同一 workpad 写最终交接备注：提交 + 验证摘要 + 本地计划路径。
   - 不要在 workpad 里重复 PR URL，PR 关系应通过 issue attachment/link 表达。
   - 如有不清楚的地方，在底部加入短小 `### 疑问`。
   - 不发布额外完成摘要评论。
11. 移动到 `Human Review` 前：
   - 如果有 PR Manual QA Plan，读取并用它加强 UI/runtime 验证。
   - 运行完整 PR feedback sweep。
   - 确认 PR checks 在最新提交后全绿。
   - 确认所有 ticket-provided 验证项已在 workpad 标记完成。
   - 重复 check-address-verify，直到无未处理评论且 checks 通过。
   - 刷新 workpad，确保 `计划`、`验收标准`、`验证` 与真实完成状态一致。
12. 只有完成以上步骤后，才把 issue 移动到 `Human Review`。
13. 例外：如果按 blocked-access escape hatch 被必要非 GitHub 工具或认证阻塞，可移动到 `Human Review`，并写清 blocker brief 和 unblock 动作。

## Step 3：Human Review 与合并处理

1. 当 issue 在 `Human Review`，不要编码或修改 ticket 内容。
2. 根据需要轻量轮询更新，只检查 Linear 状态、PR head SHA、review/comment/check 更新时间；只有发现新活动时才执行完整 PR feedback sweep。
3. 如果 review feedback 要求修改，把 issue 移动到 `Rework` 并执行返工流程。
4. 如果批准，由人类把 issue 移动到 `Merging`。
5. issue 在 `Merging` 时，打开并遵循 `.codex/skills/land/SKILL.md`，循环执行 `land` flow 直到 PR merged。不要直接调用 `gh pr merge`。
6. merge 完成后，把 issue 移动到 `Done`。

## Step 4：Rework 处理

1. 把 `Rework` 当作完整方案重置，不是小修小补。
2. 重读完整 issue body 和所有人类评论，明确这次 attempt 会有什么不同。
3. 关闭当前 issue 绑定的旧 PR。
4. 移除当前 issue 的旧 `## Codex 工作台` / `## Codex Workpad` 评论。
5. 从 `origin/main` 创建新分支。
6. 从正常 kickoff flow 重新开始：
   - 如果当前 issue 是 `Todo`，移动到 `In Progress`；否则保持状态。
   - 创建新的 `## Codex 工作台` bootstrap 评论。
   - 建立新计划/checklist 并端到端执行。

## HDX 仓库入口

开始任何实现前，必须按顺序阅读：

- `AGENTS.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`
- `docs/GIT.md`
- `docs/adr/0001-harness-engineering-constraints.md`

根据任务涉及范围继续阅读：

- 后端：`docs/adr/0002-backend-java-spring-cloud-alibaba-architecture.md`、`services/backend/README.md`
- Web：`docs/adr/0003-web-nuxt-architecture.md`、`apps/web/README.md`
- App / desktop：`docs/ARCHITECTURE.md`、`apps/mobile/README.md`、`apps/desktop/README.md`
- 计划和技术债：`docs/plans/README.md`、`docs/plans/tech-debt-tracker.md`

使用 PowerShell 读取项目文档时，`Get-Content` 必须显式加 `-Encoding UTF8`。

## HDX 工程约束

- 不改变已经由 ADR 固定的技术基线；引入或调整框架、运行时、包管理器、数据库、消息队列、状态管理、UI 组件库或跨端方案前，必须新增 ADR。
- 后端第一阶段已绑定 Java 25（GraalVM）、Maven 3.8.8、Spring Boot 4.x、Spring Cloud Alibaba 2025.1.x。
- Web 第一阶段已绑定 Nuxt 4.x、Nuxt UI 4.x、`@nuxtjs/i18n`、Pinia、Zod 与 pnpm。
- App 当前阶段仍不绑定框架；不要擅自固定 App 技术栈。
- 后台、Web、App 与共享能力之间的依赖方向必须清楚、单向、可检查。
- Web 浏览器代码不得直接访问后端地址；浏览器只能调用 Nuxt server 暴露的 `/api/hdx/v1/**`。
- 所有业务输入、外部 API、配置、环境变量、存储读写结果和跨端通信，都必须在边界处进行类型化解析或显式校验。
- 不复制粘贴临时工具函数到多个端；稳定共性能力进入共享层，或在文档中说明暂不共享的原因。
- 重要设计、取舍、缺口和临时债务必须沉淀到 `docs/`，不能只留在聊天记录、workpad 或个人记忆里。
- 发现文档与代码不一致时，把不一致当作缺陷处理：要么修正文档，要么修正代码。
- 不提交密钥、令牌、证书、真实用户数据或敏感日志。

## HDX 计划要求

- 小改动可以直接实现。
- 跨端、跨模块、会影响架构边界或技术选择的改动，需要先在 `docs/plans/active/` 新增或更新计划。
- 需要调整长期技术决策时，先新增或更新 `docs/adr/`，说明背景、决策、备选方案、影响范围、验证方式和回滚条件。
- 计划文件必须写明范围、非目标、步骤、验证方式、回滚方式和剩余风险。
- 如果约束阻碍实现，不绕过约束；先更新设计记录，说明为什么需要调整。

## HDX 常用验证

根据变更范围选择最小充分验证，并把实际执行结果写入 workpad。

根仓库文档或约束变更：

```powershell
git status --short
```

后端变更，在 `services/backend/` 下执行：

```powershell
$env:JAVA_HOME = 'D:\JetBrains\.jdks\graalvm-jdk-25.0.3+9.1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' validate
& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' test
```

涉及 Spring AOT、RuntimeHints、Hibernate enhance、native metadata 或启动器行为时，还要按 `services/backend/README.md` 执行相称的 AOT/native 验证。

Web 变更，在 `apps/web/` 下执行：

```powershell
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build
```

如果验证因环境、凭证、网络或工具链缺失而无法执行，必须记录具体命令、失败输出摘要、影响判断和剩余风险。

## Git 与提交

- Git 写操作必须串行执行。
- 提交信息使用中文，并使用约定式前缀：`功能：`、`修复：`、`重构：`、`杂项：`。
- 每个提交只包含一个逻辑单元。
- 根仓库和子模块仓库分开提交；子模块内改动应先在对应子仓库提交，再视需要单独提交根仓库子模块指针更新。
- 流程需要发布分支、更新 PR 或推进状态时可以执行 `git push`；推送前必须确认目标 remote、目标分支、工作树状态、相关验证结果和敏感信息检查。
- 如果本轮产生代码、文档或配置变更，完成相称验证后应提交本轮改动。
- 如果因为已有脏工作树、验证失败、权限限制或用户指令而无法提交，必须在 workpad 和最终交接中说明未提交文件、原因、已验证内容和剩余风险。

## Human Review 前完成标准

- Step 1/2 checklist 已完整完成，并准确反映在单一 workpad 评论中。
- 验收标准和 ticket-provided 验证项全部完成。
- 最新提交对应的验证/tests 为绿色。
- PR feedback sweep 完成且没有未处理 actionable comments。
- PR checks 绿色，分支已推送，PR 已链接到 issue。
- PR metadata 完整，包括 `symphony` label。
- 如果触及 App/Web 运行行为，已完成对应运行时验证和必要媒体/截图证据。

## Guardrails

- 如果分支 PR 已关闭或合并，不复用该分支或旧实现状态。
- 如果 issue 是 `Backlog`，不修改，等待人类移动到 `Todo`。
- 不编辑 issue body/description 记录计划或进度。
- 每个 issue 只使用一个持久 workpad 评论：优先使用 `## Codex 工作台`；继续兼容旧评论 `## Codex Workpad`。
- 如果 comment editing 不可用，使用 update script；只有 MCP 编辑和脚本编辑都不可用时，才报告阻塞。
- 临时 proof edits 只能用于本地验证，提交前必须还原。
- 超出范围的改进另建 Backlog issue，不扩大当前 scope。
- 不满足 Human Review 前完成标准时，不要移动到 `Human Review`。
- 在 `Human Review` 中不要做改动，只等待和轮询。
- 如果状态是终态 `Done`，不做任何事并关闭。
- Linear 文本保持简洁、具体、面向 reviewer。
- 如果被阻塞且还没有 workpad，创建一个 blocker comment，说明 blocker、影响和 unblock 动作。

## Workpad 模板

使用这个结构作为持久 workpad 评论，并在执行全过程原地更新。标题和正文默认中文，命令、路径、协议字段、日志和错误输出可以保留原文；完整排障细节写入 `详情位置` 指向的本地计划：

````md
## Codex 工作台

```text
host:path@shortSha
```

### 详情位置

- 本地计划：`docs/plans/active/<ticket>.md`
- 入口文档已读：`HEAD@shortSha`
- 最近检查：`YYYY-MM-DDTHH:mm:ssZ`，无新 Linear/PR 活动

### 计划

- [ ] 1. 父任务
  - [ ] 1.1 子任务
  - [ ] 1.2 子任务
- [ ] 2. 父任务

### 验收标准

- [ ] 验收项 1
- [ ] 验收项 2

### 验证

- [ ] 目标测试：``

### 备注

- 待补充

### 疑问

- 暂无
````
