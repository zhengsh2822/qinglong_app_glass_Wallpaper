import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// 壁纸背景类型。
enum WallpaperType {
  /// 默认渐变。
  gradient,
  /// 纯色背景。
  solid,
  /// 本地相册图片。
  local,
  /// 网络图片 URL。
  network,
}

/// 壁纸配置（不可变快照）。
@immutable
class WallpaperConfig {
  final WallpaperType type;
  /// 纯色背景的颜色值（仅 [WallpaperType.solid] 生效）。
  final int? solidColor;
  /// 本地图片在 app docs 目录下的相对路径（仅 [WallpaperType.local] 生效）。
  final String? localPath;
  /// 网络图片 URL（仅 [WallpaperType.network] 生效）。
  final String? networkUrl;
  /// 背景模糊度 sigma（0 表示不模糊）。
  final double blurSigma;
  /// 蒙层不透明度（0~1，黑色蒙层增强文字可读性）。
  final double dimOpacity;
  /// 是否启用自动切换。
  final bool autoSwitchEnabled;
  /// 自动切换间隔（分钟）。
  final int autoSwitchMinutes;
  /// 自动切换的壁纸池（网络 URL 列表）。
  final List<String> autoSwitchPool;
  /// 渐变预设索引（仅 [WallpaperType.gradient] 生效）。
  /// -1 表示使用自定义渐变（见 [customGradientA]/[customGradientB]）。
  /// 0 及以上表示使用 [PresetGradients.all] 中的第 n 项。
  final int gradientIndex;
  /// 自定义渐变起始色（仅当 [gradientIndex] == -1 时生效）。
  final int? customGradientA;
  /// 自定义渐变结束色（仅当 [gradientIndex] == -1 时生效）。
  final int? customGradientB;

  const WallpaperConfig({
    this.type = WallpaperType.gradient,
    this.solidColor,
    this.localPath,
    this.networkUrl,
    this.blurSigma = 0,
    this.dimOpacity = 0.35,
    this.autoSwitchEnabled = false,
    this.autoSwitchMinutes = 30,
    this.autoSwitchPool = const [],
    this.gradientIndex = 0,
    this.customGradientA,
    this.customGradientB,
  });

  WallpaperConfig copyWith({
    WallpaperType? type,
    int? solidColor,
    String? localPath,
    String? networkUrl,
    double? blurSigma,
    double? dimOpacity,
    bool? autoSwitchEnabled,
    int? autoSwitchMinutes,
    List<String>? autoSwitchPool,
    int? gradientIndex,
    int? customGradientA,
    int? customGradientB,
  }) =>
      WallpaperConfig(
        type: type ?? this.type,
        solidColor: solidColor ?? this.solidColor,
        localPath: localPath ?? this.localPath,
        networkUrl: networkUrl ?? this.networkUrl,
        blurSigma: blurSigma ?? this.blurSigma,
        dimOpacity: dimOpacity ?? this.dimOpacity,
        autoSwitchEnabled: autoSwitchEnabled ?? this.autoSwitchEnabled,
        autoSwitchMinutes: autoSwitchMinutes ?? this.autoSwitchMinutes,
        autoSwitchPool: autoSwitchPool ?? this.autoSwitchPool,
        gradientIndex: gradientIndex ?? this.gradientIndex,
        customGradientA: customGradientA ?? this.customGradientA,
        customGradientB: customGradientB ?? this.customGradientB,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'solidColor': solidColor,
        'localPath': localPath,
        'networkUrl': networkUrl,
        'blurSigma': blurSigma,
        'dimOpacity': dimOpacity,
        'autoSwitchEnabled': autoSwitchEnabled,
        'autoSwitchMinutes': autoSwitchMinutes,
        'autoSwitchPool': autoSwitchPool,
        'gradientIndex': gradientIndex,
        'customGradientA': customGradientA,
        'customGradientB': customGradientB,
      };

