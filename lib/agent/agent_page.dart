import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/agent/agent_backend_builtin.dart';
import 'package:qinglong_app/agent/agent_backend_remote.dart';
import 'package:qinglong_app/agent/agent_capability.dart';
import 'package:qinglong_app/agent/agent_config.dart';
import 'package:qinglong_app/agent/agent_protocol.dart';
import 'package:qinglong_app/agent/agent_session_store.dart';
import 'package:qinglong_app/base/ui/agent_toast.dart';
import 'package:qinglong_app/agent/agent_tools.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/blur_effect.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

class _ChatEntry {
  final bool fromUser;
  final String text;
  final List<AgentCandidate> candidates;
  final bool isError;

  const _ChatEntry({
    required this.fromUser,
    this.text = '',
    this.candidates = const <AgentCandidate>[],
    this.isError = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fromUser': fromUser,
    'text': text,
    'isError': isError,
    'candidates': candidates.map((e) => e.toJson()).toList(),
  };

  factory _ChatEntry.fromJson(Map<String, dynamic> json) => _ChatEntry(
    fromUser: json['fromUser'] == true,
    text: json['text']?.toString() ?? '',
    isError: json['isError'] == true,
    candidates:
        (json['candidates'] is List)
            ? (json['candidates'] as List)
                .whereType<Map>()
                .map(
                  (e) => AgentCandidate.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : const <AgentCandidate>[],
  );
}

/// 所有后端共用的会话界面：消息、模糊搜索候选、写操作确认卡片。
/// 取色/字重走项目 themeProvider；键盘用 didChangeMetrics + View.of 取原始
/// insets（main.dart 全局把 MediaQuery.viewInsets 归零了）。
class AgentPage extends ConsumerStatefulWidget {
  /// 入口可显式指定账号槽位（如「我的」页按当前账号进入）；
  /// 为空时由页面上下文解析，避免跨账号读到同一份会话。
  final int? accountIndex;

  const AgentPage({super.key, this.accountIndex});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatEntry> _entries = <_ChatEntry>[];

  AgentBackend? _backend;
  StreamSubscription<AgentEvent>? _subscription;
  AgentPendingAction? _pendingAction;
  String _sessionKey = 'ai_session_default';
  int _accountIndex = 0;

  /// 当前账号的面板主机，参与会话 key（同槽位换面板不串记录）
  String _accountHost = '';

  /// 账号槽位只解析一次（didChangeDependencies 可能被多次调用）
  bool _slotResolved = false;
  bool _busy = false;
  bool _ready = false;
  double _lastKeyboard = 0;

  // ── 会话首屏性能（A 首帧直达底部 + C 按块读盘）──
  /// 恢复会话中：此期间不渲染空态，避免「空态闪一下再出内容」
  bool _restoring = true;

  /// 内存只保留一段窗口：_entries[0] 在整段会话中的绝对下标
  int _windowStart = 0;

  /// 已落盘条目数（绝对下标），用于只追加新消息、避免整段重写
  int _persistedCount = 0;

  /// 每页读盘 / 渲染条数
  static const int _pageSize = 40;

  /// 内存窗口上限：超过后从最旧侧丢弃（仅用户位于底部时）
  static const int _maxWindow = 160;

  bool _loadingEarlier = false;

  /// 内置后端完整历史恢复（发送前 await，避免丢上下文）
  Future<void>? _historyReady;

  bool _persisting = false;
  bool _persistPending = false;

  /// 会话代际：清空/切换后端时自增，丢弃过期的异步落盘与历史恢复结果
  int _sessionEpoch = 0;

  /// 落盘防抖：流式回复期间每个事件都写盘会反复编码大 JSON
  Timer? _persistTimer;

  // ── 悬浮输入框 · 弹簧接管（同步自 demos/kb_spring_demo v10）──
  // 只保留收起方向的落点回弹：一次性静态目标弹簧（目标=静止位，无斜坡滞后），
  // 带 IME 末速超车落底，close 规格过冲 ~10px（全程屏内）。
  // 弹起方向 1:1 跟随；demo 的弹起 dip 回弹在真机上受 IME 上报时机影响会
  // 明显慢半拍，按要求取消。
  late final AnimationController _takeCtrl = AnimationController.unbounded(
    vsync: this,
  );
  double _takeoverValue = 0;
  bool _takeover = false;
  bool _collapseSpringUsed = false;
  double _velocity = 0; // IME 速度（px/s，正=升高）
  DateTime _lastInsetAt = DateTime.now();

  /// 会话 key 用「后端 label + 固定账号索引」，不实时调 resolveAccountIndex()，
  /// 避免账号 token 状态变化导致写入/读取 key 不一致（记录就丢了）。
  String get _effectiveSessionKey {
    final backend = _backend;
    if (backend == null) return _sessionKey;
    return AgentSessionStore.keyFor(
      backend.label,
      _accountIndex,
      host: _accountHost,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 弹簧值逐帧同步到 UI（接管收起的落点回弹渲染）
    _takeCtrl.addListener(() {
      if (mounted) setState(() => _takeoverValue = _takeCtrl.value);
    });
    // 反向列表（0=底部）：滑到顶部附近时按页放出更早的记录
    _scroll.addListener(_onScrollLoadEarlier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slotResolved) return;
    _slotResolved = true;
    // 优先用入口显式传入的槽位；否则取页面上下文，最后退回当前激活账号。
    // 绝不能用 resolveAccountIndex()（永远第一个已登录账号 → 跨账号串数据）。
    final SingleAccountPageState? slot = SingleAccountPageState.of(context);
    _accountIndex =
        widget.accountIndex ??
        slot?.index ??
        MultiAccountPageState.currentAccountIndex;
    _accountHost = AgentCapabilityService.accountHost(_accountIndex);
    _initBackend();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistTimer?.cancel();
    // 退出前再落一次盘，避免最后一条消息只在内存里。
    _persist();
    _subscription?.cancel();
    _backend?.dispose();
    _input.dispose();
    _scroll.dispose();
    _takeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 必须用逻辑像素：View.viewInsets 是物理像素，直接使用会把接管起点
    // 放大 devicePixelRatio 倍（输入框先飞出屏幕再砸下来）。
    final bottom = MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
    if ((bottom - _lastKeyboard).abs() < 0.5) return;
    // IME 速度采样（px/s），供接管弹簧末速度接力
    final now = DateTime.now();
    final dt = now.difference(_lastInsetAt).inMicroseconds / 1e6;
    if (dt > 0 && dt < 0.2) {
      _velocity = (bottom - _lastKeyboard) / dt;
    }
    _lastInsetAt = now;

    final bool rising = bottom > _lastKeyboard;
    if (rising) {
      // 弹起：退出接管态，1:1 跟随（下次收起重新接管）
      _takeover = false;
      _takeCtrl.stop();
      _collapseSpringUsed = false;
    } else if (!_takeover && !_collapseSpringUsed && _lastKeyboard > 0.5) {
      // 收起中：一次性接管（目标 = 静止位，静态无滞后）
      _collapseSpringUsed = true;
      _startCollapseTakeover(from: _lastKeyboard + 8, velocity: _velocity);
    }
    _lastKeyboard = bottom;
    if (mounted) setState(() {});
  }

  /// 收起弹簧接管：from = 当前悬浮位（键盘上沿），to = 静止位（安全区+2，
  /// 与底部导航 margin 同源）；close 规格过冲落在静止位下方 ~10px，
  /// 全程屏内 = 落点回弹
  void _startCollapseTakeover({
    required double from,
    required double velocity,
  }) {
    _takeover = true;
    final navBottom = MediaQuery.of(context).viewPadding.bottom;
    _takeCtrl
        .animateWith(
          SpringSimulation(
            SpringSheetSpec.close,
            from,
            navBottom + 2,
            velocity.clamp(-1400.0, 1400.0),
          ),
        )
        .whenComplete(() {
          if (!mounted) return;
          setState(() => _takeover = false);
        });
  }

  Future<void> _initBackend() async {
    final config = await AgentConfigStore.load();
    final index = _accountIndex; // 已由页面上下文解析，固定不变
    final AgentBackend backend;
    if (config.backendType == AgentBackendType.builtin) {
      backend = BuiltinAgentBackend(
        config: config,
        executor: QingLongToolExecutor(index, scopes: config.scopes),
      );
    } else {
      backend = RemoteAgentBackend(config: config);
    }
    _sessionKey = AgentSessionStore.keyFor(
      backend.label,
      index,
      host: _accountHost,
    );

    // 先让页面立刻可用，再异步恢复会话与探测能力，避免初始化阻塞发送。
    if (!mounted) return;
    setState(() {
      _backend = backend;
      _ready = true;
    });
    // 等恢复完成再允许保存，避免「先写空、后恢复」把历史覆盖掉。
    await _restoreSession(backend);
    unawaited(_detectCapabilities(backend, index));
  }

  Future<void> _restoreSession(AgentBackend backend) async {
    final key = _effectiveSessionKey;
    // 按块读盘：只解最近 _pageSize 条，内存不加载整段会话
    final AgentSessionWindow win = await AgentSessionStore.loadRecent(
      key,
      limit: _pageSize,
    );
    if (!mounted || _backend != backend) return;
    // 只在页面上还没有消息时才填充，避免把用户刚发的消息覆盖掉
    if (_entries.isEmpty) {
      final List<_ChatEntry> parsed = <_ChatEntry>[];
      for (final e in win.entries) {
        parsed.add(_ChatEntry.fromJson(e));
      }
      setState(() {
        _entries.addAll(parsed);
        _windowStart = win.startIndex;
        _persistedCount = win.total;
        _restoring = false;
      });
    } else {
      setState(() => _restoring = false);
    }
    // 恢复完成：反向列表首帧直接停在底部，不做滚动动画
    _scrollToBottom(force: true);
    // 模型上下文（完整历史）后台恢复；发送前会 await，通常此时已完成
    _historyReady = _restoreHistory(backend, key);
  }

  /// 后台恢复内置后端的完整对话历史（按块读盘 + 大 JSON 后台解码）
  Future<void> _restoreHistory(AgentBackend backend, String key) async {
    if (backend is! BuiltinAgentBackend) return;
    final int epoch = _sessionEpoch;
    final history = await AgentSessionStore.loadHistory(key);
    if (!mounted || _backend != backend || epoch != _sessionEpoch) return;
    backend.restoreHistory(history);
  }

  /// 反向列表滑到顶部附近：从磁盘读上一页更早记录
  void _onScrollLoadEarlier() {
    if (!_scroll.hasClients || _loadingEarlier || _windowStart <= 0) return;
    final ScrollPosition p = _scroll.position;
    if (p.pixels < p.maxScrollExtent - 240) return;
    unawaited(_loadEarlier());
  }

  Future<void> _loadEarlier() async {
    if (_loadingEarlier || _windowStart <= 0) return;
    _loadingEarlier = true;
    final int before = _windowStart;
    try {
      final earlier = await AgentSessionStore.loadEarlier(
        _effectiveSessionKey,
        beforeIndex: before,
        count: _pageSize,
      );
      if (!mounted) return;
      if (earlier.isEmpty) {
        // 块缺失（存储异常）：停止继续向上请求，避免反复读盘
        setState(() => _windowStart = 0);
        return;
      }
      final List<_ChatEntry> parsed = <_ChatEntry>[];
      for (final e in earlier) {
        parsed.add(_ChatEntry.fromJson(e));
      }
      setState(() {
        _entries.insertAll(0, parsed);
        _windowStart = before - parsed.length;
      });
    } finally {
      _loadingEarlier = false;
    }
  }

  /// 内存窗口回收：仅在用户位于底部时，从最旧侧丢弃超出上限的部分。
  /// 未落盘的条目一律不丢；反向列表下丢弃的是最上方内容，底部锚点不变。
  void _trimWindow() {
    if (_scroll.hasClients && _scroll.offset > 80) return;
    if (_entries.length <= _maxWindow) return;
    int drop = _entries.length - _maxWindow;
    final int keepFrom = _persistedCount - _windowStart; // 未落盘起点
    if (keepFrom >= 0 && drop > keepFrom) drop = keepFrom;
    if (drop <= 0) return;
    _entries.removeRange(0, drop);
    _windowStart += drop;
  }

  /// 落盘防抖（流式事件频繁触发时合并写）
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persist());
    });
  }

  Future<void> _detectCapabilities(AgentBackend backend, int index) async {
    if (backend is! BuiltinAgentBackend) return;
    final supported = await AgentCapabilityService.detectDashboard(
      index,
    ).timeout(const Duration(seconds: 4), onTimeout: () => true);
    if (!mounted || _backend != backend) return;
    backend.updateDisabledTools(
      supported ? <String>{} : AgentCapabilityService.dashboardTools,
    );
  }

  Future<void> _reload() async {
    // 先落盘，避免清空 _entries 时把未保存的消息丢掉
    await _persist();
    _persistTimer?.cancel();
    _sessionEpoch++;
    _subscription?.cancel();
    _backend?.dispose();
    setState(() {
      _ready = false;
      _backend = null;
      _pendingAction = null;
      _entries.clear();
      _windowStart = 0;
      _persistedCount = 0;
      _historyReady = null;
      _restoring = true;
    });
    await _initBackend();
  }

  /// 追加落盘：只写尚未保存的新条目，重写末尾块；历史只重写变化块。
  Future<void> _persist() async {
    if (_persisting) {
      _persistPending = true;
      return;
    }
    _persisting = true;
    try {
      await _persistNow();
    } finally {
      _persisting = false;
      if (_persistPending) {
        _persistPending = false;
        unawaited(_persist());
      }
    }
  }

  Future<void> _persistNow() async {
    final key = _effectiveSessionKey;
    // 还没完成初始化（key 仍是占位值）时不写，避免落到错误 key
    if (key == 'ai_session_default') return;
    final int epoch = _sessionEpoch;
    final backend = _backend;
    try {
      // 未落盘起点在内存窗口中的位置
      final int from = _persistedCount - _windowStart;
      if (from >= 0 && from < _entries.length) {
        final fresh = _entries.sublist(from).map((e) => e.toJson()).toList();
        await AgentSessionStore.appendEntries(
          key,
          fresh,
          atIndex: _persistedCount,
        );
        // 期间被清空/切换会话：丢弃本次计数（写入的孤立块无 meta 引用，不影响读取）
        if (epoch != _sessionEpoch) return;
        _persistedCount += fresh.length;
      }
      if (backend is BuiltinAgentBackend) {
        await AgentSessionStore.saveHistory(key, backend.historySnapshot());
      }
    } catch (_) {
      // 保存失败不阻断对话
    }
  }

  Future<void> _clearSession() async {
    _persistTimer?.cancel();
    _sessionEpoch++;
    final key = _effectiveSessionKey;
    await AgentSessionStore.clear(key);
    if (_backend is BuiltinAgentBackend) {
      (_backend as BuiltinAgentBackend).restoreHistory(
        <Map<String, dynamic>>[],
      );
    }
    setState(() {
      _entries.clear();
      _pendingAction = null;
      _windowStart = 0;
      _persistedCount = 0;
      _historyReady = null;
    });
  }

  /// 定位到最新记录。反向列表下 offset 0 即底部，用 jumpTo 无滚动过程；
  /// 非强制时仅当用户已在底部附近才跟随，避免打断向上翻看历史。
  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (!force && _scroll.offset > 80) return;
      _scroll.jumpTo(0);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final backend = _backend;
    if (backend == null) {
      '正在初始化，请稍候…'.toast();
      return;
    }
    // 历史上下文可能还在按块恢复：等它完成再发送，避免模型丢上下文
    final historyReady = _historyReady;
    if (historyReady != null) {
      try {
        await historyReady;
      } catch (_) {}
      if (!mounted) return;
    }
    _input.clear();
    _subscription?.cancel();
    setState(() {
      _entries.add(_ChatEntry(fromUser: true, text: text));
      _busy = true;
      _pendingAction = null;
      _trimWindow();
    });
    _scrollToBottom(force: true);
    _schedulePersist();

    _subscription = backend
        .send(text)
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              switch (event.type) {
                case AgentEventType.candidates:
                  _entries.add(
                    _ChatEntry(
                      fromUser: false,
                      text: event.text,
                      candidates: event.candidates,
                    ),
                  );
                  break;
                case AgentEventType.needConfirmation:
                  _pendingAction = event.pending;
                  if (event.text.isNotEmpty) {
                    _entries.add(_ChatEntry(fromUser: false, text: event.text));
                  }
                  break;
                case AgentEventType.error:
                  _entries.add(
                    _ChatEntry(
                      fromUser: false,
                      text: event.text,
                      isError: true,
                    ),
                  );
                  break;
                default:
                  if (event.text.isNotEmpty) {
                    _entries.add(_ChatEntry(fromUser: false, text: event.text));
                  }
              }
              _trimWindow();
            });
            _scrollToBottom();
            _schedulePersist();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _entries.add(
                _ChatEntry(fromUser: false, text: '发生错误：$error', isError: true),
              );
              _busy = false;
            });
            _schedulePersist();
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _busy = false);
            _schedulePersist();
          },
        );
  }

  Future<void> _confirm(bool approved) async {
    final action = _pendingAction;
    final backend = _backend;
    if (action == null || backend == null) return;
    setState(() {
      _pendingAction = null;
      _busy = true;
    });
    final event = await backend.confirm(action, approved);
    if (!mounted) return;
    setState(() {
      _entries.add(
        _ChatEntry(
          fromUser: false,
          text:
              event.text.isEmpty ? (approved ? '已提交执行。' : '已取消。') : event.text,
          isError: event.type == AgentEventType.error,
        ),
      );
      _busy = false;
    });
    _scrollToBottom(force: true);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(themeProvider);
    final titleColor = model.themeColor.titleColor();
    final descColor = model.themeColor.descColor();
    final accent = model.primaryColor;
    final navBottom = MediaQuery.of(context).viewPadding.bottom;
    // MediaQueryData.fromView 会做 devicePixelRatio 转换；直接读 View.viewInsets
    // 拿到的是物理像素，会把输入框顶到最上面。
    final keyboard =
        MediaQueryData.fromView(View.of(context)).viewInsets.bottom;

    // 悬浮输入框 bottom：接管期 = 弹簧值（超车落底 + 落点回弹）；
    // 键盘上 = 键盘上沿 + 8；收起静止 = 安全区 + 2（与底部导航同源）
    final double composerBottom;
    if (_takeover) {
      composerBottom = _takeoverValue.clamp(2.0, double.infinity);
    } else if (keyboard > 0) {
      composerBottom = keyboard + 8;
    } else {
      composerBottom = navBottom + 2;
    }
    // 列表底部让位：输入框框高 ≈ 56（最新消息不被盖住；滚动时从框底穿过）
    double listPadding = keyboard + 64;
    if (listPadding < navBottom + 58) listPadding = navBottom + 58;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        title: 'AI 助手',
        actions: <Widget>[
          IconButton(
            tooltip: '清空会话',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearSession,
          ),
          IconButton(
            tooltip: 'AI 设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(
                context,
              ).pushNamed(Routes.routeAgentSettings, arguments: _accountIndex);
              await _reload();
            },
          ),
        ],
      ),
      // 点击空白处收起键盘（输入框/按钮等自身处理 tap 的子组件优先，
      // 不会被这里抢走；仅空白区域触发）
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => Utils.hideKeyBoard(context),
        child: GlassPageBackground(
          child: Column(
            children: <Widget>[
              _buildBackendBanner(descColor),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    // 消息列表：底部让位 = 输入框悬浮位 + 框高（最新消息不被盖住；
                    // 滚动时内容从半透明输入框底下穿过）。
                    // 空态例外：固定让位（不随键盘）——空态是居中定位，若让位随
                    // 键盘变化，居中内容会整体下坠与输入框重叠（用户实测难看）
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              _entries.isEmpty ? navBottom + 58 : listPadding,
                        ),
                        child:
                            _entries.isEmpty
                                ? (_restoring
                                    // 恢复中：留白而非空态，避免「空态闪一下」
                                    ? const SizedBox.shrink()
                                    : _buildEmpty(
                                      titleColor,
                                      descColor,
                                      accent,
                                    ))
                                : Builder(
                                  builder: (context) {
                                    // 内存中只有一段窗口，直接整段渲染即可
                                    final int visible = _entries.length;
                                    final int extra = _busy ? 1 : 0;
                                    return ListView.builder(
                                      controller: _scroll,
                                      // 反向列表：index 0 就是底部最新一条，
                                      // 首帧 offset 0 = 天然停在最新记录，
                                      // 无需「渲染后滚到底」的动画。
                                      reverse: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      itemCount: visible + extra,
                                      itemBuilder: (context, index) {
                                        // 忙碌指示器固定在底部（最新一侧）
                                        if (extra == 1 && index == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: accent,
                                                    ),
                                              ),
                                            ),
                                          );
                                        }
                                        final int i = index - extra;
                                        // _entries 为时间正序：反向列表下从末尾往前取
                                        return _buildEntry(
                                          _entries[_entries.length - 1 - i],
                                          titleColor,
                                          descColor,
                                          accent,
                                        );
                                      },
                                    );
                                  },
                                ),
                      ),
                    ),
                    // 悬浮输入框：Positioned 定位在键盘上沿 / 安全区+2
                    // （与底部导航 margin bottom:2 同源，小白条不遮挡）
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: composerBottom,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_pendingAction != null)
                            _buildConfirmCard(titleColor, descColor, accent),
                          const SizedBox(height: 8),
                          _buildComposer(titleColor, descColor, accent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackendBanner(Color descColor) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      '当前后端：${_ready ? (_backend?.label ?? '') : '初始化中'} · 写操作需确认',
      style: TextStyle(fontSize: 11, color: descColor),
    ),
  );

  Widget _buildEmpty(Color titleColor, Color descColor, Color accent) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_awesome_outlined, size: 40, color: accent),
          const SizedBox(height: 12),
          Text(
            '用一句话管理青龙',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight(ref.watch(textWeightProvider)),
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '例如：今天运行了哪些任务？\n或：跑一下某某脚本（会先列候选，确认后执行）',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: descColor),
          ),
        ],
      ),
    ),
  );

  /// 轻量清理：模型偶尔仍会输出 Markdown 表格/加粗，聊天里显示原始符号很难看。
  static String _plainText(String input) {
    if (input.isEmpty) return input;
    var text = input.replaceAll('**', '').replaceAll('__', '');
    // 去掉 Markdown 标题前缀（## 小结 → 小结）
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    final lines = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      // 表格分隔行，如 |---|---|
      if (RegExp(r'^\|?[\s:\-|]+\|?$').hasMatch(trimmed) &&
          trimmed.contains('-')) {
        continue;
      }
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells =
            trimmed
                .split('|')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        if (cells.isNotEmpty) {
          lines.add('· ${cells.join(' · ')}');
          continue;
        }
      }
      lines.add(line);
    }
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Widget _buildEntry(
    _ChatEntry entry,
    Color titleColor,
    Color descColor,
    Color accent,
  ) {
    final align = entry.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final background =
        entry.isError
            ? AppColors.danger.withValues(alpha: 0.12)
            : entry.fromUser
            ? accent.withValues(alpha: 0.18)
            : descColor.withValues(alpha: 0.10);
    final foreground = entry.isError ? AppColors.danger : titleColor;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: descColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (entry.text.isNotEmpty)
              Text(_plainText(entry.text), style: TextStyle(color: foreground)),
            if (entry.candidates.isNotEmpty)
              ...entry.candidates.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.task_alt_outlined, size: 15, color: accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '#${candidate.id} ${candidate.title}'
                          '${candidate.subtitle.isEmpty ? '' : ' · ${candidate.subtitle}'}',
                          style: TextStyle(color: foreground, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmCard(Color titleColor, Color descColor, Color accent) {
    final action = _pendingAction!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('需要确认', style: TextStyle(fontSize: 14, color: titleColor)),
          const SizedBox(height: 6),
          Text(
            action.summary,
            style: TextStyle(fontSize: 13, color: descColor),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => _confirm(false),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () => _confirm(true),
                child: const Text('确认执行'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(Color titleColor, Color descColor, Color accent) {
    // 单一层次（对齐 demo）：胶囊是唯一视觉层，TextField 自身不画边框/底色。
    // 必须显式关闭 enabled/focused 等各状态 border —— 全局 InputDecorationTheme
    // 的 focusedBorder 会在聚焦时再画一个内层胶囊（"套着两层 UI"的来源）。
    //
    // 模糊跟随「毛玻璃效果」开关（GlassContainer）：开启 = 透明底 + BackdropFilter；
    // 关闭 = 纯色底、零模糊开销。此处是普通毛玻璃，不涉及液态玻璃组件。
    final Color solidBg = _composerSolidBackground();
    return GlassContainer(
      borderRadius: 24,
      backgroundColor: descColor.withValues(alpha: 0.08),
      solidBackgroundColor: solidBg,
      maxBlurSigma: 10,
      border: Border.all(color: accent.withValues(alpha: 0.20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                // 点击输入框立即关闭浮动提示，避免遮挡
                onTap: () => AgentToast.hide(),
                style: TextStyle(color: titleColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '说点什么，如：今天运行哪些任务？',
                  // 提示文案最多 1 行（默认跟随 maxLines:4，长文案会把输入框
                  // 撑高并压住会话卡片）；超出用省略号，输入框高度恒定
                  hintMaxLines: 1,
                  hintStyle: TextStyle(fontSize: 13, color: descColor),
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: accent),
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_rounded),
              tooltip: '发送',
            ),
          ],
        ),
      ),
    );
  }

  /// 毛玻璃关闭时的输入框纯色底：优先取页面背景；
  /// 页面背景透明（赛博模式）时回退到主题次背景色，避免"关模糊后完全透明"。
  Color _composerSolidBackground() {
    final Color scaffold = Theme.of(context).scaffoldBackgroundColor;
    if (scaffold.a >= 0.99) return scaffold;
    return ref.read(themeProvider).themeColor.bg2Color();
  }
}
