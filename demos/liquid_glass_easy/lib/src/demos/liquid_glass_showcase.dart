import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';
import 'package:liquid_glass_easy/src/helpers/slider_page_view.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass_view.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_border_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';

// Playground widget
class LiquidGlassShowcase extends StatefulWidget {
  const LiquidGlassShowcase({
    super.key,
  });

  @override
  State<LiquidGlassShowcase> createState() => _LiquidGlassShowcaseState();
}

class _LiquidGlassShowcaseState extends State<LiquidGlassShowcase> {
  // Lens properties
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // all the state values
  double lensWidth = 280;
  double lensHeight = 60;
  double cornerRadius = 30;
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
  bool isRadialLightMode = false;
  bool isRadialRefractionMode = false;
  double doubleSideLightIntensity = 0.0;
  double borderSaturation = 1.0;
  double ambientIntensity = 1.0;
  double borderSolidity = 0.0;
  double borderSoftness = 1.0;
  bool isOpticalBorderMode = true;
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

  bool isVisible = true;
  final controller = LiquidGlassController();
  final viewController = LiquidGlassViewController();

  void toggleLiquidGlassAnimation() {
    // Toggle the direction flag
    if (isVisible = (!isVisible)) {
      viewController.startRealtimeCapture();
      controller.showLiquidGlass();
    } else {
      controller.hideLiquidGlass(
          onComplete: viewController.stopRealtimeCapture);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: toggleLiquidGlassAnimation,
        child: Text(
          'Animation',
          style: TextStyle(fontSize: 11),
        ),
      ),
      appBar: const _FrostedAppBar(title: "Gallery"),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5 -
                70 -
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
                        alignment: Alignment.bottomLeft,
                        margin:
                            EdgeInsets.only(top: 20, bottom: 20, left: 20)),
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
                    diagonalFlip: diagonalFlip,
                    distortion: distortion,
                    distortionWidth: distortionWidth,
                    chromaticAberration: chromaticAberration,
                  ),
                  appearance: LiquidGlassAppearance(
                    enableInnerRadiusTransparent: enableInnerRadiusTransparent,
                    saturation: saturation,
                    color: glassColor,
                    blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
                  ),
                  behavior: LiquidGlassBehavior(
                    controller: controller,
                    draggable: true,
                    visibility: visibility,
                  ),

                  //child:_GlassInputBar()
                ),
              ],
              backgroundWidget: _GalleryCardsPage(),
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
            onLightDirectionChanged: (v) => setState(() => lightDirection = v),
            onChromaticAberrationChanged: (v) =>
                setState(() => chromaticAberration = v),
            onSaturationChanged: (v) => setState(() => saturation = v),
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

class _GalleryCardsPage extends StatelessWidget {
  static const imageUrls = [
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/flower.jpg',
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/rain.jpg',
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/neon.png',
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_1.png',
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_2.jpg',
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_3.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.vertical, //
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 12), // vertical spacing
        itemBuilder: (context, index) {
          return _GalleryCard(
            url: imageUrls[index],
            title: "Beautiful Shot #${index + 1}",
            description: "A stunning view captured for inspiration.",
          );
        },
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final String url;
  final String title;
  final String description;

  const _GalleryCard({
    required this.url,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    )),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {},
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _FrostedAppBar({
    required this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          elevation: 0,
          backgroundColor: Color.fromRGBO(0, 0, 0, 0.9),
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.tealAccent, Colors.blueAccent],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    NetworkImage("https://i.pravatar.cc/150?img=8"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
