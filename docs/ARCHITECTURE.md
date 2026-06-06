# 暂定架构

本项目整体框架仍在逐步确定中。后端架构已由 `docs/adr/0002-backend-java-spring-cloud-alibaba-architecture.md` 确定第一阶段方案。

## 目标形态

HDX 暂定由以下部分组成：

- `services/backend/`：后台服务端 Maven 多模块工程，采用 Java 25（GraalVM）、Spring Boot 4.x、Spring Cloud Alibaba 2025.1.x。
- `apps/web/`：Web 端 Nuxt 应用，采用 Nuxt 4.x、Nuxt UI 4.x、`@nuxtjs/i18n`、Pinia、Zod 与 pnpm。
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

## Web 第一阶段架构

Web 工程位于 `apps/web/`，当前不把仓库根目录升级为 pnpm workspace。

Web 第一阶段采用：

- Nuxt 4.x 默认 SSR 形态。
- Nuxt UI 4.x 作为 UI 组件和主题基础。
- `@nuxtjs/i18n` 作为国际化方案，默认 `zh-CN`，备用 `en-US`。
- i18n 使用应用内部状态切换，URL 不随语言变化，不使用域名或路径前缀切换语言。
- Pinia 作为端侧状态管理，按领域拆分 store。
- Zod 作为 Web 边界数据解析与显式校验工具。
- pnpm 作为 `apps/web/` 内包管理器。

Web 浏览器代码不直接访问后端地址。浏览器调用 Nuxt server 暴露的 BFF/proxy 路径，例如 `/api/hdx/v1/**`；Nuxt server 再调用后端公开 REST API，例如 `/api/v1/**`。后端地址、本机 all-in-one 令牌和其他敏感配置只能放在 Nuxt server 私有 `runtimeConfig` 中。

## 待决策事项

以下事项尚未决策，不能在没有 ADR 的情况下擅自固定：

- App 技术栈。
- 缓存、对象存储和队列。
- 部署、CI、发布和环境管理方式。

## 后端第一阶段架构

后端 Maven 工程位于 `services/backend/`，不把仓库根目录改成 Maven 主工程。

后端第一阶段包含：

- `backend-contract`：后端共享 API 契约与 DTO。
- `backend-core`：核心业务能力、JPA 实体、Repository、服务和 REST 控制器。
- `backend-core-service`：核心业务微服务启动器。
- `backend-auth-service`：认证中心微服务启动器，作为 JWT/OAuth2 issuer，使用 PostgreSQL `auth` schema。
- `backend-gateway`：API 网关微服务启动器。
- `backend-all-in-one`：desktop 集成用本机后端启动器。

运行拓扑：

- 服务端微服务部署：`backend-gateway` 对外开放 REST API，转发到 `backend-auth-service` 和 `backend-core-service`；`backend-auth-service` 使用 Spring Security Authorization Server 签发 token，`backend-gateway` 与 `backend-core-service` 作为 Resource Server 校验 token；服务端使用 Nacos Discovery、Nacos Config、Sentinel、OpenFeign 和 PostgreSQL。
- desktop all-in-one：`backend-all-in-one` 复用 `backend-core`，绑定 `127.0.0.1`，使用 H2，并通过随机本机令牌保护 HTTP 请求。

后端配置规则：

- Spring Cloud Alibaba 2025.1.x 不使用 bootstrap 配置，Nacos 配置通过 `spring.config.import` 接入。
- 服务端 profile 使用外部数据库和 Nacos；非密钥配置放 Nacos，数据库密码、Nacos 登录凭据、API Key、证书和令牌通过环境变量或部署 Secret 注入。
- all-in-one 使用本地配置文件和本地嵌入式数据库。
- 数据库迁移使用 Flyway。核心业务迁移脚本由 `services/backend/backend-core/src/main/resources/db/migration/` 提供；认证中心迁移脚本由 `services/backend/backend-auth-service/src/main/resources/db/migration/` 提供，并只面向服务端 PostgreSQL `auth` schema。PostgreSQL 是服务端数据库事实源，H2 用于 desktop all-in-one、local 和测试；运行时 Hibernate 只做 `ddl-auto: validate` 校验。

后端 native 规则：

- 正式 native 构建入口使用 `mvn -Pnative package`，由 Maven 生命周期先执行 Spring AOT，再执行 GraalVM Native Build Tools。
- JPA 实体在 `backend-core` 中通过 Hibernate Maven 插件做构建期字节码增强；新增实体时必须纳入增强范围。
- Native Image metadata 优先依赖 Spring AOT 与官方 reachability metadata；项目内缺口只通过 Spring `RuntimeHints` 补齐。
