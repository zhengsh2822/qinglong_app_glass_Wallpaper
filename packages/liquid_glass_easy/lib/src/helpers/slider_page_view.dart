import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

import '../widgets/utils/liquid_glass_refraction_mode.dart';
import '../widgets/utils/liquid_glass_shape.dart';

class SlidersPageView extends StatelessWidget {
  final PageController controller;
  final int currentPage;

  // values + callbacks
  final double lensWidth;
  final double lensHeight;
  final double cornerRadius;
  final double magnification;
  final bool refractionMode;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final double borderWidth;
  final double borderSoftness;
  final double lightIntensity;
  final double oneSideLightIntensity;
  final double lightDirection;
  final bool lightMode;
  final double doubleSideLightIntensity;
  final double borderSaturation;
  final double ambientIntensity;
  final double borderSolidity;
  final bool borderMode;
  final Color glassColor;
  final Color lightColorValue;
  final Color shadowColorValue;
  final double chromaticAberration;
  final double saturation;
  final LiquidGlassCornerStyle cornerStyle;
  final double pixelRatio;
  final double blur;
  final double refreshRate;
  final bool realTimeCapture;
  final bool useSync;
  final bool enableInnerRadiusTransparent;

  final ValueChanged<int> onPageChanged;

  final ValueChanged<double> onLensWidthChanged;
  final ValueChanged<double> onLensHeightChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final ValueChanged<double> onMagnificationChanged;
  final ValueChanged<bool> onRefractionModeChanged;
  final ValueChanged<double> onDistortionChanged;
  final ValueChanged<double> onDistortionWidthChanged;
  final ValueChanged<double> onDiagonalFlipChanged;
  final ValueChanged<double> onBorderWidthChanged;
  final ValueChanged<double> onBorderSoftnessChanged;
  final ValueChanged<double> onLightIntensityChanged;
  final ValueChanged<double> onOneSideLightIntensityChanged;

  final ValueChanged<double> onLightDirectionChanged;
  final ValueChanged<bool> onLightModeChanged;
  final ValueChanged<double> onDoubleSideLightIntensityChanged;
  final ValueChanged<double> onBorderSaturationChanged;
  final ValueChanged<double> onAmbientIntensityChanged;
  final ValueChanged<double> onBorderSolidityChanged;
  final ValueChanged<bool> onBorderModeChanged;
  final ValueChanged<Color> onGlassColorChanged;
  final ValueChanged<Color> onLightColorChanged;
  final ValueChanged<Color> onShadowColorChanged;
  final ValueChanged<double> onChromaticAberrationChanged;
  final ValueChanged<double> onSaturationChanged;

  final ValueChanged<LiquidGlassCornerStyle> onCornerStyleChanged;
  final ValueChanged<double> onBlurChanged;
  final ValueChanged<double> onRefreshRateChanged;
  final ValueChanged<double> onPixelRatioChanged;
  final ValueChanged<bool> onRealTimeCaptureChanged;
  final ValueChanged<bool> onUseSyncChanged;
  final ValueChanged<bool> onEnableInnerRadiusTransparent;

