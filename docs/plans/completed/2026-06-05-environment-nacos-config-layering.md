# 环境配置与 Nacos 分层

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户要求“按非密钥配置放 Nacos 继续实现”
- 创建时间：2026-06-05
- 最后更新：2026-06-05

## 目标

把 HDX 环境配置分层落到仓库事实源：本地开发使用 `.env.local` 统一管理；后端服务端部署通过 Nacos 管理非密钥配置；密码、令牌、证书和 Nacos 启动凭据仍通过环境变量或部署 Secret 注入。

## 非目标

- 本轮不搭建真实 Nacos 服务。
- 本轮不把密钥托管到 Nacos。
- 本轮不改 `backend-all-in-one` 的本地配置来源。
- 本轮不推进认证权限模型细节。

## repo 内范围

- `.env.example`
- `.env.symphony.example`
- `docs/ENVIRONMENT.md`
- `docs/ARCHITECTURE.md`
- `docs/config/nacos/`
- `scripts/load-env.ps1`
- `services/backend/backend-core-service/src/main/resources/application-service.yml`
- `services/backend/backend-gateway/src/main/resources/application-service.yml`
- `services/backend/README.md`

## 本地任务清单

- [x] 建立本地计划并记录配置分层边界。
- [x] 调整后端 service profile，让 Nacos 承载非密钥配置，环境变量承载启动项和密钥。
- [x] 新增 Nacos Data ID 示例，明确不得放入密钥。
- [x] 更新 `.env.example`、`.env.symphony.example`、`docs/ENVIRONMENT.md` 和后端 README。
- [x] 执行配置与文档验证。
- [x] 提交并推送子模块与根仓库。

## 验收标准

- 后端 service profile 使用 `spring.config.import` 从 Nacos 导入配置，且仓库示例能说明 Data ID、Group、Namespace 的来源。
- 数据库密码、Nacos 登录密码、API Key、令牌和证书不出现在 Nacos 示例或提交内容中。
- 本地 `.env.local` 仍可作为 Codex Desktop、Symphony、手动 PowerShell 的统一配置入口。
- 后续智能体能从本文档和 `docs/ENVIRONMENT.md` 判断哪些配置该放 Nacos，哪些必须走 env/Secret。

## 验证方式

- `.\scripts\load-env.ps1 -Path .env.example -ValidateOnly`
- `git diff --check`
- `mvn validate`

## 风险与阻塞

- 本轮不连接真实 Nacos，因此只能验证配置结构和 Maven 基础校验，不能确认 Nacos 服务端 Data ID 已实际存在。
- `service` profile 如果没有可用 Nacos 配置和必要 Secret，启动会失败；这是部署前置配置缺失，不作为本轮缺陷处理。

## 状态记录

- 2026-06-05：创建计划，当前状态为“进行中”。
- 2026-06-05：完成后端 service profile、Nacos 示例和环境文档初版调整；开始验证。
- 2026-06-05：完成配置、文档和后端测试验证；准备提交。
- 2026-06-05：已先提交并推送 `services/backend`，再由根仓库本提交记录环境文档、Nacos 示例、本地加载脚本和子模块指针；计划移动到 `completed/`。

## 验证结果

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\load-env.ps1 -Path .env.example -ValidateOnly`：通过，只输出变量名。
- `git diff --check`：通过。
- `git -C services/backend diff --check`：通过。
- `rg -n "HDX_POSTGRES_JDBC_URL|HDX_POSTGRES_USERNAME|HDX_JWT_ISSUER_URI" .env.example .env.symphony.example docs/ENVIRONMENT.md docs/ARCHITECTURE.md docs/config services/backend`：无结果，旧 service profile 环境变量入口已移除。
- `mvn validate`：通过。
- 使用 Java 25 执行 `mvn test`：通过，测试 2 个；保留 Jansi、Unsafe、Mockito/Byte Buddy 动态 agent 的 JDK 未来兼容 warning。
- 在补充 service profile 空占位后再次执行 Java 25 `mvn test`：通过，测试 2 个；warning 同上。

## 剩余风险

- 本轮未连接真实 Nacos，不能证明目标环境已创建 Data ID；部署前仍需在 Nacos 中按 `docs/config/nacos/` 建配置。
- service profile 改为要求 Nacos Data ID 和 `HDX_POSTGRES_PASSWORD` 存在，缺失时会快速失败。
- JDK 未来兼容 warning 未在本轮处理，不影响当前测试通过。

## 相关 commit

- `9703d0f 杂项：按 Nacos 分层服务端配置`（`services/backend`）
- 根仓库本提交：`杂项：统一环境配置与 Nacos 分层`
