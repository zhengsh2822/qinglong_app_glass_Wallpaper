import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/tab_bar_page.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预编译液态玻璃 shader：LiquidGlassLens 首次渲染即走完整 shader 路径，
  // 避免首帧走 frosted fallback（fallback 仅模糊 + 细边框，无折射、无外圈
  // 高光 —— "顶部 tab 外圈高光丢失"的根源之一）。
  await LiquidGlassShaders.ensureLoaded();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const TabBarPage(),
    ),
  );
}

// =============================================================
// The glass-pill nav bar on a LIGHT page: one wide, centred frosted-white
// capsule holding all four tabs, with the red belonging to the selected
// STATE rather than to one tab.
//
// A drop-in pairing — `LiquidGlassScaffold` for the page,
// `LiquidGlassTabBar` for the bar — with the selection pill turned up to
// the glass-refracting tier (`pillStyle.mode`). Everything the pill does
// is configured through `LiquidGlassTabPillStyle`: its glass look, its
// resting look, its contact shadow and its motion.
//
// The pill's deformation comes from acceleration: its drawn position is
// sampled every frame in pixels, differentiated twice, and the averaged
// acceleration scales it oppositely on the two axes — stretching wide and
// flat as it launches off a tab, squashing narrow and tall as it brakes
// into the next, and sitting undeformed at constant speed.
// =============================================================

/// The red the selected tab burns in — the one saturated colour on the
/// page, so it is also the colour the surrounding glass picks up.
const Color _kBrand = Color(0xFFFF3B30);

/// Type and hairlines on the light page — near-black rather than black,
/// so nothing on the page is a pure endpoint.
const Color _kInk = Color(0xFF121215);

// ═══ 主项目赛博模式配色（对齐主项目 CyberColors） ═══
const Color _cyberBg = Color(0xFF0A0A0F); // CyberColors.bg
const Color _cyberCardBg = Color(0xFF12121A); // CyberColors.cardBg
const Color _cyberCyan = Color(0xFF00F0FF); // CyberColors.cyan
const Color _cyberTitle = Color(0xFFE0E0FF); // CyberColors.titleWhite
const Color _cyberHint = Color(0xFF808080); // CyberColors.hintGray

/// The frosted-white capsule material over a soft optical rim.
/// 对齐官方 LiquidGlassNavBarMotionPill 默认（borderSolidity 0.5、lightIntensity
/// 1.3）：rim 高光变细（≈1px 细线），不再因 borderSolidity 0.95 全实而显粗。
LiquidGlassShape _glassShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.4, // 配合 _fullBorderWidth 收紧补偿，rim 高光约 1px 细线
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    );

/// 赛博模式胶囊：深色底 + 光学边框。外圈高光用默认白色 lightColor（不带青色），
/// 深色背景上更清晰；青色仅作为胶囊内部 tint / 文字高亮。
LiquidGlassShape _cyberShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.5, // 配合 _fullBorderWidth 收紧补偿，rim 高光约 1px 细线
      lightIntensity: 1.0,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    );

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});

  @override
  State<TabBarPage> createState() => _TabBarPageState();
}

class _TabBarPageState extends State<TabBarPage> {
  int _index = 0;

  /// 顶部液态玻璃分段 tab（移植主项目任务页顶部 tab）当前选中项
  int _topIndex = 0;

  /// 主题预览切换：false = 浅色（苹果），true = 赛博（主项目 CyberColors）
  bool _cyber = false;

  static const double _barHeight = 60;
  static const double _edge = 16;
  static const double _bottom = 22;

  /// The glyph's size — and therefore `itemStyle.iconSize`, the box every
  /// glyph is fitted into.
  static const double _iconRest = 24;

