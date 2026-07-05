# ADR 0017：后端 Native 交付与服务端单体公开边界

- 日期：2026-07-04
- 状态：已接受
- 修订：2026-07-05 将本 ADR 收敛为公开主仓库交付边界；后端内部实现细节迁入 `services/backend/docs/`。

## 背景

HDX 后端仓库保持私有，但公开 Release 需要交付可运行的后端 native 产物，用于 Desktop Full 本机模式和服务端部署。公开主仓库需要说明用户和发布流程能依赖的交付边界；后端模块名/服务名不敏感，但源码、内部调用链、职责拆分和实现细节仍不公开。

## 决策

- 所有进入公开 Release 的后端包只允许发布 native archive。
- 公开 Release 不发布后端 JAR/WAR、`.class`、源码快照、JVM 后端包或后端构建中间产物。
- JVM 运行只作为后端开发、测试、CI 或内部排障形态，不作为公开 Release 交付形态。
- 本机 Local/Full 后端与服务端 Standalone 后端保持独立交付边界，不把本机安全链路和服务端真实账号链路塞进同一个 native 包。
- 后端公开交付形态分为：
  - Desktop Full / Local 本机后端：服务本机 sidecar 和本机数据场景。
  - Services 微服务服务端：服务有部署能力的服务端环境。
  - Standalone 服务端单体：服务手工部署服务端环境，降低多进程部署门槛。
- 服务端单体属于服务端部署形态，不复用本机 Full 模式的本机 token、固定管理员身份或仅本机访问假设。
- 公开主仓库只保留本 ADR 这类交付摘要、必要模块/服务名和路由；后端运行拓扑、迁移、基础设施适配、内部契约、AOT/native 诊断和验证流水账以 `services/backend/README.md` 与 `services/backend/docs/README.md` 为事实源。

## 影响范围

- `apps/desktop` 的 Full 安装包可以消费公开 Release 中的本机后端 native 产物，但不得包含后端源码或构建中间产物。
- Web/Desktop Online/App 继续通过公开 API、BFF 或客户端运行时能力访问远端服务，不依赖后端源码或内部实现。
- 主仓库 release workflow 可以下载、校验并发布后端 native archive，但不 checkout 后端私有源码。
- 后端 native artifact 的内部结构、职责拆分、服务端配置和验证细节不写入公开主仓库；需要维护时进入后端私有文档。

## 验证方式

- 公开主仓库 release 校验继续扫描后端 native archive，禁止 JAR/WAR、`.class`、源码快照和后端构建中间目录。
- 后端交付形态变更时，公开主仓库只验证 release manifest、asset 交接和 Desktop/Web/App 消费边界。
- 后端 native 编译、服务端单体运行、数据库、缓存和身份链路验证在后端私有仓库记录。

## 回滚条件

- 公开交付必须支持 JVM 包，并且安全、私有源码和反编译风险被新的 ADR 接受。
- 服务端单体确认不需要独立交付形态，且微服务部署自动化已经足够覆盖目标用户。
- 本机 Local/Full 与服务端 Standalone 可以在构建期完全隔离安全链路，并通过安全审查后，才可重新评估是否合并交付物。
