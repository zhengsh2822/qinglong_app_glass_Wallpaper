import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/hsl_color_picker.dart';

/// 颜色选择器底部弹窗（可复用组件）
///
/// 用于需要自定义颜色的设置项（字体颜色 / 卡片纯色等），
/// 内部使用 [HslColorPicker]（色相/饱和度/明度 3 滑块）+ 顶部色块预览。
/// 通过 [showModalBottomSheet] 弹出，背景透明 + 毛玻璃卡片。
class ColorPickerSheet extends ConsumerStatefulWidget {
  /// 弹窗标题
  final String title;

  /// 副标题说明
  final String subtitle;

  /// 当前颜色（作为初始值）
  final Color initialColor;

  /// 确认回调（返回最终选择的颜色）
  final ValueChanged<Color> onConfirm;

  /// 可选：「恢复默认」按钮回调（点击后自动关闭弹窗）
  final VoidCallback? onReset;

  const ColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onConfirm,
    this.title = '选择颜色',
    this.subtitle = '',
    this.onReset,
  });

  @override
  ConsumerState<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<ColorPickerSheet> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final titleColor = theme.themeColor.titleColor();
    final descColor = theme.themeColor.descColor();

    return GlassCard(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      sigma: 10,
      forceOpaqueSolid: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              if (widget.onReset != null)
                GestureDetector(
                  onTap: () {
                    widget.onReset!();
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "恢复默认",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: titleColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 13, color: descColor),
            ),
          ],
          const SizedBox(height: 16),
          _ColorPreviewBlock(color: _currentColor),
          const SizedBox(height: 20),
          HslColorPicker(
            color: _currentColor,
            onChanged: (c) {
              setState(() => _currentColor = c);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("取消", style: TextStyle(fontSize: 15, color: titleColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CupertinoButton(
                  color: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () {
                    widget.onConfirm(_currentColor);
                    Navigator.of(context).pop();
                  },
                  child: const Text("确认", style: TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 颜色选择器顶部预览块（色块 + 十六进制色值）
class _ColorPreviewBlock extends StatelessWidget {
  final Color color;
  const _ColorPreviewBlock({required this.color});

  @override
  Widget build(BuildContext context) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#${hex.substring(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}