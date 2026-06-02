# 项目约束

本文档是 HDX 工具箱的约束事实源。约束灵感来自 OpenAI 关于 Harness Engineering 的工程实践：让人类明确意图、设计环境和反馈回路，让智能体在严格边界内执行。

参考资料：[OpenAI：工程技术：在智能体优先的世界中利用 Codex](https://openai.com/zh-Hans-CN/index/harness-engineering/)

## 1. 文档约束

- 仓库内项目文档默认使用中文编写。
- 使用 PowerShell 读取项目文档时，`Get-Content` 必须显式加 `-Encoding UTF8`，避免中文内容在控制台中乱码。
- `AGENTS.md` 只做地图和硬规则，不写成长篇手册。
- 长期有效的知识必须放入 `docs/`，并通过索引或链接可发现。
- 临时计划、架构取舍、技术债务和验证缺口必须版本化记录。
- 需要计划的工作必须把计划落实到 `docs/plans/` 下的本地文件，不能只保留在聊天记录中。
- Symphony、Linear 等外部任务系统可以作为主计划来源，但不能替代 repo-local handoff；本地计划不机械复制完整产品/项目管理步骤，只记录仓库实现状态、验证缺口、技术债、风险、决策和 commit 关联。
- 当外部任务不可访问、内容不足以恢复仓库状态，或工作跨模块、跨多次提交、跨多天、涉及架构边界、ADR、技术选型、安全、高风险行为、验证缺口、技术债、回滚条件、复杂失败处理，或用户明确要求时，必须在 `docs/plans/active/` 创建或更新本地计划。
- 文档如果不再反映真实代码行为，视为缺陷。

## 2. 框架与选型约束

- 后端第一阶段已绑定 Java 25（GraalVM）、Maven 3.8.8、Spring Boot 4.x、Spring Cloud Alibaba 2025.1.x，详见 `docs/adr/0002-backend-java-spring-cloud-alibaba-architecture.md`。
- Web 第一阶段已绑定 Nuxt 4.x、Nuxt UI 4.x、`@nuxtjs/i18n`、Pinia、Zod 与 pnpm，详见 `docs/adr/0003-web-nuxt-architecture.md`。
- App 当前阶段仍不绑定框架。
- 引入或调整框架、运行时、包管理器、数据库、消息队列、状态管理、UI 组件库或跨端方案前，必须新增 ADR。
- ADR 至少说明：背景、决策、备选方案、影响范围、验证方式、回滚条件。
- 默认选择可读、稳定、生态成熟、容易被工具和智能体检查的技术。

## 3. 架构边界约束

- 后台、Web、App、共享能力必须拥有清晰职责。
- 跨端共享逻辑进入共享层；端侧 UI、平台 API 和运行时适配留在各自端内。
- 依赖方向必须单向、可检查，不允许循环依赖。
- 禁止为了快速实现让 Web 或 App 直接耦合后台内部实现；必须通过公开契约或 SDK。
- 禁止让后台依赖 Web 或 App 的实现细节。

## 4. 数据边界约束

所有不可信或跨边界数据必须在边界处解析或校验，包括：

- HTTP 请求与响应。
- 外部 API 返回值。
- 用户输入。
- 环境变量和配置文件。
- 数据库、缓存、队列、文件系统读写结果。
- Web 与 App 调用后台的协议数据。
- 后台推送到前端或 App 的事件数据。

实现方式不预设具体库，但结果必须具备：

- 明确的数据形状。
- 失败路径。
- 可测试样例。
- 调用方可理解的错误信息。

## 5. 质量门禁约束

- 新增行为必须有对应测试、脚本验证或手工复现步骤。
- 能自动验证的内容不依赖人工记忆。
- 复杂改动应包含最小可复现用例。
- 修复缺陷时，先复现再修复；无法复现必须记录原因。
- 生成代码、生成文档和配置也属于项目产物，必须进入质量门禁。
- 后端 GraalVM Native Image 的构建参数属于质量门禁的一部分；调整 `native-maven-plugin`、`--exclude-config`、Spring AOT、`RuntimeHints`、Hibernate enhance 或类初始化参数后，必须重新验证 `backend-core-service`、`backend-gateway` 与 `backend-all-in-one` 的 native 编译和健康检查。
- 后端 native metadata 优先顺序为：Spring Boot/Spring Framework AOT 内置支持、GraalVM 官方 Reachability Metadata Repository、项目内 Spring `RuntimeHints`。除非用于短期诊断，项目源码不直接维护手写 `reflect-config.json`、`resource-config.json` 等旧式 native metadata。
- Hibernate enhance 只能视为构建期实体字节码增强能力，用于减少 Hibernate 在 native closed world 环境中的运行期动态增强风险；它不是 RuntimeHints 或官方 reachability metadata 的替代品。

## 6. 可观测性约束

- 后台服务必须为关键路径预留结构化日志、指标和追踪接入点。
- Web 与 App 必须为关键用户路径预留错误上报、性能指标和版本信息。
- 日志不得泄露密钥、令牌、个人敏感信息或完整凭证。
- 错误信息要能帮助定位边界、模块和失败类型。

## 7. 安全约束

- 密钥、令牌、证书和真实用户数据不得提交到仓库。
- 权限、认证、鉴权、支付、文件上传、远程执行等高风险能力必须先有设计文档。
- 所有外部输入默认不可信。
- 错误处理不得把内部堆栈、数据库结构或密钥上下文暴露给终端用户。

## 8. 智能体可读性约束

- 代码、文档、测试和配置应让后续智能体能从仓库本身恢复上下文。
- 不把关键知识只放在聊天记录、外部文档或个人记忆中。
- 外部任务链接或编号可以作为追踪入口，但关键实现交接信息必须沉淀到仓库内计划、ADR、质量记录或相关文档。
- 命名应稳定、直观，避免只有当前作者理解的缩写。
- 目录职责变化必须更新 `docs/ARCHITECTURE.md`。
- 重复出现的人工审查意见，应转化为文档规则、测试或 lint。

## 9. 技术债约束

- 允许有意留下临时实现，但必须记录原因、影响、移除条件和负责人或触发条件。
- 技术债优先小步清理，不等待集中重构。
- 如果某个坏模式重复出现，优先把约束编码进工具、测试或文档，而不是只在评审中提醒。
