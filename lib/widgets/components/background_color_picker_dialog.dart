import 'package:flutter/material.dart';
import '../../services/log_service.dart';

/// 背景色選択ダイアログ
class BackgroundColorPickerDialog extends StatefulWidget {
  final String currentColor;
  final Function(String) onColorSelected;

  const BackgroundColorPickerDialog({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<BackgroundColorPickerDialog> createState() => _BackgroundColorPickerDialogState();
}

class _BackgroundColorPickerDialogState extends State<BackgroundColorPickerDialog> {
  late String _selectedColor;
  late double _alpha; // 透明度（0.0-1.0）

  // プリセット色のリスト
  static const List<ColorPreset> _colorPresets = [
    ColorPreset(name: '暗い背景', color: '0xFF1E1E1E'),
    ColorPreset(name: '黒', color: '0xFF000000'),
    ColorPreset(name: '濃いグレー', color: '0xFF2D2D2D'),
    ColorPreset(name: 'ダークブルー', color: '0xFF1A1A2E'),
    ColorPreset(name: 'ダークグリーン', color: '0xFF0D4F3C'),
    ColorPreset(name: 'ダークレッド', color: '0xFF4A0E0E'),
    ColorPreset(name: 'ダークパープル', color: '0xFF2D1B69'),
    ColorPreset(name: 'ダークオレンジ', color: '0xFF5D4037'),
    ColorPreset(name: '明るい背景', color: '0xFFFFFFFF'),
    ColorPreset(name: 'ライトグレー', color: '0xFFF5F5F5'),
    ColorPreset(name: 'ライトブルー', color: '0xFFE3F2FD'),
    ColorPreset(name: 'ライトグリーン', color: '0xFFE8F5E8'),
    ColorPreset(name: 'ライトレッド', color: '0xFFFFEBEE'),
    ColorPreset(name: 'ライトパープル', color: '0xFFF3E5F5'),
    ColorPreset(name: 'ライトオレンジ', color: '0xFFFFF3E0'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
    // 現在の色から透明度を抽出
    _alpha = _extractAlphaFromColor(widget.currentColor);
  }

  /// 色文字列から透明度を抽出
  double _extractAlphaFromColor(String colorString) {
    try {
      final color = Color(int.parse(colorString));
      return color.a;
    } catch (e) {
      return 1.0; // デフォルトは不透明
    }
  }

  /// 色と透明度から新しい色文字列を生成
  String _generateColorWithAlpha(String baseColor, double alpha) {
    try {
      final color = Color(int.parse(baseColor.replaceAll('#', '0x')));
      final newColor = color.withValues(alpha: alpha);
      final result = '0x${newColor.toARGB32().toRadixString(16).toUpperCase()}';
      LogService.instance.debug('色生成', '色生成: $baseColor + alpha:$alpha = $result');
      return result;
    } catch (e) {
      LogService.instance.error('色生成', '色生成エラー: $e');
      return baseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SelectableText('背景色を選択'),
      content: SizedBox(
        width: 400,
        height: 600, // 高さを増やして透明度スライダーのスペースを確保
        child: Column(
          children: [
            // 色選択グリッド
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: _colorPresets.length,
                itemBuilder: (context, index) {
                  final preset = _colorPresets[index];
                  final isSelected = _selectedColor == preset.color;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = preset.color;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(int.parse(preset.color)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          const SizedBox(height: 4),
                          SelectableText(
                            preset.name,
                            style: TextStyle(
                              color: _isLightColor(Color(int.parse(preset.color))) 
                                  ? Colors.black 
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // 透明度スライダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SelectableText(
                        '透明度',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SelectableText(
                        '${(_alpha * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _alpha,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (double value) {
                      setState(() {
                        _alpha = value;
                      });
                    },
                  ),
                  // プレビュー
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse(_selectedColor)).withValues(alpha: _alpha),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(
                      child: SelectableText(
                        'プレビュー',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const SelectableText('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            // 選択された色と透明度を組み合わせて最終的な色を生成
            final finalColor = _generateColorWithAlpha(_selectedColor, _alpha);
            widget.onColorSelected(finalColor);
            Navigator.of(context).pop();
          },
          child: const SelectableText('適用'),
        ),
      ],
    );
  }

  /// 色が明るいかどうかを判定
  bool _isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }
}

/// 色プリセットクラス
class ColorPreset {
  final String name;
  final String color;

  const ColorPreset({
    required this.name,
    required this.color,
  });
}
