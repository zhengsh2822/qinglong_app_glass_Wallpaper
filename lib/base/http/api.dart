import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_bean.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/login/login_bean.dart';
import 'package:qinglong_app/module/login/user_bean.dart';
import 'package:qinglong_app/module/others/LogDelBean.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/others/login_log/login_log_bean.dart';
import 'package:qinglong_app/module/others/scripts/script_bean.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/others/update/check_update_bean.dart';
import 'package:qinglong_app/module/task/task_bean.dart';

import '../../module/task/TaskBean2.dart';
import '../ui/tree/models/script_data.dart';

class Api {
  int index;

  Api(this.index);

  Future<HttpResponse<LogDelBean>> logDel() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<LogDelBean>(getIt<Url>(instanceName: index.toString()).logDel, {});
  }

  Future<HttpResponse<String>> logDelTime(int time) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).logDelUpdate,
      {"logRemoveFrequency": time},
    );
  }

  Future<HttpResponse<SystemBean>> system() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<SystemBean>(Url.system, {});
  }

  Future<HttpResponse<String>> dashboardOverview() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardOverview,
      {},
    );
  }

  Future<HttpResponse<String>> dashboardSystem() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardSystem,
      {},
    );
  }

  Future<HttpResponse<String>> dashboardRuntime() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardRuntime,
      {},
    );
  }

  // 近 N 日趋势（默认 7 天）
  Future<HttpResponse<String>> dashboardTrend({int days = 7}) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardTrend,
      {"days": days.toString()},
    );
  }

  // 今日耗时 Top 5
  Future<HttpResponse<String>> dashboardTopTime() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardTopTime,
      {},
    );
  }

  // 今日执行次数 Top 5
  Future<HttpResponse<String>> dashboardTopCount() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardTopCount,
      {},
    );
  }

  // 标签统计
  Future<HttpResponse<String>> dashboardLabels() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardLabels,
      {},
    );
  }

  // 今日成功任务明细（按成功次数降序）
  Future<HttpResponse<String>> dashboardSuccesses() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardSuccesses,
      {},
    );
  }

  // 今日失败任务明细（按失败次数降序）
  Future<HttpResponse<String>> dashboardFailures() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dashboardFailures,
      {},
    );
  }

  // ==== 青龙 2.22 新增接口（客户端补齐对齐） ====

  /// 可信代理解析配置（GET，返回 trustProxy/source/editable）
  Future<HttpResponse<String>> clientIpConfig() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).clientIpConfig,
      {},
    );
  }

  /// 更新可信代理解析配置（PUT）
  Future<HttpResponse<String>> updateClientIpConfig(String trustProxy) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).clientIpConfig,
      {"trustProxy": trustProxy},
    );
  }

  /// 访问链路诊断（GET）
  Future<HttpResponse<String>> clientIpDiagnose() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).clientIpDiagnose,
      {},
    );
  }

  /// 登录 IP 黑名单列表（GET）
  Future<HttpResponse<String>> ipBlacklist() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).ipBlacklist,
      {},
    );
  }

  /// 添加 IP 到黑名单（PUT，body: {ip}）
  Future<HttpResponse<String>> addIpBlacklist(String ip) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).ipBlacklist,
      {"ip": ip},
    );
  }

  /// 从黑名单移除 IP（DELETE，body: {ip}）
  Future<HttpResponse<String>> removeIpBlacklist(String ip) async {
    return await getIt<Http>(instanceName: index.toString()).delete<String>(
      getIt<Url>(instanceName: index.toString()).ipBlacklist,
      {"ip": ip},
    );
  }

  /// 更新存储保留策略（PUT）
  Future<HttpResponse<String>> updateRetentionConfig(
    int runningInstanceRetentionDays,
    int cronStatRetentionDays,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).retentionConfig,
      {
        "runningInstanceRetentionDays": runningInstanceRetentionDays,
        "cronStatRetentionDays": cronStatRetentionDays,
      },
    );
  }

  /// 清理预览（POST）
  Future<HttpResponse<String>> previewRetention(
    Map<String, dynamic> body,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).retentionPreview,
      body,
    );
  }

  /// 执行清理（POST，自动补 confirmation: 'CLEAN'）
  Future<HttpResponse<String>> cleanupRetention(
    Map<String, dynamic> body,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).retentionCleanup,
      {...body, "confirmation": "CLEAN"},
    );
  }

  /// 某任务的历史运行实例列表（GET）
  Future<HttpResponse<String>> cronInstances(dynamic id) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).cronInstances(id),
      {},
    );
  }

  /// 停止指定运行实例（POST）
  Future<HttpResponse<String>> stopCronInstance(
    dynamic id,
    dynamic instanceId,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).cronInstanceStop(id, instanceId),
      {},
    );
  }

  /// 某任务的历史日志文件列表（GET）
  Future<HttpResponse<String>> cronLogs(dynamic id) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).cronLogs(id),
      {},
    );
  }

  Future<HttpResponse<LoginBean>> login(
    String userName,
    String passWord,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).post<LoginBean>(Url.login, {"username": userName, "password": passWord});
  }

  Future<HttpResponse<LoginBean>> loginOld(
    String userName,
    String passWord,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<LoginBean>(
      Url.loginOld,
      {"username": userName, "password": passWord},
    );
  }

  Future<HttpResponse<LoginBean>> loginTwo(
    String userName,
    String passWord,
    String code,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<LoginBean>(
      Url.loginTwo,
      {"username": userName, "password": passWord, "code": code},
    );
  }

  Future<HttpResponse<LoginBean>> loginByClientId(
    String id,
    String secret,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).get<LoginBean>(
      Url.loginByClientId,
      {"client_id": id, "client_secret": secret},
    );
  }

  Future<HttpResponse<UserBean>> user() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<UserBean>(Url.user, null);
  }

  Future<HttpResponse<TaskBean2>> crons2_13_09() async {
    return await getIt<Http>(instanceName: index.toString()).get<TaskBean2>(
      getIt<Url>(instanceName: index.toString()).tasks,
      {"page": "1", "size": "10000", "searchText": ""},
      // 任务运行状态是高频动态数据：禁用 1 分钟分级缓存，否则脚本结束后
      // 卡片仍停留在"运行中"（需等缓存过期或重进才刷新）。
      useCache: false,
    );
  }

  Future<HttpResponse<List<TaskBean>>> crons() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<TaskBean>>(
      getIt<Url>(instanceName: index.toString()).tasks,
      {"searchValue": ""},
      // 同上：任务运行状态实时性优先，不走通用分级缓存
      useCache: false,
    );
  }

  Future<HttpResponse<NullResponse>> deleteLogFold(
    String fileName,
    String path,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).logFoldDelete,
      {"filename": fileName, "path": path, "type": "directory"},
    );
  }

  Future<HttpResponse<NullResponse>> deleteLog(
    String fileName,
    String path,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).logFoldDelete,
      {"filename": fileName, "path": path, "type": "file"},
    );
  }

  Future<HttpResponse<String>> subscribes() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      {"searchValue": ""},
    );
  }

  Future<HttpResponse<NullResponse>> updateNotifcation(
    Map<String, dynamic> params,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).notifcations,
      params,
    );
  }

  Future<HttpResponse<String>> getNotifcation() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<String>(getIt<Url>(instanceName: index.toString()).notifcations, {});
  }

  Future<HttpResponse<String>> updateSubscribes(
    Map<String, dynamic> params,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      params,
    );
  }

  Future<HttpResponse<String>> addSubscribes(
    Map<String, dynamic> params,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      params,
    );
  }

  Future<HttpResponse<NullResponse>> startTasks(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).runTasks,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> stopTasks(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).stopTasks,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> startSubscribes(List<int> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).runSubscribes,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> stopSubscribes(List<int> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).stopSubscribes,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> updatePassword(
    String name,
    String password,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      Url.updatePassword,
      {"username": name, "password": password},
    );
  }

  Future<HttpResponse<String>> inTimeLog(String cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeLog(cron),
      null,
      // 实时日志接口禁用缓存,否则 2s 轮询会被 TTL 缓存层抵消
      useCache: false,
    );
  }

  Future<HttpResponse<String>> inTimeDepLog(String cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeDepLog(cron),
      null,
      useCache: false,
    );
  }

  Future<HttpResponse<String>> inTimeSubscribeLog(int cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeSubscribeLog(cron),
      null,
      useCache: false,
    );
  }

  Future<HttpResponse<NullResponse>> addTask(
    String name,
    String command,
    String cron, {
    int? id,
    String? nId,
  }) async {
    var data = <String, dynamic>{
      "name": name,
      "command": command,
      "schedule": cron,
    };

    if (id != null || nId != null) {
      if (id != null) {
        data["id"] = id;
      } else if (nId != null) {
        data["_id"] = nId;
      }
      return await getIt<Http>(
        instanceName: index.toString(),
      ).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).addTask,
        data,
      );
    }
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addTask,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> delSubscribe(int cron) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addSubscribes,
      [cron],
    );
  }

  Future<HttpResponse<NullResponse>> delTask(List<String> crons) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> pinTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).pinTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> unpinTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).unpinTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> enableTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> disableTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> enableSubscribe(int id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableSubscribes,
      [id],
    );
  }

  Future<HttpResponse<NullResponse>> disableSubscribe(int id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableSubscribes,
      [id],
    );
  }

  Future<HttpResponse<List<ConfigBean>>> files() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<ConfigBean>>(
      getIt<Url>(instanceName: index.toString()).files,
      null,
    );
  }

  Future<HttpResponse<String>> content(String name) async {
    final SystemBean systemBean = getIt<SystemBean>(
      instanceName: index.toString(),
    );
    final Url url = getIt<Url>(instanceName: index.toString());
    // 2.22+：/configs/:file 已下线（业务码 410），改用 /configs/detail?path=
    // 2.21 及更早：无 detail 路由，仍走旧路径
    final bool useDetail = systemBean.isUpperVersion2_22_0();
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      useDetail ? url.configDetail : url.configContent + name,
      useDetail ? {"path": name} : null,
    );
  }

  Future<HttpResponse<NullResponse>> saveFile(
    String name,
    String content,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).saveFile,
      {"content": content, "name": name},
    );
  }

  Future<HttpResponse<List<EnvBean>>> envs(String search) async {
    return await getIt<Http>(instanceName: index.toString()).get<List<EnvBean>>(
      getIt<Url>(instanceName: index.toString()).envs,
      {"searchValue": search},
    );
  }

  Future<HttpResponse<NullResponse>> enableEnv(List<String> ids) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableEnvs,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> disableEnv(List<String> ids) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableEnvs,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> delEnvs(List<String> ids) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).delEnv,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> delEnv(String id) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(getIt<Url>(instanceName: index.toString()).delEnv, [
      id,
    ]);
  }

  Future<HttpResponse<NullResponse>> addEnv(
    String name,
    String value,
    String remarks, {
    int? id,
    String? nId,
  }) async {
    var data = <String, dynamic>{
      "value": value,
      "remarks": remarks,
      "name": name,
    };

    if (id != null || nId != null) {
      if (id != null) {
        data["id"] = id;
      } else if (nId != null) {
        data["_id"] = nId;
      }
      return await getIt<Http>(
        instanceName: index.toString(),
      ).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).addEnv,
        data,
      );
    }
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addEnv,
      [data],
    );
  }

  Future<HttpResponse<NullResponse>> moveEnv(
    String id,
    int fromIndex,
    int toIndex,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).envMove(id),
      {"fromIndex": fromIndex, "toIndex": toIndex},
    );
  }

  Future<HttpResponse<List<LoginLogBean>>> loginLog() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<LoginLogBean>>(
      getIt<Url>(instanceName: index.toString()).loginLog,
      null,
    );
  }

  Future<HttpResponse<List<TaskLogBean>>> taskLog() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<TaskLogBean>>(
      getIt<Url>(instanceName: index.toString()).taskLog,
      null,
      serializationName:
          getIt<SystemBean>(
                instanceName: index.toString(),
              ).isUpperVersion2_12_2()
              ? "data"
              : "dirs",
    );
  }

  /// 任务日志内容读取
  /// [offset] 为 null 时返回尾部片段（2.22+ 默认策略，尾部 256KB）；
  /// 传入 offset 则从该字节位置读取，用于向上加载更早的日志
  Future<HttpResponse<String>> taskLogDetail(
    String name,
    String path, {
    int? offset,
  }) async {
    final SystemBean systemBean = getIt<SystemBean>(
      instanceName: index.toString(),
    );
    final Url url = getIt<Url>(instanceName: index.toString());
    // 2.22+：/logs/:file 已下线（业务码 410），改用 /logs/detail?file=&path=
    // 并支持 offset 分块续读；响应含 offset/nextOffset/total/truncated
    if (systemBean.isUpperVersion2_22_0()) {
      final Map<String, String?> query = {"file": name, "path": path};
      if (offset != null) {
        query["offset"] = offset.toString();
      }
      return await getIt<Http>(instanceName: index.toString()).get<String>(
        url.logDetail,
        query,
      );
    }
    if (systemBean.isUpperVersion2_13_0()) {
      return await getIt<Http>(instanceName: index.toString()).get<String>(
        url.taskLogDetail + name + "?path=" + path,
        null,
      );
    }
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      url.taskLogDetail + path + "/" + name,
      null,
    );
  }

  Future<HttpResponse<List<ScriptData>>> scripts() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<ScriptData>>(
      getIt<SystemBean>(instanceName: index.toString()).isUpperVersion2_13_0()
          ? getIt<Url>(instanceName: index.toString()).scripts2
          : getIt<Url>(instanceName: index.toString()).scripts,
      null,
    );
  }

  Future<HttpResponse<NullResponse>> updateScript(
    String name,
    String path,
    String content,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": name, "path": path, "content": content},
    );
  }

  Future<HttpResponse<NullResponse>> delScript(String name, String path) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": name, "path": path},
    );
  }

  Future<HttpResponse<NullResponse>> delScriptFold(
    String fileName,
    String path,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": fileName, "path": path, "type": "directory"},
    );
  }

  Future<HttpResponse<NullResponse>> addScriptFolder(
    String fileName,
    String path,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"directory": fileName, "path": path},
    );
  }

  Future<HttpResponse<NullResponse>> delScriptNewVersion(
    String fileName,
    String path,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": fileName, "path": path, "type": "file"},
    );
  }

  Future<HttpResponse<String>> scriptDetail(String name, String? path) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).scriptDetailForReadFile,
      {"file": name, "path": path ?? ""},
    );
  }

  /// 拉取脚本运行时保存的二进制文件（如二维码 PNG）
  /// [path] 脚本侧 print 出的绝对路径，如 /ql/data/scripts/pupu_login_qr.png
  /// 成功 GetBytesResult.success(bytes)
  /// 失败 GetBytesResult.fail(code, message, bodyPreview) —— 含真实 HTTP 状态码与响应体
  Future<GetBytesResult> scriptFile(String path) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).getBytes(
      getIt<Url>(instanceName: index.toString()).scriptFile,
      {"path": path},
    );
  }

  /// 单个脚本文件原始二进制下载：POST /scripts/download，res.download() 文件流
  /// [filename] 文件名；[path] scripts 下相对子目录，可空
  /// 这是 PNG 等二进制文件唯一不损字节取数通道（scriptFile 的 JSON 字符串信封会毁掉二进制）
  Future<GetBytesResult> scriptFileDownload(
    String filename,
    String path,
  ) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).postBytes(
      getIt<Url>(instanceName: index.toString()).scriptFileDownload,
      {"filename": filename, "path": path},
    );
  }

  Future<HttpResponse<List<DependencyBean>>> dependencies(String type) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<List<DependencyBean>>(
      getIt<Url>(instanceName: index.toString()).dependencies,
      {"type": type.toString()},
    );
  }

  Future<HttpResponse<NullResponse>> dependencyReinstall(
    List<String?>? sId,
    List<int?>? id,
  ) async {
    if (sId != null && sId.isNotEmpty && sId[0] != null) {
      return await getIt<Http>(
        instanceName: index.toString(),
      ).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).dependenciesReinstall,
        sId,
      );
    } else {
      return await getIt<Http>(
        instanceName: index.toString(),
      ).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).dependenciesReinstall,
        id,
      );
    }
  }

  Future<HttpResponse<String>> dependencyLog(String id) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dependencies + "/" + id,
      null,
    );
  }

  // ============ 依赖设置（系统设置 → 依赖设置） ============
  // 青龙面板 v2.21+ 新增：依赖代理 + Node/Python/Linux 镜像源配置

  /// 获取系统配置（含依赖设置字段：dependenceProxy/nodeMirror/pythonMirror/linuxMirror）
  /// 禁用缓存：依赖设置页面每次打开都需要最新配置，避免 _origXxx 保存旧值导致比对错误
  Future<HttpResponse<String>> systemConfig() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<String>(
      getIt<Url>(instanceName: index.toString()).systemConfig,
      null,
      useCache: false,
    );
  }

  /// 更新依赖代理（http_proxy/https_proxy）
  /// 传空字符串清除代理
  Future<HttpResponse<String>> updateDependenceProxy(String proxy) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).dependenceProxy,
      {"dependenceProxy": proxy},
    );
  }

  /// 更新 Node.js 镜像源（pnpm config set registry）
  /// 传空字符串清除镜像源
  /// 注意：此接口会触发 pnpm i -g 重装已安装的 nodejs 依赖，耗时较长；
  /// 返回 application/octet-stream 流式响应（重装依赖进度日志）非标准 JSON，
  /// 需用 rawResponse 跳过 JSON 解析，并设 5 分钟超时
  Future<HttpResponse<String>> updateNodeMirror(String mirror) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).nodeMirror,
      {"nodeMirror": mirror},
      rawResponse: true,
      receiveTimeout: const Duration(minutes: 5),
    );
  }

  /// 更新 Python 镜像源（pip3 config set global.index-url）
  /// 传空字符串清除镜像源
  Future<HttpResponse<String>> updatePythonMirror(String mirror) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).pythonMirror,
      {"pythonMirror": mirror},
    );
  }

  /// 更新 Linux 镜像源（仅 Linux 平台生效）
  /// 传空字符串清除镜像源
  /// 注意：此接口返回 application/octet-stream 流式响应（重装依赖进度日志）
  /// 非标准 JSON，需用 rawResponse 跳过 JSON 解析；重装依赖耗时较长，设 5 分钟超时
  Future<HttpResponse<String>> updateLinuxMirror(String mirror) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).linuxMirror,
      {"linuxMirror": mirror},
      rawResponse: true,
      receiveTimeout: const Duration(minutes: 5),
    );
  }

  // ============ 压缩包备份与恢复 ============

  /// 导出数据备份（生成 .tgz 压缩包）
  /// [type] 可选，指定要备份的数据目录（config/scripts/deps/log等）
  /// 不传 type 默认只备份 db + upload
  /// [savePath] 本地保存路径
  /// 成功返回 null，失败返回错误信息
  Future<String?> exportData(String savePath, {List<String>? type}) async {
    final body = <String, dynamic>{};
    if (type != null && type.isNotEmpty) {
      body['type'] = type;
    }
    return await getIt<Http>(
      instanceName: index.toString(),
    ).downloadFile(
      getIt<Url>(instanceName: index.toString()).dataExport,
      body,
      savePath,
    );
  }

  /// 导入数据恢复（上传 .tgz 压缩包）
  /// [filePath] 本地 .tgz 文件路径
  /// 返回服务器解压输出信息
  Future<HttpResponse<String>> importData(String filePath) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).uploadFile<String>(
      getIt<Url>(instanceName: index.toString()).dataImport,
      filePath,
      'data',
    );
  }

  /// 重载系统（恢复后调用使配置生效）
  /// [type] "data" 或 "system"
  Future<HttpResponse<NullResponse>> reloadSystem(String type) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).systemReload,
      {"type": type},
    );
  }

  Future<HttpResponse<String>> addDependency(
    List<Map<String, dynamic>> list,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).dependencies,
      list,
    );
  }

  Future<HttpResponse<NullResponse>> addScript(
    String name,
    String path,
    String content,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addScript,
      {"filename": name, "path": path, "content": content},
    );
  }

  Future<HttpResponse<NullResponse>> delDependency(
    List<String?>? sIds,
    List<int?>? ids,
  ) async {
    bool focus =
        getIt<SystemBean>(
          instanceName: index.toString(),
        ).isUpperVersion2_13_0();

    String url = "";
    if (focus) {
      url = getIt<Url>(instanceName: index.toString()).dependenciesDeleteFocus;
    } else {
      url = getIt<Url>(instanceName: index.toString()).dependencies;
    }

    HttpResponse<NullResponse> response;
    if (sIds != null && sIds.isNotEmpty && sIds[0] != null) {
      response = await getIt<Http>(
        instanceName: index.toString(),
      ).delete<NullResponse>(url, sIds);
    } else {
      response = await getIt<Http>(
        instanceName: index.toString(),
      ).delete<NullResponse>(url, ids);
    }

    if (response.success == false && focus) {
      url = getIt<Url>(instanceName: index.toString()).dependencies;
      if (sIds != null && sIds.isNotEmpty && sIds[0] != null) {
        response = await getIt<Http>(
          instanceName: index.toString(),
        ).delete<NullResponse>(url, sIds);
      } else {
        response = await getIt<Http>(
          instanceName: index.toString(),
        ).delete<NullResponse>(url, ids);
      }
    }
    return response;
  }

  Future<HttpResponse<CheckUpdateBean>> checkUpdate() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).put<CheckUpdateBean>(
      getIt<Url>(instanceName: index.toString()).checkUpdate,
      {},
    );
  }

  Future<HttpResponse<String>> appKeys() async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).get<String>(getIt<Url>(instanceName: index.toString()).appkeys, {});
  }

  Future<HttpResponse<NullResponse>> addAppKey(
    Map<String, dynamic> data,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> updateAppKey(
    Map<String, dynamic> data,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> deleteAppKey(List<String> data) async {
    return await getIt<Http>(
      instanceName: index.toString(),
    ).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> resetAppKey(dynamic id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).resetAppKey(id),
      {},
    );
  }
}
