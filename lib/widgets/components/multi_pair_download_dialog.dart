import 'package:flutter/material.dart';
import '../../models/trading_pair.dart';
import '../../models/timeframe.dart';
import '../../services/multi_pair_download_service.dart';

/// 複数取引ペアダウンロードダイアログ
class MultiPairDownloadDialog extends StatefulWidget {
  const MultiPairDownloadDialog({super.key});

  @override
  State<MultiPairDownloadDialog> createState() => _MultiPairDownloadDialogState();
}

class _MultiPairDownloadDialogState extends State<MultiPairDownloadDialog> {
  final List<TradingPair> _selectedPairs = [TradingPair.eurusd];
  final List<Timeframe> _selectedTimeframes = [Timeframe.m5];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  List<Map<String, dynamic>> _results = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SelectableText('複数取引ペアダウンロード'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: _isDownloading ? _buildDownloadProgress() : _buildDownloadSettings(),
      ),
      actions: _isDownloading ? [] : [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const SelectableText('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _startDownload,
          child: const SelectableText('ダウンロード開始'),
        ),
      ],
    );
  }

  Widget _buildDownloadSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 取引ペア選択
        const SelectableText(
          '取引ペア選択',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: TradingPair.values.length,
            itemBuilder: (context, index) {
              final pair = TradingPair.values[index];
              return CheckboxListTile(
                title: SelectableText(pair.displayName),
                subtitle: SelectableText(pair.description),
                value: _selectedPairs.contains(pair),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedPairs.add(pair);
                    } else {
                      _selectedPairs.remove(pair);
                    }
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        
        // 時間周期選択
        const SelectableText(
          '時間周期選択',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: Timeframe.values.map((timeframe) {
            return Expanded(
              child: CheckboxListTile(
                title: SelectableText(timeframe.displayName),
                value: _selectedTimeframes.contains(timeframe),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedTimeframes.add(timeframe);
                    } else {
                      _selectedTimeframes.remove(timeframe);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // 日付範囲選択
        const SelectableText(
          '日付範囲',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SelectableText('開始日'),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SelectableText('終了日'),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // クイック選択ボタン
        const SelectableText(
          'クイック選択',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: _selectMajorPairs,
              child: const SelectableText('主要ペア'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectAllPairs,
              child: const SelectableText('全ペア'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectAllTimeframes,
              child: const SelectableText('全時間周期'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      children: [
        const SelectableText(
          'ダウンロード中...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _downloadProgress,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 8),
        SelectableText(
          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        SelectableText(
          _statusMessage,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_results.isNotEmpty) ...[
          const SelectableText(
            'ダウンロード結果',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                final pair = result['pair'] as TradingPair;
                final timeframe = result['timeframe'] as Timeframe;
                final status = result['status'] as String;
                final message = result['message'] as String;
                
                return ListTile(
                  leading: Icon(
                    status == 'success' ? Icons.check_circle : Icons.error,
                    color: status == 'success' ? Colors.green : Colors.red,
                  ),
                  title: SelectableText('${pair.displayName} ${timeframe.displayName}'),
                  subtitle: SelectableText(message),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isDownloading ? _cancelDownload : _closeDialog,
          child: SelectableText(_isDownloading ? 'キャンセル' : '閉じる'),
        ),
      ],
    );
  }

  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _selectMajorPairs() {
    setState(() {
      _selectedPairs.clear();
      _selectedPairs.addAll([
        TradingPair.eurusd,
        TradingPair.usdjpy,
        TradingPair.gbpjpy,
        TradingPair.xauusd,
        TradingPair.gbpusd,
        TradingPair.audusd,
      ]);
    });
  }

  void _selectAllPairs() {
    setState(() {
      _selectedPairs.clear();
      _selectedPairs.addAll(TradingPair.values);
    });
  }

  void _selectAllTimeframes() {
    setState(() {
      _selectedTimeframes.clear();
      _selectedTimeframes.addAll(Timeframe.values);
    });
  }

  void _startDownload() async {
    if (_selectedPairs.isEmpty || _selectedTimeframes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: SelectableText('取引ペアと時間周期を選択してください')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'ダウンロードを開始しています...';
      _results.clear();
    });

    try {
      // 進捗監視
      MultiPairDownloadService.getProgressStream('download').listen((progress) {
        setState(() {
          _downloadProgress = progress;
          _statusMessage = 'ダウンロード中... ${(progress * 100).toStringAsFixed(1)}%';
        });
      });

      // ダウンロード実行
      final results = await MultiPairDownloadService.downloadSpecificPairs(
        pairs: _selectedPairs,
        timeframes: _selectedTimeframes,
        startDate: _startDate,
        endDate: _endDate,
        progressKey: 'download',
      );

      setState(() {
        _results = results;
        _statusMessage = 'ダウンロード完了';
        _isDownloading = false;
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
        _isDownloading = false;
      });
    }
  }

  void _cancelDownload() {
    MultiPairDownloadService.cancelDownload('download');
    setState(() {
      _isDownloading = false;
      _statusMessage = 'ダウンロードがキャンセルされました';
    });
  }

  void _closeDialog() {
    Navigator.of(context).pop();
  }
}
