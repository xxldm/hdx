# Web 首页工具箱布局网格

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：见下方 active plan 状态块。
- 计划来源：用户要求登录后首页改为用户端工具箱，可跨行跨列、拖拽排序，并允许考虑引入 VueUse。
- 创建时间：2026-06-16
- 最后更新：2026-06-22

<!-- active-plan-status:start -->
- 何时读取：修改 Web 首页工具箱布局、模块组件接入、布局持久化或首页视觉风格时读取。
- 当前状态：Web 首页工具箱主体、桌面宽度触摸兜底、主题入口、主要 UI/UX 收口项、widget registry 契约、固定菜单和顶栏边框路由进度反馈已完成。第一个正式 widget `timer` 已接入 registry/default layout，并用独立 store 按 `endsAt` 支持后台计时；旧占位 widget 已从 registry、默认布局、菜单和首页请求链路移除。全局未登录跳转已恢复。
- 下一步：继续按中心 registry 契约接入下一个真实模块；模块自身状态使用独立 store 或模块内边界，不写进 layout。菜单项若升级为真实页面，只更新 navigation registry 的 `to`/行为；页面自己的保存、编辑等操作挂到顶栏动作区。
- 主要剩余风险：除 `timer` 外仍未接入真实业务 widget；当前菜单里的 widget 项只定位/高亮首页已有 widget，不代表已有独立页面。
<!-- active-plan-status:end -->

## 目标

把 Web 登录后的首页从运行状态面板改成用户端工具箱首页：支持网格行列与间距配置，组件可跨行跨列，占位组件可拖拽排序，并把布局配置本地持久化。后续业务模块应通过明确的组件定义接入，而不是把组件列表和布局规则散落在页面里。

## 非目标

- 不实现真实模块市场、后台同步布局或权限化组件分发。
- 不引入复杂第三方 grid 编辑器；本轮先使用 Pointer Events 和明确的数据结构验证交互。
- 不处理 App 端首页。
- 不做手机 Web 窄屏适配；手机端体验由后续 App 承接。

## repo 内范围

- `apps/web/app/pages/index.vue`
- `apps/web/app/stores/`
- `apps/web/app/components/workbench/`
- `apps/web/app/utils/`
- `apps/web/i18n/locales/`
- `apps/web/package.json`
- `apps/web/pnpm-lock.yaml`

## 本地任务清单

- [x] 增加 VueUse 直接依赖，用于布局持久化。
- [x] 新增布局 store，使用 Zod 校验本地存储数据。
- [x] 新增组件注册表和占位工具组件。
- [x] 重写首页为可编辑工具箱网格，支持跨行跨列和拖拽排序。
- [x] 补充 i18n 文案和单元测试。
- [x] 临时放开未登录跳转用于首页调试，并记录恢复条件。
- [x] 运行 Web 与文档相关验证。
- [x] 按 Chrome 真实交互结果修复编辑态拖拽/缩放和头像菜单，并将动作按钮统一回 Nuxt UI 控件。
- [x] 新增首页菜单抽屉和顶栏固定菜单偏好，固定项本地持久化。
- [x] 接入第一个正式工具箱组件“计时器”，支持横/竖排列、自定义时长和后台计时。
- [x] 删除 `quick-links`、`tool-catalog`、`notes`、`runtime` 临时占位 widget，只保留真实注册模块。
- [x] 恢复全局未登录跳转，未登录访问首页会回到登录页并保留 redirect。

## 验收标准

- 首页第一屏是可用的工具箱网格，不再呈现正式后台仪表盘气质。
- 编辑模式下可以调整行数、列数、间距、组件跨度、添加/移除组件并保存或取消。
- 编辑模式下拖动整张组件到另一组件上可以实时预览并改变排序。
- 编辑模式下拖动右下角手柄可以实时预览组件跨行跨列变化，且非法缩放不会挤掉其它组件。
- 关键编辑操作不能只依赖 hover；桌面宽度触摸输入仍能通过 tap 或显式入口完成关键路径。
- 本地存储数据解析失败时回退默认布局，不让脏数据破坏首页。
- 明暗模式、移动端宽度和键盘焦点状态没有明显破损。

