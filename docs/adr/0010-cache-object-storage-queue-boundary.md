# ADR 0010：缓存、对象存储与队列采用可替换基础设施边界

- 日期：2026-06-08
- 状态：已接受

## 背景

HDX 需要同时支持服务端/云端部署与 Desktop Full 本机模式。前者可以依赖 PostgreSQL、Redis、对象存储和消息队列等基础设施；后者应保持轻量，不能把完整服务端运维套件塞进客户端安装包。

项目已确认：

- Redis 已用于服务端认证会话撤销能力，公开策略见 `docs/adr/0005-auth-revocation-redis.md`，具体实现细节只在后端私有文档维护。
- Desktop Full 本机模式不运行认证中心，使用固定本机身份与本机 token，不需要登录验证码、登录限流或 JWT 撤销。
- 对象存储代码层只使用 S3-compatible 标准核心能力，默认本地/私有化候选暂定 RustFS，后续可切云端 OSS/COS/OBS/S3。
- 队列需要服务端可部署、云端可托管、Desktop Full 本机模式可降级，避免业务代码直接绑定某个队列 SDK。

## 决策

### 对象存储

HDX 对象存储统一通过 `ObjectStoragePort` 之类的内部端口访问。实现层使用 S3-compatible API，第一阶段只允许使用核心子集：

- `PutObject`
- `GetObject`
- `DeleteObject`
- `HeadObject`
- `ListObjectsV2`
- multipart upload
- presigned upload/download URL
- range GET

默认本地/私有化候选暂定 **RustFS**。生产或云端部署可以切换到任意兼容 S3 核心子集的云对象存储，例如 OSS、COS、OBS 或 S3。切换时主要调整 endpoint、bucket、region、凭据和 path-style/virtual-hosted-style 配置，后端业务代码不随 provider 改写。

第一阶段禁止依赖 provider 专属能力，包括但不限于：

- bucket ACL 或 bucket policy 表达业务权限。
- 云厂商图片处理、转码、事件通知或工作流。
- object lock、versioning、跨区域复制、生命周期高级规则等高级能力。
- 云厂商专有 SDK 能力。

文件归属、业务权限、引用关系、审计信息、可见性和生命周期状态必须保存在 PostgreSQL/H2 的业务表中；对象存储只保存 blob。Web、Desktop 和 App 不持有对象存储 AK/SK，只能通过后端获取受控的 presigned URL 或后端代理结果。

### 队列

服务端/云端默认队列方案暂定 **RabbitMQ**。业务代码不直接散落 RabbitMQ API，而是通过 `MessageQueuePort`、领域事件发布器或应用服务端口访问队列能力。

服务端可靠投递采用：

- PostgreSQL transactional outbox 记录待发布消息。
- outbox publisher 投递 RabbitMQ。
- consumer 幂等消费消息。

第一阶段 RabbitMQ 只使用通用能力：

- durable exchange/queue
- routing key
- JSON message envelope，包含消息版本号、类型、业务 id、trace id 和发生时间。
- publisher confirm
- manual ack
- retry
- dead letter queue

第一阶段不依赖 RabbitMQ 插件。延迟任务不依赖 delayed-message plugin，优先使用数据库 `scheduled_at`、`next_retry_at` 等字段加 worker 扫描，到期后再投递或执行。

### Redis

Redis 是服务端部署基础设施。除 JWT 会话撤销外，后续可以按能力扩展到短期缓存、TTL store、验证码、限流、短期任务状态或分布式协调，但每一类用途都必须通过清晰端口或适配器进入业务代码。

Desktop Full 本机模式默认不启动 Redis，也不模拟服务端反滥用能力：

- 验证码默认禁用。
- 登录限流默认禁用。
- JWT 会话撤销默认 no-op，因为本地模式不跑认证中心。
- 服务端防机器人、防撞库、防分布式并发类能力默认不进入本地模式。

本地模式只保留数据安全和本机运行必要能力，例如文件大小/类型校验、导入导出校验、本机 token 保护、数据目录权限、任务失败重试和危险操作确认。

如果后续某个能力在服务端使用 Redis，本地模式按能力降级：

