import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// A zero-content layer that watches its render object's **global
/// transform** and fires a callback when it changes between frames.
///
/// Why this exists: a lens's shader uniforms encode its on-screen
/// position, but when an ancestor moves the lens (scroll, slide
/// transition, drag of a parent) the lens's own `paint()` is usually
/// NOT re-run — the compositor just shifts the retained layers. Nothing
/// widget-side observes "my global position changed".
///
/// This layer closes that gap at the latest possible moment: layers are
/// re-added to the scene every frame the surrounding tree changes
/// ([alwaysNeedsAddToScene]), and [addToScene] runs *after* all layout
/// and paint, when `getTransformTo(null)` is final for the frame. When
/// the transform differs from the previous frame's, [onTransformChanged]
/// (typically `markNeedsPaint`) schedules a repaint so the next frame's
/// uniforms are correct.
///
/// The detection lags the movement by one frame by construction — the
/// stale frame has already been built when we detect it. During
/// continuous movement (scrolling) this self-corrects every frame;
/// after movement stops the final frame is exact.
class LensTransformTrackingLayer extends OffsetLayer {
  LensTransformTrackingLayer();

  /// The render object whose global transform is watched.
  RenderObject? renderObject;

  /// Invoked (during scene building) when the transform changed since
  /// the last frame. Keep it cheap — typically just `markNeedsPaint`.
  VoidCallback? onTransformChanged;

  Matrix4? _lastTransform;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    // Intentionally does NOT call super: this layer contributes nothing
    // visual to the scene; it exists purely for the transform probe.
    final RenderObject? ro = renderObject;
    if (ro == null || !ro.attached) return;
    final Matrix4 current = ro.getTransformTo(null);
    if (_lastTransform == null) {
      // First frame: just record. The frame being built was painted
      // with this same transform, so there is nothing to correct.
      _lastTransform = current;
      return;
    }
    if (!MatrixUtils.matrixEquals(current, _lastTransform)) {
      _lastTransform = current;
      onTransformChanged?.call();
    }
  }
}

/// Mixin for a [RenderProxyBox] that needs to repaint whenever its
/// global transform changes — even when the change originates from an
/// ancestor and would normally not repaint this subtree.
///
/// Call [pushTransformTracking] at the start of `paint()`.
mixin LensTransformTrackingMixin on RenderProxyBox {
  final LayerHandle<LensTransformTrackingLayer> _trackingLayerHandle =
      LayerHandle<LensTransformTrackingLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  /// Pushes (and lazily creates) the tracking layer into the current
  /// painting context. Call first thing in `paint()`.
  void pushTransformTracking(PaintingContext context, Offset offset) {
    final layer =
        _trackingLayerHandle.layer ??= LensTransformTrackingLayer();
    layer
      ..renderObject = this
      ..onTransformChanged = () {
        if (attached) onGlobalTransformChanged();
      };
    context.pushLayer(layer, (PaintingContext context, Offset offset) {},
        offset);
  }

  /// Called when this render object's global transform changed between
  /// frames. Default behavior repaints; override to add bookkeeping.
  void onGlobalTransformChanged() => markNeedsPaint();

  @override
  void detach() {
    _trackingLayerHandle.layer?.renderObject = null;
    super.detach();
  }

  @override
  void dispose() {
    _trackingLayerHandle.layer = null;
    super.dispose();
  }
}
