---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: hdx-44dde4471027
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Canceled
    - Cancelled
    - Closed
    - Duplicate
polling:
  interval_ms: 30000
workspace:
  root: D:\Project\symphony-workspaces\hdx
hooks:
  timeout_ms: 300000
  after_create: |
    if [ -d .git ]; then
      exit 0
    fi
    git clone --recurse-submodules https://github.com/xxldm/hdx.git .
    git submodule update --init --recursive || {
      git clone https://github.com/xxldm/hdx-backend.git services/backend
      git clone https://github.com/xxldm/hdx-web.git apps/web
      git clone https://github.com/xxldm/hdx-desktop.git apps/desktop
    }
agent:
  max_concurrent_agents: 1
  max_turns: 10
  max_retry_backoff_ms: 300000
codex:
  command: PATH="/e/soft/codex-cli/node_modules/.bin:$PATH" codex app-server
  turn_timeout_ms: 3600000
  read_timeout_ms: 30000
  stall_timeout_ms: 300000
server:
  port: 4321
observability:
  dashboard_enabled: true
  refresh_ms: 1000
  render_interval_ms: 16
---

你正在处理 Linear issue {{ issue.identifier }}：{{ issue.title }}。

## Symphony 运行纪律

- 本轮由 Symphony 调度，工作目录是当前 issue 的隔离 workspace。
- 开始前先用 `linear_graphql` 读取 issue 当前状态、描述、标签、评论和关联信息。
- 如果 issue 已被标记为阻塞、被依赖项阻塞、需求明显缺失，或状态不再属于 `Todo` / `In Progress`，不要改代码；在 Linear 留下清楚说明并停止。
- 如果 issue 适合执行，先把 Linear issue 状态更新为 `In Progress`。
- 为本次运行创建或复用一个 Linear 评论作为 workpad。后续进度、计划、验证结果、失败原因和交接信息都更新到这个评论，避免散落多个评论。
- 需要用户决策时，在 workpad 中写明问题、可选方案、推荐方案和阻塞范围，然后停止。

## 仓库入口

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

仓库内项目文档默认使用中文编写。使用 PowerShell 读取项目文档时，`Get-Content` 必须显式加 `-Encoding UTF8`。

## HDX 工程约束

- 不改变已经由 ADR 固定的技术基线；引入或调整框架、运行时、包管理器、数据库、消息队列、状态管理、UI 组件库或跨端方案前，必须新增 ADR。
- App 当前阶段仍不绑定框架；不要擅自固定 App 技术栈。
- 后台、Web、App 与共享能力之间的依赖方向必须清楚、单向、可检查。
- Web 浏览器代码不得直接访问后端地址；浏览器只能调用 Nuxt server 暴露的 `/api/hdx/v1/**`。
- 所有业务输入、外部 API、配置、环境变量、存储读写结果和跨端通信，都必须在边界处进行类型化解析或显式校验。
- 不复制粘贴临时工具函数到多个端；稳定共性能力进入共享层，或在文档中说明暂不共享的原因。
- 重要设计、取舍、缺口和临时债务必须沉淀到 `docs/`，不能只留在聊天记录、workpad 或个人记忆里。
- 发现文档与代码不一致时，把不一致当作缺陷处理：要么修正文档，要么修正代码。

## 计划要求

- 小改动可以直接实现。
- 跨端、跨模块、会影响架构边界或技术选择的改动，需要先在 `docs/plans/active/` 新增或更新计划。
- 需要调整长期技术决策时，先新增或更新 `docs/adr/`，说明背景、决策、备选方案、影响范围、验证方式和回滚条件。

## 实现方式

- 先检查工作树状态，识别已有未提交改动；不得覆盖、回滚或顺手提交不是本轮产生的改动。
- 优先使用仓库既有模式、目录边界和文档事实源。
- 新增行为必须带有相称验证。没有可运行测试时，必须记录替代验证步骤和剩余风险。
- 修复缺陷时，先复现再修复；无法复现必须在 workpad 和最终交接中说明原因。
- 代码、文档、测试和配置都属于项目产物，必须纳入质量门禁。

## 常用验证

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

## Git 交接

- 提交信息使用中文，并使用约定式前缀：`功能：`、`修复：`、`重构：`、`杂项：`。
- 每个提交只包含一个逻辑单元。
- 根仓库和子模块仓库分开提交；子模块内改动应先在对应子仓库提交，再视需要单独提交根仓库子模块指针更新。
- Git 写操作必须串行执行。
- 严禁未经用户明确批准执行 `git push`。
- 完成后在 workpad 中写明：变更范围、提交哈希、验证命令与结果、未验证内容、剩余风险、需要人工处理的事项。
- 如果任务完成，把 Linear issue 状态更新为 `Done`。如果未完成，保持或更新为适当的非终态，并在 workpad 中写清楚下一步。