  /// One tab. Every one of them goes through the glyph builder — not
  /// because the art is custom, but because a selected icon **blooms**,
  /// and the built-in [Icon] path has no shadow to give it.
  ///
  /// The builder never names a colour: it paints `i.color`, the colour
  /// the bar already resolved for the layer it is drawing. That is what
  /// makes the pill reveal work — the shell draws every tab twice per
  /// frame, once forced unselected outside the pill and once forced
  /// selected inside it, so the red is wiped on as the pill arrives
  /// instead of switching under it.
  /// One tab: outlined icon when unselected, filled when selected — 与
  /// 主项目底部导航图标对（outlined/filled）保持一致。
  static LiquidGlassTabBarItem _tab(
    IconData outlined,
    IconData filled,
    String label,
  ) {
    return LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, i) => Icon(
        i.selected ? filled : outlined,
        // Under the glass the glyph is drawn at its own size; the bar
        // hands the builder the box, the builder only has to fill it.
        size: i.underGlass == true ? 24 : _iconRest,
        color: i.color,
        shadows: i.selected
            ? [Shadow(color: i.color.withValues(alpha: 0.85), blurRadius: 14)]
            : null,
      ),
    );
  }

  // 主项目底部导航：定时任务 / 环境变量 / 配置文件 / 我的
  // 图标沿用主项目 home_page.dart 的 icon 对（schedule / settings_ethernet /
  // description / person）。
  static final _items = <LiquidGlassTabBarItem>[
    _tab(Icons.schedule_outlined, Icons.schedule, '定时任务'),
    _tab(Icons.settings_ethernet_outlined, Icons.settings_ethernet, '环境变量'),
    _tab(Icons.description_outlined, Icons.description, '配置文件'),
    _tab(Icons.person_outline, Icons.person, '我的'),
  ];

  static const _titles = ['定时任务', '环境变量', '配置文件', '我的'];

  /// 顶部液态玻璃分段 tab（移植主项目任务页顶部 tab，纯文字无图标）
  /// 文案沿用主项目任务页：全部 / 运行中 / 未使用 / 已禁用
  static const _topTabs = ['全部', '运行中', '未使用', '已禁用'];

  @override
  Widget build(BuildContext context) {
    // Fill the phone width with a small edge margin, while keeping the four
    // tabs comfortably grouped on tablets.
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth = (screen - _edge * 2).clamp(280.0, 560.0);
    final EdgeInsets pad = MediaQuery.of(context).padding;

    // 主题配色：false=浅色（苹果），true=赛博（主项目 CyberColors）
    final Color brand = _cyber ? _cyberCyan : _kBrand;
    final Color hint = _cyber ? _cyberHint : _kInk;

    // ── 底部 morph pill 管道（单管道：绘制页面内容 + 底部胶囊） ──
    // 复用官方 LiquidGlassTabBar.buildGlassPillBar（滑动 + 长按拖拽抓取 + 变形）。
    final LiquidGlassTabBar bottomBar = LiquidGlassTabBar(
      items: _items,
      selectedIndex: _index,
      onChanged: (i) => setState(() => _index = i),
      width: barWidth,
      height: _barHeight,
      itemPadding: 3,
      // The safe-area inset is folded in via bottomInset below.
      margin: const EdgeInsets.only(bottom: _bottom),
      style: LiquidGlassStyle(
        shape: _cyber ? _cyberShape(_barHeight / 2) : _glassShape(_barHeight / 2),
        appearance: _cyber
            ? const LiquidGlassAppearance(
                color: Color(0x8C12121A), // 赛博：半透明深色（对齐苹果半透明结构）
                blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
                shadow: LiquidGlassShadow(blur: 9, opacity: 0.2),
              )
            : const LiquidGlassAppearance(
                color: Color(0x8FFFFFFF),
                blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
                shadow: LiquidGlassShadow(blur: 9, opacity: 0.13),
              ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.06,
          distortionWidth: 26,
        ),
      ),
      itemStyle: LiquidGlassTabItemStyle(
        selectedColor: brand,
        unselectedColor: hint,
        iconSize: _iconRest,
        labelFontSize: 10,
        iconLabelGap: 2,
        underGlassIconSize: 30,
        underGlassLabelFontSize: 10,
        selectedFontWeight: FontWeight.w700,
        unselectedFontWeight: FontWeight.w600,
      ),
      pillStyle: LiquidGlassTabPillStyle(
        mode: LiquidGlassPillMode.both,
        rest: LiquidGlassStyle(
          shape: _cyber ? _cyberShape(28) : _glassShape(28),
          appearance: LiquidGlassAppearance(
            // 赛博/苹果选中 pill 统一浅灰微光，深色胶囊上可见（不再深色隐没）
            color: _cyber ? const Color(0x2EAEAEB2) : const Color(0x2EAEAEB2),
          ),
        ),
      ),
    );
    final Widget bottomPipeline = bottomBar.buildGlassPillBar(
      body: _OnAirFeed(title: _titles[_index], cyber: _cyber),
      bottomInset: pad.bottom,
      realTimeCapture: true,
      outerNeedsRealtime: true,
    );

    // ── 顶部液态玻璃分段 tab（大胶囊官方玻璃 + 小滑块自研样式） ─────
    // 保留官方液态玻璃大胶囊，小滑块用自研（渐变+边框+高光），
    // 无长按抓取放大，支持点击 + 按住直接滑动选择。
    final Widget topTab = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _GlassTopTab(
            tabs: _topTabs,
            selectedIndex: _topIndex,
            onChanged: (i) => setState(() => _topIndex = i),
            cyber: _cyber,
          ),
        ),
      ),
    );

    // ── 主题切换按钮（浅色 ↔ 赛博） ────────────────────────────
    final Widget themeToggle = Positioned(
      right: 16,
      bottom: pad.bottom + _bottom + _barHeight + 16,
      child: Material(
        color: _cyber ? const Color(0xFF1A1A24) : Colors.white70,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() => _cyber = !_cyber),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              _cyber ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: brand,
              size: 22,
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：底部管道绘制页面内容 + 底部胶囊
        bottomPipeline,
        // 顶层：顶部液态玻璃分段 tab（纯文字）
        topTab,
        themeToggle,
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — a red-lit radio station, so the bar
//  has real colour to bend.
// ════════════════════════════════════════════════════════════════

class _OnAirFeed extends StatelessWidget {
  const _OnAirFeed({required this.title, this.cyber = false});

  final String title;

  /// 赛博模式（主项目 CyberColors 深色配色）
  final bool cyber;

  Color get brand => cyber ? _cyberCyan : _kBrand;
  Color get ink => cyber ? _cyberTitle : _kInk;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // 浅色：浅灰渐变；赛博：主项目 CyberColors 深色渐变
                  colors: cyber
                      ? [_cyberBg, _cyberCardBg, _cyberCardBg]
                      : [
                          Color(0xFFE7E5EB),
                          Color(0xFFDBD9E2),
                          Color(0xFFCFCDD8),
                        ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          // Two glows — the colour the glass picks up as you scroll.
          Positioned(
            top: -110,
            right: -80,
            child: _Glow(size: 340, color: brand),
          ),
          Positioned(
            bottom: 40,
            left: -130,
            child: _Glow(size: 320, color: brand),
          ),
          ListView(
            // 顶部留白增大，给顶部液态玻璃分段 tab 让位
            padding: const EdgeInsets.fromLTRB(20, 122, 20, 160),
            children: [
              _header(),
              const SizedBox(height: 24),
              _liveCard(),
              const SizedBox(height: 30),
              _sectionTitle('Stations'),
              const SizedBox(height: 14),
              _stationRow(),
              const SizedBox(height: 30),
              _sectionTitle('Recently played'),
              const SizedBox(height: 14),
              for (int i = 0; i < _recent.length; i++) ...[
                _row(_recent[i]),
                if (i != _recent.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: brand,
                      boxShadow: [
                        BoxShadow(
                            color: brand, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ON AIR · 88.6',
                    style: TextStyle(
                      color: brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: ink.withValues(alpha: 0.12), width: 1.4),
            image: const DecorationImage(
              image: NetworkImage('https://picsum.photos/seed/dj/120/120'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Image.network(
            'https://picsum.photos/seed/onair/900/620',
            height: 232,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    _kBrand.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: _kBrand,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Midnight Signal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'with Nadia Rey · 2 hrs left',
                        style:
                            TextStyle(color: Color(0xBFFFFFFF), fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBrand,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x80FF3B30),
                          blurRadius: 22,
                          spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 31),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationRow() {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final (String name, String seed) = _stations[i];
          return SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://picsum.photos/seed/$seed/260/260',
                    width: 118,
                    height: 118,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(_Item item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kInk.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://picsum.photos/seed/${item.seed}/120/120',
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kInk.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded, color: _kBrand, size: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: _kInk,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      );

  /// Artwork-only cards — name + image seed, no second line.
  static const List<(String, String)> _stations = [
    ('Nightline', 'ra'),
    ('Static FM', 'rb'),
    ('Deep Cuts', 'rc'),
    ('Red Room', 'rd'),
    ('Low Tide', 're'),
  ];

  static const _recent = [
    _Item('Signal Lost', 'Kova · 4:12', 'r1'),
    _Item('Analog Heart', 'June Wilder · 3:38', 'r2'),
    _Item('Neon Rain', 'The Hours · 5:02', 'r3'),
    _Item('Slow Burn', 'Marisa Oak · 4:47', 'r4'),
  ];
}

/// A soft coloured bloom behind the feed, so the glass has colour to bend.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// 顶部液态玻璃分段 tab —— 混合方案：
///  - 大胶囊 = 官方 [LiquidGlassLens] 液态玻璃（赛博/苹果两套）
///  - 小滑块 = 自研样式（渐变 + 边框 + 高光/内发光），无长按抓取放大
///  - 交互 = 点击选择 + 按住直接滑动选择（无需长按）
class _GlassTopTab extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool cyber;

  const _GlassTopTab({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.cyber,
  });

  @override
  State<_GlassTopTab> createState() => _GlassTopTabState();
}

class _GlassTopTabState extends State<_GlassTopTab>
    with TickerProviderStateMixin {
  // 玻璃就绪标记：shader 编译完成 + 首帧背景已绘制后才淡入玻璃。
  // 固定延迟不可靠（各设备 shader 编译耗时不同）；改为等待真实就绪信号，
  // 避免 LiquidGlassLens 首次 BackdropFilter 采样背景未就绪 → shapeMask/rim
  // 异常 → 外圈高光丢失。
  bool _glassReady = false;

  // 滑块位置动画（index 单位）：animateTo 从当前实时值平滑接管新目标
  late final AnimationController _pos;
  // 回弹挤压：0..1，0=挤压态，1=恢复
  late final AnimationController _sq;

  double _lastAmp = 1.0; // 最近一次切换的回弹幅度（0.35~1.0）
  double _boundaryDir = 1.0; // +1 向右过墙 / -1 向左过墙
  double _pressValue = 0; // 按下时滑块位置（index 单位，回弹距离/方向依据）

  // 手势/拖拽状态
  bool _isInteracting = false;
  bool _isDragging = false;
  double _dragP = 0; // 拖拽时滑块位置（index 单位）
  double _downLocal = 0;
  double _lastTotalW = 0;
  bool _downSwitched = false; // 按下是否已立即切页（松手 tap 避免重复提交）
  bool _animating = false; // 外部 selectedIndex 变化是否由本组件动画引起

  // 边界过墙量（tab 宽度比例，与底部导航一致）
  static const double _boundaryOvershoot = 0.11;
  // 进入拖拽的最小水平位移
  static const double _dragThreshold = 5.0;

  double get _displayP => _isDragging ? _dragP : _pos.value + _offsetP();

  @override
  void initState() {
    super.initState();
    _pos = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: -0.5,
      upperBound: (widget.tabs.length - 1).toDouble() + 0.5,
    )
      ..value = widget.selectedIndex.toDouble()
      ..addListener(_onTick)
      ..addStatusListener(_onPosStatus);
    _sq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )
      ..value = 1.0
      ..addListener(_onTick);
    _ensureGlassReady();
  }

  /// 可靠的玻璃就绪：双 postFrame 后首帧背景已 paint（LiquidGlassLens 的
  /// BackdropFilter 需要完整背景可采样），再等待 shader 编译完成，最后淡入。
  /// 相比固定延迟，能覆盖"shader 编译慢"与"首帧背景未就绪"两种竞态。
  void _ensureGlassReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final Future<void> ready = LiquidGlassShaders.isLoaded
            ? Future.value()
            : LiquidGlassShaders.ensureLoaded();
        ready.then((_) {
          if (mounted) setState(() => _glassReady = true);
        }).catchError((Object _) {
          // shader 加载失败（异常构建）：仍显示（走 fallback），不留白屏。
          if (mounted) setState(() => _glassReady = true);
        });
      });
    });
  }

  void _onPosStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _animating = false;
  }

  @override
  void didUpdateWidget(_GlassTopTab old) {
    super.didUpdateWidget(old);
    // 外部程序化切换（非本组件动画引起）才驱动滑块动画
    if (widget.selectedIndex != old.selectedIndex &&
        widget.selectedIndex != _pos.value.round() &&
        !_animating) {
      _commit(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _sq.dispose();
    super.dispose();
  }

  void _onTick() => setState(() {});

  // ---------- 手势（点击 + 直接滑动，无长按抓取） ----------

  double _pFromFinger(double dx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (dx / w).clamp(0.0, 1.0);
    return p * (widget.tabs.length - 1);
  }

  int _indexAt(double dx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (dx / w).clamp(0.0, 0.9999);
    return (p * widget.tabs.length).floor().clamp(0, widget.tabs.length - 1);
  }

  void _onPointerDown(PointerDownEvent e) {
    _isInteracting = true;
    _isDragging = false;
    _downLocal = e.localPosition.dx;
    // 按下立即切页（最快的响应），二段回弹留到松手
    final int downTarget = _indexAt(_downLocal);
    _pressValue = _pos.value;
    _downSwitched = downTarget != _pos.value.round();
    if (_downSwitched) {
      _commitPlain(downTarget);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isInteracting) return;
    final delta = e.localPosition.dx - _downLocal;
    if (!_isDragging) {
      if (delta.abs() < _dragThreshold) return;
      _isDragging = true;
    }
    _dragP = _pFromFinger(e.localPosition.dx);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_isInteracting) return;
    if (_isDragging) {
      // 拖拽松手：落到最近的 tab
      final next = _dragP.round().clamp(0, widget.tabs.length - 1);
      _commit(next);
    } else if (_downSwitched) {
      // 按下已平滑切页，快速点击松手补一段回弹
      _bounceOnly(_indexAt(e.localPosition.dx));
    } else {
      _commit(_indexAt(e.localPosition.dx));
    }
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_isInteracting && _isDragging) {
      _commit(_dragP.round().clamp(0, widget.tabs.length - 1));
    }
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  // ---------- 动画 ----------

  /// 提交切换：页面切换 + 回弹
  void _commit(int i) {
    final current = _pos.value.round();
    final maxDist = widget.tabs.length - 1;
    final dist = (i - current).abs();
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= current ? 1.0 : -1.0;
    _animating = true;
    _sq.forward(from: 0);
    _pos.animateTo(
      i.toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (i != widget.selectedIndex) widget.onChanged(i);
  }

  /// 仅平滑切页（按下起手），回弹留在快速点击松手
  void _commitPlain(int i) {
    final current = _pos.value.round();
    final maxDist = widget.tabs.length - 1;
    final dist = (i - current).abs();
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= current ? 1.0 : -1.0;
    _animating = true;
    _pos.animateTo(
      i.toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (i != widget.selectedIndex) widget.onChanged(i);
  }

  /// 仅补一段二段回弹
  void _bounceOnly(int i) {
    final dist = (i - _pressValue).abs();
    final maxDist = widget.tabs.length - 1;
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= _pressValue ? 1.0 : -1.0;
    _sq.forward(from: 0);
  }

  /// 滑块过冲偏移（tab 宽度单位）
  double _offsetP() {
    final t = _sq.value;
    final p = t < 0.48 ? (t / 0.48) : (1 - (t - 0.48) / 0.52);
    return _boundaryDir * _boundaryOvershoot * _lastAmp * p;
  }

  double _scaleX() {
    final t = _sq.value;
    final target = 1.0 - 0.22 * _lastAmp;
    return t < 0.48
        ? 1.0 + (target - 1.0) * (t / 0.48)
        : target + (1.0 - target) * ((t - 0.48) / 0.52);
  }

  double _scaleY() {
    final t = _sq.value;
    final target = 1.0 + 0.05 * _lastAmp;
    return t < 0.48
        ? 1.0 + (target - 1.0) * (t / 0.48)
        : target + (1.0 - target) * ((t - 0.48) / 0.52);
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.tabs.length;

    // 大胶囊 = 官方液态玻璃（与苹果同构：半透明 + 模糊 + 投影，仅换赛博深色）
    final LiquidGlassStyle capsuleStyle = LiquidGlassStyle(
      shape: widget.cyber ? _cyberShape(22) : _glassShape(22),
      appearance: widget.cyber
          ? const LiquidGlassAppearance(
              color: Color(0x8C12121A), // 赛博：半透明深色（对齐苹果半透明结构）
              blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
              shadow: LiquidGlassShadow(blur: 9, opacity: 0.2),
            )
          : const LiquidGlassAppearance(
              color: Color(0x8FFFFFFF),
              blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
              shadow: LiquidGlassShadow(blur: 9, opacity: 0.13),
            ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 22,
      ),
    );

    // 小滑块 = 透明玻璃（官方 LiquidGlassLens，折射背景；保留自研交互/回弹/滑动）
    // 形状两模式完全一致（统一 _glassShape，避免赛博/苹果滑块 rim 高光/边框参数
    // 不同而观感不一致）；颜色与底部导航滑块默认状态一致：浅灰微光 0x2EAEAEB2。
    final LiquidGlassStyle thumbGlass = LiquidGlassStyle(
      shape: _glassShape(17.5),
      appearance: LiquidGlassAppearance(
        // 与底部导航滑块默认状态一致：浅灰微光 0x2EAEAEB2（约 18% 透明），
        // 赛博/苹果统一，不随毛玻璃开关
        color: const Color(0x2EAEAEB2),
        blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 14,
      ),
    );
    final Color activeColor = widget.cyber ? _cyberCyan : _kBrand;
    final Color inactiveColor = widget.cyber ? _cyberHint : _kInk;

    return AnimatedOpacity(
      // 玻璃就绪（shader 编译 + 背景绘制）后才淡入，避免首帧采样异常
      opacity: _glassReady ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SizedBox(
        height: 44,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double tabWidth = totalWidth / count;
              const double horizontalPadding = 3.0;
              final double thumbWidth = tabWidth - horizontalPadding * 2;
              _lastTotalW = totalWidth;
              final double displayP = _displayP;
              final double sx = _scaleX();
              final double sy = _scaleY();
              final double thumbLeft = horizontalPadding + displayP * tabWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 大胶囊：官方液态玻璃 ──
                  Positioned.fill(
                    child: LiquidGlassLens(style: capsuleStyle),
                  ),
                  // ── 小滑块：透明玻璃（官方折射，保留自研交互） ──
                  Positioned(
                    left: thumbLeft,
                    top: 2,
                    bottom: 2,
                    width: thumbWidth,
                    child: IgnorePointer(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(sx, sy),
                        child: LiquidGlassLens(style: thumbGlass),
                      ),
                    ),
                  ),
                  // ── 文字（颜色跟随滑块位置插值） ──
                  Row(
                    children: List.generate(count, (i) {
                      final double distance = (displayP - i).abs();
                      final double t = distance.clamp(0.0, 1.0);
                      final Color textColor = Color.lerp(
                        activeColor,
                        inactiveColor,
                        t,
                      )!;
                      return Expanded(
                        child: Center(
                          child: Text(
                            widget.tabs[i],
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Item {
  const _Item(this.title, this.subtitle, this.seed);
  final String title;
  final String subtitle;
  final String seed;
}
