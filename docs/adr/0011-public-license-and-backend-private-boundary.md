# ADR 0011：公开仓库采用 Apache-2.0 与后端私有边界

- 日期：2026-06-08
- 状态：已接受

## 背景

HDX 后续计划让主仓库、Web、Desktop、App 和共享契约面向公开协作，但后端源码会维持私有。用户希望项目许可保持简单，不引入 GPL 带来的组合发布、私有后端边界、App 商店分发等额外复杂度。

项目还需要降低后端实现被轻易改掉来源提示或被直接还原售卖的风险，因此不能让后端源码、Spring Boot JAR/WAR 或容易反编译的后端构建产物流入公开主仓库。

## 决策

公开主仓库采用 **Apache License 2.0**。根仓库新增 `LICENSE` 与 `NOTICE`：

- `LICENSE` 放置 Apache-2.0 标准文本。
- `NOTICE` 说明 HDX 品牌、Logo、图标和官方发布标识不随 Apache-2.0 授权给容易混淆的使用方式。
- 根仓库 Apache-2.0 只覆盖本仓库内未另行声明许可的文件，不自动覆盖独立子模块、外部依赖、私有后端仓库或后端二进制附带许可。

公开子仓库边界：

- `apps/web` 与 `apps/desktop` 作为后续公开子仓库，分别补齐 Apache-2.0 `LICENSE`、`NOTICE` 和 package `license` 字段。
- `apps/mobile` 当前仍是根仓库内占位目录，跟随根仓库 Apache-2.0；后续如果拆为独立公开仓库，需要在该仓库内补齐 Apache-2.0 `LICENSE` 与适合自身的 `NOTICE`。
- 子仓库的 Apache-2.0 不覆盖私有后端源码、后端二进制、后端 native archive、Spring Boot JAR/WAR 或后端构建中间产物，除非对应后端仓库或二进制附带说明另行声明。

后端边界：

- `services/backend` 后续维持私有仓库。
- 公开主仓库禁止提交后端源码快照、后端 Spring Boot JAR/WAR、`.class` 文件和后端构建中间产物。
- 后端 release 目标只允许 native executable archive，不发布 JAR/WAR。
- 后端 native 包如果进入 Desktop Full 或其他发行包，必须作为独立二进制产物附带自身说明；它不因公开主仓库 Apache-2.0 而自动变成 Apache-2.0 源码授权。

命名边界：

- 用户可见的本地完整模式后续统一称为 **Full**，例如 `HDX Desktop Full`。
- 当前后端内部模块名 `backend-all-in-one` 暂不在本轮重命名；代码级重命名会影响后端私有仓库、Desktop sidecar 打包、文档、OpenAPI 调试说明和质量门禁，需后续单独计划。
- 历史计划、旧 ADR 和当前模块名中的 `Local`/`all-in-one` 保留为历史上下文与现状描述；后续新的发布设计、用户可见安装包和产品文案应优先使用 Full，并在必要时注明当前内部模块名。

发布边界：

- GitHub Releases 后续作为公开主仓库的发布入口时，不得上传后端源码、JAR/WAR 或后端构建中间产物。
- 后端 native 包、Desktop Full 包和公开主仓库 Release 资产粒度已由 `docs/adr/0012-github-releases-artifact-boundary.md` 确认；主仓库 Release 可以公开后端 native archive，但不公开后端源码、JAR/WAR、`.class` 或构建中间产物。
- CI 不应把私有后端仓库源码复制进公开主仓库工作区或 release artifact。

## 备选方案

- MIT：更简单，但缺少 Apache-2.0 的专利授权和 NOTICE 机制，项目未来存在多端与企业用户时 Apache-2.0 更稳。
- GPL-3.0：能要求修改分发开源，但会给私有后端、Desktop Full sidecar、App 商店分发和组合发布带来额外复杂度，不符合当前“简单”的目标。
- PolyForm Noncommercial 或 Commons Clause：可以限制商用或售卖，但不属于传统开源路线，会提高用户理解成本。
- 后端完全开源：协作透明，但不符合当前希望降低后端实现被直接改包售卖的目标。
- 公开仓库发布后端 JAR：构建简单，但容易被反编译，不符合后端私有边界。

## 影响范围

- 根仓库新增 `LICENSE` 和 `NOTICE`。
- `.gitignore` 增加 JAR/WAR/class 等后端构建产物防误提交规则。
- `docs/CONSTRAINTS.md`、`docs/ARCHITECTURE.md`、根 README 和后续事项总纲需要记录许可、公私仓库和后端发布边界。
- `apps/web` 与 `apps/desktop` 独立子仓库补齐 Apache-2.0 `LICENSE`、`NOTICE` 和 package `license` 字段。
- 后续如果 `apps/mobile` 作为独立公开仓库发布，也应在自身仓库补齐 Apache-2.0 `LICENSE` 与适合自身的 `NOTICE`。

## 验证方式

- 通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。
- 检查 Apache-2.0、后端私有、JAR/WAR 禁止进入公开仓库、Full 命名边界是否可发现。
- 执行 `git -C apps/web diff --check` 与 `git -C apps/desktop diff --check`。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- 项目决定严格禁止商业使用，改用 source-available 或非商业许可证。
- 项目决定采用 GPL/AGPL 等 copyleft 许可证。
- 后端源码决定公开，或公开仓库/后端仓库的边界发生重大调整。
- 发布策略决定公开分发后端 JAR/WAR，并接受对应反编译风险。

## 后续事项

- 第 9 步 GitHub Releases 产物边界已由 ADR 0012 继续明确：不做自动部署，后端 native 通过 GitHub Actions artifact 临时交接，主仓库 Release 公开后端 native archive 和聚合发布包。
- Desktop 用户可见安装包、Tauri flavor 入口和发布设计已收敛为 Full；后端代码模块是否从 `backend-all-in-one` 改名另行确认。
