# 后端总体架构方案 v1 实施计划

- 创建日期：2026-05-25
- 当前状态：已落地骨架，待 GraalVM JDK 25 与 Windows native 工具链就绪后复验
- 计划来源：用户确认的“后端总体架构方案 v1”
- 文档语言：中文

## 目标摘要

- 后端采用 Java 25（GraalVM）+ Maven 3.8.8 + Spring Boot 4.x + Spring Cloud Alibaba 2025.1.x。
- Maven 工程放在 `services/backend/` 内，使用多模块聚合，不把仓库根目录改成 Maven 主工程。
- 第一阶段采用多微服务起步，拆出 `gateway` 与 `core`，并提供 desktop 集成用 `all-in-one` 本机包。
- 微服务部署使用 Nacos Discovery + Nacos Config + Sentinel；暂不引入 Seata。
- 服务间调用使用 HTTP + OpenFeign；对外 API 使用 REST + OpenAPI。
- 远端数据库第一目标为 PostgreSQL；本地 all-in-one 数据库第一目标为 H2。
- 数据访问采用 Spring Data JPA 抽象。
- 服务端 API 安全采用 JWT / OAuth2 Resource Server；all-in-one 本机 HTTP 使用随机本机令牌保护。
- 所有可执行产物都要求支持 GraalVM Native Image。

## 实施状态

| 编号 | 状态 | 项目 | 验收标准 |
| --- | --- | --- | --- |
| 0 | 已完成 | 持久化本实施计划 | 本文件存在于 `docs/plans/active/`，并作为后续状态源。 |
| 1 | 已完成 | 确认官方版本与本机环境 | 采用 Spring Boot `4.0.0`、Spring Cloud `2025.1.0`、Spring Cloud Alibaba `2025.1.0.0`、springdoc `3.0.3`、Native Build Tools `0.11.5`；本机 Maven 可用，JDK 25、`native-image`、VS C++ 工具链和 Windows SDK 仍缺失。 |
| 2 | 已完成 | 创建 Maven 多模块骨架 | `services/backend/` 下已创建 Maven 聚合工程，模块覆盖 `backend-contract`、`backend-core`、`backend-core-service`、`backend-gateway`、`backend-all-in-one`。 |
| 3 | 已完成，待 Java 25 复验 | 实现 core 核心能力与核心微服务启动器 | 已提供最小 REST API、JPA/H2 测试支撑、PostgreSQL 服务端配置入口和 OpenAPI/Actuator 能力；临时 `-Djava.version=21` 全模块测试已通过，正式 Java 25 测试待 GraalVM JDK 25 复验。 |
| 4 | 已完成，待 Java 25 复验 | 实现 gateway 微服务启动器 | 已加入 Spring Cloud Gateway MVC、Nacos、Sentinel、OpenFeign、OAuth2 Resource Server 依赖与基础配置；临时 `-Djava.version=21` 全模块测试已通过，正式 Java 25 测试待 GraalVM JDK 25 复验。 |
| 5 | 已完成，待 Java 25 复验 | 实现 all-in-one 本机启动器 | 已复用 core 能力，绑定 `127.0.0.1`，使用 H2，并通过随机本机令牌保护 HTTP 请求；临时 `-Djava.version=21` 全模块测试已通过，正式 Java 25 测试待 GraalVM JDK 25 复验。 |
| 6 | 已完成 | 更新中文架构文档和 ADR | 已新增后端选型 ADR，并更新 `docs/ARCHITECTURE.md`、`docs/CONSTRAINTS.md`、`services/backend/README.md`。 |
| 7 | 已完成，部分受阻 | 运行 Maven 验证并记录限制 | `mvn validate` 已通过；临时 `mvn test -Djava.version=21` 已通过；正式 `mvn test` 因当前 JDK 21 不支持 `--release 25` 失败；`spring-boot:process-aot` 与 `-Pnative native:compile` 待 GraalVM JDK 25、`native-image`、VS C++ 工具链和 Windows SDK 就绪后执行；`native` profile 已补齐。 |

## 已确认约束

- Maven 固定使用 `D:\JetBrains\.m2\apache-maven-3.8.8`。
- GraalVM JDK 25 安装目录统一放在 `D:\JetBrains\.jdks` 下。
- 当前默认 `java` 指向 Microsoft JDK 21；当前未发现 GraalVM/JDK 25。
- 当前未发现 `native-image`、`cl`、`link`、`vswhere`、常见 Visual Studio Build Tools 目录或 Windows SDK 痕迹。
- MySQL、SQLite、Seata、更多微服务拆分、具体 API 字段、权限模型细节和数据库迁移工具留到下一轮细节设计。

## 状态记录

- 2026-05-25：计划已持久化，准备进入版本与环境确认。
- 2026-05-25：版本与本机环境确认完成，开始创建 Maven 多模块骨架。
- 2026-05-25：Maven 多模块骨架创建完成，开始实现 core 核心能力与核心微服务启动器。
- 2026-05-25：core、gateway、all-in-one 最小代码已实现，进入 Maven 验证前状态为“已实现待验证”。
- 2026-05-25：中文架构文档和后端 ADR 更新完成，开始整理验证结果。
- 2026-05-25：`mvn validate` 已通过；`mvn test` 因当前构建会话使用 JDK 21 而项目要求 Java 25 受阻，等待 GraalVM JDK 25 安装后复验。
- 2026-05-25：为提前排查代码问题，额外执行临时 `mvn test -Djava.version=21`，全模块测试通过；项目文件仍保持 Java 25。
- 2026-05-25：补齐 `native` profile 与可执行模块 native main class 配置后，复跑 `mvn validate` 和临时 `mvn test -Djava.version=21` 均通过。
