# 后端总体架构方案 v1 实施计划

- 创建日期：2026-05-25
- 当前状态：后端 v1 骨架、正式 Java 25、Spring AOT 与三模块 Native Image 健康检查已完成
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
| 1 | 已完成 | 确认官方版本与本机环境 | 采用 Spring Boot `4.0.0`、Spring Cloud `2025.1.0`、Spring Cloud Alibaba `2025.1.0.0`、springdoc `3.0.3`、Native Build Tools `0.11.5`；本机 Maven、GraalVM JDK 25、`native-image`、VS C++ 工具链和 Windows SDK 已确认可用。 |
| 2 | 已完成 | 创建 Maven 多模块骨架 | `services/backend/` 下已创建 Maven 聚合工程，模块覆盖 `backend-contract`、`backend-core`、`backend-core-service`、`backend-gateway`、`backend-all-in-one`。 |
| 3 | 已完成 | 实现 core 核心能力与核心微服务启动器 | 已提供最小 REST API、JPA/H2 测试支撑、PostgreSQL 服务端配置入口和 OpenAPI/Actuator 能力；正式 Java 25 `mvn test`、AOT、`backend-core-service` native 编译与 `/actuator/health` 均已通过；`backend-core` 已启用 Hibernate 构建期实体字节码增强。 |
| 4 | 已完成 | 实现 gateway 微服务启动器 | 已加入 Spring Cloud Gateway MVC、Nacos、Sentinel、OpenFeign、OAuth2 Resource Server 依赖与基础配置；正式 Java 25 AOT、native 编译、`/actuator/health` 与 `/gateway/runtime` 均已通过。 |
| 5 | 已完成 | 实现 all-in-one 本机启动器 | 已复用 core 能力，绑定 `127.0.0.1`，使用 H2，并通过随机本机令牌保护 HTTP 请求；正式 Java 25 AOT、native 编译、`/actuator/health`、`/local/session` 与令牌保护冒烟测试均已通过。 |
| 6 | 已完成 | 更新中文架构文档和 ADR | 已新增后端选型 ADR，并更新 `docs/ARCHITECTURE.md`、`docs/CONSTRAINTS.md`、`services/backend/README.md`。 |
| 7 | 已完成 | 运行 Maven 验证并记录限制 | 正式 `mvn validate`、`mvn test`、`compile spring-boot:process-aot` 通过；`native` profile 已绑定 Spring AOT 与 Native Build Tools `compile-no-fork`；`backend-core-service`、`backend-gateway`、`backend-all-in-one` 均已通过 `mvn -Pnative package` 和健康检查。 |

## 已确认约束

