import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';

class Url {
  int index;

  Url(this.index);

  static get login => "/api/user/login";

  static get system => "/api/system";

  static get loginOld => "/api/login";

  static get loginTwo => "/api/user/two-factor/login";
  static const loginByClientId = "/open/auth/token";
  static const user = "/api/user";

  static const updatePassword = "/api/user";

  get logDel =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config"
          : "/api/system/config";

  get logDelUpdate =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config/log-remove-frequency"
          : "/api/system/config/log-remove-frequency";

  get tasks =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons"
          : "/api/crons";

  get subscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions"
          : "/api/subscriptions";

  get notifcations =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/user/notification"
          : "/api/user/notification";

  get runSubscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions/run"
          : "/api/subscriptions/run";

  get stopSubscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions/stop"
          : "/api/subscriptions/stop";

  get addSubscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions"
          : "/api/subscriptions";

  get enableSubscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions/enable"
          : "/api/subscriptions/enable";

  get disableSubscribes =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/subscriptions/disable"
          : "/api/subscriptions/disable";

  get runTasks =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/run"
          : "/api/crons/run";

  get stopTasks =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/stop"
          : "/api/crons/stop";

  get taskDetail =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/"
          : "/api/crons/";

  get addTask =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons"
          : "/api/crons";

  get pinTask =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/pin"
          : "/api/crons/pin";

  get unpinTask =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/unpin"
          : "/api/crons/unpin";

  get enableTask =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/enable"
          : "/api/crons/enable";

  get disableTask =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/crons/disable"
          : "/api/crons/disable";

  get files =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/configs/files"
          : "/api/configs/files";

  get configContent =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/configs/"
          : "/api/configs/";

  get saveFile =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/configs/save"
          : "/api/configs/save";

  get envs =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/envs"
          : "/api/envs";

  get addEnv =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/envs"
          : "/api/envs";

  get delEnv =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/envs"
          : "/api/envs";

  get disableEnvs =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/envs/disable"
          : "/api/envs/disable";

  get enableEnvs =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/envs/enable"
          : "/api/envs/enable";

  get loginLog =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/user/login-log"
          : "/api/user/login-log";

  get logFoldDelete =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/logs"
          : "/api/logs";

  get taskLog =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/logs"
          : "/api/logs";

  get taskLogDetail =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/logs/"
          : "/api/logs/";

  get scripts =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts/files"
          : "/api/scripts/files";

  get scripts2 =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts"
          : "/api/scripts";

  get scriptUpdate =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts"
          : "/api/scripts";

  get scriptDetail =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts"
          : "/api/scripts";
  get scriptDetailForReadFile =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts/detail"
          : "/api/scripts/detail";

  get dependencies =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dependencies"
          : "/api/dependencies";

  get dependenciesDeleteFocus =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dependencies/force"
          : "/api/dependencies/force";

  get dependenciesReinstall =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dependencies/reinstall"
          : "/api/dependencies/reinstall";

  // ============ 依赖设置（系统设置 → 依赖设置） ============
  // 青龙面板 v2.21+ 新增：依赖代理 + Node/Python/Linux 镜像源配置
  // 用于解决依赖安装慢/失败的问题（走国内镜像源）

  get systemConfig =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config"
          : "/api/system/config";

  get dependenceProxy =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config/dependence-proxy"
          : "/api/system/config/dependence-proxy";

  get nodeMirror =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config/node-mirror"
          : "/api/system/config/node-mirror";

  get pythonMirror =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config/python-mirror"
          : "/api/system/config/python-mirror";

  get linuxMirror =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/config/linux-mirror"
          : "/api/system/config/linux-mirror";

  // ============ 压缩包备份与恢复 ============
  // 青龙面板数据导出（生成 .tgz 压缩包）和导入（恢复压缩包）

  get dataExport =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/data/export"
          : "/api/system/data/export";

  get dataImport =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/data/import"
          : "/api/system/data/import";

  get systemReload =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/reload"
          : "/api/system/reload";

  get addScript =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts"
          : "/api/scripts";

  get dependencyReinstall =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dependencies/reinstall"
          : "/api/dependencies/reinstall";

  get checkUpdate =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/update-check"
          : "/api/system/update-check";

  get dashboardOverview =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/overview"
          : "/api/dashboard/overview";

  get dashboardSystem =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/system"
          : "/api/dashboard/system";

  get dashboardRuntime =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/runtime"
          : "/api/dashboard/runtime";

  // 近 N 日趋势（默认 7 天）— 参数 ?days=
  get dashboardTrend =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/trend"
          : "/api/dashboard/trend";

  // 今日耗时 Top 5
  get dashboardTopTime =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/top-time"
          : "/api/dashboard/top-time";

  // 今日执行次数 Top 5
  get dashboardTopCount =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/top-count"
          : "/api/dashboard/top-count";

  // 标签统计
  get dashboardLabels =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/labels"
          : "/api/dashboard/labels";

  get appkeys =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/apps"
          : "/api/apps";

  resetAppKey(dynamic id) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/api/apps/${id.toString()}/reset-secret"
        : "/api/apps/${id.toString()}/reset-secret";
  }

  intimeLog(String cronId) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/crons/$cronId/log"
        : "/api/crons/$cronId/log";
  }

  intimeDepLog(String id) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/dependencies/$id"
        : "/api/dependencies/$id";
  }

  intimeSubscribeLog(int cronId) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/subscriptions/$cronId/log"
        : "/api/subscriptions/$cronId/log";
  }

  envMove(String envId) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/envs/$envId/move"
        : "/api/envs/$envId/move";
  }

  static bool inWhiteList(String path) {
    if (path == login ||
        path == loginByClientId ||
        path == loginTwo ||
        path == loginOld) {
      return true;
    }
    return false;
  }

  static bool inLoginList(String path) {
    if (path == login || path == loginByClientId || path == loginOld) {
      return true;
    }
    return false;
  }
}
