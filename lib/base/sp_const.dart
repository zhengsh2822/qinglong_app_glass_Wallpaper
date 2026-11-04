const String spLoginHistory = "loginHistory";
const String spTokenBeanList = "spTokenBeanList";
const String spAccountCount = "spAccountCount";
const String spVIP = "spvip";
const String spVIPLOGO = "spviplogo";
const String spVIPLOGOChangeReminder = "spVIPLOGOChangeReminder";
const String spOpenAuth = "spOpenAuth";
const String spPoetToken = "spPoetToken";

const typeNormal = 0;
const typeVIP = 10;
const typeSVIP = 12531;

const String spEnvBackTime = "envBackTime";
const String spSubscribeBackTime = "subscribeBackTime";
const String spConfigBackTime = "configBackTime";
const String spICloud = "spICloud";
const String spShowLine = "spShowLine";
const String spUseWebCodeEditor = "spUseWebCodeEditor";
const String spAutoShowLog = "spAutoShowLog";
const String spVersioCodeHistory = "spVersioCodeHistory";
const String spLocalBackUpFileExperiedTime = "spLocalBackUpFileExperiedTime";
const String spThemeStyle = "spThemeStyle";
const String spThemeFollowSystem = "spThemeFollowSystem";
const String spTextScaleFactor = "spTextScaleFactor";
const String spTextFontWeight = "spTextFontWeight"; // 全局字体粗细（400/500/600/700 四档），默认 400
const String spPrimaryTextColor = "spPrimaryTextColor";
const String spSecondaryTextColor = "spSecondaryTextColor";
const String spTextAutoContrast = "spTextAutoContrast"; // 主/次字体自动根据壁纸亮度反色（默认开启，自定义颜色优先）
const String spLogAutoJump2Bottom = "spLogAutoJump2Bottom";
const String spAndroidKeyboardError = "spAndroidKeyboardError";
const String spSingleInstance = "spSingleInstance";

// 模糊参数调节：背景模糊和卡片模糊单独调节
const String spBgBlurSigma = "spBgBlurSigma"; // 背景模糊值（路由级 WallpaperBackground），默认 6
const String spBlurEffect = "spBlurEffect"; // 毛玻璃开关（主题版键，确认弹窗读取兼容）
const String spCardBlurSigma = "spCardBlurSigma"; // 卡片模糊值（GlassCard 等），默认 4

// 页面转场动画（bool，默认 false=容器展开：从点击卡片展开/返回收回原处）
// true = 经典右侧滑入（Cupertino 同款视差压暗）
const String spClassicPageTransition = "spClassicPageTransition";
const String spCardSolidOpacity = "spCardSolidOpacity"; // 卡片纯色不透明度（卡片模糊=0 时生效），默认 0.45
const String spCardSolidColor = "spCardSolidColor"; // 卡片纯色自定义颜色（-1=随主题自动白/黑），用于不同壁纸适配
const String spGithubLastReleaseTime = "spGithubLastReleaseTime"; // 已确认过的 GitHub 最新 release 发布时间(epoch 毫秒)，用于"获取新版安装包"时间对比（版本号不变，靠时间判断）
const String spGithubLastReleaseNo = "spGithubLastReleaseNo"; // 已确认过的 GitHub 安装包文件名序号（release_N），用于序号对比判断新版
// 冷启动主动提醒时"已提醒过"的 GitHub release 附件上传时间(epoch 毫秒)，
// 用于避免同一版本重复打扰；出现更新的 release 后才再次提醒
const String spGithubLastRemindTime = "spGithubLastRemindTime";
// 冷启动主动提醒时"已提醒过"的 GitHub 安装包文件名序号（release_N）
const String spGithubLastRemindNo = "spGithubLastRemindNo";

// ==== WebDAV 云备份（青龙 2.x 客户端，方案见 docs/云备份方案.md）====
const String spWebDavUrl =
    "spWebDavUrl"; // 服务器地址，如 https://dav.jianguoyun.com/dav/
const String spWebDavUser = "spWebDavUser"; // 账号
const String spWebDavPassword = "spWebDavPassword"; // 应用密码（坚果云为专用应用密码）
const String spWebDavDir = "spWebDavDir"; // 远程目录，默认 /qinglong_app_backup
const String spWebDavEncryptPass = "spWebDavEncryptPass"; // 备份加密口令
const String spWebDavAuto = "spWebDavAuto"; // 自动备份开关，默认关
const String spWebDavLastBackTime = "spWebDavLastBackTime"; // 上次手动备份时间
const String spWebDavLastAutoBackTime =
    "spWebDavLastAutoBackTime";

