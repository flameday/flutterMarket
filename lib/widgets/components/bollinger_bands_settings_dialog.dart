import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 布林通道设置对话框
class BollingerBandsSettingsDialog extends StatefulWidget {
  final int currentPeriod;
  final double currentStdDev;
  final Map<String, String> currentColors;
  final Map<String, double> currentAlphas;
  final Function(int period, double stdDev, Map<String, String> colors, Map<String, double> alphas) onSettingsChanged;

  const BollingerBandsSettingsDialog({
    super.key,
    required this.currentPeriod,
    required this.currentStdDev,
    required this.currentColors,
    required this.currentAlphas,
    required this.onSettingsChanged,
  });

  @override
  State<BollingerBandsSettingsDialog> createState() => _BollingerBandsSettingsDialogState();
}

class _BollingerBandsSettingsDialogState extends State<BollingerBandsSettingsDialog> {
  late int _period;
  late double _stdDev;
  late Map<String, String> _colors;
  late Map<String, double> _alphas;

  @override
  void initState() {
    super.initState();
    _period = widget.currentPeriod;
    _stdDev = widget.currentStdDev;
    _colors = Map<String, String>.from(widget.currentColors);
    _alphas = Map<String, double>.from(widget.currentAlphas);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SelectableText('布林通道设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 期间设置
            _buildPeriodSetting(),
            const SizedBox(height: 16),
            
            // 标准偏差倍率设置
            _buildStdDevSetting(),
            const SizedBox(height: 16),
            
            // 颜色设置
            _buildColorSettings(),
            const SizedBox(height: 16),
            
            // 透明度设置
            _buildAlphaSettings(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const SelectableText('取消'),
        ),
        TextButton(
          onPressed: _resetToDefaults,
          child: const SelectableText('重置'),
        ),
        ElevatedButton(
          onPressed: _applySettings,
          child: const SelectableText('应用'),
        ),
      ],
    );
  }

  Widget _buildPeriodSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          '期间设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SelectableText('期间: '),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _period.toString()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: (value) {
                  final period = int.tryParse(value);
                  if (period != null && period > 0) {
                    _period = period;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const SelectableText('(推荐: 20)'),
          ],
        ),
      ],
    );
  }

  Widget _buildStdDevSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          '标准偏差倍率设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SelectableText('倍率: '),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _stdDev.toString()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: (value) {
                  final stdDev = double.tryParse(value);
                  if (stdDev != null && stdDev > 0) {
                    _stdDev = stdDev;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const SelectableText('(推荐: 2.0)'),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          '颜色设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildColorPicker('上轨', 'upper', _colors['upper'] ?? '0xFF2196F3'),
        _buildColorPicker('中轨', 'middle', _colors['middle'] ?? '0xFFFF9800'),
        _buildColorPicker('下轨', 'lower', _colors['lower'] ?? '0xFF2196F3'),
      ],
    );
  }

  Widget _buildColorPicker(String label, String key, String currentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: SelectableText('$label:'),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(int.parse(currentColor)),
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: currentColor),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                hintText: '0xFF2196F3',
              ),
              onChanged: (value) {
                if (value.startsWith('0x') && value.length == 10) {
                  _colors[key] = value;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlphaSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          '透明度设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildAlphaSlider('上轨', 'upper', _alphas['upper'] ?? 0.7),
        _buildAlphaSlider('中轨', 'middle', _alphas['middle'] ?? 0.8),
        _buildAlphaSlider('下轨', 'lower', _alphas['lower'] ?? 0.7),
      ],
    );
  }

  Widget _buildAlphaSlider(String label, String key, double currentAlpha) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: SelectableText('$label:'),
          ),
          Expanded(
            child: Slider(
              value: currentAlpha,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(currentAlpha * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _alphas[key] = value;
                });
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: SelectableText('${(currentAlpha * 100).round()}%'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _period = 20;
      _stdDev = 1.3;
      _colors = {
        'upper': '0xFF2196F3',
        'middle': '0xFFFF9800',
        'lower': '0xFF2196F3',
      };
      _alphas = {
        'upper': 0.7,
        'middle': 0.8,
        'lower': 0.7,
      };
    });
  }

  void _applySettings() {
    widget.onSettingsChanged(_period, _stdDev, _colors, _alphas);
    Navigator.of(context).pop();
  }
}
