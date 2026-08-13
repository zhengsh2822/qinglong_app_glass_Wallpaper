# qinglong_app_glass_Wallpaper

基于 Flutter 框架编写的青龙面板第三方客户端（可更换壁纸版本）

基于 [qinglong](https://github.com/whyour/qinglong) 开源项目，二改自 [ayoulx/qinglong-app](https://github.com/ayoulx/qinglong-app)

> 本项目在原项目基础上进行了主题系统重构、多账号安全增强、仪表盘功能扩展、脚本搜索能力补全、京东助手独立模块化、全局可更换壁纸系统、统一毛玻璃组件体系等改进，并移除了部分不兼容的依赖与功能。
## 相关项目

- [qinglong_app_glass](https://github.com/zhengsh2822/qinglong_app_glass) — 主题版本

## App 功能介绍

### 仪表盘（对齐 Web 端）

并行调用 7 个 dashboard 接口，老版本服务端会自动隐藏不支持的卡片：

- **青龙版本信息**：服务端版本号展示
- **任务概览**：总任务/已启用/已禁用/今日执行/今日成功/今日失败/成功率/平均耗时
- **近 7 日趋势**：自绘折线图（纯 `CustomPaint`，无 fl_chart 依赖），含网格线、Y 轴刻度、X 轴日期、总趋势线（渐变区域填充）、成功/失败虚线、数据圆点
- **今日耗时 Top 5**：排名/任务/平均耗时/最长单次
- **今日执行次数 Top 5**：排名/任务/次数/平均耗时/成功率
- **标签统计**：标签/任务数/今日执行/成功率/平均耗时
- **实时运行态**：运行中/排队中数量、正在运行任务（含 PID）、24 小时未运行任务
- **系统资源**：平台/CPU 核心/系统负载/运行时长/内存与堆内存进度条

### 定时任务

- 任务列表卡片化展示，支持左/右滑动操作（启用/禁用、收藏、运行、编辑、删除等）
- 切换底部导航 Tab 时自动收起所有展开的滑动卡片（全局 `SlidableCloseNotifier` 通知器 + `ValueKey` 重建机制）
- 任务详情、即时日志、历史日志查看
- 日志支持长按选择复制，并启用 iOS 风格文本选择放大镜

### 环境变量

- 列表/分组管理，滑动操作与任务页一致
- Tab 切换自动收起滑动卡片
- 详情页支持长按复制与 iOS 风格放大镜

### 订阅管理

- 订阅列表滑动操作（运行、编辑、删除等）
- Tab 切换自动收起滑动卡片
- 详情页支持长按复制

### 脚本管理

- 树形目录展示，顶部常驻胶囊形搜索栏（圆角 24），300ms 防抖递归过滤文件名/目录名
- 脚本查看/编辑页：点击右上角搜索图标弹出搜索卡片，支持 `/re/flags` 正则语法，200ms 防抖
- 搜索卡片含上一个（chevron_up）/下一个（chevron_down）/关闭（xmark）按钮
- 通过 `WebView.runJavaScript` 注入 `appSearch/appSearchNext/appSearchPrev` 函数，使用 CodeMirror `getSearchCursor` + `markText` 高亮匹配
- CSS 类 `.cm-app-search-match` / `.cm-app-search-current` 区分普通匹配与当前匹配
- 代码高亮基于 `flutter_highlight`，支持 90+ 主题
- 代码区 `SelectableText.rich` 同样启用 iOS 风格放大镜

### 京东助手（独立模块）

- 独立青龙面板登录，自动从应用设置获取 clientId/clientSecret
- Cookie 上传前校验 pt_key/pt_pin
- 账号与青龙配置备份/恢复
- 添加/编辑/删除账号弹窗统一使用 `_showBlurDialog` 模糊展开动画与卡片样式（三主题一致）

### 其他功能

- 配置文件管理、依赖管理（缺失依赖扫描）、登录日志、任务日志
- 应用内购买、推送设置、字体设置（字体大小+主/次字体颜色自定义 HSL 选色器）、修改密码、账号排序、iCloud 备份
- 检查更新、关于页面
- 全局可更换壁纸系统（渐变/纯色/本地图片/网络图片），支持模糊度与暗化调节
- 适配安卓小白条和状态栏沉浸效果

## 主要改进

### 新增功能与设计

- **全局可更换壁纸系统**：`WallpaperService` 单例管理壁纸配置（渐变/纯色/本地/网络），`WallpaperBackground` 在 main.dart Stack 底层渲染，所有 Scaffold 透明化，路由级独立壁纸背景
- **统一毛玻璃组件体系**：`GlassCard`（通用卡片）/ `GlassListItemCard`（列表项）/ `GlassAppBarContainer`（顶部 AppBar）/ `SettingsCard`（设置页）/ `GlassPageBackground`（列表页面背景）/ `GlassSegmentedTab`（分段 Tab）/ `GlassTextField`（胶囊输入框），支持全局模糊度调节
- **三种主题模式**：赛博朋克（青色霓虹 #00F0FF + 玻璃态背景 + BackdropFilter 模糊）、Apple（#00cccc 纯色 + BackdropFilter 模糊弹窗）、白色（18px 圆角统一规范）。黑色主题已合并入赛博模式
- **主题切换动画**：基于 `AnimatedTheme`（300ms easeInOut）实现当前页面平滑过渡
- **字体自定义**：字体大小全局调节 + 主/次字体颜色独立自定义（HSL 色相/饱和度/明度三条滑块），通过 `ThemeViewModel` 全局通知生效
- **多账号 HTTP 缓存隔离**：HTTP 缓存按账号隔离，防止跨账号数据泄漏
- **仪表盘功能扩展**：新增 4 个 API 端点（`/api/dashboard/trend`、`/top-time`、`/top-count`、`/labels`）及对应 UI 模块，自绘折线图（`CustomPaint`，无 fl_chart 依赖），老版本服务端自动隐藏不支持的卡片
- **脚本搜索能力补全**：脚本列表页常驻搜索过滤；脚本查看/编辑页弹出式搜索卡片，支持正则语法、上下导航、200ms 防抖、CodeMirror 高亮匹配
- **Slidable 跨 Tab 自动收起**：全局 `SlidableCloseNotifier`（`ValueNotifier<int>`）在底部导航切换时通知任务/环境变量/订阅三个页面，通过更新 `ValueKey` 强制重建 Slidable 卡片以重置展开状态
- **iOS 风格文本选择放大镜**：11 个文件的 `SelectableText` / `SelectableText.rich` 应用了 `cupertinoTextSelectionControls`，覆盖日志、任务详情、环境变量详情、订阅详情、代码高亮等可复制区域
- **京东助手独立模块**：独立青龙面板登录、自动从应用设置获取 clientId/clientSecret、Cookie 上传前校验 pt_key/pt_pin、账号与青龙配置备份/恢复
- **京东助手弹窗统一**：添加/编辑/删除账号弹窗统一使用 `_showBlurDialog` 模糊展开动画与卡片样式，三主题一致
- **按钮配色统一**：非破坏性长按钮使用主色渐变 `[primaryColor, primaryColor.withOpacity(0.85)]`，Apple 主题为 #00cccc 渐变；破坏性按钮保留红色渐变
- **赛博模式搜索框深色化**：搜索框在赛博模式下使用 `0xFF12121A` 深色背景 + 青色微光边框，解决白底问题
- **统一滑动操作**：任务/环境变量/订阅三个页面统一使用 `Slidable + SlidableAction`，赛博与非赛博模式结构完全一致，仅配色不同
- **统一设计规范**：所有搜索框/输入框胶囊形状（borderRadius 24）、卡片统一 18px 圆角、依赖管理 Tab 胶囊样式（24px 圆角 + 青色 thumb）
- **HTTP 容错**：`ResponseType.plain` + 手动 `jsonDecode`，过滤底层库 JSON 解析错误
- **构建脚本**：`build_apk.ps1` 禁用 R8 优化（`--no-shrink`），自动复制 APK 到 apk_output 目录，自动检测 ADB 设备并安装
- **沉浸式适配**：`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` + 透明 `SystemUiOverlayStyle`，适配安卓小白条和状态栏

### 移除的不兼容功能与依赖

- **App 内消息推送功能**（原项目 2.6.3 已移除，本项目延续此变更）
- **`convex_bottom_bar`**：改用自定义底部导航
- **`cached_network_image`**：移除网络图片缓存库
- **`file_picker`**：移除文件选择器
- **`quick_actions`**：移除桌面快捷方式
- **`flutter_dynamic_icon`**：移除动态图标切换
- **`flutter_scroll_to_top`**：移除列表顶部跳转
- **`json_table` / `extended_text`**：移除表格与扩展文本
- **`launch_review` / `package_info_plus` / `move_to_background`**：移除评分跳转、包信息、后台运行
- **`dio_log` / `json_conversion`**：移除网络日志与 JSON 转换注解
- **`CyberSlidable` 组件**：弃用，统一为标准 `Slidable`
- **Lottie 扫描动画**：弃用无效的 `assets/scan.json`，改用 `CupertinoIcons.doc_text_search`
- **主题切换强制跳转首页逻辑**：移除 `MaterialApp` 的 `key: ValueKey(themeMode)` 与 `onThemeChanged` 回调

### 依赖升级

- Dart SDK：`>=2.18.0` → `^3.7.2`
- `dio`：`4.0.6` → `5.7.0`
- `flutter_slidable`：`2.0.0` → `3.1.2`
- `shared_preferences`：`2.0.15` → `2.3.4`
- `flutter_riverpod`：`2.1.1` → `2.6.1`

## 致谢

### 上游项目

- [whyour/qinglong](https://github.com/whyour/qinglong) — 青龙面板服务端
- [ayoulx/qinglong-app](https://github.com/ayoulx/qinglong-app) — 原客户端项目
- [yclown/ql_jd_cookie](https://github.com/yclown/ql_jd_cookie)@XanderYe - 原版京东助手作者
- [yclown/jdck-android](https://github.com/yclown/jdck-android)@yclown - 原版修改者

### 开源依赖（Flutter / Dart 包）

| 依赖 | 用途 |
| --- | --- |
| [flutter](https://github.com/flutter/flutter) | UI 框架 |
| [flutter_localizations](https://github.com/flutter/flutter) | 国际化支持 |
| [cupertino_icons](https://github.com/flutter/flutter/tree/master/packages/cupertino_icons) | iOS 风格图标 |
| [flutter_riverpod](https://github.com/rrousselGit/riverpod) | 状态管理 |
| [shared_preferences](https://github.com/flutter/packages/tree/main/packages/shared_preferences) | 本地键值存储 |
| [synchronized](https://github.com/dart-archive/synchronized) | 同步锁 |
| [back_button_interceptor](https://github.com/Marcio-Quimbunde/back_button_interceptor) | 返回键拦截 |
| [flutter_slidable](https://github.com/letsar/flutter_slidable) | 列表项滑动操作 |
| [dio](https://github.com/cfug/dio) | HTTP 网络请求 |
| [logger](https://github.com/SourceHorizon/logger) | 日志输出 |
| [intl](https://github.com/dart-lang/intl) | 国际化与日期数字格式化 |
| [get_it](https://github.com/fluttercommunity/get_it) | 依赖注入 |
| [highlight](https://github.com/git-touch/highlight.dart) / flutter_highlight | 代码语法高亮（90+ 主题） |
| [drag_and_drop_lists](https://github.com/JonathanMcclellan/drag_and_drop_lists) | 账号排序拖拽 |
| [fluttertoast](https://github.com/PonnamKarthik/FlutterToast) | Toast 提示 |
| [flutter_displaymode](https://github.com/JonathanMcclellan/drag_and_drop_lists) | 屏幕高刷新率支持 |
| [flip_card](https://github.com/fedeoo/flip_card) | 翻转卡片动画 |
| [url_launcher](https://github.com/flutter/packages/tree/main/packages/url_launcher) | URL 跳转 |
| [share_plus](https://github.com/fluttercommunity/plus_plugins/tree/main/packages/share_plus) | 系统分享 |
| [flutter_colorpicker](https://github.com/mchudy/flutter_colorpicker) | 颜色选择器 |
| [flutter_animator](https://github.com/codegrue/flutter_animator) | 动画工具 |
| [local_auth](https://github.com/flutter/packages/tree/main/packages/local_auth) | 生物识别（指纹/Face ID） |
| [pretty_dio_logger](https://github.com/Jeelscode/pretty_dio_logger) | Dio 网络日志 |
| [icloud_storage](https://github.com/rekab-dev/icloud_storage) | iCloud 备份 |
| [path_provider](https://github.com/flutter/packages/tree/main/packages/path_provider) | 文件路径 |
| [date_format](https://github.com/dart-lang/date_format) | 日期格式化 |
| [flutter_easyloading](https://github.com/JiangJuHub/Flutter_easyLoading) | 加载提示 |
| [custom_sliding_segmented_control](https://github.com/markusthander/custom_sliding_segmented_control) | 分段控件 |
| [timeago](https://github.com/andresaraujo/timeago.dart) | 相对时间显示 |
| [lottie](https://github.com/xvrh/lottie-flutter) | Lottie 动画（扫描动画） |
| [webview_flutter](https://github.com/flutter/packages/tree/main/packages/webview_flutter) | CodeMirror 代码编辑器内嵌 |
| [permission_handler](https://github.com/baseflow/flutter-permission-handler) | 权限管理 |
| [flutter_keyboard_visibility](https://github.com/MisterJimson/flutter_keyboard_visibility) | 键盘可见性监听 |
| [loading_animation_widget](https://github.com/jpdevr/loading_animation_widget) | 加载动画 |
| [get](https://github.com/jonataslaw/getx) | GetX 状态管理（部分使用） |
| [timezone](https://github.com/srawlins/timezone) | 时区数据库 |
| [image_picker](https://github.com/flutter/packages/tree/main/packages/image_picker) | 图片选择（壁纸） |
| [http](https://github.com/dart-lang/http) | HTTP 客户端（iCloud/壁纸下载） |
| [flutter_lints](https://github.com/flutter/packages/tree/main/packages/flutter_lints) | 代码规范检查 |

### 前端 JS 库（内嵌于 WebView）

| 依赖 | 用途 |
| --- | --- |
| [CodeMirror](https://codemirror.net/) | 脚本编辑器（内嵌于 `webview_flutter`，含搜索高亮） |

## 许可证

本项目基于 AGPL-3.0 许可证开源，与上游 [qinglong](https://github.com/whyour/qinglong) 保持一致。
