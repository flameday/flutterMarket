import 'package:flutter/material.dart';
import '../models/price_data.dart';
import '../models/timeframe.dart';
import '../services/real_multi_window_manager.dart';
import '../services/log_service.dart';

class RealMultiWindowLauncher extends StatefulWidget {
  final List<PriceData> originalKlineDataList;
  final Timeframe defaultTimeframe;
  final Function(List<PriceData>)? onDataUpdate;

  const RealMultiWindowLauncher({
    super.key,
    required this.originalKlineDataList,
    this.defaultTimeframe = Timeframe.m30,
    this.onDataUpdate,
  });

  @override
  State<RealMultiWindowLauncher> createState() => _RealMultiWindowLauncherState();
}

class _RealMultiWindowLauncherState extends State<RealMultiWindowLauncher> {
  bool _isMultiWindowSupported = false;
  bool _isLoading = false;
  Map<String, bool> _windowStates = {};
  List<Map<String, dynamic>> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeMultiWindow();
  }

  Future<void> _initializeMultiWindow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // マルチウィンドウサポートをチェック
      _isMultiWindowSupported = await RealMultiWindowManager.isMultiWindowSupported();

      if (_isMultiWindowSupported) {
        // ディスプレイ情報を取得
        _screens = await RealMultiWindowManager.getScreens();

        // ウィンドウ状態を取得
        _windowStates = await RealMultiWindowManager.getAllWindowStates();

        Log.info('RealMultiWindowLauncher', '初期化完了 - マルチウィンドウサポート: $_isMultiWindowSupported, ディスプレイ数: ${_screens.length}');
      }
    } catch (e) {
      Log.error('RealMultiWindowLauncher', '初期化失敗: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SelectableText('真のマルチウィンドウ管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_isMultiWindowSupported) {
      return _buildNotSupportedView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトルと説明
          _buildHeader(),

          const SizedBox(height: 24),

          // ディスプレイ情報
          if (_screens.isNotEmpty) _buildScreenInfo(),

          const SizedBox(height: 24),

          // ウィンドウ管理
          _buildWindowManagement(),

          const SizedBox(height: 24),

          // 操作ボタン
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildNotSupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const SelectableText(
              'マルチウィンドウ機能はサポートされていません',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const SelectableText(
              'マルチウィンドウ機能にはWindows、macOSまたはLinuxシステムが必要です。\n\n'
              '現在は"分割表示"機能を代替案として使用できます。',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeMultiWindow,
              icon: const Icon(Icons.refresh),
              label: const SelectableText('再チェック'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          '真のマルチウィンドウK線チャート',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  '真の独立ウィンドウをサポート！各ウィンドウは独立したFlutterプロセスで、異なるディスプレイにドラッグできます。',
                  style: TextStyle(color: Colors.green, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScreenInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor, color: Colors.blue),
                SizedBox(width: 8),
                SelectableText(
                  '显示器信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._screens.asMap().entries.map((entry) {
              final index = entry.key;
              final screen = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: SelectableText(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        'ディスプレイ ${index + 1}: ${screen['width']}x${screen['height']} @ (${screen['x']}, ${screen['y']})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SelectableText(
          'ウィンドウ管理',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ウィンドウカードリスト
        _buildWindowCard(
          title: '5分K線チャート',
          description: '短期分析',
          windowId: RealMultiWindowManager.m5WindowId,
          icon: Icons.timeline,
          color: Colors.blue,
        ),

        // const SizedBox(height: 8),

        // _buildWindowCard(
        //   title: '30分K線チャート',
        //   description: '中期分析',
        //   windowId: RealMultiWindowManager.m30WindowId,
        //   icon: Icons.show_chart,
        //   color: Colors.green,
        // ),

        const SizedBox(height: 8),

        _buildWindowCard(
          title: '4時間K線チャート',
          description: '長期分析',
          windowId: RealMultiWindowManager.h4WindowId,
          icon: Icons.trending_up,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildWindowCard({
    required String title,
    required String description,
    required String windowId,
    required IconData icon,
    required Color color,
  }) {
    final isOpen = _windowStates[windowId] ?? false;
    final config = RealMultiWindowManager.getWindowConfig(windowId);
    final supportsTimeframeSelection = config?['supportsTimeframeSelection'] ?? false;

    return Card(
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Row(
          children: [
            SelectableText(title, style: const TextStyle(fontSize: 14)),
            if (supportsTimeframeSelection) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const SelectableText(
                  '周期選択サポート',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: SelectableText(description, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                isOpen ? '開いている' : '閉じている',
                style: TextStyle(
                  color: isOpen ? Colors.green : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(isOpen ? Icons.close : Icons.open_in_new, size: 18),
              onPressed: () => _toggleWindow(windowId),
              tooltip: isOpen ? 'ウィンドウを閉じる' : 'ウィンドウを開く',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: () => _toggleWindow(windowId),
      ),
    );
  }

  Widget _buildActionButtons() {
    final openCount = _windowStates.values.where((state) => state).length;
    final totalCount = _windowStates.length;

    return Column(
      children: [
        // 状态信息
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              SelectableText(
                '已打开: $openCount / $totalCount 个窗口',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openAllWindows,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const SelectableText('打开所有窗口', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _closeAllWindows,
                icon: const Icon(Icons.close, size: 16),
                label: const SelectableText('すべてのウィンドウを閉じる', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleWindow(String windowId) async {
    final isOpen = _windowStates[windowId] ?? false;

    if (isOpen) {
      // ウィンドウを閉じる
      final success = await RealMultiWindowManager.closeWindow(windowId);
      if (success) {
        setState(() {
          _windowStates[windowId] = false;
        });
      }
    } else {
      // ウィンドウを開く
      final windowData = _getWindowData();

      Log.info('RealMultiWindowLauncher', 'ウィンドウ作成準備: $windowId');

      // まず既存のウィンドウを閉じてから再作成
      await RealMultiWindowManager.closeWindow(windowId);

      // ウィンドウが完全に閉じるまで遅延を追加
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await RealMultiWindowManager.createWindow(
        windowId: windowId,
        data: windowData,
      );
      if (success) {
        setState(() {
          _windowStates[windowId] = true;
        });
      }
    }
  }

  void _openAllWindows() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await RealMultiWindowManager.createAllWindows(
        data: _getWindowData(),
        distributeToScreens: true,
      );

      setState(() {
        _windowStates = results;
      });

      final successCount = results.values.where((success) => success).length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('$successCount / ${results.length} 個のウィンドウを開くことに成功'),
            backgroundColor: successCount == results.length ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Log.error('RealMultiWindowLauncher', 'すべてのウィンドウを開くのに失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('ウィンドウを開くのに失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _closeAllWindows() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await RealMultiWindowManager.closeAllWindows();

      setState(() {
        _windowStates = results.map((key, value) => MapEntry(key, false));
      });

      final successCount = results.values.where((success) => success).length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('$successCount / ${results.length} 個のウィンドウを閉じることに成功'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error('RealMultiWindowLauncher', 'すべてのウィンドウを閉じるのに失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('ウィンドウを閉じるのに失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Map<String, dynamic> _getWindowData() {
    return {
      'originalKlineDataList': widget.originalKlineDataList.map((k) => {
        'timestamp': k.timestamp,
        'open': k.open,
        'high': k.high,
        'low': k.low,
        'close': k.close,
        'volume': k.volume,
      }).toList(),
      'defaultTimeframe': widget.defaultTimeframe.name,
    };
  }
}