- 短期可丢缓存：内存或 Caffeine。
- 需要重启后保留的状态：H2 表。
- 单机锁：JVM 锁或 H2 锁表。
- 服务端反滥用：禁用或 no-op。

### Desktop Full 本机模式

Desktop Full 本机模式的默认基础设施边界为：

- H2：业务数据、outbox、任务状态。
- RustFS sidecar：需要本地附件/文件能力时作为 S3-compatible 对象存储，绑定 `127.0.0.1`，使用本地生成凭据和本地数据目录。
- local outbox worker：替代 RabbitMQ 执行本地异步任务。

Desktop Full 本机模式不内置 RabbitMQ，不内置 Redis。local outbox worker 只承诺单机语义，不承诺 RabbitMQ 的分布式路由、DLQ 运维生态或多实例协调能力。

## 影响

- 后续实现对象存储时，应先建立 `ObjectStoragePort` 和 S3-compatible adapter，不让业务代码直接依赖具体 OSS SDK。
- 后续实现队列时，应先建立 outbox 表、消息 envelope、publisher 和 consumer 幂等约束，再接 RabbitMQ。
- Desktop Full 本机后端后续文件能力可以启动 RustFS sidecar，但必须通过本机端口、随机/本地生成凭据和数据目录隔离。
- Desktop Full 本机后端后续异步任务通过本机 outbox + local worker 实现，不因服务端 RabbitMQ 决策而强制引入 RabbitMQ。
- Redis 后续扩展用途时，必须同步定义 Desktop Full 本机模式的 no-op、内存、本机数据库或 JVM 降级行为。
- 配置和环境文档后续需要为对象存储、RabbitMQ 和本地 RustFS sidecar 增加模板；真实密钥通过环境变量或部署 Secret 注入。

## 备选方案

- 直接绑定某个云厂商 OSS/COS/OBS：云能力完整，但会让私有化和云迁移成本变高。
- MinIO 作为默认本地对象存储：历史生态成熟，但当前开源维护和许可证风险不适合作为新默认。
- Garage 或 SeaweedFS 作为默认本地对象存储：均可作为 S3-compatible 备选，但当前先选择 RustFS 作为默认候选，避免让用户同时安装多个实现做验证。
- Ceph RGW 作为默认：适合已有企业级 Ceph 集群，不适合 HDX 默认轻量部署。
- Kafka 或 RocketMQ 作为默认队列：适合事件流、高吞吐或特定云生态，但首版异步任务、通知、导入导出等场景用 RabbitMQ 更轻。
- Redis Streams 作为主队列：能减少基础设施种类，但会把 Redis 从认证撤销/缓存扩展为主消息系统，可靠性、DLQ 和运维边界不如 RabbitMQ 清楚。
- Desktop Full 本机模式内置 Redis 与 RabbitMQ：运行时一致性更高，但安装包、端口、进程管理和排障复杂度过高，不符合本地模式轻量目标。

## 验证方式

本 ADR 阶段只固定基础设施边界，不引入运行时依赖。通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。

本 ADR 特有检查：

- RustFS、RabbitMQ、S3-compatible、outbox worker 和 Desktop Full 本机降级语义在相关文档中可发现。

后续实现阶段必须补充：

- 使用一个默认本地候选 RustFS 验证 S3 核心子集，不要求用户安装 Garage、SeaweedFS、Ceph 等全部候选。
- 对象存储 adapter 的边界解析、错误映射、presigned URL 过期和文件大小/类型限制测试。
- transactional outbox 与 RabbitMQ publisher confirm、consumer 幂等、retry 和 DLQ 测试。
- Desktop Full 本机 outbox + local worker 的任务成功、失败重试和重启恢复测试。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- RustFS 无法稳定满足 HDX 本地对象存储和 S3 核心子集需求。
- 目标部署环境无法提供 RabbitMQ 或兼容托管服务，且替代队列更符合项目成本。
- HDX 业务必须依赖云厂商对象存储专属能力，S3-compatible 核心子集无法覆盖。
- Desktop Full 本机模式必须与服务端保持同等分布式队列或 Redis 语义，无法接受本地降级。
- 用户明确要求改变本地/云端基础设施迁移目标。
