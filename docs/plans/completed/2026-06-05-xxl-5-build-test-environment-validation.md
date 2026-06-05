# XXL-5 编译与测试环境验证

- 外部任务系统：Linear
- 外部任务链接/编号：XXL-5，https://linear.app/xxldtm/issue/XXL-5/验证编译与测试环境是否通畅
- 外部任务是否为主计划来源：是
- 当前状态：已完成
- 计划来源：Linear 重试未完成验证项
- 创建时间：2026-06-05
- 最后更新：2026-06-05

## 目标

确认当前隔离仓库副本中的后端与 Web 编译、测试和构建环境是否通畅，并把可复现的失败信号、验证缺口和副作用清理结果留在仓库与 Linear workpad 中。

## 非目标

- 不调整后端、Web 或 App 技术栈。
- 不修复验证中发现的业务代码问题，除非是本 ticket 范围内的环境验证脚本或文档缺口。
- 不创建 PR 或推送分支，除非后续产生需要评审的代码/文档变更并获得明确推送批准。

## repo 内范围

- `services/backend/`
- `apps/web/`
- `docs/plans/completed/2026-06-05-xxl-5-build-test-environment-validation.md`

## 本地任务清单

- [x] 读取最新仓库入口、质量、Git 和计划规则。
- [x] 同步 `origin/main` 到本地 `main`。
- [x] 记录上轮遗留的 `apps/web/_tmp_*` 临时文件复现信号。
- [x] 清理上轮 Web 验证副作用，或记录无法清理原因。
- [x] 重跑后端 `validate`、`test`、`process-aot` 和 native profile package 入口。
- [x] 重跑 Web `pnpm install`、`typecheck`、`lint`、`test`、`build`。
- [x] 同步 Linear workpad 与本地计划的最终验证结果、剩余风险和相关 commit。

## 验收标准

- 后端验证命令按 `services/backend/README.md` 执行并记录结果。
- Web 验证命令按 `apps/web/README.md` 执行并记录结果。
- 验证副作用已清理；若清理失败，记录具体命令和失败输出摘要。
- Linear workpad 与本地计划反映同一组真实验证结果。

## 验证方式

- `git status --short`
- `git -C apps/web status --short`
- `git fetch origin`
- `git merge --ff-only origin/main`
- `& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' validate`
- `& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' test`
- `& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`
- `& 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd' -Pnative package -DskipTests -Dnative.skip=true`
- `pnpm install`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm test`
- `pnpm build`

## 风险与阻塞

- 普通沙箱权限下，Git 写操作、Maven AOT 输出清理、pnpm 临时文件删除、Vitest 启动 esbuild 子进程和 Nuxt build 缓存清理仍会出现 `Permission denied`、`AccessDeniedException`、`EPERM` 或 `spawn EPERM`。这些步骤按授权流程提升后均已通过。
- 后端与 Web 验证均有第三方工具 warning，当前未阻塞构建或测试。

## 状态记录

- 2026-06-05：创建计划。本轮已将 `XXL-5` 从 `Todo` 移回 `In Progress`，复用 Linear workpad；普通 `git fetch origin` 与 `git merge --ff-only origin/main` 均因 `.git` 写权限失败，提升权限后已快进到 `f1db06d`。
- 2026-06-05：提升权限删除上轮与本轮 `apps/web/_tmp_*` 0 字节临时文件；清理后 `apps/web` 子模块工作树干净。
- 2026-06-05：后端 `mvn validate`、`mvn test`、`mvn compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`、`mvn -Pnative package -DskipTests -Dnative.skip=true` 均完成；AOT 与 native profile package 入口在普通权限下复现旧 target 删除权限问题，提升后通过。
- 2026-06-05：Web `pnpm install`、`pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build` 均完成；`install`、`test`、`build` 在普通权限下分别因 `_tmp_*` unlink、`spawn EPERM`、Nuxt cache unlink 失败，提升后通过。
- 2026-06-05：计划移入 `docs/plans/completed/`，最终 commit hash 写入 Linear workpad 与最终交接。

## 验证结果

- `git fetch origin`：普通权限失败于 `.git/FETCH_HEAD`，提升后成功。
- `git merge --ff-only origin/main`：普通权限失败于 `.git/ORIG_HEAD.lock`，提升后 fast-forward 到 `f1db06d`。
- 后端 `mvn validate`：`BUILD SUCCESS`，6/6 reactor modules success。
- 后端 `mvn test`：`BUILD SUCCESS`，`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`。
- 后端 `mvn compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`：普通权限失败于删除 `backend-core-service/target/spring-aot/...SentinelFeignClientAutoConfiguration__BeanDefinitions.java`；提升后 `BUILD SUCCESS`，覆盖 `backend-core-service`、`backend-gateway`、`backend-all-in-one`。
- 后端 `mvn -Pnative package -DskipTests -Dnative.skip=true`：PowerShell 直接传参会把 `-Dnative.skip=true` 误解析为 Maven phase `.skip=true`；使用显式字符串参数后普通权限失败于同一 AOT 删除权限点；提升后 `BUILD SUCCESS`，native-image 按 `skipNativeBuild` 跳过。
- Web `pnpm install`：普通权限失败于 `EPERM ... unlink '_tmp_6176_efe94ae966a5d6465d0a25cf3755e645'`；提升后成功，`nuxt prepare` 生成类型。
- Web `pnpm typecheck`：通过。
- Web `pnpm lint`：通过。
- Web `pnpm test`：普通权限失败于 Vitest/Vite 加载配置时 `Error: spawn EPERM`；提升后 `3 passed` test files、`7 passed` tests。
- Web `pnpm build`：普通权限失败于删除 `node_modules/.cache/nuxt/.nuxt/eslint.config.mjs`；提升后 build complete。
- 最终 `git status --short --branch`：根仓库仅剩本计划文件变更；`apps/web` 与 `services/backend` 子模块工作树干净。

## 剩余风险

- 当前会话普通权限无法完整代表本机无提升权限的开发体验；验证结论是工具链在授权写入/删除/子进程权限下通畅。
- 保留 warning：Java 25 restricted native access、Guava `Unsafe` deprecated、Mockito dynamic agent future behavior、pnpm ignored build scripts 提示、Nuxt/Tailwind sourcemap warning、Rollup pure annotation warning、Node `DEP0155` deprecation warning。它们未阻塞本轮验证命令。

## 相关 commit

- 本计划文件所在提交；最终 hash 记录在 Linear workpad 与最终交接中。