  factory WallpaperConfig.fromJson(Map<String, dynamic> j) => WallpaperConfig(
        type: WallpaperType.values.firstWhere(
          (t) => t.name == (j['type'] as String? ?? 'gradient'),
          orElse: () => WallpaperType.gradient,
        ),
        solidColor: j['solidColor'] as int?,
        localPath: j['localPath'] as String?,
        networkUrl: j['networkUrl'] as String?,
        blurSigma: (j['blurSigma'] as num?)?.toDouble() ?? 0,
        dimOpacity: (j['dimOpacity'] as num?)?.toDouble() ?? 0.35,
        autoSwitchEnabled: j['autoSwitchEnabled'] as bool? ?? false,
        autoSwitchMinutes: j['autoSwitchMinutes'] as int? ?? 30,
        autoSwitchPool:
            (j['autoSwitchPool'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        gradientIndex: j['gradientIndex'] as int? ?? 0,
        customGradientA: j['customGradientA'] as int?,
        customGradientB: j['customGradientB'] as int?,
      );

  static const empty = WallpaperConfig();
}

/// 壁纸服务（单例 [ChangeNotifier]）。
///
/// 参考 GitHub 开源项目 hoc081098/wallpaper-flutter 的做法组合：
/// - image_picker：相册选图
/// - shared_preferences：配置持久化
/// - cached_network_image：网络图片加载（在 UI 层使用）
/// - BackdropFilter：背景模糊（在 UI 层使用）
///
/// 性能要点：
/// - 单例 + ChangeNotifier，避免 Widget tree 传递
/// - 配置变更只通知监听者 rebuild，不主动重建图片缓存
/// - 本地图片复制到 app docs dir 持久化，避免源文件被删除
class WallpaperService extends ChangeNotifier {
  WallpaperService._();
  static final WallpaperService instance = WallpaperService._();

  static const _kPrefKey = 'wallpaper_config_v1';

  WallpaperConfig _config = const WallpaperConfig();
  SharedPreferences? _prefs;
  String? _docsDirPath;
  Timer? _autoSwitchTimer;
  int _autoSwitchIndex = 0;

  /// 网络图片下载到本地的缓存路径（相对 _docsDirPath）。
  /// 当 type==network 且此字段非空时，优先用本地缓存文件显示。
  String? _networkCachedPath;

  /// 是否正在下载网络图片（UI 据此显示 loading）。
  bool _downloading = false;
  bool get isDownloading => _downloading;

  /// 当前壁纸的代表色（用于文字反色计算）。
  /// null 表示尚未计算完成（此时 UI 应使用默认色）。
  Color? _averageColor;
  Color? get averageColor => _averageColor;

  /// 背景是否偏亮（考虑蒙层后的实际亮度）。
  /// true → 文字应使用深色；false → 文字应使用浅色。
  bool _isLightBackground = false;
  bool get isLightBackground => _isLightBackground;

  /// 根据背景亮度返回对比文字色（黑或白）。
  /// 亮背景返回深色（保证可读），暗背景返回浅色。
  Color get contrastTextColor =>
      _isLightBackground ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0FF);

  /// 根据背景亮度返回次级文字色（比主文字色稍弱）。
  Color get contrastSubTextColor =>
      _isLightBackground ? const Color(0xFF4A4A4A) : const Color(0xFFB8B8D8);

  /// 根据背景亮度返回提示文字色（更弱）。
  Color get contrastHintTextColor =>
      _isLightBackground ? const Color(0xFF6A6A6A) : const Color(0xFF8A8AAC);

  /// 根据背景亮度返回描述文字色。
  Color get contrastDescTextColor =>
      _isLightBackground ? const Color(0xFF5A5A5A) : const Color(0xFF9A9AB8);

  WallpaperConfig get config => _config;

  /// 当前背景类型。
  WallpaperType get type => _config.type;

  /// 当前模糊度。
  double get blurSigma => _config.blurSigma;

  /// 当前蒙层不透明度。
  double get dimOpacity => _config.dimOpacity;

  /// 初始化：加载持久化配置 + 启动自动切换定时器。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    _docsDirPath = dir.path;
    final raw = _prefs?.getString(_kPrefKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _config = WallpaperConfig.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('加载壁纸配置失败: $e');
      }
    }
    // 若有网络壁纸，启动时尝试用本地缓存
    if (_config.type == WallpaperType.network &&
        _config.networkUrl != null) {
      _networkCachedPath = _findCachedNetworkFile(_config.networkUrl!);
    }
    _applyAutoSwitch();
    // 异步计算壁纸平均色，用于文字反色
    _computeAverageColor();
  }

  // —— 配置变更 API ——

  /// 切换背景类型。
  Future<void> setType(WallpaperType type) async {
    _config = _config.copyWith(type: type);
    await _save();
    notifyListeners();
    _computeAverageColor();
  }

  /// 设置纯色背景颜色。
  Future<void> setSolidColor(Color color) async {
    _config = _config.copyWith(
      type: WallpaperType.solid,
      solidColor: color.value,
    );
    await _save();
    notifyListeners();
    _computeAverageColor();
  }

  /// 选择预设渐变（index 对应 [PresetGradients.all] 索引）。
  Future<void> setGradientPreset(int index) async {
    _config = _config.copyWith(
      type: WallpaperType.gradient,
      gradientIndex: index,
    );
    await _save();
    notifyListeners();
    _computeAverageColor();
  }

  /// 设置自定义渐变（两色线性，左上→右下）。
  /// 会把 [gradientIndex] 置为 -1 表示使用自定义。
  Future<void> setCustomGradient(Color a, Color b) async {
    _config = _config.copyWith(
      type: WallpaperType.gradient,
      gradientIndex: -1,
      customGradientA: a.value,
      customGradientB: b.value,
    );
    await _save();
    notifyListeners();
    _computeAverageColor();
  }

  /// 当前生效的渐变（仅 [WallpaperType.gradient] 时有意义）。
  LinearGradient get currentGradient {
    final cfg = _config;
    if (cfg.gradientIndex >= 0 &&
        cfg.gradientIndex < PresetGradients.all.length) {
      return PresetGradients.all[cfg.gradientIndex];
    }
    // 自定义渐变
    final a = cfg.customGradientA;
    final b = cfg.customGradientB;
    if (a != null && b != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(a), Color(b)],
      );
    }
    return PresetGradients.defaultGradient;
  }

  /// 从相册选图并设为背景。
  ///
  /// 流程：image_picker 选图 → 复制到 app docs dir → 持久化路径。
  /// 返回 null 表示用户取消或失败（错误已打印）。
  Future<String?> pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2160,
        imageQuality: 92,
      );
      if (xfile == null) return null;
      final savedPath = await _persistLocalImage(File(xfile.path));
      _config = _config.copyWith(
        type: WallpaperType.local,
        localPath: savedPath,
      );
      await _save();
      notifyListeners();
      _computeAverageColor();
      return savedPath;
    } catch (e) {
      debugPrint('相册选图失败: $e');
      return null;
    }
  }

  /// 设置网络图片 URL 为背景。
  ///
  /// 流程：保存 URL → 通知 UI 立即用 Image.network 预览 →
  /// 后台用 http 下载到 app docs dir 的 network_cache/ →
  /// 下载完成后切换到本地缓存路径显示，下次启动无需重新下载。
  Future<void> setNetworkUrl(String url) async {
    _config = _config.copyWith(
      type: WallpaperType.network,
      networkUrl: url,
    );
    _networkCachedPath = _findCachedNetworkFile(url);
    await _save();
    notifyListeners();
    // 先尝试用 URL 提取主色（预览阶段），下载完成后 _downloadAndCacheNetwork
    // 会再次触发 _computeAverageColor 切换到本地文件提取（更快更稳定）
    _computeAverageColor();
    // 后台下载（不阻塞 UI）
    if (_networkCachedPath == null) {
      _downloadAndCacheNetwork(url);
    }
  }

  /// 后台下载网络图片到本地缓存目录。
  Future<void> _downloadAndCacheNetwork(String url) async {
    if (_docsDirPath == null || _downloading) return;
    _downloading = true;
    notifyListeners();
    try {
      final dir = Directory('$_docsDirPath/network_cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final name =
          'net_${url.hashCode.abs()}${_extFromUrl(url)}';
      final target = File('${dir.path}/$name');
      if (!target.existsSync()) {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          await target.writeAsBytes(resp.bodyBytes);
        } else {
          debugPrint('下载网络壁纸失败：HTTP ${resp.statusCode}');
          _downloading = false;
          notifyListeners();
          return;
        }
      }
      _networkCachedPath = 'network_cache/$name';
      _downloading = false;
      notifyListeners();
      // 下载完成，用本地缓存文件重新提取主色（比 NetworkImage 更快更稳定）
      _computeAverageColor();
    } catch (e) {
      debugPrint('下载网络壁纸异常: $e');
      _downloading = false;
      notifyListeners();
    }
  }

  /// 从 URL 推断图片扩展名。
  String _extFromUrl(String url) {
    final u = url.split('?').first.toLowerCase();
    final dot = u.lastIndexOf('.');
    if (dot >= 0) {
      final ext = u.substring(dot);
      if ({'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'}
          .contains(ext)) {
        return ext;
      }
    }
    return '.jpg';
  }

  /// 查找已下载的网络图片缓存路径（若存在）。
  String? _findCachedNetworkFile(String url) {
    if (_docsDirPath == null) return null;
    final name = 'net_${url.hashCode.abs()}${_extFromUrl(url)}';
    final f = File('$_docsDirPath/network_cache/$name');
    return f.existsSync() ? 'network_cache/$name' : null;
  }

  /// 网络壁纸的本地缓存 File（若已下载）。
  File? get networkCachedFile {
    final p = _networkCachedPath;
    if (p == null || _docsDirPath == null) return null;
    final f = File('$_docsDirPath/$p');
    return f.existsSync() ? f : null;
  }

  /// 设置模糊度 sigma（0~50）。
  Future<void> setBlurSigma(double sigma) async {
    _config = _config.copyWith(blurSigma: sigma.clamp(0.0, 50.0));
    await _save();
    notifyListeners();
  }

  /// 设置黑色蒙层不透明度（0~1）。
  Future<void> setDimOpacity(double opacity) async {
    _config = _config.copyWith(dimOpacity: opacity.clamp(0.0, 1.0));
    await _save();
    // 蒙层影响实际亮度，需重新计算反色
    _updateLightFlag();
    notifyListeners();
  }

  /// 配置自动切换。
  Future<void> setAutoSwitch({
    bool? enabled,
    int? minutes,
    List<String>? pool,
  }) async {
    _config = _config.copyWith(
      autoSwitchEnabled: enabled,
      autoSwitchMinutes: minutes,
      autoSwitchPool: pool,
    );
    await _save();
    _applyAutoSwitch();
    notifyListeners();
  }

  /// 手动触发自动切换池中的下一张。
  Future<void> rotateAutoSwitch() async {
    final pool = _config.autoSwitchPool;
    if (pool.isEmpty) return;
    _autoSwitchIndex = (_autoSwitchIndex + 1) % pool.length;
    await setNetworkUrl(pool[_autoSwitchIndex]);
  }

  /// 重置为默认渐变背景。
  Future<void> reset() async {
    _config = const WallpaperConfig();
    await _save();
    _applyAutoSwitch();
    notifyListeners();
    _computeAverageColor();
  }

  /// 返回本地图片的绝对 File（仅 [WallpaperType.local] 有意义）。
  File? get localImageFile {
    final p = _config.localPath;
    if (p == null || _docsDirPath == null) return null;
    final f = File('$_docsDirPath/$p');
    return f.existsSync() ? f : null;
  }

  // —— 内部 ——

  Future<void> _save() async {
    try {
      await _prefs?.setString(_kPrefKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('保存壁纸配置失败: $e');
    }
  }

  /// 把源图片复制到 app docs 目录下的 wallpapers/ 子目录，
  /// 返回相对路径（用于持久化）。
  Future<String> _persistLocalImage(File source) async {
    final dir = Directory('$_docsDirPath/wallpapers');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final name =
        'wp_${DateTime.now().millisecondsSinceEpoch}${_ext(source.path)}';
    final target = File('${dir.path}/$name');
    await source.copy(target.path);
    return 'wallpapers/$name';
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot).toLowerCase() : '.jpg';
  }

  void _applyAutoSwitch() {
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = null;
    if (!_config.autoSwitchEnabled || _config.autoSwitchPool.isEmpty) return;
    final duration = Duration(minutes: _config.autoSwitchMinutes);
    _autoSwitchTimer = Timer.periodic(duration, (_) => rotateAutoSwitch());
  }

  // —— 壁纸平均色 / 文字反色 ——

  /// 异步计算当前壁纸的代表色，并更新 [_averageColor] 与 [_isLightBackground]。
  ///
  /// 不同类型壁纸的计算方式：
  /// - gradient：取渐变两端颜色的平均
  /// - solid：直接用 solidColor
  /// - local/network：用 Flutter 内置 [ColorScheme.fromImageProvider]
  ///   提取图片主色（Material 3 能力，无需第三方依赖）
  ///
  /// 计算完成后通知 UI 刷新文字色。
  Future<void> _computeAverageColor() async {
    final cfg = _config;
    Color? color;
    try {
      switch (cfg.type) {
        case WallpaperType.gradient:
          final grad = currentGradient.colors;
          if (grad.length >= 2) {
            color = _blendColors(grad[0], grad[1]);
          } else if (grad.isNotEmpty) {
            color = grad[0];
          }
          break;
        case WallpaperType.solid:
          if (cfg.solidColor != null) {
            color = Color(cfg.solidColor!);
          }
          break;
        case WallpaperType.local:
          final file = localImageFile;
          if (file != null) {
            color = await _extractFromImage(FileImage(file));
          }
          break;
        case WallpaperType.network:
          final cached = networkCachedFile;
          if (cached != null) {
            color = await _extractFromImage(FileImage(cached));
          } else if (cfg.networkUrl != null && isHttpUrl(cfg.networkUrl!)) {
            color = await _extractFromImage(NetworkImage(cfg.networkUrl!));
          }
          break;
      }
    } catch (e) {
      debugPrint('计算壁纸平均色失败: $e');
    }
    _averageColor = color;
    _updateLightFlag();
    notifyListeners();
  }

  /// 用 [ColorScheme.fromImageProvider] 提取图片主色。
  /// 这是 Flutter Material 3 内置能力，无需 palette_generator 等第三方包。
  Future<Color?> _extractFromImage(ImageProvider provider) async {
    final scheme = await ColorScheme.fromImageProvider(
      provider: provider,
      brightness: Brightness.light,
    );
    return scheme.primary;
  }

  /// 混合两个颜色（算术平均，忽略 alpha）。
  Color _blendColors(Color a, Color b) {
    return Color.fromARGB(
      255,
      ((a.red + b.red) / 2).round(),
      ((a.green + b.green) / 2).round(),
      ((a.blue + b.blue) / 2).round(),
    );
  }

  /// 根据 [_averageColor] 和 [dimOpacity] 更新 [_isLightBackground]。
  ///
  /// 实际显示亮度 = 壁纸亮度 × (1 - dimOpacity)
  /// - dimOpacity=0.35 时，亮度 0.8 的壁纸实际显示亮度约 0.52，仍算亮色
  /// - dimOpacity=0.5 时，亮度 0.8 的壁纸实际显示亮度 0.4，算暗色
  ///
  /// 阈值 0.5：高于此值文字用深色，低于用浅色。
  void _updateLightFlag() {
    final base = _averageColor;
    if (base == null) {
      _isLightBackground = false;
      return;
    }
    final rawLum = base.computeLuminance();
    final effectiveLum = rawLum * (1.0 - _config.dimOpacity);
    _isLightBackground = effectiveLum > 0.5;
  }

  @override
  void dispose() {
    _autoSwitchTimer?.cancel();
    super.dispose();
  }
}