## 验证方式

- `pnpm test`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm build`
- `pwsh -NoLogo -NoProfile -File scripts/sync-active-plan-status.ps1 -Check`
- 浏览器手工验证首页编辑、拖拽、保存、取消和明暗模式。

## Nuxt UI 待优化清单

按 2026-06-19 Nuxt UI 技能审计结果，后续优化先处理 P2，再处理 P3。以下内容是当前事实源，避免后续只靠聊天记录恢复。

- 已完成：`apps/web/app/app.vue` 与 `apps/web/nuxt.config.ts`。`UApp` 已接入 Nuxt UI locale，并用 `useHead` 随 `@nuxtjs/i18n` 更新 `html lang/dir`。
- 已废弃：旧 `ToolboxNotesWidget.vue` 已随临时占位 widget 一起删除；后续随手记若作为真实模块接入，需要按当前 registry 契约和独立模块状态重新实现。
- 已完成：`apps/web/nuxt.config.ts` 与 `apps/web/app/app.config.ts`。已补齐 Nuxt UI 默认 7 语义色中的 `info`，给说明、提示和信息态组件留下语义出口。
- 已完成：统一 icon 命名规范。Web 页面、组件、widget registry 和 README 已从 `lucide:*` 迁移为 Nuxt UI v4 推荐的 `i-lucide-*`。
- 已完成：账号菜单保留 `UPopover mode="hover"` 的已验证 hover/touch 手感，同时补齐 trigger 的 `aria-haspopup`、`aria-expanded` 与内容区 `menu` 语义；若未来新增更复杂的账户动作或快捷键导航，再评估是否切到 `UDropdownMenu`。
- 已确认不作为 Nuxt UI 错用处理：`UPopover + UColorPicker` 符合官方示例；删除确认使用 popconfirm 形态符合当前交互；玻璃风格里的 raw `white/slate/cyan` 是项目视觉实现，不按组件 API 问题处理。

## 风险与阻塞

- 模块动态提供组件的正式契约还未设计完成，本轮注册表是本地边界占位。
- 当前拖拽和缩放为 Pointer Events 版本；不把手机 Web 作为适配目标，但桌面宽度触摸输入的命中区和 tap 退路需持续自测。
- 全局未登录跳转已恢复；后续产品化认证能力继续归认证计划处理。

## 状态记录

- 2026-06-16：创建计划，开始实现 Web 首页工具箱布局。
- 2026-06-16：主体实现完成后，为便于当前无后台服务阶段直接调首页，临时注释 Web 未登录跳转。
- 2026-06-16：浏览器中已看到首页网格和编辑态入口；用户确认编辑态可以打开。
- 2026-06-16：按用户反馈改为整卡拖动排序和右下角拖动缩放，拖动中实时预览；新增非法缩放保护，防止组件被挤出网格。
- 2026-06-17：按用户反馈移除右侧概览、可摆放组件和顶栏下方介绍，把布局编辑控制收进顶栏；头像改为只显示头像并使用下拉菜单。
- 2026-06-17：改用 Chrome 复测内置浏览器疑似鼠标兼容问题；确认 `UDropdownMenu` 与 `UButton` 可正常工作，将本轮新增动作按钮统一回 Nuxt UI 控件。
- 2026-06-17：Chrome 验证整卡拖动排序不再飞走或回弹，右下角缩放可从 `1x1` 拉到 `1x2`，缩放过程不再整卡变白。
- 2026-06-17：按用户反馈修复拖拽回拉和多目标重叠问题；参考 `v3-grid-layout` 的 `calcXY`、row/col 排序和单碰撞目标思路，改为把拖动卡片投影到网格坐标后只选择一个碰撞目标。
- 2026-06-17：继续修复拖拽中图 2/3/4 多个预览状态反复跳动的问题；命中检测不再每帧读取预览后的 DOM，而是使用拖拽开始时记录的目标位置和顺序快照。
- 2026-06-17：修复 `连接状态` 从左往右拖到 `随手记` 上半区时预览撤回的问题；起拖组件和目标组件原始行重叠时按横向 before/after 判断。
- 2026-06-17：按用户确认改为保存明确坐标；布局 store 持久化 `row`、`column`、`colSpan`、`rowSpan`，删除或移动组件不再自动紧凑补洞，拖到空位移动坐标，拖到组件尝试交换坐标。
- 2026-06-17：修复小组件拖到大组件内部时只能落到大组件左上角的问题；命中组件时使用拖拽卡片投影到网格后的实际目标格子。
- 2026-06-17：继续修复小组件落到大组件内部非左上格子的提交路径；松手时也提交投影坐标，并在大组件直接交换会撞车时把大组件挪到最近可用位置。
- 2026-06-17：移除真实空格预览和特殊添加组件格子；空白格只在 hover 时显示悬浮添加入口，选择组件后写入该坐标，避免空格参与 CSS grid 自动排布和拖拽碰撞。
- 2026-06-18：用浏览器临时 debug 日志确认问题在动画层而不在坐标层；组件坐标变化正确，但 Vue `TransitionGroup` 未稳定给跨格让位组件 move class，于是加了手动 FLIP 兜底。
- 2026-06-18：按用户反馈把拖到组件时的提交语义从“交换位置/最近空位”改为“按拖动方向最小必要格数挤开”，让 `1` 格高组件挤压大卡时优先只顺延 `1` 格，更接近手机桌面体验。
- 2026-06-18：用户确认 Web 首页不做手机 Web 专项适配；文档同步明确桌面优先、手机端由 App 承接，但保留桌面宽度触摸输入和关键操作的 tap 退路。
- 2026-06-18：继续收口桌面宽度触摸输入：空白格可 tap 后显示添加入口，卡片触摸首 tap 只选中并显示编辑动作，鼠标移出会隐藏固定动作，编辑动作收敛为角落“修改组件”，移除组件改为弹层确认；卡片 hover 显示使用显式 hover media query，触摸合成 click 误触由事件守卫处理。
- 2026-06-18：接入全局主题颜色入口，补一套类似 Nuxt UI 文档站的主题管理，允许预设色与 ColorPicker 自定义共存，并保留登录/首页的液态玻璃渐变背景。
- 2026-06-19：用 UI/UX、Web Guidelines、Nuxt/Vue 技能做辅助审计；整体视觉方向成立，优先缺口是主题双轨和主题选中语义。用户确认编辑态是布局模式，卡片内容只作预览，不承载业务操作；整卡 `touch-action: none` 合理保留。
- 2026-06-19：收口主题双轨；主题 store 统一通过 Nuxt UI `primary/neutral` 语义色阶写入预设色和自定义色，主题设置面板补 `aria-pressed`，点击自定义色不再重置已保存的自定义值。
- 2026-06-19：明确工具箱布局编辑是强视觉、强空间定位交互。Tauri 本身不提供屏幕阅读器，但 WebView 可接系统 Accessibility API；当前项目不为工具箱布局编辑做单独屏幕阅读器适配。保留图标按钮等基础可读名称，但不为卡片和空位坐标强行补复杂 `aria-label`。
- 2026-06-19：把 UI/UX 审计清单收口为明确状态：主题双轨、主题选中语义、图片显式尺寸、登录页桌面细指针自动聚焦和删除按钮 Nuxt UI 化已修；整卡 `touch-action: none`、头像 `UPopover mode="hover"` 和 resize 原生手柄为当前交互决策保留；共享玻璃 surface、拖拽/缩放 composable 拆分和字体评估列为后续结构债。
- 2026-06-19：确定并落地真实模块接入前的契约边界：registry 只声明模块事实（稳定 `key`、i18n 标题/描述、图标、组件、默认尺寸、可选 constraints、支持方向）；layout 只保存实例展示偏好（坐标、跨度、`chrome`、`orientation`、`header.visible/icon/title/description`）。`chrome` 默认 `card` 且所有组件默认支持，不进入模块注册；`orientation: auto` 由容器统一解析，模块不接收布局、编辑态、外壳或统一 data。
- 2026-06-19：为组件缩放触达 constraints 或网格边界时补充视觉反馈；resize 手柄和卡片边缘会进入短暂警示态，并显示“已到最小/最大尺寸”提示。store 和 UI 反馈共用 `constrainWorkbenchWidgetSpan`，避免限制规则分叉。
- 2026-06-19：继续收口主题半径一致性；新增 `--hdx-radius-*` 派生 token，使登录页、首页顶栏、布局编辑工具框、浮层、工具箱卡片、添加占位和占位 widget 跟随主题圆角。纯圆形头像、图标按钮、颜色 swatch、关闭按钮和 resize 角标保留自身形态语义；账号入口改用 Nuxt UI `UAvatar`，无头像时用文字兜底。
- 2026-06-20：收口 Nuxt UI P3 账号菜单语义。继续保留已通过真实交互验证的 `UPopover mode="hover"`，同时为头像触发器补齐 `aria-haspopup="menu"`、`aria-expanded`、`aria-controls`，菜单项点击后显式关闭浮层。
- 2026-06-21：跳过登录拦截恢复，继续收口视觉结构债。已把登录页和首页重复维护的背景层、液态光场、网格纹理、浮层菜单和图标工具按钮抽到 `app/assets/css/main.css` 的 `hdx-*` 共享类；页面内只保留面板、品牌、表单和账号入口等局部差异。
- 2026-06-21：登录页精简主题面板的外观选项改为竖向列表，避免 `跟随系统` 在窄浮层中被截断；完整主题面板仍保留三列选项。
- 2026-06-21：继续收口 `ToolboxGridItem.vue` 结构债；已把拖拽命中和预览提交抽到 `use-workbench-widget-drag.ts`，把缩放和 constraints 反馈抽到 `use-workbench-widget-resize.ts`，把移除确认、触摸首击防误触和清理定时器抽到 `use-workbench-widget-edit-surface.ts`。
- 2026-06-21：修复拖拽组件继续越过目标中心后，预览推挤方向从原始相对位置翻转的问题。拖到组件时的 push direction 现在优先锚定起拖组件与目标组件的原始上下/左右关系，只有原始轴向重叠时才回退到当前中心点。
- 2026-06-21：修复 `随手记` 这类多行组件拖到第 0 行失败的问题。链式挤开过程中，拖动源组件现在作为固定目标排除在递归碰撞移动之外，允许被挤开的组件跨过与源组件的中间重叠格，最后再统一校验是否完全让开。
- 2026-06-21：确定首页导航形态为左侧菜单抽屉加桌面宽屏顶栏固定项；用户置顶偏好由独立 `workbench-navigation` store 本地持久化。菜单里的组件项先定位/高亮首页已有 widget，后续真实页面接入时只更新 navigation registry。
- 2026-06-21：为路由跳转增加全局 client 进度状态，并在首页顶栏边框上渲染主题色进度光带。当前顶栏仍在首页内，后续若抽成全局 App Shell，可复用该进度状态。
- 2026-06-22：把工具箱顶栏抽为 Nuxt 默认 layout，登录页显式 `layout: false` 保持独立；新增空白 `/settings` 页面测试默认 layout。页面级动作不写进 layout，首页通过 `#workbench-topbar-actions` 挂载“整理布局”等按钮。
- 2026-06-22：为方便定稿顶栏边框进度条观感，`route-progress.client.ts` 曾在开发环境临时延迟路由跳转 5 秒；进度条定稿后已删除该延迟。
- 2026-06-22：按用户反馈把顶栏边框进度改为从左侧同时顺时针、逆时针各扫半圈到右侧；进度节奏改用 Nuxt 默认 `estimatedProgress`。视觉层已从 conic-mask 改为 SVG `pathLength`，避免矩形边框内外沿出现两条不同步的进度线。
- 2026-06-22：接入第一个正式工具箱 widget `timer`。计时器默认 `1x1`、不设置尺寸 constraints；时长默认 10 分钟并可自定义，运行状态由 `workbench-timer` store 持久化 `durationSeconds`、`remainingSeconds` 与 `endsAt`，不混入 layout store。
- 2026-06-22：恢复 `auth.global.ts` 全局未登录跳转；未登录访问工作台会跳转 `/login` 并保留 redirect，已登录访问登录页会回到内部 redirect 目标。
- 2026-06-22：按用户确认删除旧临时占位 widget。`quick-links`、`tool-catalog`、`notes`、`runtime` 已从 widget registry、默认布局、菜单项和首页 `runtime/tools` 概览消费链路移除；旧本地/远端布局若带这些 key，会按当前默认布局回退到 `timer`。

