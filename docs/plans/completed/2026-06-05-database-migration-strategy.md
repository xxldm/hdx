# 数据库迁移策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成并归档
- 计划来源：HDX 后续事项总纲第 2 步
- 创建时间：2026-06-05
- 最后更新：2026-06-05

## 目标

为后端建立明确、可版本化、可验证的数据库迁移入口，让服务端 PostgreSQL、desktop all-in-one H2、local/test H2 都通过同一套迁移历史创建和演进表结构。

## 非目标

- 不支持 MySQL。
- 不保留当前早期本地数据库数据；允许清空开发期 PostgreSQL/H2 数据库后由 Flyway 重建。
- 不提前设计未来业务表。
- 不修改认证、OpenAPI、desktop 或部署策略。

## repo 内范围

- `services/backend/docs/adr/`
- `services/backend/backend-core/src/main/resources/db/migration/`
- `services/backend/backend-core/pom.xml`
- `services/backend/backend-core-service/pom.xml`
- `services/backend/backend-all-in-one/pom.xml`
- `services/backend/backend-core-service/src/main/resources/application.yml`
- `services/backend/backend-core-service/src/main/resources/application-service.yml`
- `services/backend/backend-all-in-one/src/main/resources/application.yml`
- `services/backend/backend-core/src/test/java/com/hdx/backend/core/tool/ToolCatalogServiceTest.java`
- `services/backend/README.md`
- `docs/ARCHITECTURE.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-05-database-migration-strategy.md`

## 本地任务清单

- [x] 新增后端数据库迁移 ADR。
- [x] 引入 Flyway 依赖。
- [x] 新增 `V1__create_tool_definition.sql`。
- [x] 将运行时 Hibernate 建表策略收紧为 `validate`。
- [x] 将测试改为 Flyway 建表 + Hibernate validate。
- [x] 更新后端 README 与根仓库架构/总纲记录。
- [x] 执行 Maven 验证。
- [x] 子模块先提交推送，根仓库再提交推送。

## 验收标准

- 后端迁移工具明确为 Flyway。
- PostgreSQL 为服务端事实源，H2 用于 desktop all-in-one/local/test。
- 运行时不再依赖 Hibernate `ddl-auto: update` 自动改表。
- 第一版迁移只创建当前已有的 `tool_definition` 表。
- 后续智能体可从仓库恢复迁移目录、命名规则、验证命令和剩余风险。

## 验证方式

- `mvn validate`
- `mvn test`
- 根据改动结果决定是否补充 AOT/native 验证。

## 风险与阻塞

- Flyway 新依赖可能需要联网下载。
- Flyway 与 Spring Boot 4 / GraalVM Native Image 组合需要后续 AOT/native 验证确认。
- 当前允许清空早期本地数据库；如未来已有用户数据，迁移脚本不得用清库方式处理。

## 状态记录

- 2026-06-05：创建第 2 步本地计划，用户已确认使用 Flyway、不支持 MySQL、早期本地数据可清空。
- 2026-06-05：已新增后端 Flyway ADR、V1 迁移脚本，并将运行时和测试配置改为 Flyway 建表 + Hibernate validate；等待 Maven 验证。
- 2026-06-05：`mvn validate`、`mvn test` 和 native profile 轻量包构建已通过；等待提交、推送和最终状态收口。
- 2026-06-05：已在 `services/backend` 创建提交 `9090455 功能：引入 Flyway 数据库迁移`；等待根仓库提交子模块指针和计划更新。
- 2026-06-07：复核本计划任务清单、验证结果、后端迁移脚本和总纲状态后，确认数据库迁移策略已完成并移动到 `docs/plans/completed/`。

## 验证结果

- `mvn validate`：通过。
- `mvn test`：通过，当前测试 2 个；测试日志确认 Flyway 创建 `flyway_schema_history` 并执行 `V1__create_tool_definition.sql` 后，Hibernate validate 成功。
- `mvn -Pnative package '-DskipTests' '-Dnative.skip=true'`：通过，确认 Spring AOT 与 native profile 的基础包构建路径可用。
- `mvn -Pnative package -DskipTests -Dnative.skip=true`：在 PowerShell 中失败，原因是未加引号时 `-Dnative.skip=true` 被解析成错误 lifecycle phase；README 已改为带引号写法。
- `mvn -Pnative package '-DskipTests' '-Dnative.skip=true'` 普通权限首次失败于 `target` jar 写入权限；提权后通过。

## 剩余风险

- 尚未运行真实 PostgreSQL 服务端 profile 启动和健康检查。
- 尚未运行完整 native-image 编译；本轮只验证到 Spring AOT 与 native profile 跳过 native-image 的包构建路径。
- H2 2.4.240 高于 Flyway 11.14.1 当前已验证 H2 版本 2.3.232，测试通过但保留兼容性观察。

## 相关 commit

- `9090455 功能：引入 Flyway 数据库迁移`（`services/backend`）
