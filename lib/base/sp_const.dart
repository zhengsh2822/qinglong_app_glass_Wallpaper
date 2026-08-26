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
const String spLogAutoJump2Bottom = "spLogAutoJump2Bottom";
const String spAndroidKeyboardError = "spAndroidKeyboardError";
const String spSingleInstance = "spSingleInstance";

// 模糊参数调节：背景模糊和卡片模糊单独调节
const String spBgBlurSigma = "spBgBlurSigma"; // 背景模糊值（路由级 WallpaperBackground），默认 6
const String spCardBlurSigma = "spCardBlurSigma"; // 卡片模糊值（GlassCard 等），默认 4
const String spCardSolidOpacity = "spCardSolidOpacity"; // 卡片纯色不透明度（卡片模糊=0 时生效），默认 0.45
const String spCardSolidColor = "spCardSolidColor"; // 卡片纯色自定义颜色（-1=随主题自动白/黑），用于不同壁纸适配
const String spGithubLastReleaseTime = "spGithubLastReleaseTime"; // 已确认过的 GitHub 最新 release 发布时间(epoch 毫秒)，用于"获取新版安装包"时间对比（版本号不变，靠时间判断）