## 验证结果

- 已通过：`pnpm test`、`pnpm typecheck`、`pnpm lint`、`pnpm build`、`git diff --check`。
- 空白格 hover 添加、小组件落到大组件内部非左上格子和“最小挤开”规则接入后，均已重新通过相称的 Web 验证。
- 2026-06-18：触摸输入与卡片工具条收口后重新通过 `pnpm test`、`pnpm typecheck`、`pnpm lint`、`pnpm build`、`git diff --check`。
- 2026-06-19：主题语义收口后通过 `pnpm test tests/unit/theme-preference-store.test.ts`、`pnpm typecheck`、`pnpm lint`、`pnpm test` 和相关文件 `git diff --check`。
- 2026-06-19：工具箱可访问性边界收口后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test` 和相关文件 `git diff --check`。
- 2026-06-19：组件缩放边界反馈后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test tests/unit/workbench-layout-store.test.ts` 和相关文件 `git diff --check`。
- 2026-06-19：主题圆角和账号头像收口后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test tests/unit/theme-preference-store.test.ts`、`pnpm test`、相关文件 `git diff --check` 和计划索引同步检查。
- 2026-06-19：Nuxt UI P2 收口后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`、相关文件 `git diff --check` 和计划索引同步。
- 2026-06-19：补齐 Nuxt UI `info` 语义色后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`、相关文件 `git diff --check` 和计划索引同步。
- 2026-06-20：统一 Nuxt UI icon 命名后通过 `rg "lucide:" apps/web`、`pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`、相关文件 `git diff --check` 和计划索引同步。
- 2026-06-20：账号菜单语义收口后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`、相关文件 `git diff --check` 和计划索引同步。
- 2026-06-21：共享背景层、浮层菜单、工具按钮样式和精简主题面板布局后通过 `pnpm typecheck`、`pnpm lint`、`pnpm build`、`pnpm test`、相关文件 `git diff --check` 和计划索引同步。
- 2026-06-21：`ToolboxGridItem.vue` composable 拆分后通过 `pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build` 和相关文件 `git diff --check`；build 仍只有既有工具链 warning。
- 2026-06-21：拖拽推挤方向修复后通过 `pnpm test tests/unit/workbench-widget-drag.test.ts`、`pnpm test tests/unit/workbench-layout-store.test.ts`、`pnpm typecheck`、`pnpm lint`、`pnpm test` 和 `pnpm build`；build 仍只有既有工具链 warning。
- 2026-06-21：多行组件顶行投放修复后通过 `pnpm test tests/unit/workbench-layout-store.test.ts`、`pnpm test tests/unit/workbench-widget-drag.test.ts`、`pnpm typecheck`、`pnpm lint`、`pnpm test` 和 `pnpm build`；build 仍只有既有工具链 warning。
- 2026-06-21：首页导航抽屉和顶栏固定菜单通过 `pnpm test tests/unit/workbench-navigation-store.test.ts`、`pnpm typecheck`、`pnpm lint`、`pnpm test` 和 `pnpm build`；build 仍只有既有工具链 warning。Playwright 使用本机 Chrome 验证：左侧菜单抽屉可打开，默认固定项显示在宽屏顶栏，固定 `连接状态` 后顶栏更新，点击后会高亮对应 widget。
- 2026-06-21：顶栏边框路由进度反馈通过 `pnpm typecheck`、`pnpm lint`、`pnpm test`、`git diff --check`，并用本机 Chrome/Playwright 强制打开进度态确认亮/暗模式下圆角边框光带可见且不遮挡顶栏内容。
- 2026-06-22：默认 layout 与空白设置页通过 `pnpm typecheck`、`pnpm lint`、`pnpm test` 和 `git diff --check`。Chrome/Playwright 验证：`/` 有顶栏和首页整理布局动作，`/settings` 有顶栏但无首页动作，`/login` 不显示顶栏。
- 2026-06-22：顶栏进度节奏改为 Nuxt 默认估算公式，边框进度改为 SVG 半路径 dash 渲染；通过 `pnpm test tests/unit/route-progress.test.ts`、`pnpm typecheck`、`pnpm lint` 和根/ Web `git diff --check`。
- 2026-06-22：顶栏进度条定稿后删除开发态 5 秒路由延迟；圆角主题变化会主动重读顶栏真实 `border-radius`。通过 `pnpm test`、`pnpm typecheck`、`pnpm lint`。
- 2026-06-22：计时器 widget 接入后通过 `pnpm test tests/unit/workbench-timer-store.test.ts`、`pnpm test tests/unit/workbench-layout-store.test.ts`、`pnpm typecheck`、`pnpm lint`、`pnpm test` 和 `pnpm build`；build 仍只有既有工具链 warning。
- 2026-06-22：恢复全局未登录跳转后通过 `pnpm test -- tests/unit/auth-middleware.test.ts`（Vitest 实际运行当前全部 Web 单测）、`pnpm typecheck` 和 `pnpm lint`。
- 2026-06-22：删除旧占位 widget 后通过 `pwsh -NoLogo -NoProfile -File scripts/web-verify.ps1`，覆盖 Web 空白检查、98 个单测、Nuxt typecheck 和 ESLint；本轮未跑 build。
- 浏览器验证：Chrome 已打开 `http://localhost:3000/`；确认头像菜单可打开并点外部关闭、编辑态可打开、整卡拖动排序可提交、右下角拖动缩放可实时改变跨行跨列，且缩放时卡片保持透明度反馈而不是变白。2026-06-18 用户确认“快捷入口”挤压与回位的手感已明显改善，当前感觉不错；同时确认当前范围不要求手机 Web 适配，但后续仍保留桌面宽度触摸输入。
- 构建 warning：仍有 Nuxt/Tailwind sourcemap、VueUse Rollup PURE 注释、chunk > 500 kB 和 DEP0155 trailing slash export warning；本轮未改变这些既有工具链风险。

