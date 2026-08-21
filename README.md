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
- 添加/编辑/删除账号弹窗统一使用

### 其他功能

- 配置文件管理、依赖管理（缺失依赖扫描）、登录日志、任务日志
- 应用内购买、推送设置、字体设置（字体大小+主/次字体颜色自定义 HSL 选色器）、修改密码、账号排序
- 检查更新、关于页面、依赖设置、备份恢复
- 全局可更换壁纸系统（渐变/纯色/本地图片/网络图片），支持模糊度与暗化调节
- 适配安卓小白条和状态栏沉浸效果
SystemUiMode.edgeToEdge)` + 透明 `SystemUiOverlayStyle`，适配安卓小白条和状态栏

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


## 许可证

本项目基于 AGPL-3.0 许可证开源，与上游 [qinglong](https://github.com/whyour/qinglong) 保持一致。