/// 预设渐变背景集合（项目内可复用）。
class PresetGradients {
  PresetGradients._();

  /// 项目默认渐变（青龙主色 cyan 系）。
  static const LinearGradient defaultGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF0F2027), Color(0xFF203A43)],
    stops: [0.0, 0.35, 0.65, 1.0],
  );

  static const List<LinearGradient> all = [
    defaultGradient,
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF41295B), Color(0xFF2F0743)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF603813), Color(0xFFB29F94)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF000428), Color(0xFF004E92)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF141E30), Color(0xFF243B55)],
    ),
    // 青色系（与青龙主色 #00CCCC 呼应）
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF006064), Color(0xFF00CCCC), Color(0xFF26D0CE)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A0A0F), Color(0xFF12121A), Color(0xFF1A1A2E)],
    ),
  ];
}

/// 预设纯色背景集合。
class PresetSolidColors {
  PresetSolidColors._();

  static const List<Color> all = [
    Color(0xFF0D1B2A),
    Color(0xFF1B263B),
    Color(0xFF000000),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
    Color(0xFF2D3436),
    Color(0xFF1E272E),
    // 青龙赛博深色
    Color(0xFF0A0A0F),
    Color(0xFF12121A),
  ];
}

/// 内置网络壁纸源（Bing 每日壁纸，无密钥）。
class NetworkWallpaperSources {
  NetworkWallpaperSources._();

  /// Bing 每日壁纸（最近 8 天，idx=0 为今天）。
  static List<String> bingDaily({int count = 8}) {
    return List.generate(count, (i) {
      return 'https://bing.biturl.top/?resolution=1920&index=$i&format=image';
    });
  }

  /// picsum 随机壁纸。
  static String picsum({int seed = 0, int w = 1920, int h = 1080}) {
    return 'https://picsum.photos/seed/$seed/$w/$h';
  }

  /// 预设的 picsum 壁纸池（10 张稳定种子）。
  static List<String> get picsumPool =>
      List.generate(10, (i) => picsum(seed: 1000 + i));
}

/// 颜色工具：把 ARGB int 转 Color。
Color colorFromInt(int? value) =>
    value == null ? const Color(0xFFF9F9F9) : Color(value);

/// 工具：判断字符串是否是 http(s) URL。
bool isHttpUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

/// 工具：生成随机种子（保留以防未来需要）。
int randomSeed() => math.Random().nextInt(1 << 32);