  const SlidersPageView({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.lensWidth,
    required this.lensHeight,
    required this.cornerRadius,
    required this.magnification,
    required this.refractionMode,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.borderWidth,
    required this.borderSoftness,
    required this.lightIntensity,
    required this.oneSideLightIntensity,
    required this.lightDirection,
    required this.lightMode,
    required this.doubleSideLightIntensity,
    required this.borderSaturation,
    required this.ambientIntensity,
    required this.borderSolidity,
    required this.borderMode,
    required this.glassColor,
    required this.lightColorValue,
    required this.shadowColorValue,
    required this.chromaticAberration,
    required this.saturation,
    required this.cornerStyle,
    required this.pixelRatio,
    required this.blur,
    required this.refreshRate,
    required this.realTimeCapture,
    required this.useSync,
    required this.enableInnerRadiusTransparent,
    required this.onPageChanged,
    required this.onLensWidthChanged,
    required this.onLensHeightChanged,
    required this.onCornerRadiusChanged,
    required this.onMagnificationChanged,
    required this.onRefractionModeChanged,
    required this.onDistortionChanged,
    required this.onDistortionWidthChanged,
    required this.onEnableInnerRadiusTransparent,
    required this.onDiagonalFlipChanged,
    required this.onBorderWidthChanged,
    required this.onBorderSoftnessChanged,
    required this.onLightIntensityChanged,
    required this.onOneSideLightIntensityChanged,
    required this.onLightDirectionChanged,
    required this.onLightModeChanged,
    required this.onDoubleSideLightIntensityChanged,
    required this.onBorderSaturationChanged,
    required this.onAmbientIntensityChanged,
    required this.onBorderSolidityChanged,
    required this.onBorderModeChanged,
    required this.onGlassColorChanged,
    required this.onLightColorChanged,
    required this.onShadowColorChanged,
    required this.onChromaticAberrationChanged,
    required this.onSaturationChanged,
    required this.onCornerStyleChanged,
    required this.onBlurChanged,
    required this.onRefreshRateChanged,
    required this.onPixelRatioChanged,
    required this.onRealTimeCaptureChanged,
    required this.onUseSyncChanged,
  });