- Maven 固定使用 `D:\JetBrains\.m2\apache-maven-3.8.8`。
- GraalVM JDK 25 安装目录统一放在 `D:\JetBrains\.jdks` 下。
- 当前普通 PowerShell 默认 `java` 仍指向 Microsoft JDK 21；正式构建会话必须临时将 `JAVA_HOME` 与 `PATH` 指向 `D:\JetBrains\.jdks\graalvm-jdk-25.0.3+9.1`。
- GraalVM JDK 25、`native-image`、Visual Studio Build Tools、MSVC `cl`/`link` 与 Windows SDK `10.0.26100.0` 已确认可用；native 构建前必须先加载 `E:\soft\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat`。
- 当前 Codex/PowerShell 会话可能同时带有 `PATH` 与 `Path` 两个环境变量；native 构建前需清理旧 `Path` 并只保留带 GraalVM 与 MSVC 的 `PATH`，否则 Java/GraalVM 子进程可能找不到 `cl.exe`。
- GraalVM JDK 25 解析部分依赖内嵌旧式 `resource-config.json` 时会触发 `LegacyResourceConfigurationParser` 内部 NPE。
- 方案一：通过 `--exclude-config` 排除 Nacos client、Angus Activation、WebJars locator、Tomcat、Log4j API、H2 的部分内嵌 `resource-config.json` 后，三个可执行模块均可编译为 native 可执行文件；但运行 `backend-core-service.exe` 时暴露 Tomcat/Jakarta/Hibernate/JBoss Logging metadata 缺口，健康检查未通过。当前方案一代码已在后端子仓库提交 `8c01948` 留档。
- 方案二：移除 `--exclude-config` 与 `<excludeConfig>`，改用 `--exact-reachability-metadata=false` 降低严格可达性检查；`backend-core-service` native 编译仍在 `LegacyResourceConfigurationParser` 解析阶段触发 GraalVM 内部 NPE。额外补测 `-R:MissingRegistrationReportingMode=Warn` 也不能绕过该 NPE，因为错误发生在资源配置解析阶段，而不是缺失注册报告阶段。
- 当前已按用户要求回到方案一：父 POM 重新使用 `--exclude-config` 排除依赖内嵌旧式 `resource-config.json`，并保留 `--initialize-at-build-time=com.alibaba.fastjson,com.alibaba.fastjson2`；在 Spring AOT、官方 reachability metadata、项目内 `RuntimeHints` 和 Hibernate 构建期增强配合下，三类可执行模块已通过 native 编译与健康检查。
- 方案一继续收敛原则：排除只使用 Maven `native-maven-plugin` 的 `<configuration><buildArgs><buildArg>...`；运行期 metadata 只使用 Spring 官方 `RuntimeHints` 补齐项目和当前版本缺口；官方 reachability metadata 保持启用。
- Hibernate enhance 已作为补充能力加入 `backend-core`，用于在构建期完成实体字节码增强，降低运行期动态增强风险；它不是 native metadata 的替代品，不能替代 Spring AOT、官方 reachability metadata 或项目内 `RuntimeHints`。
- Tracing Agent 可作为后续复杂 Hibernate/native 问题的辅助发现工具，但生成结果必须整理为 `RuntimeHints` 或确认由官方 metadata 覆盖后再进入长期配置。
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
- 2026-05-25：GraalVM JDK 25、`native-image`、Visual Studio Build Tools、MSVC `cl`/`link` 与 Windows SDK 已确认可用，开始正式 Java 25 与 native 构建复验。
- 2026-05-26：正式 Java 25 `mvn validate` 通过。
- 2026-05-26：正式 Java 25 `mvn test` 通过，当前测试共 2 个，均通过。
- 2026-05-26：正式 Java 25 `compile spring-boot:process-aot` 通过。
- 2026-05-26：定位并修复 Windows 构建会话 `PATH`/`Path` 重复导致 GraalVM 子进程找不到 MSVC `cl.exe` 的问题；native 构建命令需清理旧 `Path`。
- 2026-05-26：根据 GraalVM 25 `--exclude-config <classpath 正则> <资源正则>` 语法排除依赖内嵌旧式 native resource 配置，越过 `LegacyResourceConfigurationParser` 内部 NPE；随后通过 fastjson/fastjson2 build-time 初始化解决镜像堆初始化错误。
- 2026-05-26：`backend-core-service`、`backend-gateway`、`backend-all-in-one` 在方案一配置下均已成功生成 Windows native 可执行文件。
- 2026-05-26：运行期冒烟测试发现 `backend-core-service.exe` 不能通过健康检查；先后暴露 Tomcat/Jakarta 资源缺口与 Hibernate/JBoss Logging 生成 logger metadata 缺口，说明方案一的排除范围会引入运行期风险。
- 2026-05-26：已按用户要求先提交方案一状态：后端子仓库提交 `8c01948`，根仓库文档提交 `2480d51`。
- 2026-05-26：切换方案二，移除 POM 中 `--exclude-config` 与 `<excludeConfig>`，加入 `--exact-reachability-metadata=false`；`mvn validate` 通过。
- 2026-05-26：方案二下 `backend-core-service` native 编译失败，仍为 GraalVM `LegacyResourceConfigurationParser` 处理旧式 `resource-config.json` 时的内部 NPE；补测 `-R:MissingRegistrationReportingMode=Warn` 同样无效。
- 2026-05-26：按用户要求回到方案一，后端子仓库通过 revert 提交恢复 `--exclude-config` 排除配置，后续在方案一基础上补运行期 metadata 缺口。
- 2026-05-26：根据用户补充说明确认 Hibernate enhance 的定位：它用于构建期实体字节码增强，不替代 native metadata；`backend-core` 已启用 Hibernate 官方 Maven 插件增强 `ToolDefinition`，并设置增强失败即构建失败。
- 2026-05-26：父 POM 的 `native` profile 已绑定 Spring Boot `process-aot` 与 Native Build Tools `compile-no-fork`，正式 native 构建入口改为 `mvn -Pnative package`，避免生成非 Spring AOT native 镜像。
- 2026-05-26：复验 `mvn validate`、正式 Java 25 `mvn test`、`backend-core-service` 的 `compile spring-boot:process-aot` 均通过；下一步运行单模块 `mvn -Pnative package` 并检查 `target/spring-aot` 与健康检查。
- 2026-05-26：`backend-core-service` 使用 `mvn -Pnative package` clean 构建通过，`target/spring-aot` 已生成，native 启动日志显示 `AOT-processed`，`/actuator/health` 返回 `UP`。
- 2026-05-26：`backend-gateway` 使用 `mvn -Pnative package` clean 构建通过，native `/actuator/health` 返回 `UP`，`/gateway/runtime` 返回 `nativeImage=true`。
- 2026-05-26：`backend-all-in-one` 使用 `mvn -Pnative package` clean 构建通过，native `/actuator/health` 返回 `UP`，`/local/session` 返回 `X-HDX-Local-Token` 与 64 位随机令牌；未带令牌访问业务 API 返回 `403`，带令牌返回 `200`。
- 2026-05-26：`backend-all-in-one` 排除 Spring Security 默认 `UserDetailsServiceAutoConfiguration`，避免生成默认开发密码，保持 all-in-one 安全边界只使用本机令牌。
