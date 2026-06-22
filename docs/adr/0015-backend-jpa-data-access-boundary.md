# ADR 0015：后端业务数据访问默认使用 JPA

- 日期：2026-06-22
- 状态：已接受

## 背景

ADR 0002 第一阶段选择 Spring Data JPA。随后为了降低 native-image 可达图和构建内存风险，曾短暂评估将业务数据访问默认方案收窄为 Spring JDBC / JdbcClient。

重新评估后确认：HDX 后端仍需要优先保障人类维护体验、实体关系表达、常规 CRUD 开发效率和代码一致性。大规模手写 SQL 会把字段映射、查询拼装、分页、排序、审计字段和关联维护分散到仓储代码里，长期更容易形成重复和漂移。

Native Image 成本仍是重要约束，但不应以全局放弃 JPA 作为默认代价。后续应通过 build report、依赖收窄、实体模型克制、启动器拆分和局部热点优化来控制 native 构建成本。

## 决策

- 后端普通业务数据访问默认使用 Spring Data JPA / Hibernate ORM。
- `backend-auth-service` 中 HDX 自有认证表同样遵守 JPA 优先，例如用户、登录标识、密码凭据、角色、权限、会话、refresh token、登录审计和签名密钥表。
- Spring Authorization Server 官方 OAuth2 表继续交给框架 JDBC repository/service 管理，不强行映射为 HDX 业务实体。
- Flyway 继续作为数据库结构事实源，Hibernate 运行时只使用 `ddl-auto=validate` 校验实体与表结构。
- 需要自定义查询时，优先使用 JPA 体系内能力，例如 `@Query`、JPQL、native query、projection、Specification/Criteria、`EntityManager` 或 repository fragment。
- refresh token 原子消费、幂等撤销、审计追加等需要精确 SQL 语义的操作，可以放在 Spring Data JPA repository 的 `@Modifying @Query(nativeQuery = true)` 中，并检查更新行数。
- 不推荐大规模绕开 JPA 手写 SQL；只有 JPA 查询能力不适合或收益明确时，才使用 Spring JDBC / JdbcClient / JdbcOperations。
- 允许使用 JDBC/JdbcClient 的场景包括：结果不适合实体或 projection、极端批量写入、报表统计、性能热点、数据库方言特性、以及必须贴近第三方框架 JDBC schema 的表。
- 一个业务模块应只有一个默认持久化风格。模块内可以有少量 JDBC/JdbcClient 例外，但不能让同类业务长期在 JPA repository 与大量 `JdbcOperations` 手写仓储之间双轨维护。
- 确需 JDBC/JdbcClient 时，必须记录例外原因、隔离边界和迁移触发条件；优先把例外封装在明确命名的 adapter/repository 中，不把手写 SQL 扩散成模块默认写法。
- `backend-user`、`backend-user-service` 等新业务域默认从 JPA 开始；出现明确例外时，在代码或文档中说明原因。
- MyBatis 暂不引入；如果后续大量复杂 SQL 让 JdbcClient 组织成本升高，再单独 ADR。

## 影响范围

- `services/backend/backend-core` 保留 `spring-boot-starter-data-jpa`、JPA 实体和 Spring Data Repository。
- `backend-core` 的 Hibernate enhance 继续作为 native 构建约束的一部分；新增实体时必须纳入增强范围或调整增强策略。
- `backend-auth-service` 当前 HDX 自有认证表已迁向 JPA repository；后续新增登录、会话、refresh token、审计或签名密钥能力时，默认继续扩展 JPA repository，不再重新引入一套普通 `JdbcOperations` 手写仓储。
- Spring Authorization Server 官方 OAuth2 表继续使用 `JdbcRegisteredClientRepository`、`JdbcOAuth2AuthorizationService`、`JdbcOAuth2AuthorizationConsentService` 等框架 JDBC 服务；不把官方协议表纳入自有业务 JPA 模型。
- Native Image 可达图仍会包含 Hibernate/JPA 成本；真实优化方向应以 build report 和启动器依赖分析为准。
- 旧 completed plan 中的 JDBC 或 JPA 记录按历史保留；当前事实以本 ADR、`docs/ARCHITECTURE.md` 和后端 README 为准。

## 备选方案

- 全局改用 Spring JDBC / JdbcClient：依赖更轻，native 构建可能更省，但会明显增加普通业务维护成本，不符合当前项目长期维护目标。
- 改用 MyBatis：SQL 显式且组织能力更强，但会新增 mapper 体系和框架选型；当前还没有足够复杂且不适合 JPA 查询能力的 SQL 证明需要。
- 混用且无边界：短期灵活，但会让同类业务在 JPA、JdbcClient、手写 mapper 之间漂移，后续维护成本最高。

## 验证方式

- `mvn -pl :backend-core -am test`
- `mvn test`
- `mvn -pl :backend-core-service,:backend-all-in-one -am compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`
- `mvn -Pnative package -DskipTests -Dnative.skip=true`
- 涉及 native 参数、Hibernate enhance 或实体范围变化时，按后端 README 运行真实 native build 或 build report。

## 回滚条件

如果后续 build report 证明某个具体业务域的 JPA 成本不可接受，或该域天然以报表、批量操作、非实体结果集为主且 JPA 查询能力不合适，可以为该业务域单独新增 ADR，改用 Spring JDBC / JdbcClient 或 MyBatis。不得静默把例外扩散为全局默认。