  static const int totalPages = 4;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentPage > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    controller.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                )
              else
                const SizedBox(width: 48),
              Text(
                "Page ${currentPage + 1} / $totalPages",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (currentPage < totalPages - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () {
                    controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: PageView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: onPageChanged,
              children: [
                // --- Page 1: Lens Settings ---
                _buildSliderPage(
                  context,
                  title: "Lens Settings",
                  icon: Icons.center_focus_strong,
                  copyButton: ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text(
                      "Copy values",
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      //backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final code = _generateLiquidGlassCode();
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Copied LiquidGlass code with sliders values to clipboard"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  sliders: [
                    SliderWidget(
                      label: "Width",
                      value: lensWidth,
                      min: 50,
                      max: 400,
                      devision: 350,
                      onChanged: onLensWidthChanged,
                    ),
                    SliderWidget(
                      label: "Height",
                      value: lensHeight,
                      min: 50,
                      max: 400,
                      devision: 350,
                      onChanged: onLensHeightChanged,
                    ),
                    SliderWidget(
                      label: "Corner Radius",
                      value: cornerRadius,
                      min: 0,
                      max: 100,
                      devision: 100,
                      onChanged: onCornerRadiusChanged,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Corner Style"),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child:
                                SegmentedButton<LiquidGlassCornerStyle>(
                              segments: const [
                                ButtonSegment(
                                  value:
                                      LiquidGlassCornerStyle.roundedRectangle,
                                  label: Text('Round'),
                                ),
                                ButtonSegment(
                                  value: LiquidGlassCornerStyle.squircle,
                                  label: Text('Squircle'),
                                ),
                                ButtonSegment(
                                  value: LiquidGlassCornerStyle
                                      .continuousRoundedRectangle,
                                  label: Text('Continuous'),
                                ),
                              ],
                              selected: {cornerStyle},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) =>
                                  onCornerStyleChanged(s.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // --- Page 2: Effects & Distortion ---
                _buildSliderPage(
                  context,
                  title: "Effects & Distortion",
                  icon: Icons.blur_on,
                  sliders: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Shape Refraction - Radial Refraction"),
                        ),
                        Switch(
                          value: refractionMode,
                          onChanged: onRefractionModeChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Distortion",
                      value: distortion,
                      min: 0,
                      max: 1,
                      devision: 100,
                      onChanged: onDistortionChanged,
                    ),
                    SliderWidget(
                      label: "Distortion Width",
                      value: distortionWidth,
                      min: 0,
                      max: 100,
                      devision: 100,
                      onChanged: onDistortionWidthChanged,
                    ),
                    SliderWidget(
                      label: "Magnification",
                      value: magnification,
                      min: 0,
                      max: 5.0,
                      devision: 100,
                      onChanged: onMagnificationChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Enable Transparency"),
                        ),
                        Switch(
                          value: enableInnerRadiusTransparent,
                          onChanged: onEnableInnerRadiusTransparent,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Diagonal Flip",
                      value: diagonalFlip,
                      min: 0,
                      max: 1,
                      devision: 100,
                      onChanged: onDiagonalFlipChanged,
                    ),
                    SliderWidget(
                      label: "Blur",
                      value: blur,
                      min: 0,
                      max: 3,
                      devision: 30,
                      onChanged: onBlurChanged,
                    ),
                    SliderWidget(
                      label: "Chromatic Aberration",
                      value: chromaticAberration,
                      min: 0,
                      max: 0.25,
                      devision: 100,
                      onChanged: onChromaticAberrationChanged,
                    ),
                    SliderWidget(
                      label: "Saturation",
                      value: saturation,
                      min: 0,
                      max: 3,
                      devision: 30,
                      onChanged: onSaturationChanged,
                    ),
                    const SizedBox(height: 12),
                    _ColorPickerRow(
                      label: "Glass Color",
                      color: glassColor,
                      onChanged: onGlassColorChanged,
                    ),
                  ],
                ),

                // --- Page 3: Border Settings (NEW) ---
                _buildSliderPage(
                  context,
                  title: "Border Settings",
                  icon: Icons.border_style,
                  sliders: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Classic Border - Optical Border"),
                        ),
                        Switch(
                          value: borderMode,
                          onChanged: onBorderModeChanged,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Edge light Mode - Radial Light Mode"),
                        ),
                        Switch(
                          value: lightMode,
                          onChanged: onLightModeChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Border Width",
                      value: borderWidth,
                      min: 0,
                      max: 20,
                      devision: 100,
                      onChanged: onBorderWidthChanged,
                    ),
                    // Classic only
                    SliderWidget(
                      label: "Border Softness${borderMode ? ' (Classic only)' : ''}",
                      value: borderSoftness,
                      min: 0,
                      max: 50,
                      devision: 100,
                      onChanged: onBorderSoftnessChanged,
                      enabled: !borderMode,
                    ),
                    SliderWidget(
                      label: "Light Intensity",
                      value: lightIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onLightIntensityChanged,
                    ),
                    SliderWidget(
                      label: "One Side Light Intensity${borderMode ? ' (Classic only)' : ''}",
                      value: oneSideLightIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onOneSideLightIntensityChanged,
                      enabled: !borderMode,
                    ),
                    SliderWidget(
                      label: "Double Side Light Intensity${borderMode ? ' (Classic only)' : ''}",
                      value: doubleSideLightIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onDoubleSideLightIntensityChanged,
                      enabled: !borderMode,
                    ),
                    SliderWidget(
                      label: "Light Direction",
                      value: lightDirection,
                      min: 0,
                      max: 360,
                      devision: 360,
                      onChanged: onLightDirectionChanged,
                    ),
                    // Optical only
                    SliderWidget(
                      label: "Border Saturation${!borderMode ? ' (Optical only)' : ''}",
                      value: borderSaturation,
                      min: 0,
                      max: 3,
                      devision: 100,
                      onChanged: onBorderSaturationChanged,
                      enabled: borderMode,
                    ),
                    // Optical only
                    SliderWidget(
                      label: "Ambient Intensity${!borderMode ? ' (Optical only)' : ''}",
                      value: ambientIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onAmbientIntensityChanged,
                      enabled: borderMode,
                    ),
                    // Optical only
                    SliderWidget(
                      label: "Border Solidity${!borderMode ? ' (Optical only)' : ''}",
                      value: borderSolidity,
                      min: 0,
                      max: 1,
                      devision: 100,
                      onChanged: onBorderSolidityChanged,
                      enabled: borderMode,
                    ),
                    const SizedBox(height: 12),
                    // Classic only — shadow color
                    _ColorPickerRow(
                      label: "Light Color",
                      color: lightColorValue,
                      onChanged: onLightColorChanged,
                    ),
                    const SizedBox(height: 8),
                    _ColorPickerRow(
                      label: "Shadow Color${borderMode ? ' (Classic only)' : ''}",
                      color: shadowColorValue,
                      onChanged: onShadowColorChanged,
                      enabled: !borderMode,
                    ),
                  ],
                ),

                // --- Page 4: Performance ---
                _buildSliderPage(
                  context,
                  title: "Performance",
                  icon: Icons.speed,
                  sliders: [
                    const SizedBox(height: 8),
                    SliderWidget(
                      label: "Pixel Ratio",
                      value: pixelRatio,
                      min: 0,
                      max: 3.0,
                      devision: 30,
                      onChanged: onPixelRatioChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Real Time Capture"),
                        Switch(
                          value: realTimeCapture,
                          onChanged: onRealTimeCaptureChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Refresh Rate",
                      value: refreshRate,
                      min: 0,
                      max: 3,
                      devision: 3,
                      onChanged: onRefreshRateChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Low"),
                        Text("Medium"),
                        Text("High"),
                        Text("Device Refresh Rate"),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Use Sync"),
                        Switch(
                          value: useSync,
                          onChanged: onUseSyncChanged,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(4),
                width: currentPage == index ? 20 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: currentPage == index ? accent : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _generateLiquidGlassCode() {
    final refractionModeCode = refractionMode
        ? '''${LiquidGlassRefractionMode.radialRefraction}'''
        : '''${LiquidGlassRefractionMode.shapeRefraction}''';
    final lightModeCode = lightMode
        ? '''${LiquidGlassLightMode.radial}'''
        : '''${LiquidGlassLightMode.edge}''';
    final borderModeCode = borderMode
        ? '''OpticalBorder(
    borderSaturation: $borderSaturation,
    ambientIntensity: $ambientIntensity,
    borderSolidity: $borderSolidity,
  )'''
        : '''ClassicBorder(
    borderSoftness: $borderSoftness,
    shadowColor: $shadowColorValue,
    oneSideLightIntensity: $oneSideLightIntensity,
    doubleSideLightIntensity: $doubleSideLightIntensity,
  )''';

    final cornerStyleName = switch (cornerStyle) {
      LiquidGlassCornerStyle.roundedRectangle => 'roundedRectangle',
      LiquidGlassCornerStyle.squircle => 'squircle',
      LiquidGlassCornerStyle.continuousRoundedRectangle =>
        'continuousRoundedRectangle',
    };
    final shapeCode = '''
LiquidGlassShape.$cornerStyleName(
  cornerRadius: $cornerRadius,
  borderWidth: $borderWidth,
  lightIntensity: $lightIntensity,
  lightDirection: $lightDirection,
  lightMode: $lightModeCode,
  lightColor: $lightColorValue,
  borderType: $borderModeCode,
)
''';

    return '''
LiquidGlassView(
  controller: viewController,
  pixelRatio: $pixelRatio,
  realTimeCapture: $realTimeCapture,
  refreshRate: ${refreshRate == 0 ? LiquidGlassRefreshRate.low : refreshRate == 1 ? LiquidGlassRefreshRate.medium : refreshRate == 2 ? LiquidGlassRefreshRate.high : LiquidGlassRefreshRate.deviceRefreshRate},
  useSync: $useSync,
  backgroundWidget: YourBackgroundWidget(),
  children: [
    LiquidGlass(
      geometry: LiquidGlassGeometry(
        position: const LiquidGlassAlignPosition(
          alignment: Alignment.center,
        ),
        width: $lensWidth,
        height: $lensHeight,
      ),
      shape: $shapeCode,
      refraction: LiquidGlassRefraction(
        magnification: $magnification,
        refractionMode:$refractionModeCode,
        diagonalFlip: $diagonalFlip,
        distortion: $distortion,
        distortionWidth: $distortionWidth,
        chromaticAberration:$chromaticAberration,
      ),
      appearance: LiquidGlassAppearance(
        enableInnerRadiusTransparent: $enableInnerRadiusTransparent,
        blur: LiquidGlassBlur(sigmaX: $blur, sigmaY: $blur),
        saturation:$saturation,
      ),
      behavior: LiquidGlassBehavior(
        controller: controller,
        draggable: true,
      ),
    ),
  ],
);
''';
  }

  Widget _buildSliderPage(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> sliders,
    Widget copyButton = const SizedBox.shrink(),
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        clipBehavior: Clip.antiAlias,
        child: _ScrollableWithHint(
          title: title,
          icon: icon,
          sliders: sliders,
          copyButton: copyButton,
        ),
      ),
    );
  }
}

class _ScrollableWithHint extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> sliders;
  final Widget copyButton;

  const _ScrollableWithHint({
    required this.title,
    required this.icon,
    required this.sliders,
    this.copyButton = const SizedBox.shrink(),
  });

  @override
  State<_ScrollableWithHint> createState() => _ScrollableWithHintState();
}

class _ScrollableWithHintState extends State<_ScrollableWithHint> {
  bool _showHint = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(widget.icon,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  widget.copyButton,
                ],
              ),
              const Divider(),

              // Scrollable sliders
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels > 10 && _showHint) {
                      setState(() => _showHint = false);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(children: widget.sliders),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 👇 Show animated arrow only if _showHint = true
        if (_showHint)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: _ScrollHintArrow(),
          ),
      ],
    );
  }
}

