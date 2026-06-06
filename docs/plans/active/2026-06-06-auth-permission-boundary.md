# 认证与权限边界

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已确认认证中心采用独立后端模块；已确认服务端与 all-in-one 的认证持久化边界；已确认 all-in-one 固定本机身份基础字段；已确认服务端认证数据使用 PostgreSQL 独立 schema；等待继续确认最小数据模型
- 计划来源：HDX 后续事项总纲第 3 步
- 创建时间：2026-06-06
- 最后更新：2026-06-06

## 目标

确定 HDX 的认证中心、JWT issuer、角色权限模型、Web 登录态、desktop 本机 token 和各端身份传递边界。

## 已确认决策

- HDX 使用自建认证中心，不只接外部认证服务。
- 认证中心按独立后端模块设计，模块名暂定为 `backend-auth-service`。
- `backend-auth-service` 与 `backend-gateway`、`backend-core-service` 同级，不把认证中心实现放入 gateway 或 core。
- `backend-auth-service` 负责登录、签发 token、刷新 token、暴露 JWK/OIDC discovery，并持久化认证授权相关数据。
- `backend-gateway` 和 `backend-core-service` 作为 OAuth2 Resource Server 校验 JWT，不承担 token issuer 职责。
- 角色和权限需要持久化，后续作为鉴权事实源之一。
- 当前技术线为 Spring Boot 4.x / Spring Security 7.x；认证中心设计应优先跟随 Spring Security 7 的 Authorization Server 能力。
- 认证授权持久化只面向服务端 PostgreSQL；用户、角色、权限、OAuth2 client、authorization、consent 等认证授权数据不进入 all-in-one 的 H2 迁移路径。
- `backend-all-in-one` 不运行认证中心，不提供登录流程；它继续绑定本机服务边界，并使用随机本机 token 保护 HTTP 调用。
- all-in-one/H2 模式下默认注入固定本机管理员身份，拥有本机模式下的全部权限；业务层仍应能读取当前身份，避免与服务端模式拆成两套业务逻辑。
- Desktop 使用内置本地服务时走 all-in-one/H2 本机管理员身份；Desktop 填写外部服务端地址时与 Web/App 一样走服务端认证中心。
- all-in-one 固定本机身份的稳定 principal/subject/id 使用 `local-admin`，角色使用 `ADMIN`，权限表达使用 `*` 或内部常量 `ALL`。
- all-in-one 固定本机身份面向用户端回显的 `displayName` 使用 `用户`，不使用 `本机管理员`。
- 日志、审计、权限判断和业务规则不得依赖 `displayName`；应使用稳定字段，例如 `actorType=LOCAL_ADMIN`、`subject=local-admin`、roles 或 permissions。
- 服务端认证中心数据使用 PostgreSQL 独立 schema `auth`，不与 `backend-core-service` 的业务表混在默认 `public` schema。
- `auth` schema 已由用户手动创建，所有者为 `hdx`。
- 当前后端数据库账号已通过手工 SQL 验证：可在 `auth` schema 下建表、插入、查询、更新、删除和删表，满足 Flyway 开发阶段迁移权限。

## 待确认事项

- 用户、角色、权限、用户角色关系、角色权限关系的最小数据模型。
- OAuth2 client、authorization、consent 等 Authorization Server 持久化表的落点。
- Web 登录态与 refresh token 策略。
- all-in-one 固定本机管理员身份与服务端用户身份的统一接口形状。
- desktop all-in-one 本机 token 与服务端认证 token 的切换边界。

## 非目标

- 本计划不立即实现认证服务代码。
- 本计划不在未确认前固定 Web 登录流程、desktop 登录流程、App 登录流程或权限细粒度规则。
- 本计划不把密钥、私钥、client secret 或真实用户数据提交到仓库。

## 下一步确认

优先确认服务端认证中心最小数据模型：用户、角色、权限、用户角色关系、角色权限关系，以及 OAuth2 授权表是否全部落在 `auth` schema。

## 验证方式

- 使用 `Get-Content -Encoding UTF8` 读取本文件，确认中文内容正常。
- 使用 `git status --short --branch` 确认本轮文档变更范围。

## 状态记录

- 2026-06-06：用户确认认证中心按独立模块设计；创建本地计划，等待继续确认持久化边界。
- 2026-06-06：用户确认登录只在 PostgreSQL 服务端模式执行；all-in-one/H2 不需要登录，默认管理员账号；Desktop 连接外部服务端时走 PostgreSQL 服务端认证中心。
- 2026-06-06：用户确认 all-in-one 固定本机身份可使用稳定字段 `local-admin`、`ADMIN`、全量权限；用户端回显名改为 `用户`，日志和规则判断不得依赖该显示名。
- 2026-06-06：用户确认服务端认证中心使用 PostgreSQL 独立 schema `auth`；`auth` schema 已手动创建且所有者为 `hdx`；手工 SQL 权限检查通过。

## 剩余风险

- 尚未确定服务端认证中心最小数据模型，不能开始创建 Flyway 脚本或实体模型。
- 尚未确定 Web、App、desktop 的登录态和 token 策略，不能开始端侧认证集成。
- 尚未确定本机身份与服务端用户身份的统一接口形状，不能开始改造 all-in-one 当前用户注入逻辑。
