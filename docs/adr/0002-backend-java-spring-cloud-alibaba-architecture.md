# ADR 0002：后端采用 Java 25 与 Spring Cloud Alibaba 架构

- 日期：2026-05-25
- 状态：已接受

## 背景

HDX 工具箱需要同时支持服务端部署和 desktop 集成。服务端形态需要对外开放 API、连接外部数据库，并具备微服务治理能力；desktop 集成形态需要作为 all-in-one 本机包运行，不开放外部 API，并使用本地嵌入式 SQL 数据库。

## 决策

- 后端使用 Java 25（GraalVM）和 Maven 3.8.8。
- Maven 工程放在 `services/backend/` 内，不把仓库根目录改成 Maven 主工程。
- 后端框架采用 Spring Boot 4.x、Spring Cloud 2025.1.x、Spring Cloud Alibaba 2025.1.x。
- 第一阶段采用多微服务起步，拆分为 `gateway` 与 `core`。
- 额外提供 `all-in-one` 启动器，用于 desktop 本机集成。
- 微服务治理使用 Nacos Discovery、Nacos Config 和 Sentinel；暂不引入 Seata。
- 服务间调用使用 HTTP + OpenFeign。
- 对外 API 使用 REST + OpenAPI。
- 服务端数据库第一目标为 PostgreSQL，本机 all-in-one 数据库第一目标为 H2。
- 数据访问采用 Spring Data JPA。
- 服务端 API 安全采用 JWT / OAuth2 Resource Server。
- all-in-one 绑定 `127.0.0.1`，并使用启动时生成的随机本机令牌保护 HTTP 请求。
- 所有可执行产物都应支持 GraalVM Native Image。

## 影响范围

- `services/backend/` 成为后端 Maven 聚合工程。
- 后端新增契约、核心能力、核心微服务、网关和 all-in-one 模块。
- 后续数据库迁移、权限细节、更多微服务拆分和 Native Image 优化应围绕该架构继续设计。
- Java 25 与 Native Image 构建依赖本机 GraalVM JDK 25、`native-image`、Visual Studio Build Tools 和 Windows SDK。

## 备选方案

- 模块化单体优先：实现更简单，但不符合本轮已确定的多微服务起步方向。
- 从一开始拆多个业务微服务：治理形态更完整，但业务域尚未稳定，初期拆分成本更高。
- all-in-one 进程内调用：安全边界更窄，但当前选择本机 HTTP 以复用 API 契约。
- SQLite 作为本地库：更贴近桌面本地持久化，但 H2 对 Java/Spring 测试和初期 Native Image 验证更直接。

## 验证方式

- `mvn validate` 验证 Maven 多模块结构和依赖管理。
- `mvn test` 验证 Java 编译、单元测试和 JPA/H2 冒烟测试。
- `mvn spring-boot:process-aot` 验证 Spring AOT 处理。
- `mvn -Pnative native:compile` 验证 GraalVM Native Image 构建。
- 分别启动 `gateway`、`core`、`all-in-one` 验证 profile、配置来源、端口绑定和健康检查。

## 后续事项

- 安装 GraalVM JDK 25，并将构建会话 `JAVA_HOME` 指向该 JDK。
- 安装或确认 Visual Studio Build Tools、MSVC C++ 工具链和 Windows SDK。
- 细化数据库迁移工具与 PostgreSQL/H2 迁移脚本策略。
- 细化 OAuth2/JWT issuer、权限模型和 desktop 获取本机令牌的安全交互。