## 剩余风险

- 除计时器外，当前尚未接入其它真实业务 widget。
- 本轮以桌面 Chrome 做真实鼠标交互验证；内置浏览器可能仍有鼠标事件兼容差异。
- 组件方向目前已由容器统一解析并传给占位组件，但占位组件暂未按横/竖方向改变内部排版；真实模块接入时按需使用该 prop。
- 登录页与首页的背景层、浮层菜单和工具按钮已共享；部分卡片、表单和 widget 内部 surface 仍是局部样式，后续页面继续扩展前可继续收敛到共享 CSS layer。
- `ToolboxGridItem.vue` 已拆出拖拽、缩放和编辑 surface composable；后续继续改编辑器时，应优先扩展这些 composable，而不是把 pointer 副作用重新塞回组件。
- resize 手柄当前保留原生 button，原因是它是特殊拖拽控件；只有在 Nuxt UI 控件不影响 pointer 捕获、拖拽手感和圆角视觉时，再考虑统一回框架按钮。
- 当前字体可用但未作为独立视觉刷新处理；如果后续继续强化年轻化、个人工具箱气质，再评估更圆润的正文字体，不作为当前主题收口阻塞项。

## 相关 commit

- `dec5a48 功能：重做首页工具箱布局`（`apps/web`）
- `4a47733 功能：收口首页工具箱编辑体验`（`apps/web`）
- `dbac2f2 功能：收口工具箱布局编辑与动画`（`apps/web`）
- `6d4f1b7 功能：改为按方向最小挤开组件`（`apps/web`）
- `07036d5 功能：收口删除确认弹层`（`apps/web`）
- `78f455c 重构：抽取 Web 共享视觉样式`（`apps/web`）
- `1d58b5d 杂项：移除工作台占位组件`（`apps/web`）