class _ScrollHintArrow extends StatefulWidget {
  @override
  State<_ScrollHintArrow> createState() => _ScrollHintArrowState();
}

class _ScrollHintArrowState extends State<_ScrollHintArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _offset = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 28,
            color: Colors.black.withAlpha(229),
          ),
        );
      },
    );
  }
}

class SliderWidget extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? devision;
  final ValueChanged<double> onChanged;
  final bool enabled;

  const SliderWidget({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.devision,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final disabledColor = Colors.grey.shade400;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: enabled ? null : disabledColor,
                  ),
                ),
                Text(
                  value.toStringAsFixed(2), // Show value here
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: enabled ? accent : disabledColor,
                  ),
                ),
              ],
            ),

            // Slider
            Slider(
              activeColor: enabled ? accent : disabledColor,
              inactiveColor: (enabled ? accent : disabledColor).withAlpha(76),
              value: value,
              min: min,
              max: max,
              divisions: devision,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  final bool enabled;

  const _ColorPickerRow({
    required this.label,
    required this.color,
    required this.onChanged,
    this.enabled = true,
  });

  void _showPicker(BuildContext context) {
    double r = (color.r * 255).roundToDouble();
    double g = (color.g * 255).roundToDouble();
    double b = (color.b * 255).roundToDouble();
    double a = (color.a * 255).roundToDouble();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Color preview = Color.fromARGB(
              a.round().clamp(0, 255),
              r.round().clamp(0, 255),
              g.round().clamp(0, 255),
              b.round().clamp(0, 255),
            );
            Widget channelSlider(String ch, double val, Color trackColor,
                ValueChanged<double> onCh) {
              return Row(
                children: [
                  SizedBox(
                      width: 20,
                      child:
                          Text(ch, style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: Slider(
                      activeColor: trackColor,
                      inactiveColor: trackColor.withAlpha(76),
                      value: val,
                      min: 0,
                      max: 255,
                      divisions: 255,
                      onChanged: onCh,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(val.round().toString(),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: preview,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 12),
                  channelSlider("R", r, Colors.red, (v) {
                    setDialogState(() => r = v);
                  }),
                  channelSlider("G", g, Colors.green, (v) {
                    setDialogState(() => g = v);
                  }),
                  channelSlider("B", b, Colors.blue, (v) {
                    setDialogState(() => b = v);
                  }),
                  channelSlider("A", a, Colors.grey, (v) {
                    setDialogState(() => a = v);
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    onChanged(preview);
                    Navigator.pop(ctx);
                  },
                  child: const Text("Apply"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabledColor = Colors.grey.shade400;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? () => _showPicker(context) : null,
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: enabled ? null : disabledColor)),
            const Spacer(),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.color_lens_outlined,
                size: 18, color: enabled ? null : disabledColor),
          ],
        ),
      ),
    );
  }
}
