# Symphony 本地环境变量配置

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户要求为 Symphony 新工作区保留不便提交的后端本地配置
- 创建时间：2026-06-05
- 最后更新：2026-06-05

## 目标

让 Symphony 每次创建新的隔离 workspace 后，仍能通过进程环境读取后端数据库、Nacos、JWT issuer 和 Desktop Full 本机数据库配置，避免在每个 workspace 手工补不便提交的配置。

## 非目标

- 不提交真实数据库密码、令牌或其他密钥。
- 不修改后端 Spring 配置的变量名。
- 不修改 Symphony 源码。

## repo 内范围

- 根仓库 `.gitignore`
- 根仓库 `.env.symphony.example`
- 根仓库本地忽略文件 `.env.symphony.local`
- 根仓库本地忽略脚本 `start-symphony.local.ps1`
- 子模块 `services/backend/README.md`

## 本地任务清单

- [x] 创建 `.env.symphony.local` 本地配置文件。
- [x] 创建可提交的 `.env.symphony.example`。
- [x] 调整 `.gitignore`，继续忽略真实本地 env，同时允许提交示例文件。
- [x] 让 `start-symphony.local.ps1` 启动前读取 `.env.symphony.local` 并注入进程环境。
- [x] 更新后端 README，说明 Symphony 本地配置用法。

## 验收标准

- `.env.symphony.local` 被 Git 忽略。
- `.env.symphony.example` 可提交且不包含真实密钥。
- `start-symphony.local.ps1 -ValidateOnly` 能读取本地 env 文件，并只打印变量名不打印变量值。
- 后端 README 能说明常用变量和配置来源。

## 验证方式

- `git check-ignore -v .env.symphony.local`
- `git check-ignore -v .env.symphony.example`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\start-symphony.local.ps1 -ValidateOnly`
- `git diff --check`

## 过程记录

- `start-symphony.local.ps1` 是本地忽略文件，无法通过仓库提交同步到其他机器；其他机器需要按示例和说明自行配置本地启动脚本。
- `.env.symphony.local` 当前只填了默认/空值，需要用户填入真实数据库密码等本机配置。

## 状态记录

- 2026-06-05：完成本地 env 文件、示例文件、启动脚本读取逻辑和 README 说明。

## 验证结果

- `git check-ignore -v .env.symphony.local`：确认由 `.gitignore` 的 `.env.*` 忽略。
- `git check-ignore -v .env.symphony.example`：确认由 `.gitignore` 例外允许提交。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\start-symphony.local.ps1 -ValidateOnly`：通过，输出已读取 Symphony 本地环境变量名。
- `git diff --check`：已在提交前验证流程中通过。

## 归档备注

- 本轮没有运行后端服务连接真实数据库；后续认证与 Nacos 联调已验证 `.env.local` 结合真实 Nacos/PostgreSQL/Redis 可启动后端链路。`.env.symphony.local` 仍只验证到 Symphony 启动脚本进程环境层。

## 相关 commit

- `6b52844 杂项：添加 Symphony 本地环境示例`（根仓库）
