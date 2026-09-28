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

  /// 2.22+ 配置文件内容读取：/configs/detail?path=<name>
  /// 旧 /configs/:file 在 2.22 已下线（返回业务码 410），响应结构不变
  get configDetail =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/configs/detail"
          : "/api/configs/detail";

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

  /// 2.22+ 任务日志内容读取：/logs/detail?file=<name>&path=<path>
  /// 旧 /logs/:file 在 2.22 已下线（返回业务码 410）；
  /// 新增 offset/limit/tail 参数，响应含 offset/nextOffset/total/truncated
  get logDetail =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/logs/detail"
          : "/api/logs/detail";

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

  /// 拉取脚本目录中的二进制文件（如脚本运行时保存的二维码 PNG）
  /// 走 token 鉴权 GET，返回文件 bytes
  get scriptFile =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts/file"
          : "/api/scripts/file";

  /// 单个脚本文件原始二进制下载：POST /scripts/download（body: filename+path）
  /// 后端 res.download() 回原始文件流；二进制文件只认这条——
  /// /open/scripts/file 是 UTF-8 字符串 JSON 信封（二进制必损），
  /// /scripts/:file 老接口已下线（返回 410）
  get scriptFileDownload =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/scripts/download"
          : "/api/scripts/download";

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

  // ==== 青龙 2.22 新增：客户端 IP / 可信代理解析 ====
  // GET 读取配置；PUT 更新（body: {trustProxy}）
  get clientIpConfig =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/client-ip/config"
          : "/api/system/client-ip/config";

  // GET 访问链路诊断（返回 remoteAddress/forwardedFor/expressIps/clientIp/hops）
  get clientIpDiagnose =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/client-ip/diagnose"
          : "/api/system/client-ip/diagnose";

  // ==== 青龙 2.22 新增：登录 IP 黑名单 ====
  // GET 列表；PUT 添加（body: {ip}）；DELETE 移除（body: {ip}）
  get ipBlacklist =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/user/ip-blacklist"
          : "/api/user/ip-blacklist";

  // ==== 青龙 2.22 新增：存储保留策略与清理 ====
  // PUT 更新保留策略（body: runningInstanceRetentionDays + cronStatRetentionDays）
  get retentionConfig =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/storage-retention/config"
          : "/api/system/storage-retention/config";

  // POST 清理预览（body 同策略 + dependenceCacheTypes + compactDatabase）
  get retentionPreview =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/storage-retention/preview"
          : "/api/system/storage-retention/preview";

  // POST 执行清理（body 需额外带 confirmation: 'CLEAN'）
  get retentionCleanup =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/system/storage-retention/cleanup"
          : "/api/system/storage-retention/cleanup";

  // ==== 青龙 2.22 新增：任务历史运行实例 ====
  // GET 某任务的历史运行实例列表（按 started_at 倒序）
  cronInstances(dynamic id) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/crons/${id.toString()}/instances"
        : "/api/crons/${id.toString()}/instances";
  }

  // POST 停止指定运行实例
  cronInstanceStop(dynamic id, dynamic instanceId) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/crons/${id.toString()}/instances/${instanceId.toString()}/stop"
        : "/api/crons/${id.toString()}/instances/${instanceId.toString()}/stop";
  }

  // GET 某任务的历史日志文件列表
  cronLogs(dynamic id) {
    return getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined
        ? "/open/crons/${id.toString()}/logs"
        : "/api/crons/${id.toString()}/logs";
  }

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

  // 今日成功任务明细（按成功次数降序，无参数）
  get dashboardSuccesses =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/successes"
          : "/api/dashboard/successes";

  // 今日失败任务明细（按失败次数降序，无参数）
  get dashboardFailures =>
      getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined
          ? "/open/dashboard/failures"
          : "/api/dashboard/failures";

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
