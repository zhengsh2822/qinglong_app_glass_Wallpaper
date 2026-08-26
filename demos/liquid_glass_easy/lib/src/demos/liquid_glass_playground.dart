import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

import '../controllers/liquid_glass_view_controller.dart';
import '../helpers/slider_page_view.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/liquid_glass_view.dart';
import '../widgets/utils/liquid_glass_blur.dart';
import '../widgets/utils/liquid_glass_border_mode.dart';
import '../widgets/utils/liquid_glass_light_mode.dart';
import '../widgets/utils/liquid_glass_refraction_mode.dart';
import '../widgets/utils/liquid_glass_shape.dart';
import '../widgets/utils/liquid_glass_position.dart';

// Playground widget
class LiquidGlassPlayground extends StatefulWidget {
  final Widget backgroundWidget; // <-- Passable background

  const LiquidGlassPlayground({
    super.key,
    required this.backgroundWidget,
  });

  @override
  State<LiquidGlassPlayground> createState() => _LiquidGlassPlaygroundState();
}

class _LiquidGlassPlaygroundState extends State<LiquidGlassPlayground> {
  // Lens properties
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // all the state values
  double lensWidth = 200;
  double lensHeight = 100;
  double cornerRadius = 50;
  double magnification = 1.0;
  double distortion = 0.1;
  double distortionWidth = 33;
  double backgroundTransparencyFadeIn = 0;
  double diagonalFlip = 0;
  double borderWidth = 1.0;
  double lightIntensity = 1.0;
  double oneSideLightIntensity = 0.0;
  double chromaticAberration = 0.003;
  double saturation = 1;
  double lightDirection = 39.0;
  LiquidGlassCornerStyle cornerStyle = LiquidGlassCornerStyle.roundedRectangle;
  double pixelRatio = 1.0;
  bool realTimeCapture = true;
  bool useSync = true;
  bool enableInnerRadiusTransparent = false;
  bool visibility = true;
  double blur = 0;
  double refreshRate = 3;
  LiquidGlassRefreshRate liquidGlassRefreshRate =
      LiquidGlassRefreshRate.deviceRefreshRate;
  final controller = LiquidGlassController();
  final viewController = LiquidGlassViewController();
  bool isVisible = true;
  bool isRadialLightMode = false;
  bool isRadialRefractionMode = false;
  double doubleSideLightIntensity = 0.0;
  double borderSaturation = 1.0;
  double ambientIntensity = 1.0;
  double borderSolidity = 0.0;
  double borderSoftness = 1.0;
  bool isOpticalBorderMode = false;
  Color glassColor = Colors.transparent;
  Color lightColorValue = const Color(0xB2FFFFFF);
  Color shadowColorValue = const Color(0x1A000000);

