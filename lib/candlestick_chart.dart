import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../models/price_data.dart';
import '../constants/chart_constants.dart';
import '../services/log_service.dart';
import '../services/chart_object_factory.dart';
import 'widgets/chart_view_controller.dart';
import 'widgets/candlestick_painter.dart';

/// キャンドルスティックチャートを表示するウィジェット
class CandlestickChart extends StatefulWidget {
  final List<PriceData> data;
  final double height;
  final Function(List<PriceData>)? onDataUpdated; // データ更新のコールバック
  final Map<int, bool>? maVisibilitySettings; // 移動平均線可視性設定
  final Map<int, String>? maColorSettings; // MA色設定
  final bool? isWavePointsVisible;
  final bool? isWavePointsLineVisible;
  final bool? isFormattedWaveVisible;
  final String? selectedInterpolationMethod;
  final Color? backgroundColor; // 背景色
  final int? autoUpdateIntervalMinutes; // 自动更新间隔（分钟）

  const CandlestickChart({
    super.key,
    required this.data,
    this.height = 400.0,
    this.onDataUpdated,
    this.maVisibilitySettings,
    this.maColorSettings,
    this.isWavePointsVisible,
    this.isWavePointsLineVisible,
    this.isFormattedWaveVisible,
    this.selectedInterpolationMethod,
    this.backgroundColor,
    this.autoUpdateIntervalMinutes,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  late final ChartViewController _controller;
  double _lastWidth = 0.0;
  Offset? _crosshairPosition;
  PriceData? _hoveredCandle;
  double? _hoveredPrice;
  bool _isRightClickDeleting = false; // 右クリック削除処理中フラグ
  
  // 自動更新関連
  Timer? _autoUpdateTimer;
  bool _isAutoUpdateEnabled = false;
  
  // ダブルクリック検出用
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();
    _controller = ChartViewController(
      data: widget.data,
      onUIUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    
    // 移動平均線設定を適用
    if (widget.maVisibilitySettings != null) {
      _controller.applyMaVisibilitySettings(widget.maVisibilitySettings!);
    }
    
    if (widget.isWavePointsVisible != null) {
      _controller.isWavePointsVisible = widget.isWavePointsVisible!;
    }
    
    if (widget.isWavePointsLineVisible != null) {
      _controller.isWavePointsLineVisible = widget.isWavePointsLineVisible!;
    }
    
    if (widget.data.isNotEmpty) {
      // 初回ビルド後に画面幅に基づいて表示範囲を初期化
      // 最新のK線が右端に表示されるように設定
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetView();
        }
      });
    }
  }

  @override
  void didUpdateWidget(CandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // データが更新された場合、コントローラーのデータも更新
    if (widget.data != oldWidget.data) {
      _controller.updateData(widget.data);
    }
    
    // 移動平均線設定更新
    if (widget.maVisibilitySettings != oldWidget.maVisibilitySettings) {
      if (widget.maVisibilitySettings != null) {
        _controller.applyMaVisibilitySettings(widget.maVisibilitySettings!);
      }
    }
    
    // ウェーブポイント可視性設定更新
    if (widget.isWavePointsVisible != oldWidget.isWavePointsVisible && widget.isWavePointsVisible != null) {
      _controller.isWavePointsVisible = widget.isWavePointsVisible!;
    }
    if (widget.isWavePointsLineVisible != oldWidget.isWavePointsLineVisible && widget.isWavePointsLineVisible != null) {
      _controller.isWavePointsLineVisible = widget.isWavePointsLineVisible!;
    }
    
    // 格式化波浪可視性設定更新
    if (widget.isFormattedWaveVisible != oldWidget.isFormattedWaveVisible && widget.isFormattedWaveVisible != null) {
      _controller.isFormattedWaveVisible = widget.isFormattedWaveVisible!;
    }
    
    // 補間方法設定更新
    if (widget.selectedInterpolationMethod != oldWidget.selectedInterpolationMethod && widget.selectedInterpolationMethod != null) {
      Log.info('CandlestickChart', '補間方法設定更新: ${oldWidget.selectedInterpolationMethod} -> ${widget.selectedInterpolationMethod}');
      _controller.selectedInterpolationMethod = widget.selectedInterpolationMethod!;
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller.recordCurrentViewState();

    if (widget.data.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SelectableText('データがありません'),
        ),
      );
    }

    final double minPrice = _getMinPrice();
    final double maxPrice = _getMaxPrice();

    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: Colors.black87,
      ),
      child: Column(
        children: [
          // チャートヘッダー
          _buildChartHeader(minPrice, maxPrice),
          
          // チャート本体
          Expanded(
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  switch (event.logicalKey.keyLabel) {
                    case 'Arrow Left':
                      _scrollLeft();
                      return KeyEventResult.handled;
                    case 'Arrow Right':
                      _scrollRight();
                      return KeyEventResult.handled;
                    case '+':
                    case '=':
                      _zoomIn();
                      return KeyEventResult.handled;
                    case '-':
                      _zoomOut();
                      return KeyEventResult.handled;
                    case 'r':
                    case 'R':
                      _resetView();
                      return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: LayoutBuilder(builder: (context, constraints) {
                final currentWidth = constraints.maxWidth;
                // On first build, just store the width.
                // On subsequent builds, if width changes, schedule an adjustment.
                if (_lastWidth != 0.0 && _lastWidth != currentWidth) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _adjustViewForResize(currentWidth);
                      });
                    }
                  });
                }
                _lastWidth = currentWidth;

                // デバッグ用ログ
                LogService.instance.debug('CandlestickChart', '背景色: ${widget.backgroundColor}');
                
                return RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: widget.backgroundColor ?? Colors.transparent, // 背景色を適用（デフォルトは透明）
                    child: MouseRegion(
                      onExit: _onPointerExit,
                      child: Listener( // For mouse wheel, hover, and right-click
                        onPointerSignal: _onPointerSignal,
                        onPointerHover: _onPointerHover,
                        onPointerMove: _onPointerHover, // Handles touch drag as well
                        onPointerDown: _onPointerDown, // Handle mouse right-click
                        child: GestureDetector( // For pan and scale
                            onScaleUpdate: _onScaleUpdate,
                            onScaleStart: _onScaleStart,
                        onScaleEnd: _onScaleEnd,
                        onTapUp: _onChartTap,
                    child: CustomPaint(
                    willChange: false, // パフォーマンス最適化
                    painter: CandlestickPainter(
                      data: widget.data,
                          candleWidth: _controller.candleWidth * _controller.scale,
                          spacing: _controller.spacing,
                      minPrice: minPrice,
                      maxPrice: maxPrice,
                          startIndex: _controller.startIndex,
                          endIndex: _controller.endIndex,
                      chartHeight: widget.height - 80, // ヘッダーとフッターの高さを考慮
                          chartWidth: currentWidth, // Use width from LayoutBuilder
                          emptySpaceWidth: _controller.emptySpaceWidth,
                          crosshairPosition: _crosshairPosition,
                          hoveredCandle: _hoveredCandle,
                          hoveredPrice: _hoveredPrice,
                          movingAverages: _getMovingAveragesData(),
                          maVisibility: _controller.maVisibility,
                          maColorSettings: widget.maColorSettings,
                            chartObjects: ChartObjectFactory.build(
                              controller: _controller,
                            ),
                          backgroundColor: widget.backgroundColor, // 背景色を渡す
                    ),
                    size: Size.infinite,
                  ),
                ),
                  )),
                ),
                  );
              }),
            ),
          ),
          
          // チャートフッター（コントロール）
          _buildChartControls(),
        ],
      ),
    );
  }

  Widget _buildChartHeader(double minPrice, double maxPrice) {
    Widget headerContent;
    if (_hoveredCandle != null && _hoveredPrice != null) {
      final candle = _hoveredCandle!;
      final o = candle.open.toStringAsFixed(5);
      final h = candle.high.toStringAsFixed(5);
      final l = candle.low.toStringAsFixed(5);
      final c = candle.close.toStringAsFixed(5);
      final v = candle.volume.toStringAsFixed(2);
      headerContent = SelectableText(
        '${candle.formattedDateTime}  O: $o  H: $h  L: $l  C: $c  V: $v',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    } else {
      headerContent = SelectableText(
        '価格レンジ: ${minPrice.toStringAsFixed(5)} - ${maxPrice.toStringAsFixed(5)}',
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 10,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Align(alignment: Alignment.centerRight, child: headerContent)),
        ],
      ),
    );
  }

  Widget _buildChartControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[800], // 元の色に戻す
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ズームアウト
          IconButton(
            onPressed: _zoomOut,
              icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
            tooltip: 'ズームアウト',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          
          // ズームイン
          IconButton(
            onPressed: _zoomIn,
              icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
            tooltip: 'ズームイン',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          
            const SizedBox(width: 4),
          
          // 左にスクロール
          IconButton(
            onPressed: _scrollLeft,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            tooltip: '左にスクロール',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          
          // 右にスクロール
          IconButton(
            onPressed: _scrollRight,
              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            tooltip: '右にスクロール',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          
            const SizedBox(width: 4),
          
          // リセット
          IconButton(
            onPressed: _resetView,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'ビューをリセット',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            const SizedBox(width: 4),
            
            // Dukascopyデータ取得
            IconButton(
              onPressed: _controller.isLoadingData ? null : _downloadData,
              icon: _controller.isLoadingData 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_download, color: Colors.white, size: 20),
              tooltip: '最新K線から3日分のデータをダウンロード',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // 自動更新ボタン
            IconButton(
              onPressed: _toggleAutoUpdate,
              icon: Icon(
                _isAutoUpdateEnabled ? Icons.pause_circle : Icons.play_circle,
                color: _isAutoUpdateEnabled ? Colors.green : Colors.white,
                size: 20,
              ),
              tooltip: _isAutoUpdateEnabled ? '自動更新が有効 (クリックで停止)' : '自動更新を有効化 (毎分チェック)',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // チャート設定ボタン
            IconButton(
              onPressed: _showMaSettingsDialog,
              icon: Icon(Icons.settings, color: Colors.white, size: 20),
              tooltip: 'チャート設定（移動平均線、ウェーブポイント）',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // ウェーブポイント表示制御ボタン
            IconButton(
              onPressed: _toggleWavePointsVisibility,
              icon: Icon(
                _controller.isWavePointsVisible ? Icons.visibility : Icons.visibility_off,
                color: _controller.isWavePointsVisible ? Colors.green : Colors.white,
                size: 20,
              ),
              tooltip: _controller.isWavePointsVisible ? 'ウェーブポイントを非表示' : 'ウェーブポイントを表示',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // 縦線描画ボタン
            IconButton(
              onPressed: _toggleVerticalLineMode,
              icon: Icon(
                _controller.isVerticalLineMode ? Icons.remove : Icons.vertical_align_center,
                color: _controller.isVerticalLineMode ? Colors.red : Colors.white,
                size: 20,
              ),
              tooltip: _controller.isVerticalLineMode ? '縦線描画モードを終了' : '縦線描画モードに入る',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // すべての縦線をクリアボタン
            IconButton(
              onPressed: _clearAllVerticalLines,
              icon: Icon(Icons.clear_all, color: Colors.white, size: 20),
              tooltip: 'すべての縦線をクリア',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // K線統計ボタン
            IconButton(
              onPressed: _toggleKlineCountMode,
              icon: Icon(
                _controller.isKlineCountMode ? Icons.close : Icons.analytics,
                color: _controller.isKlineCountMode ? Colors.orange : Colors.white,
                size: 20,
              ),
              tooltip: _controller.isKlineCountMode ? 'K線統計モードを終了' : 'K線統計モードに入る',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // データ制限ボタン
            IconButton(
              onPressed: _limitDataDisplay,
              icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
              tooltip: 'データ表示を制限',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            const SizedBox(width: 8),
          
          // 表示範囲情報
          SelectableText(
              '表示: ${_controller.startIndex.clamp(0, widget.data.length) + 1}-${_controller.endIndex.clamp(0, widget.data.length)} / ${widget.data.length}',
            style: TextStyle(
              color: Colors.grey[300],
                fontSize: 11,
            ),
          ),
          
            const SizedBox(width: 8),
          
            // 操作説明（簡略版）
          SelectableText(
              '操作: ドラッグ/←→ スクロール, +/- ズーム, ホイール ズーム, R リセット',
            style: TextStyle(
              color: Colors.grey[400],
                fontSize: 9,
              ),
            ),
          ],
          ),
      ),
    );
  }

  double _getMinPrice() {
    if (widget.data.isEmpty) return 0.0;
    
    final int start = _controller.startIndex.clamp(0, widget.data.length);
    final int end = _controller.endIndex.clamp(0, widget.data.length);

    if (start >= end) return 0.0;

    final visibleData = widget.data.sublist(start, end);
    return visibleData.map((d) => d.low).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxPrice() {
    if (widget.data.isEmpty) return 0.0;
    
    final int start = _controller.startIndex.clamp(0, widget.data.length);
    final int end = _controller.endIndex.clamp(0, widget.data.length);

    if (start >= end) return 0.0;

    final visibleData = widget.data.sublist(start, end);
    return visibleData.map((d) => d.high).reduce((a, b) => a > b ? a : b);
  }

  /// ウィンドウリサイズ時に表示を調整する
  void _adjustViewForResize(double newWidth) {
    _controller.adjustViewForResize(newWidth);
  }

  void _onPointerHover(PointerEvent event) {
    setState(() {
      _crosshairPosition = event.localPosition;
      
      final double chartBodyHeight = widget.height - 80;
      final double minPrice = _getMinPrice();
      final double maxPrice = _getMaxPrice();

      _hoveredCandle = _controller.getCandleAtX(event.localPosition.dx, _lastWidth);
      _hoveredPrice = _controller.getPriceAtY(event.localPosition.dy, chartBodyHeight, minPrice, maxPrice);
    });
  }

  void _onPointerExit(PointerExitEvent event) {
    setState(() {
      _crosshairPosition = null;
      _hoveredCandle = null;
      _hoveredPrice = null;
    });
  }

  /// マウスポインター押下イベントを処理（右クリックを含む）
  void _onPointerDown(PointerDownEvent event) {
    // マウス右クリックかどうかチェック
    if (event.buttons == kSecondaryMouseButton) {
      // Set a flag to prevent onScaleStart from creating a new selection.
      // This flag is reset after a delay to ensure the gesture is complete.
      _isRightClickDeleting = true;
      Future.delayed(const Duration(milliseconds: 100), () {
        _isRightClickDeleting = false;
      });

      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPosition = renderBox.globalToLocal(event.position);
      final double chartX = localPosition.dx;
      final double chartWidth = renderBox.size.width;

      // 縦線削除を優先処理
      if (_controller.verticalLines.isNotEmpty) {
        _controller.removeVerticalLineNearPosition(chartX, chartWidth).then((deleted) {
          if (deleted && mounted) {
            setState(() {
              // 縦線を削除するために再描画をトリガー
            });
          }
        });
        return;
      }

      // 縦線モードでない場合、K線統計モードの削除を処理
      if (_controller.isKlineCountMode) {
        final selection = _controller.findKlineSelectionAtPosition(chartX, chartWidth);
        if (selection != null) {
          _controller.removeKlineSelection(selection.id).then((success) {
            if (success && mounted) {
              setState(() {
                // Rebuild to reflect the removed selection.
              });
            }
          });
        }
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (_controller.isKlineCountMode) {
        // K線統計モード：ドラッグ選択を処理
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localPosition = renderBox.globalToLocal(details.focalPoint);
        _controller.updateSelection(localPosition.dx);
        } else {
        // 通常モード：ズームを処理
        _controller.onScaleUpdate(details, _lastWidth);
      }
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isRightClickDeleting) return; // 右クリック削除中は処理しない
    if (_controller.isKlineCountMode) {
      // K線統計モード：選択開始
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPosition = renderBox.globalToLocal(details.focalPoint);
      _controller.startSelection(localPosition.dx);
    }
    // 通常モード：特別な処理は不要
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_controller.isKlineCountMode) {
      // K線統計モード：選択完了
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final double chartWidth = renderBox.size.width;
      _controller.finishSelection(chartWidth);
      
      // 選択区域を自動保存
      if (_controller.selectedKlineCount > 0) {
        _controller.saveCurrentSelection(chartWidth).then((success) {
          if (success) {
            setState(() {
              // 保存された選択区域を表示するために再描画をトリガー
              // K線統計モードを自動終了
              _controller.toggleKlineCountMode();
            });
          }
        });
      } else {
        // K線が選択されていなくても統計モードを終了
        setState(() {
          _controller.toggleKlineCountMode();
        });
      }
      
      setState(() {
        // 最終結果を表示するために再描画をトリガー
      });
    }
  }

  /// マウスホイールイベントを処理（ズーム操作）
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        // スクロール量に基づいて細かいズーム操作を実行
        final double scrollDelta = event.scrollDelta.dy;
        
        // マウスホイール専用の細かいズーム操作を使用
        _controller.zoomWithMouseWheel(_lastWidth, -scrollDelta);
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _controller.zoomIn(_lastWidth);
    });
  }

  void _zoomOut() {
    setState(() {
      _controller.zoomOut(_lastWidth);
    });
  }

  void _scrollLeft() {
    setState(() {
      _controller.scrollLeft();
    });
  }

  void _scrollRight() {
    setState(() {
      _controller.scrollRight(_lastWidth);
    });
  }

  void _resetView({bool preserveScale = false}) {
    setState(() {
      // _lastWidthが利用可能になる前に呼び出される可能性があるため、MediaQueryを使用する
      final width = _lastWidth > 0 ? _lastWidth : MediaQuery.of(context).size.width;
      _controller.resetView(width, preserveScale: preserveScale);
    });
  }

  /// dukascopy-nodeでデータをダウンロードして取得
  void _downloadData() async {
    Log.info('CandlestickChart', '=== 手动下载按钮被点击 ===');
    Log.info('CandlestickChart', '开始执行手动下载...');
    
    setState(() {
      // ローディング状態を更新
    });
    
    try {
      Log.info('CandlestickChart', '调用ChartViewController.downloadAndLoadData()...');
      await _controller.downloadAndLoadData();
      Log.info('CandlestickChart', 'ChartViewController.downloadAndLoadData()执行完成');
    } catch (e) {
      Log.error('CandlestickChart', '下载过程中发生错误: $e');
    }
    
    setState(() {
      // データ更新後にUIを更新
      // 表示範囲を強制的にリセットして最新データを表示（スケールを保持）
      if (_lastWidth > 0) {
        _controller.resetView(_lastWidth, preserveScale: true);
      }
      
      // 親コンポーネントにデータ更新を通知
      if (widget.onDataUpdated != null) {
        widget.onDataUpdated!(_controller.data);
      }
    });
    
    Log.info('CandlestickChart', '=== 手动下载完成 ===');
  }

  /// 自動更新機能
  void _toggleAutoUpdate() {
    setState(() {
      _isAutoUpdateEnabled = !_isAutoUpdateEnabled;
      
      if (_isAutoUpdateEnabled) {
        _startAutoUpdate();
      } else {
        _stopAutoUpdate();
      }
    });
  }

  /// 自動更新タイマーを起動
  void _startAutoUpdate() {
    _stopAutoUpdate(); // 重複するタイマーがないことを保証
    
    // 使用传入的间隔时间，如果没有则使用默认1分钟
    final intervalMinutes = widget.autoUpdateIntervalMinutes ?? 1;
    _autoUpdateTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      if (mounted && _isAutoUpdateEnabled) {
        _performAutoUpdate();
      }
    });
    
    Log.info('AutoUpdate', '图表组件自动更新开始: $intervalMinutes分钟间隔');
  }

  /// 自動更新タイマーを停止
  void _stopAutoUpdate() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
  }

  /// 自動更新チェックを実行
  void _performAutoUpdate() async {
    try {
      // 更新前の最新K线时间戳を记录
      DateTime? oldLatestTime;
      if (_controller.data.isNotEmpty) {
        oldLatestTime = DateTime.fromMillisecondsSinceEpoch(_controller.data.last.timestamp, isUtc: true);
        Log.info('AutoUpdate', '更新前最新K线时间: $oldLatestTime');
      }
      
      // データダウンロードを実行
      await _controller.downloadAndLoadData();
      
      // 新規データがあるかチェック（基于最新K线时间戳）
      bool hasNewData = false;
      if (_controller.data.isNotEmpty) {
        final newLatestTime = DateTime.fromMillisecondsSinceEpoch(_controller.data.last.timestamp, isUtc: true);
        Log.info('AutoUpdate', '更新后最新K线时间: $newLatestTime');
        
        if (oldLatestTime == null || newLatestTime.isAfter(oldLatestTime)) {
          hasNewData = true;
          Log.info('AutoUpdate', '检测到新数据: $oldLatestTime -> $newLatestTime');
        } else {
          Log.info('AutoUpdate', '没有新数据: 最新时间未变化');
        }
      }
      
      if (hasNewData) {
        setState(() {
          // ズーム比率を保持し、最新データを表示
          if (_lastWidth > 0) {
            _controller.resetView(_lastWidth, preserveScale: true);
          }
          
          // 親コンポーネントにデータが更新されたことを通知
          if (widget.onDataUpdated != null) {
            widget.onDataUpdated!(_controller.data);
          }
        });
      }
    } catch (e) {
      Log.error('AutoUpdate', '自動更新エラー: $e');
    }
  }

  @override
  void dispose() {
    _stopAutoUpdate();
    _controller.dispose();
    super.dispose();
  }

  /// 移動平均線データを取得
  Map<int, List<double>> _getMovingAveragesData() {
    Map<int, List<double>> maData = {};
    
    for (int period in _controller.maPeriods) {
      // 可視の移動平均線データのみを取得
      if (_controller.isMaVisible(period)) {
        final List<double>? ma = _controller.getMovingAverage(period);
        if (ma != null) {
          maData[period] = ma;
        }
      }
    }
    
    return maData;
  }

  /// 移動平均線設定ダイアログを表示
  void _showMaSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: SelectableText('チャート設定'),
              content: SizedBox(
                width: 300,
                height: 450, // 新オプションを収容するために高さを増加
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ウェーブポイント設定区域
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            'ウェーブポイント設定',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          CheckboxListTile(
                            title: SelectableText('ウェーブポイントを表示'),
                            subtitle: SelectableText('高低点マーカーを表示'),
                            value: _controller.isWavePointsVisible,
                            onChanged: (bool? value) {
                              if (value != null) {
                                _controller.toggleWavePointsVisibility();
                                setState(() {});
                              }
                            },
                            activeColor: Colors.blue,
                          ),
                          CheckboxListTile(
                            title: SelectableText('ウェーブポイント接続線を表示'),
                            subtitle: SelectableText('高低点を接続して折れ線を形成'),
                            value: _controller.isWavePointsLineVisible,
                            onChanged: (bool? value) {
                              if (value != null) {
                                _controller.toggleWavePointsLineVisibility();
                                setState(() {});
                              }
                            },
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    // 移動平均線設定区域
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '移動平均線設定',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          // 全選択/全選択解除ボタン
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  _controller.setAllMaVisibility(true);
                                  setState(() {});
                                },
                                child: SelectableText('全選択'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _controller.setAllMaVisibility(false);
                                  setState(() {});
                                },
                                child: SelectableText('全選択解除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    // スクロールコントロールでチェックボックスリストをラップ
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _controller.maPeriods.map((period) {
                            return CheckboxListTile(
                              title: SelectableText(
                                'MA$period',
                                style: TextStyle(
                                  color: _getMaColor(period),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: SelectableText(_getMaDescription(period)),
                              value: _controller.isMaVisible(period),
                              onChanged: (bool? value) {
                                if (value != null) {
                                  _controller.setMaVisibility(period, value);
                                  setState(() {});
                                }
                              },
                              activeColor: _getMaColor(period),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: SelectableText('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 設定を保存してチャートをリフレッシュ
                    Navigator.of(context).pop();
                    // ダイアログを閉じた後にメインチャートの再描画をトリガー
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          // チャートの再描画をトリガー
                        });
                      }
                    });
                  },
                  child: SelectableText('確定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 移動平均線の色を取得
  Color _getMaColor(int period) {
    return ChartConstants.maColors[period] ?? Colors.grey;
  }

  /// 移動平均線の説明を取得
  String _getMaDescription(int period) {
    return ChartConstants.maDescriptions[period] ?? '移動平均線';
  }

  /// 縦線描画モードを切り替え
  void _toggleVerticalLineMode() {
    setState(() {
      _controller.toggleVerticalLineMode();
    });
  }

  /// ウェーブポイント表示を切り替え
  void _toggleWavePointsVisibility() {
    setState(() {
      _controller.toggleWavePointsVisibility();
    });
  }

  /// チャートクリックイベントを処理
  void _onChartTap(TapUpDetails details) {
    if (_isRightClickDeleting) return; // 右クリック削除中は処理しない
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
    final double chartX = localPosition.dx;
    final double chartY = localPosition.dy;
    final double chartWidth = renderBox.size.width;
    final double chartHeight = renderBox.size.height;
    
    // ダブルクリック検出
    final now = DateTime.now();
    final isDoubleClick = _lastTapTime != null && 
                         _lastTapPosition != null &&
                         now.difference(_lastTapTime!).inMilliseconds < 500 && // 500ms以内
                         (localPosition - _lastTapPosition!).distance < 10; // 10ピクセル以内
    
    if (isDoubleClick) {
      // ダブルクリック処理：手動高低点の追加/削除
      _handleDoubleClick(chartX, chartY, chartWidth, chartHeight);
      _lastTapTime = null;
      _lastTapPosition = null;
      return;
    }
    
    // シングルクリックの記録
    _lastTapTime = now;
    _lastTapPosition = localPosition;
    
    // 右クリックかどうかチェック（K線統計モードで）
    if (_controller.isKlineCountMode && details.kind == PointerDeviceKind.mouse) {
      // クリック位置にK線選択区域があるか検索
      try {
        final selection = _controller.findKlineSelectionAtPosition(chartX, chartWidth);
        if (selection != null) {
          // 削除確認ダイアログを表示
          return;
        }
      } catch (e) {
        // 選択区域が見つからない、通常処理を継続
      }
    }
    
    if (_controller.isVerticalLineMode) {
      // 縦線描画モードで、クリック位置に縦線を追加
      Log.debug('ChartInteraction', 'マウスクリック: globalPosition=${details.globalPosition}, localPosition=$localPosition');
      Log.debug('ChartInteraction', 'チャートサイズ: width=$chartWidth, height=${renderBox.size.height}');
      Log.debug('ChartInteraction', '計算されたチャートX座標: $chartX');
      
      _addVerticalLineAtPosition(chartX, chartWidth);
    }
  }

  /// 指定位置に縦線を追加
  void _addVerticalLineAtPosition(double x, double chartWidth) async {
    await _controller.addVerticalLineAtPosition(x, chartWidth);
    setState(() {
      // 再描画をトリガー
    });
  }

  /// ダブルクリック処理：手動高低点の追加/削除
  void _handleDoubleClick(double chartX, double chartY, double chartWidth, double chartHeight) async {
    final double minPrice = _getMinPrice();
    final double maxPrice = _getMaxPrice();
    
    Log.info('ManualHighLow', 'ダブルクリック検出 - 位置: ($chartX, $chartY), 価格範囲: $minPrice - $maxPrice');
    
    // 手動高低点の追加/削除を実行
    await _controller.toggleManualHighLowPointAtPosition(chartX, chartY, chartWidth, chartHeight, minPrice, maxPrice);
    
    setState(() {
      // 再描画をトリガー
    });
  }

  /// すべての縦線をクリア
  void _clearAllVerticalLines() async {
    await _controller.clearAllVerticalLines();
    setState(() {
      // 再描画をトリガー
    });
  }

  /// データ表示を制限する
  void _limitDataDisplay() {
    setState(() {
      // 最新の1000件のみを表示するように制限
      const int limitCount = 1000;
      if (widget.data.length > limitCount) {
        final int startIndex = widget.data.length - limitCount;
        _controller.startIndex = startIndex;
        _controller.endIndex = widget.data.length;
      }
    });
  }

  // --- K線統計関連メソッド ---

  /// K線統計モードを切り替え
  void _toggleKlineCountMode() {
    setState(() {
      _controller.toggleKlineCountMode();
    });
  }


}
