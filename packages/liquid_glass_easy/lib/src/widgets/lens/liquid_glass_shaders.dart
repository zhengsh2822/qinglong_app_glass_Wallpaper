import 'dart:ui' as ui;

/// App-wide cache for the compiled liquid-glass fragment programs.
///
/// A `FragmentProgram` is expensive to compile and identical for every
/// lens in the app, so it is loaded once and shared. Individual
/// `FragmentShader` *instances* (which hold per-lens uniform state) are
/// created from the cached programs and owned by their lens.
///
/// ## Per-backend programs
///
/// The shape-gradient method differs by backend: Impeller uses hardware
/// derivatives (`dFdx`), which are invalid SkSL — so Skia/web loads a
/// separate entry that selects the analytic gradient instead. The programs
/// are therefore cached **per backend** (`impeller` true/false), and every
/// call passes the backend it needs:
///
///   * `impeller == true`  → `liquid_glass.frag` / `liquid_glass_border.frag`
///   * `impeller == false` → `liquid_glass_skia.frag` / `..._border_skia.frag`
///
/// `LiquidGlassView` and the standalone `LiquidGlassLens` both load through
/// this cache, so whichever mounts first pays the one-time async compile and
/// every later mount on the same backend gets its shaders synchronously.
///
/// Call [ensureLoaded] ahead of time (e.g. in `main()` before `runApp`) to
/// guarantee even the very first lens renders on its first frame. With no
/// argument it preloads the engine's native backend
/// (`ui.ImageFilter.isShaderFilterSupported`):
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LiquidGlassShaders.ensureLoaded();
///   runApp(const MyApp());
/// }
/// ```
class LiquidGlassShaders {
  LiquidGlassShaders._();

  // Programs keyed by backend: true = Impeller (derivative), false = Skia
  // (analytic). Each backend loads a different entry .frag.
  static final Map<bool, ui.FragmentProgram> _mainPrograms = {};
  static final Map<bool, ui.FragmentProgram> _borderPrograms = {};
  static final Map<bool, Future<void>> _loading = {};

  static const Map<bool, String> _mainAsset = {
    true: 'lib/assets/shaders/liquid_glass.frag',
    false: 'lib/assets/shaders/liquid_glass_skia.frag',
  };
  static const Map<bool, String> _borderAsset = {
    true: 'lib/assets/shaders/liquid_glass_border.frag',
    false: 'lib/assets/shaders/liquid_glass_border_skia.frag',
  };

  /// The engine's native backend — Impeller exposes the shader image filter.
  static bool get _defaultImpeller => ui.ImageFilter.isShaderFilterSupported;

  /// Whether both programs for [impeller] are compiled and shader instances
  /// can be created synchronously via [createMainShader]/[createBorderShader].
  static bool isLoadedFor(bool impeller) =>
      _mainPrograms.containsKey(impeller) &&
      _borderPrograms.containsKey(impeller);

  /// Whether the engine's native backend is loaded. Convenience for callers
  /// that don't track the backend explicitly.
  static bool get isLoaded => isLoadedFor(_defaultImpeller);

  /// Loads and compiles both fragment programs for [impeller] once (defaults
  /// to the engine's native backend). Safe to call repeatedly and from
  /// multiple call sites — concurrent callers for the same backend share the
  /// in-flight future, and once loaded it completes synchronously.
  static Future<void> ensureLoaded([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    if (isLoadedFor(backend)) return Future.value();
    return _loading[backend] ??= _load(backend);
  }

  static Future<void> _load(bool impeller) async {
    try {
      _mainPrograms[impeller] ??= await _loadProgram(_mainAsset[impeller]!);
      _borderPrograms[impeller] ??= await _loadProgram(_borderAsset[impeller]!);
    } finally {
      // Reset so a failed load (e.g. asset missing in a broken build) can be
      // retried instead of caching the failure forever.
      _loading.remove(impeller);
    }
  }

  static Future<ui.FragmentProgram> _loadProgram(String relativePath) async {
    try {
      // Normal case: this package is a dependency of the running app, so its
      // assets live under the packages/ prefix.
      return await ui.FragmentProgram.fromAsset(
          'packages/liquid_glass_easy/$relativePath');
    } catch (_) {
      // Running inside the package itself (its own widget tests), where the
      // same assets resolve without the prefix.
      return await ui.FragmentProgram.fromAsset(relativePath);
    }
  }

  /// Creates a fresh main-shader instance for [impeller] (defaults to the
  /// engine's native backend). [isLoadedFor] must be true for that backend.
  static ui.FragmentShader createMainShader([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    final program = _mainPrograms[backend];
    assert(program != null,
        'LiquidGlassShaders not loaded — await ensureLoaded($backend) first.');
    return program!.fragmentShader();
  }

  /// Creates a fresh border-shader instance for [impeller] (defaults to the
  /// engine's native backend). [isLoadedFor] must be true for that backend.
  static ui.FragmentShader createBorderShader([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    final program = _borderPrograms[backend];
    assert(program != null,
        'LiquidGlassShaders not loaded — await ensureLoaded($backend) first.');
    return program!.fragmentShader();
  }
}
