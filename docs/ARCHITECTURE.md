# 暂定架构

本项目整体框架仍在逐步确定中。后端架构已由 `docs/adr/0002-backend-java-spring-cloud-alibaba-architecture.md` 确定第一阶段方案。

## 目标形态

HDX 暂定由以下部分组成：

- `services/backend/`：后台服务端 Maven 多模块工程，采用 Java 25（GraalVM）、Spring Boot 4.x、Spring Cloud Alibaba 2025.1.x。
- `apps/web/`：Web 端占位。
- `apps/mobile/`：App 端占位。
- `packages/shared/`：跨端共享契约、类型、工具和协议占位。
- `docs/`：项目事实源、计划、约束和决策记录。

## 依赖方向

允许的默认依赖方向：

- `apps/web/` 可以依赖 `packages/shared/`。
- `apps/mobile/` 可以依赖 `packages/shared/`。
- `services/backend/` 可以依赖 `packages/shared/`。
- `packages/shared/` 不依赖任何具体端。
- `docs/` 不参与运行时依赖，但必须反映真实架构。

禁止的默认依赖方向：

- `services/backend/` 依赖 `apps/web/` 或 `apps/mobile/`。
- `apps/web/` 与 `apps/mobile/` 互相依赖实现细节。
- 任意模块绕过 `packages/shared/` 复制共享契约。

## 分层原则

具体框架确定后，每个业务域应按稳定层次组织。推荐方向如下：

1. 契约与类型。
2. 配置与环境解析。
3. 数据访问或外部适配。
4. 业务服务。
5. 运行时入口。
6. 用户界面或交付接口。

依赖只能从更靠近交付面的层指向更基础的层，不能反向穿透。

## 边界契约

- 后台对外暴露的 API 必须有契约文档或可生成契约。
- Web 与 App 调用后台时，必须通过契约或 SDK，不读取后台内部模块。
- 跨端共享的错误码、协议字段、权限枚举和基础类型应归入共享层。
- 端侧私有展示模型不得污染后台领域模型。

## 待决策事项

以下事项尚未决策，不能在没有 ADR 的情况下擅自固定：

- Web 框架、构建工具和 UI 方案。
- App 技术栈。
- 缓存、对象存储和队列。
- 部署、CI、发布和环境管理方式。

## 后端第一阶段架构

后端 Maven 工程位于 `services/backend/`，不把仓库根目录改成 Maven 主工程。

后端第一阶段包含：

- `backend-contract`：后端共享 API 契约与 DTO。
- `backend-core`：核心业务能力、JPA 实体、Repository、服务和 REST 控制器。
- `backend-core-service`：核心业务微服务启动器。
- `backend-gateway`：API 网关微服务启动器。
- `backend-all-in-one`：desktop 集成用本机后端启动器。

运行拓扑：

- 服务端微服务部署：`backend-gateway` 对外开放 REST API，转发到 `backend-core-service`；使用 Nacos Discovery、Nacos Config、Sentinel、OpenFeign、PostgreSQL 和 JWT/OAuth2 Resource Server。
- desktop all-in-one：`backend-all-in-one` 复用 `backend-core`，绑定 `127.0.0.1`，使用 H2，并通过随机本机令牌保护 HTTP 请求。

后端配置规则：

- Spring Cloud Alibaba 2025.1.x 不使用 bootstrap 配置，Nacos 配置通过 `spring.config.import` 接入。
- 服务端 profile 使用外部数据库和 Nacos。
- all-in-one 使用本地配置文件和本地嵌入式数据库。
