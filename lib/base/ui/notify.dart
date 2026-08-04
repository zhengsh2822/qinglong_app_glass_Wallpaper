
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';


///消息弹窗横幅
class Notify {
  OverlayEntry? _overlayEntry;

  final GlobalKey<_NotifyWidgetState> _stateKey = GlobalKey();

  void show(
      BuildContext context,
      Widget child, {
        bool? rootNavigator,
        int duration = 300,
        int keepDuration = 3 * 1000,
        double topOffset = 40,
        bool dismissDirectly = false,
        bool disableDrag = false,
      }) {
    _createView(
      child,
      context,
      rootNavigator,
      duration,
      keepDuration,
      topOffset,
      dismissDirectly,
      disableDrag,
    );
  }

  void _createView(
      Widget child,
      BuildContext context,
      bool? rootNavigator,
      int duration,
      int keepDuration,
      double topOffset,
      bool dismissDirectly,
      bool disableDrag,
      ) {
    if (_overlayEntry != null) {
      throw ArgumentError("you shuold call dismiss() firstly");
    }

    final OverlayState overlayState =
    Overlay.of(context, rootOverlay: rootNavigator ?? false);

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => NotifyWidget(
        key: _stateKey,
        finished: _closeSelfImmediately,
        duration: duration,
        keepDuration: keepDuration,
        topOffset: topOffset,
        dismissDirectly: dismissDirectly,
        disableDrag: disableDrag,
        child: child,
      ),
    );

    if (overlayState != null) {
      overlayState.insert(_overlayEntry!);
    }
  }

  bool isShown() {
    return _overlayEntry != null;
  }

  Future<void> dismiss([bool animated = false]) async {
    if (animated) {
      return await _stateKey.currentState?._close();
    } else {
      return _closeSelfImmediately();
    }
  }

  void _closeSelfImmediately() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class NotifyWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback finished;

  ///进出动画时长
  final int duration;

  ///弹窗持续时长
  final int keepDuration;

  ///距离顶部偏移
  final double topOffset;

  ///消失时是否不显示动画
  final bool dismissDirectly;

  ///禁止向下拖拽
  final bool disableDrag;

  const NotifyWidget({
    super.key,
    required this.finished,
    required this.duration,
    required this.keepDuration,
    required this.topOffset,
    required this.disableDrag,
    required this.dismissDirectly,
    required this.child,
  });

  @override
  State<NotifyWidget> createState() => _NotifyWidgetState();
}

class _NotifyWidgetState extends State<NotifyWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _playController;
  double _offset = -1000;
  double begin = -1000;
  Animation<double>? _offsetAnimation;
  bool _reversed = false;
  Timer? _t;
  double childHeight = 0;

  GlobalKey childKey = GlobalKey();

  @override
  void dispose() {
    _playController?.dispose();
    _cancelT();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((timeStamp) {
      final box = childKey.currentContext?.findRenderObject() as RenderBox;
      childHeight = box.size.height;
      _offset = -1 * childHeight;
      begin = _offset;
      _play();
      _ready2DismissOverlay();
    });
  }

  void _play() {
    _playController = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );
    _offsetAnimation = Tween<double>(
      begin: begin,
      end: widget.topOffset,
    ).animate(
      CurvedAnimation(
        parent: _playController!,
        curve: Curves.easeOutBack,
      ),
    );
    // 动画结束时更新 _offset 为最终值，避免下次拖拽从旧位置开始
    _playController?.addStatusListener((status) {
      if (mounted && (status == AnimationStatus.completed || status == AnimationStatus.dismissed)) {
        _offset = _offsetAnimation!.value;
      }
    });
    _playController?.forward();
  }

  @override
  Widget build(BuildContext context) {
    Size maxSize = MediaQuery.of(context).size;

    // 子树只构建一次，动画期间由 AnimatedBuilder 复用 child 不重建
    final content = GestureDetector(
      onVerticalDragUpdate: (DragUpdateDetails details) {
        _cancelT();
        final double temp = _offset + details.delta.dy;
        if (temp > widget.topOffset + childHeight) {
          return;
        }

        if (temp > widget.topOffset) {
          if (widget.disableDrag) return;
        }

        _offset = temp;
        setState(() {});
      },
      onVerticalDragEnd: (details) {
        if (_offset < widget.topOffset / 2) {
          _close();
        } else {
          _reset2Target();
          _cancelT();
          _ready2DismissOverlay();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          key: childKey,
          constraints: BoxConstraints.loose(maxSize),
          child: widget.child,
        ),
      ),
    );

    // 动画期间用 AnimatedBuilder，避免全量重建子树
    if (_playController != null && _offsetAnimation != null) {
      return AnimatedBuilder(
        animation: _playController!,
        builder: (context, child) {
          // 动画进行中用动画值，否则用 _offset（拖拽后的值）
          final top = _playController!.isAnimating ? _offsetAnimation!.value : _offset;
          return Positioned(top: top, child: child!);
        },
        child: content,
      );
    }

    return Positioned(top: _offset, child: content);
  }

  void _reset2Target() {
    if (_reversed) {
      _offsetAnimation = Tween<double>(
        begin: _offset,
        end: widget.topOffset,
      ).animate(
        CurvedAnimation(
          parent: _playController!,
          curve: Curves.easeOutBack,
        ),
      );
      _playController?.forward();
      _reversed = false;
    } else {
      _offsetAnimation = Tween<double>(
        begin: widget.topOffset,
        end: _offset,
      ).animate(
        CurvedAnimation(
          parent: _playController!,
          curve: Curves.easeInBack,
        ),
      );
      _playController?.reverse();
      _reversed = true;
    }
  }

  Future<void> _close() async {
    _cancelT();

    if (widget.dismissDirectly) {
      widget.finished();
      return;
    }

    if (_reversed) {
      _offsetAnimation = Tween<double>(
        begin: _offset,
        end: begin,
      ).animate(
        CurvedAnimation(
          parent: _playController!,
          curve: Curves.linear,
        ),
      );

      try {
        await _playController?.forward();
        widget.finished();
      } catch (e) {
        widget.finished();
      }
      return;
    } else {
      _offsetAnimation = Tween<double>(
        begin: begin,
        end: _offset,
      ).animate(
        CurvedAnimation(
          parent: _playController!,
          curve: Curves.linear,
        ),
      );
      try {
        await _playController?.reverse();
        widget.finished();
      } catch (e) {
        widget.finished();
      }
      return;
    }
  }

  void _ready2DismissOverlay() {
    if (widget.keepDuration > 0) {
      _t = Timer(Duration(milliseconds: widget.keepDuration), _close);
    }
  }

  void _cancelT() {
    if (_t == null) return;
    _t?.cancel();
    _t = null;
  }
}
