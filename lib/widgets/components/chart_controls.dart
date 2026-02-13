import 'package:flutter/material.dart';

/// チャートコントロールパネルコンポーネント
class ChartControls extends StatelessWidget {
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onScrollLeft;
  final VoidCallback onScrollRight;
  final VoidCallback onResetView;
  final VoidCallback? onDownloadData;
  final bool isLoadingData;
  final VoidCallback onToggleAutoUpdate;
  final bool isAutoUpdateEnabled;
  final VoidCallback onShowSettings;
  final VoidCallback onToggleVerticalLineMode;
  final bool isVerticalLineMode;
  final VoidCallback onClearAllVerticalLines;
  final VoidCallback onToggleKlineCountMode;
  final bool isKlineCountMode;
  final VoidCallback onLimitDataDisplay;
  final String displayRangeText;

  const ChartControls({
    super.key,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onScrollLeft,
    required this.onScrollRight,
    required this.onResetView,
    this.onDownloadData,
    required this.isLoadingData,
    required this.onToggleAutoUpdate,
    required this.isAutoUpdateEnabled,
    required this.onShowSettings,
    required this.onToggleVerticalLineMode,
    required this.isVerticalLineMode,
    required this.onClearAllVerticalLines,
    required this.onToggleKlineCountMode,
    required this.isKlineCountMode,
    required this.onLimitDataDisplay,
    required this.displayRangeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[800],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ズームアウト
            _buildControlButton(
              icon: Icons.zoom_out,
              tooltip: 'ズームアウト',
              onPressed: onZoomOut,
            ),
            
            // ズームイン
            _buildControlButton(
              icon: Icons.zoom_in,
              tooltip: 'ズームイン',
              onPressed: onZoomIn,
            ),
            
            const SizedBox(width: 4),
            
            // 左にスクロール
            _buildControlButton(
              icon: Icons.arrow_back,
              tooltip: '左にスクロール',
              onPressed: onScrollLeft,
            ),
            
            // 右にスクロール
            _buildControlButton(
              icon: Icons.arrow_forward,
              tooltip: '右にスクロール',
              onPressed: onScrollRight,
            ),
            
            const SizedBox(width: 4),
            
            // リセット
            _buildControlButton(
              icon: Icons.refresh,
              tooltip: 'ビューをリセット',
              onPressed: onResetView,
            ),
            
            const SizedBox(width: 4),
            
            // Dukascopyデータ取得
            _buildControlButton(
              icon: isLoadingData ? null : Icons.cloud_download,
              tooltip: '最新K線から3日分のデータをダウンロード',
              onPressed: isLoadingData ? null : onDownloadData,
              isLoading: isLoadingData,
            ),
            
            // 自動更新ボタン
            _buildControlButton(
              icon: isAutoUpdateEnabled ? Icons.pause_circle : Icons.play_circle,
              tooltip: isAutoUpdateEnabled ? '自動更新が有効 (クリックで停止)' : '自動更新を有効化 (毎分チェック)',
              onPressed: onToggleAutoUpdate,
              color: isAutoUpdateEnabled ? Colors.green : Colors.white,
            ),
            
            // チャート設定ボタン
            _buildControlButton(
              icon: Icons.settings,
              tooltip: 'チャート設定（移動平均線、ウェーブポイント）',
              onPressed: onShowSettings,
            ),
            
            // 縦線描画ボタン
            _buildControlButton(
              icon: isVerticalLineMode ? Icons.remove : Icons.vertical_align_center,
              tooltip: isVerticalLineMode ? '縦線描画モードを終了' : '縦線描画モードに入る',
              onPressed: onToggleVerticalLineMode,
              color: isVerticalLineMode ? Colors.red : Colors.white,
            ),
            
            // すべての縦線をクリアボタン
            _buildControlButton(
              icon: Icons.clear_all,
              tooltip: 'すべての縦線をクリア',
              onPressed: onClearAllVerticalLines,
            ),
            
            // K線統計ボタン
            _buildControlButton(
              icon: isKlineCountMode ? Icons.close : Icons.analytics,
              tooltip: isKlineCountMode ? 'K線統計モードを終了' : 'K線統計モードに入る',
              onPressed: onToggleKlineCountMode,
              color: isKlineCountMode ? Colors.orange : Colors.white,
            ),
            
            // データ制限ボタン
            _buildControlButton(
              icon: Icons.filter_list,
              tooltip: 'データ表示を制限',
              onPressed: onLimitDataDisplay,
            ),
            
            const SizedBox(width: 8),
            
            // 表示範囲情報
            SelectableText(
              displayRangeText,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData? icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color color = Colors.white,
    bool isLoading = false,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
