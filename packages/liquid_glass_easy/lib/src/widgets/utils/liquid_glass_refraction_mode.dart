/// Determines which geometry directs light through the liquid glass surface.
///
/// This is independent of `LiquidGlassRefractionType`, which selects the
/// standard or optical calculation used to bend the sampled background.
enum LiquidGlassRefractionMode {
  /// Refracts light based on the underlying shape geometry.
  ///
  /// The distortion follows the contours of the glass, creating
  /// a more physically accurate refraction effect based on the shape.
  shapeRefraction,

  /// Refracts light radially from a central point.
  ///
  /// Creates a circular distortion pattern, useful for effects like
  /// magnifying or warping around a center point.
  radialRefraction,
}
