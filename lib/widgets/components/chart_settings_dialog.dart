import 'package:flutter/material.dart';
import '../../widgets/chart_view_controller.dart';
import '../../constants/chart_constants.dart';

/// チャート設定ダイアログコンポーネント
class ChartSettingsDialog extends StatefulWidget {
  final ChartViewController controller;
  final VoidCallback onSettingsChanged;

  const ChartSettingsDialog({
    super.key,
    required this.controller,
    required this.onSettingsChanged,
  });

  @override
  State<ChartSettingsDialog> createState() => _ChartSettingsDialogState();
}

class _ChartSettingsDialogState extends State<ChartSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SelectableText('チャート設定'),
      content: SizedBox(
        width: 300,
        height: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ウェーブポイント設定区域
            _buildWavePointsSettings(),
            const SizedBox(height: 16),
            // 移動平均線設定区域
            _buildMovingAverageSettings(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const SelectableText('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSettingsChanged();
          },
          child: const SelectableText('確定'),
        ),
      ],
    );
  }

  Widget _buildWavePointsSettings() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText(
            'ウェーブポイント設定',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const SelectableText('ウェーブポイントを表示'),
            subtitle: const SelectableText('高低点マーカーを表示'),
            value: widget.controller.isWavePointsVisible,
            onChanged: (bool? value) {
              if (value != null) {
                widget.controller.toggleWavePointsVisibility();
                setState(() {});
              }
            },
            activeColor: Colors.blue,
          ),
          CheckboxListTile(
            title: const SelectableText('ウェーブポイント接続線を表示'),
            subtitle: const SelectableText('高低点を接続して折れ線を形成'),
            value: widget.controller.isWavePointsLineVisible,
            onChanged: (bool? value) {
              if (value != null) {
                widget.controller.toggleWavePointsLineVisibility();
                setState(() {});
              }
            },
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildMovingAverageSettings() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText(
            '移動平均線設定',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.controller.maPeriods.map((period) => 
            CheckboxListTile(
              title: SelectableText('MA$period'),
              subtitle: SelectableText(
                _getMaDescription(period),
                style: TextStyle(
                  color: _getMaColor(period),
                  fontSize: 12,
                ),
              ),
              value: widget.controller.isMaVisible(period),
              onChanged: (bool? value) {
                if (value != null) {
                  widget.controller.toggleMaVisibility(period);
                  setState(() {});
                }
              },
              activeColor: _getMaColor(period),
            )
          ),
        ],
      ),
    );
  }

  Color _getMaColor(int period) {
    return ChartConstants.maColors[period] ?? Colors.grey;
  }

  String _getMaDescription(int period) {
    return ChartConstants.maDescriptions[period] ?? '移動平均線';
  }
}
