# 工具箱 Widget 与模块数据契约

本文档记录 Web 首页工具箱接入真实模块前的边界。长期数据同步原则见 ADR 0016；本文只说明 widget registry、布局持久化、模块配置和设备运行态各自负责什么。

## 当前结论

- Widget registry 由 Web 静态导入 Vue 组件，不做运行时动态发现。
- Registry 只声明模块事实：稳定 `key`、i18n 标题/描述、图标、组件、默认尺寸、可选尺寸约束、支持方向和数据边界。
- Layout 只保存实例展示偏好：坐标、跨度、`chrome`、`orientation`、header 显示项和必要配置引用。
- 模块业务数据和模块配置由模块拥有独立 API、表和冲突策略，不塞进 layout。
- 设备级运行态只属于当前设备，不跨 Web、Desktop Online 和 App 同步。
- 首页组件只提供可选项和默认实例；显示不显示、显示在哪里、占多大空间，由用户在工作台布局里决定。
- 新账号默认布局只是启动建议，不是信息架构约束；用户后续可以删除、移动、缩放或重新添加组件。
- 日期倒计时当前以人工维护的事件或节日数据为事实源；暂不设计自动维护调休、农历节日推算或工作日历同步。
- 后续接入 todo 等真实模块时，优先按模块独立 API、store/composable 和可选 `configRef` 注入模块数据依赖；registry 只声明数据边界，不提供运行时组件或业务数据注入。

## Registry 声明什么

Web 当前事实源是 `apps/web/app/utils/workbench-widget-meta.ts`。

每个 widget 必须声明：

- `key`：稳定模块 key，进入 layout 和导航偏好。
- `titleKey` / `descriptionKey` / `icon`：模块默认展示材料；是否显示由 layout 的 header 偏好控制。
- `defaultLayout`：新增实例时的默认跨度。
- `constraints`：可选；不传表示不限制尺寸，只受网格边界限制。
- `supportedOrientations`：可选；不传等同支持 `auto`、`horizontal`、`vertical`。
- `data.moduleData`：模块是否读取共享业务数据，以及对应接口入口；例如日期倒计时读取 `/api/v1/holidays` 节日列表。
- `data.modulePreferences`：模块偏好是否账号级同步，以及对应接口入口。
- `data.runtimeState`：运行态是否设备级保存，以及端侧存储方式。

`chrome`、坐标、编辑态、拖拽状态和外壳 UI 不属于模块注册。模块组件只接收容器解析后的展示方向等必要展示输入，不应知道 layout、editing 或统一 chrome 的内部细节。

## Layout 保存什么

工作台 layout 是账号级用户数据，服务端为事实源。它保存的是“哪个 widget 实例在什么位置、以什么外观展示”。

当前 layout widget 字段边界：

- `id`
- `key`
- `order`
- `column` / `row`
- `colSpan` / `rowSpan`
- `chrome`
- `orientation`
- `header.visible` / `header.icon` / `header.title` / `header.description`

Layout 不能保存模块业务内容。例如计时器预设、笔记内容、文件路径、同步记录、运行中剩余秒数都不应进入 layout。

后续如果某个 widget 需要引用模块内某条记录，可以增加稳定 `configRef` 或类似引用字段，但引用目标的内容、版本和冲突处理仍由模块 API 负责。

## 默认布局与首页组件

默认布局遵守以下规则：

- 默认布局优先放高频、个人向、可快速处理的组件。
- 默认布局不要把候选池、公开发现、空间管理、实例管理等低频管理能力放进首页。
- 列表型组件固定外部尺寸，内部滚动；组件内容变化不能把网格撑开。
- 首页组件只承担查看和快速操作，不承载复杂配置、权限管理、完整历史或后台管理。
- 模块完整页面和设置页负责筛选、配置、批量管理和复杂流程。
- 公开流可以作为首页小组件，但公开发现不进入首页；公开发现只作为查找公开主页或事项的页面。
- 协作事项第一版不做首页一级组件；关联入口和完整详情页由协作模块自己提供。
- 如果用户没有某个组件所需能力或来源，组件库可以隐藏或禁用该组件，但 layout 不保存后端返回的业务内容。

## 模块配置怎么放

模块配置是用户可感知、可修改、需要跨设备同步的数据时，应由模块提供独立后端契约。

默认规则：

- 独立 API，不挂在 `/workbench/layout` 下。
- 独立表或清晰从属表，遵守 `docs/BACKEND_DATA_ACCESS.md` 和 ADR 0016。
- 可变父记录默认使用 JPA `@Version`。
- 普通读取过滤软删除。
- 保存时携带基础版本；冲突返回稳定 `code` 和服务器当前值或摘要。

计时器当前是第一片样例：

- 账号级配置：`/api/v1/timer/preferences` 保存预设时长列表。
- 设备级运行态：当前剩余时间、结束时间、暂停和响铃确认保存在 Web 本地运行态。
- Layout 只保存 `timer` widget 的位置、大小、外观和方向。

日期倒计时当前是人工维护数据样例：

- 共享数据：`/api/v1/holidays` 读取已维护事件或节日列表。
- 管理能力：管理员页面维护固定日期事件或节日；业务上暂不要求自动生成调休、农历节日或工作日历。
- Layout 只保存 `date-countdown` widget 的位置、大小、外观和方向，不保存具体事件内容。

后续 todo、随手记等模块如果需要用户私有业务数据，应新增模块自己的 API、表、版本和冲突响应；工作台容器可以通过模块 store/composable 或稳定引用把数据传给组件，但不让 layout 承担业务数据存储。

## Widget Registry 是否需要后端化

当前不需要。

原因：

- Vue 组件必须由 Web 打包期静态导入，后端不能动态提供前端组件实现。
- 当前模块数量少，权限化分发尚未开始，静态 registry 更可读、可测、可 tree-shaking。
- 后端更适合拥有模块数据 API、权限、记录版本和冲突响应，而不是拥有前端组件发现。

后续如果出现“不同用户可用 widget 不同”的需求，可以新增模块目录或能力接口，例如 `/api/v1/workbench/widgets`。该接口只返回可用模块 key、权限和服务端能力，不返回 Vue 组件，也不替代 Web 静态 registry。

## 新模块接入检查

接入真实 widget 前，先回答：

1. 这个模块有没有账号级配置或业务数据？
2. 哪些数据需要跨设备同步，哪些只属于设备运行态？
3. 是否需要独立后端 API、表、版本和冲突响应？
4. Layout 是否只保存展示偏好和必要引用？
5. Registry 是否声明了 `data.moduleData`、`data.modulePreferences` 和 `data.runtimeState`？
6. Desktop Full 是否需要进入本机数据库，而不是 Tauri app config？
7. 移动端 App 后续是否会离线暂存该模块的修改？如果会，需要提前设计幂等键和冲突策略。

## 验证入口

- Web registry 边界：`apps/web/tests/unit/workbench-widget-meta.test.ts`
- Layout 行为：`apps/web/tests/unit/workbench-layout-store.test.ts`
- 计时器模块配置：`apps/web/tests/unit/workbench-timer-store.test.ts`
- 日期倒计时共享数据：`apps/web/tests/unit/workbench-date-countdown-store.test.ts`
- 后端数据访问扫描：`pwsh -NoLogo -NoProfile -File scripts/check-backend-data-access.ps1 -ChangedOnly`