  LiquidGlassBorderType _buildBorderType() {
    if (isOpticalBorderMode) {
      return OpticalBorder(
        borderSaturation: borderSaturation,
        ambientIntensity: ambientIntensity,
        borderSolidity: borderSolidity,
      );
    } else {
      return ClassicBorder(
        borderSoftness: borderSoftness,
        shadowColor: shadowColorValue,
        oneSideLightIntensity: oneSideLightIntensity,
        doubleSideLightIntensity: doubleSideLightIntensity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isVisible = (!isVisible)) {
            viewController.startRealtimeCapture();
            controller.showLiquidGlass();
          } else {
            controller.hideLiquidGlass(
                onComplete: viewController.stopRealtimeCapture);
          }
        },
        child: Text(
          'Animation',
          style: TextStyle(fontSize: 11),
        ),
      ),
      appBar: AppBar(title: const Text("Liquid Glass Playground")),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5 -
                kToolbarHeight -
                MediaQuery.of(context).padding.top,
            child: LiquidGlassView.withPositionedLenses(
              controller: viewController,
              pixelRatio: pixelRatio,
              realTimeCapture: realTimeCapture,
              refreshRate: liquidGlassRefreshRate,

              useSync: useSync,
              children: [
                LiquidGlass(
                  geometry: LiquidGlassGeometry(
                    position: const LiquidGlassAlignPosition(
                        alignment: Alignment.center),
                    width: lensWidth,
                    height: lensHeight,
                  ),
                  shape: LiquidGlassShape(
                      cornerStyle: cornerStyle,
                      cornerRadius: cornerRadius,
                      borderWidth: borderWidth,
                      lightIntensity: lightIntensity,
                      lightDirection: lightDirection,
                      lightColor: lightColorValue,
                      borderType: _buildBorderType(),
                      lightMode: isRadialLightMode
                          ? LiquidGlassLightMode.radial
                          : LiquidGlassLightMode.edge),
                  refraction: LiquidGlassRefraction(
                    magnification: magnification,
                    refractionMode: isRadialRefractionMode
                        ? LiquidGlassRefractionMode.radialRefraction
                        : LiquidGlassRefractionMode.shapeRefraction,
                    distortion: distortion,
                    distortionWidth: distortionWidth,
                    chromaticAberration: chromaticAberration,
                  ),
                  appearance: LiquidGlassAppearance(
                    saturation: saturation,
                    color: glassColor,
                    blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
                  ),
                  behavior: LiquidGlassBehavior(
                    controller: controller,
                    draggable: true,
                    visibility: visibility,
                  ),
                ),
              ],
              backgroundWidget: widget.backgroundWidget, // <-- passed in
            ),
          ),
          SlidersPageView(
            controller: _pageController,
            currentPage: _currentPage,
            lensWidth: lensWidth,
            lensHeight: lensHeight,
            cornerRadius: cornerRadius,
            magnification: magnification,
            refractionMode: isRadialRefractionMode,
            distortion: distortion,
            distortionWidth: distortionWidth,
            diagonalFlip: diagonalFlip,
            borderWidth: borderWidth,
            borderSoftness: borderSoftness,
            cornerStyle: cornerStyle,
            lightDirection: lightDirection,
            lightIntensity: lightIntensity,
            oneSideLightIntensity: oneSideLightIntensity,
            lightMode: isRadialLightMode,
            doubleSideLightIntensity: doubleSideLightIntensity,
            borderSaturation: borderSaturation,
            ambientIntensity: ambientIntensity,
            borderSolidity: borderSolidity,
            borderMode: isOpticalBorderMode,
            glassColor: glassColor,
            lightColorValue: lightColorValue,
            shadowColorValue: shadowColorValue,
            chromaticAberration: chromaticAberration,
            saturation: saturation,
            blur: blur,
            refreshRate: refreshRate,
            pixelRatio: pixelRatio,
            realTimeCapture: realTimeCapture,
            useSync: useSync,
            enableInnerRadiusTransparent: enableInnerRadiusTransparent,
            // callbacks update state
            onPageChanged: (i) => setState(() => _currentPage = i),
            onLensWidthChanged: (v) => setState(() => lensWidth = v),
            onLensHeightChanged: (v) => setState(() => lensHeight = v),
            onCornerRadiusChanged: (v) => setState(() => cornerRadius = v),
            onMagnificationChanged: (v) => setState(() => magnification = v),
            onRefractionModeChanged: (v) =>
                setState(() => isRadialRefractionMode = v),
            onDistortionChanged: (v) => setState(() => distortion = v),
            onDistortionWidthChanged: (v) =>
                setState(() => distortionWidth = v),
            onDiagonalFlipChanged: (v) => setState(() => diagonalFlip = v),
            onBorderWidthChanged: (v) => setState(() => borderWidth = v),
            onBorderSoftnessChanged: (v) => setState(() => borderSoftness = v),
            onCornerStyleChanged: (v) =>
                setState(() => cornerStyle = v),
            onLightIntensityChanged: (v) => setState(() => lightIntensity = v),
            onOneSideLightIntensityChanged: (v) =>
                setState(() => oneSideLightIntensity = v),
            onLightModeChanged: (v) => setState(() => isRadialLightMode = v),
            onDoubleSideLightIntensityChanged: (v) =>
                setState(() => doubleSideLightIntensity = v),
            onBorderSaturationChanged: (v) =>
                setState(() => borderSaturation = v),
            onAmbientIntensityChanged: (v) =>
                setState(() => ambientIntensity = v),
            onBorderSolidityChanged: (v) =>
                setState(() => borderSolidity = v),
            onBorderModeChanged: (v) =>
                setState(() => isOpticalBorderMode = v),
            onGlassColorChanged: (v) => setState(() => glassColor = v),
            onLightColorChanged: (v) => setState(() => lightColorValue = v),
            onShadowColorChanged: (v) => setState(() => shadowColorValue = v),
            onChromaticAberrationChanged: (v) =>
                setState(() => chromaticAberration = v),
            onSaturationChanged: (v) => setState(() => saturation = v),
            onLightDirectionChanged: (v) => setState(() => lightDirection = v),
            onBlurChanged: (v) => setState(() => blur = v),
            onRefreshRateChanged: (v) => setState(() {
              v == 0
                  ? liquidGlassRefreshRate = LiquidGlassRefreshRate.low
                  : v == 1
                      ? liquidGlassRefreshRate = LiquidGlassRefreshRate.medium
                      : v == 2
                          ? liquidGlassRefreshRate = LiquidGlassRefreshRate.high
                          : liquidGlassRefreshRate =
                              LiquidGlassRefreshRate.deviceRefreshRate;
              refreshRate = v;
            }),

            onPixelRatioChanged: (v) => setState(() => pixelRatio = v),
            onRealTimeCaptureChanged: (v) =>
                setState(() => realTimeCapture = v),
            onUseSyncChanged: (v) => setState(() => useSync = v),
            onEnableInnerRadiusTransparent: (v) =>
                setState(() => enableInnerRadiusTransparent = v),
          ),
        ],
      ),
    );
  }
}
