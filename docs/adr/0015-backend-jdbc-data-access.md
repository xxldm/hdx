# ADR 0015：后端业务数据访问回归 Spring JDBC

- 日期：2026-06-22
- 状态：已接受

## 背景

ADR 0002 第一阶段选择 Spring Data JPA。随着认证中心和当前业务接口落地，实际数据库访问主要已经是 `JdbcOperations` + 显式 SQL；`backend-core` 只剩 `ToolDefinition` 一条 JPA 实体链路。

与此同时，后端 native 构建已经出现内存和长时间停滞风险。Hibernate/JPA 会扩大 native-image 可达图、反射和构建期增强边界，而当前业务并没有使用 lazy loading、cascade、dirty checking 或复杂 ORM 映射。

## 决策

- 后端业务数据访问默认采用 Spring JDBC / JdbcClient + 显式 SQL 和明确 RowMapper。
- 不再把 Spring Data JPA/Hibernate 作为新增业务模块的默认数据访问方案。
- `backend-core` 现有工具目录持久化从 JPA 迁移到 JDBC，并移除 Hibernate enhance 配置。
- 后续 `backend-user`、`backend-user-service` 等新业务域从第一天使用 JDBC 风格。
- Flyway 继续作为数据库结构事实源，迁移脚本仍需兼容 PostgreSQL 和 H2，除非后续 ADR 明确拆分方言。
- MyBatis 暂不引入；若后续 SQL 复杂度、动态 SQL 或 mapper 组织成本证明需要，再单独 ADR。

## 影响范围

- `services/backend/backend-core` 不再依赖 `spring-boot-starter-data-jpa`，改用 `spring-boot-starter-jdbc`。
- 后端运行时不再依赖 Hibernate `ddl-auto=validate` 校验实体与表结构；结构正确性由 Flyway、单元测试、集成测试和启动 smoke 覆盖。
- Native Image 可达图应减少 Hibernate/JPA 相关类型和反射边界；真实收益以后端 native build report 或构建日志为准。
- 旧 ADR 和 completed plan 中的 JPA/Hibernate 记录保留为历史；当前事实以本 ADR、`docs/ARCHITECTURE.md` 和后端 README 为准。

## 备选方案

- 继续保留 JPA：迁移成本最低，但会继续把 Hibernate 作为后端 native 构建成本的一部分，且与当前手写 SQL 实践不一致。
- 改用 MyBatis：SQL 仍明确，但会新增框架、配置和 mapper 体系；当前 SQL 简单，收益不足。
- 全部使用纯 JDBC API：依赖更少，但样板代码更多；Spring JDBC/JdbcClient 已由 Spring Boot 管理事务、连接和异常转换，更适合作为默认。

## 验证方式

- `mvn -pl :backend-core -am test`
- `mvn test`
- `mvn -pl :backend-core-service,:backend-all-in-one -am compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`
- `mvn -Pnative package -DskipTests -Dnative.skip=true`
- 后续如调整 native 参数或确认收益，再单独运行真实 native build 和 build report 对比。

## 回滚条件

如果某个业务域出现复杂 ORM 映射、实体生命周期或批量关联维护需求，且 JDBC/MyBatis 方案显著增加错误率，可以为该业务域单独新增 ADR 重新评估 ORM；不得静默把 JPA 作为全局默认带回。
