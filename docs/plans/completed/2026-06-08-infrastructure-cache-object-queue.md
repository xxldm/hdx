# 缓存、对象存储与队列基础设施边界

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成并归档
- 计划来源：HDX 后续事项总纲第 8 步，用户确认对象存储暂定 RustFS、代码层只用 S3 标准，并讨论 RabbitMQ、Redis 与 all-in-one 降级边界
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

确定 HDX 第一阶段缓存、对象存储和队列的基础设施边界：服务端/云端可以使用 Redis、S3-compatible 对象存储和 RabbitMQ；Desktop all-in-one 保持轻量，通过 RustFS sidecar、H2 outbox 和 local worker 降级。

## 非目标

- 本轮不引入 RustFS、RabbitMQ、Redis 新依赖或配置模板。
- 本轮不实现对象存储 adapter、上传下载接口、队列 outbox 表或 worker。
- 本轮不创建 Linux/Windows 本地 RustFS sidecar 启动脚本。
- 本轮不修改真实 Nacos Data ID、`.env.local` 或本地密钥。
- 本轮不做 RustFS、Garage、SeaweedFS、Ceph 全量安装对比。

## repo 内范围

- `docs/adr/0010-cache-object-storage-queue-boundary.md`
- `docs/ARCHITECTURE.md`
- `docs/CONSTRAINTS.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-infrastructure-cache-object-queue.md`

## 本地任务清单

- [x] 读取约束、架构、质量、Git、ADR 和计划规则。
- [x] 复核 Redis 撤销 ADR、Desktop all-in-one 边界和总纲状态。
- [x] 新增缓存、对象存储与队列基础设施边界 ADR。
- [x] 更新架构、约束、README 和总纲。
- [x] 运行文档验证。
- [x] 归档本计划并提交推送。

## 验收标准

- 对象存储明确为 S3-compatible 核心子集，默认本地候选 RustFS，后续可切云 OSS/COS/OBS/S3。
- 队列明确服务端/云端默认 RabbitMQ，业务代码通过端口和 outbox 模式隔离。
- Redis 明确是服务端基础设施；all-in-one 本地模式不启动 Redis，服务端反滥用能力默认禁用或 no-op。
- all-in-one 明确不内置 RabbitMQ，使用 H2 outbox + local worker。
- 相关文档不再把对象存储和队列写成完全未决策状态。

## 验证方式

- `rg -n "RustFS|RabbitMQ|S3-compatible|outbox|all-in-one.*Redis|对象存储和队列" README.md docs`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- 本轮只做架构边界，不验证 RustFS 或 RabbitMQ 运行。
- RustFS 作为默认本地候选仍需后续用真实进程验证 S3 核心子集。
- RabbitMQ、outbox publisher、consumer 幂等和 DLQ 需要后续实现阶段验证。
- all-in-one RustFS sidecar 的进程管理、端口分配、数据目录、凭据生成和升级迁移仍未设计。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：新增 ADR 0010，确认对象存储采用 S3-compatible 核心子集，默认本地候选 RustFS；服务端/云端队列默认 RabbitMQ；Redis 是服务端基础设施。
- 2026-06-08：确认 Desktop all-in-one 不内置 Redis/RabbitMQ；服务端反滥用能力默认禁用或 no-op；本地文件能力后续可用 RustFS sidecar，本地异步任务使用 H2 outbox + local worker。
- 2026-06-08：已同步 `docs/ARCHITECTURE.md`、`docs/CONSTRAINTS.md`、根 README 和后续事项总纲；当前状态改为“已完成并归档”。

## 验证结果

- 已执行 `rg -n "RustFS|RabbitMQ|S3-compatible|outbox|all-in-one.*Redis|对象存储和队列" README.md docs`：命中项集中在 ADR 0010、架构、约束、总纲和本计划；旧的“对象存储或队列未决策”历史记录已补充“后续第 8 步已由 ADR 0010 补齐基础设施边界”说明。
- 已执行 `git diff --check`：通过；仅保留 Git for Windows CRLF 提示。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- 本轮只固定基础设施边界，不验证 RustFS、RabbitMQ 或 local worker 真实运行。
- RustFS 作为默认本地候选仍需后续用真实进程验证 S3 核心子集、凭据、端口、数据目录和迁移策略。
- RabbitMQ、transactional outbox、publisher confirm、consumer 幂等、retry 和 DLQ 仍需后续实现和测试。
- all-in-one RustFS sidecar 的进程管理、端口分配、数据目录、凭据生成、升级迁移和卸载清理仍未设计。

## 相关 commit

- 本计划提交由 Git 历史体现，不在同一提交中回写自身 hash，避免递归提交。
