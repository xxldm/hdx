# ADR 0002：后端采用 Java 25 与 Spring Cloud Alibaba 架构

- 日期：2026-05-25
- 状态：已接受
- 修订：本文只保留公开主仓库可见的技术选型、必要模块/服务名和交付边界；后端内部调用链、运行拓扑、服务治理细节、native/AOT 参数和验证记录以 `services/backend/README.md` 与 `services/backend/docs/README.md` 为准。

## 背景

HDX 工具箱需要同时支持服务端部署和 desktop 集成。服务端形态需要对外开放 API、连接外部数据库，并具备微服务治理能力；desktop 集成形态需要作为 Desktop Full 本机后端运行，不开放外部 API，并使用本机数据存储。

## 决策

- 后端使用 Java 25（GraalVM）和 Maven 3.8.8。
- Maven 工程放在 `services/backend/` 内，不把仓库根目录改成 Maven 主工程。
- 后端框架采用 Spring Boot 4.x、Spring Cloud 2025.1.x、Spring Cloud Alibaba 2025.1.x。
- 第一阶段同时支持服务端部署入口和 Desktop Full 本机集成入口；模块名/服务名可以公开出现，具体职责拆分和调用关系只在后端私有文档维护。
- 服务端治理、配置中心、限流熔断、服务间调用和内部契约实现细节只在后端私有文档维护；公开主仓库只记录对外 API 和 release 交付边界。
- 对外 API 使用 REST + OpenAPI。
- 服务端数据库和本机数据库的具体适配以公开环境边界和后端私有文档为准。
- 数据访问普通业务默认采用 Spring Data JPA；自定义查询优先使用 JPA 查询能力，批量/报表、性能热点或框架 JDBC schema 例外可使用 JDBC/JdbcClient。
- 服务端 API 安全采用 JWT / OAuth2 Resource Server。
- Desktop Full 本机后端只服务本机 sidecar 场景，并使用本机边界内的令牌保护 HTTP 请求。
- 所有可执行产物都应支持 GraalVM Native Image。

## 影响范围

- `services/backend/` 成为后端 Maven 聚合工程。
- 后端新增模块和运行入口由后端私有仓库维护，公开主仓库只保留必要模块/服务名、交付边界和跨端契约入口。
- 后续数据库迁移、权限细节、服务拆分和 Native Image 优化应在后端私有文档中继续设计。

## 备选方案

- 模块化单体优先：实现更简单，但不符合本轮已确定的多微服务起步方向。
- 从一开始拆多个业务微服务：治理形态更完整，但业务域尚未稳定，初期拆分成本更高。
- Desktop Full 本机后端进程内调用：安全边界更窄，但当前选择本机 HTTP 以复用 API 契约。
- SQLite 作为本地库：更贴近桌面本地持久化，但具体本机数据库选型和验证以后端私有文档为准。

## 验证方式

- 后端内部 Maven、AOT、Native Image、服务端 profile 和健康检查验证命令以后端私有文档为准。
- 公开主仓库只验证 release manifest、OpenAPI/shared 契约、后端 native asset 禁止文件扫描和各端消费边界。

## 后续事项

- 后端构建环境、数据库迁移、认证权限和本机令牌细节在后端私有文档维护。
