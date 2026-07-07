# Release Manifest 校验脚本原型

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成；2026-06-09 已由后续小步补齐 JSON Schema 子集校验、样例检查和可选真实文件 sha256/size 校验
- 计划来源：用户确认在 release manifest schema 后，先补本地校验脚本原型
- 创建时间：2026-06-08
- 最后更新：2026-06-09

## 目标

新增 release manifest 本地校验脚本原型，并接入 docs 质量门禁，让后续 GitHub Actions workflow 可以复用同一入口。

本轮完成后应具备：

- 默认校验 `packages/shared/contracts/release/*.schema.json` 均存在且是合法 JSON。
- 可选校验 4 类 manifest 实例的基础边界字段：`schemaVersion`、`manifestKind`、`version`、`root.ref`、`root.commit`、sha256、后端 commit、asset/source 关系等。
- 可选扫描目录或 archive 的禁止文件规则原型，覆盖后端源码、JAR/WAR、`.class`、`target/classes` 和构建中间目录。
- `scripts/quality-gate.ps1 -Scope docs -NoBuild` 自动运行 release 校验脚本的默认 schema 检查。

## 非目标

- 本轮不实现完整 JSON Schema 引擎。
- 本轮不实现 GitHub Actions workflow。
- 本轮不修改后端私有仓库、Web、Desktop 或 App 代码。
- 本轮不生成真实 release 包、manifest 样例或 sha256 sums。
- 本轮不决定跨仓库 token、artifact 下载权限、安装器签名、公证、自动更新或 release notes。

## repo 内范围

- `scripts/release-manifest-check.ps1`
- `scripts/quality-gate.ps1`
- `docs/QUALITY.md`
- `packages/shared/contracts/release/README.md`
- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-release-manifest-check-script.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 `scripts/release-manifest-check.ps1`。
- [x] 将 release 校验接入 docs 质量门禁。
- [x] 更新质量文档、release 契约说明、ADR 0012 和总纲。
- [x] 运行脚本自身验证和 docs 质量门禁。
- [x] 归档计划并随本轮提交推送。

## 验收标准

- `scripts/release-manifest-check.ps1` 无参数运行时通过现有 4 个 schema 文件检查。
- 脚本支持通过参数传入 4 类 manifest 实例路径。
- 脚本支持通过参数传入待扫描目录或 archive 路径，发现禁止文件时失败。
- `scripts/quality-gate.ps1 -Scope docs -NoBuild` 会运行 release manifest 校验。
- 文档说明脚本当前是原型，不替代后续完整 CI workflow。

## 验证方式

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`
- 构造临时目录或 zip，验证禁止文件扫描能拦截 `.class` 或 JAR/WAR。
- `git diff --check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`

## 过程记录

- 当前脚本已由 2026-06-09 后续小步补齐 release schema 使用到的 JSON Schema 子集校验；它不是通用 JSON Schema 引擎，后续如果 schema 引入新关键字，需要同步扩展脚本或重新评估外部校验器。
- `.tar.gz` 扫描依赖本机 `tar` 命令；如果环境缺失，脚本会给出明确错误。
- 后续真实 workflow 仍需要接入 GitHub artifact 下载权限验证、真实发布上下文一致性、Release 上传和跨包 sha256 对齐。

## 状态记录

- 2026-06-08：创建计划并开始实施。
- 2026-06-08：完成 release manifest 本地校验脚本原型，接入 docs 质量门禁，并归档计划。
- 2026-06-09：后续小步已在同一脚本入口补齐 JSON Schema 子集校验、样例检查和可选 `-AssetRoot` sha256/size 校验；原“未集成完整 JSON Schema validator”和“未补 manifest 样例”风险已解决。

## 验证结果

- `rg -n "[^\x00-\x7F]" scripts/release-manifest-check.ps1`：无匹配，确认脚本内容保持 ASCII，避免 Windows PowerShell 5.1 读取 UTF-8 无 BOM 时误解析中文字符串。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1`：通过，4 个 release schema 文件均存在、可解析，`manifestKind.const` 与预期一致。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`：通过，release 契约目录未包含禁止的后端源码、JAR/WAR、`.class` 或构建中间目录。
- 临时构造 `.tmp/release-check-negative/target/classes/Leak.class` 负例：脚本按预期失败并报告 `编译 classes 目录` 规则命中；临时目录已清理。
- `git diff --check`：通过；仅提示部分工作区文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过；确认 docs 质量门禁已运行 release manifest 默认校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查。

## 归档备注

- 当前脚本覆盖 release schema 使用到的 JSON Schema 子集，不是通用 JSON Schema 引擎；后续 schema 如引入新关键字，需要同步扩展脚本或重新评估外部校验器。
- 当前禁止文件扫描支持目录、zip、tar/tar.gz/tgz；`.tar.gz` 依赖本机 `tar` 命令，环境缺失时会明确失败。
- 后续 GitHub Actions workflow 仍需要接入真实 artifact 下载、发布上下文一致性、Release 上传和跨包 sha256 对齐。
- 安装器签名、公证、自动更新、release notes 和版本号策略仍是第 9 步后续独立小项。

## 相关 commit

- 本计划随本轮提交 `功能：添加发布清单校验脚本` 归档；具体哈希以 Git 历史为准。
