import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../models/price_data.dart';
import '../models/timeframe.dart';
import '../models/trading_pair.dart';
import '../models/chart_object.dart';
import '../models/drawing_tool.dart';
import '../constants/chart_constants.dart';
import '../services/log_service.dart';
import '../services/chart_object_factory.dart';
import '../services/chart_object_interaction_service.dart';
import '../services/user_drawing_layer3_manager.dart';
import '../services/layer3_drawing_object_builder.dart';
import 'candlestick_painter.dart';
import 'chart_view_controller.dart';
import 'components/bollinger_bands_settings_dialog.dart';

part 'candlestick_chart_interaction_coordinator.dart';

class _ChartGeometry {
  const _ChartGeometry({required this.width, required this.height});

  final double width;
  final double height;

  bool containsY(double y) => y >= 0 && y <= height;
}

/// キャンドルスティックチャートを表示するウィジェット
class CandlestickChart extends StatefulWidget {
  static _CandlestickChartState? _currentInstance;
  final List<PriceData> data;
  final double height;
  final Map<int, bool>? maVisibilitySettings; // 移動平均線可視性設定
  final Map<int, String>? maColorSettings; // MA色設定
  final Map<int, double>? maAlphas; // MA透明度設定
  final bool? isWavePointsVisible;
  final bool? isWavePointsLineVisible;
  final bool? isOhlcVisible; // 右上O/H/L/C表示
  final bool? isKlineVisible; // K線表示/非表示
  final Color? backgroundColor; // 背景色
  final bool? isTrendFilteringEnabled; // トレンドフィルタリング有効/無効
  final double? trendFilteringThreshold; // トレンドフィルタリング閾値
  final double? trendFilteringNearThreshold; // トレンドフィルタリング近い距離閾値
  final double? trendFilteringFarThreshold; // トレンドフィルタリング遠い距離閾値
  final int? trendFilteringMinGapBars; // トレンドフィルタリング最低バー間隔
  final bool? isCubicCurveVisible; // 3次曲线显示/隐藏
  final bool? isMA60FilteredCurveVisible; // 60均线过滤曲线显示/隐藏
  final bool? isBollingerBandsFilteredCurveVisible; // 布林线过滤曲线显示/隐藏
  final bool? isBollingerBandsVisible; // 布林通道显示/隐藏
  final int? bbPeriod; // 布林通道期间
  final double? bbStdDev; // 布林通道标准偏差倍率
  final Map<String, String>? bbColors; // 布林通道色设定
  final Map<String, double>? bbAlphas; // 布林通道透明度设定
  final bool? isMaTrendBackgroundEnabled; // 移动平均线趋势背景是否启用
  final bool? isMousePositionZoomEnabled; // 鼠标位置缩放是否启用
  final bool? isAutoUpdateEnabled; // 自动更新是否启用
  final int? autoUpdateIntervalMinutes; // 自动更新间隔（分钟）
  final int? klineDataLimit; // K线数据限制
  final Timeframe? selectedTimeframe; // 选择的时间周期
  final TradingPair? selectedTradingPair; // 选择的交易对
  final Future<void> Function({bool showMessages})? onDownloadRequested; // データダウンロード要求コールバック
  final VoidCallback? onAutoUpdateToggled; // 自動更新トグルコールバック

  const CandlestickChart({
    super.key,
    required this.data,
    this.height = 400.0,
    this.maVisibilitySettings,
    this.maColorSettings,
    this.maAlphas,
    this.isWavePointsVisible,
    this.isWavePointsLineVisible,
    this.isOhlcVisible,
    this.isKlineVisible,
    this.backgroundColor,
    this.isTrendFilteringEnabled,
    this.trendFilteringThreshold,
    this.trendFilteringNearThreshold,
    this.trendFilteringFarThreshold,
    this.trendFilteringMinGapBars,
    this.isCubicCurveVisible,
    this.isMA60FilteredCurveVisible,
    this.isBollingerBandsFilteredCurveVisible,
    this.isBollingerBandsVisible,
    this.bbPeriod,
    this.bbStdDev,
    this.bbColors,
    this.bbAlphas,
    this.isMaTrendBackgroundEnabled,
    this.isMousePositionZoomEnabled,
    this.isAutoUpdateEnabled,
    this.autoUpdateIntervalMinutes,
    this.klineDataLimit,
    this.selectedTimeframe,
    this.selectedTradingPair,
    this.onDownloadRequested,
    this.onAutoUpdateToggled,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
  
  /// 静态导航方法
  static void navigateToIndex(int index) {
    if (_currentInstance != null) {
      _currentInstance!.navigateToIndex(index);
    } else {
      // LogService.instance.warning('CandlestickChart', '图表实例未初始化，无法导航');
    }
  }
  
  static void navigateToTimestamp(int timestamp) {
    if (_currentInstance != null) {
      _currentInstance!.navigateToTimestamp(timestamp);
    } else {
      // LogService.instance.warning('CandlestickChart', '图表实例未初始化，无法导航');
    }
  }
  
  static void navigateToStart() {
    if (_currentInstance != null) {
      _currentInstance!.navigateToStart();
    } else {
      // LogService.instance.warning('CandlestickChart', '图表实例未初始化，无法导航');
    }
  }
  
  static void navigateToEnd() {
    if (_currentInstance != null) {
      _currentInstance!.navigateToEnd();
    } else {
      // LogService.instance.warning('CandlestickChart', '图表实例未初始化，无法导航');
    }
  }
}

class _CandlestickChartState extends State<CandlestickChart> {
  // Architecture map:
  // 1) Lifecycle & widget sync
  // 2) Interaction input pipeline (tap/hover/scale/pointer)
  // 3) Drawing session & object CRUD
  // 4) Drag update pipeline
  // 5) Object build/preview pipeline
  // 6) View/utility operations
  late final ChartViewController _controller;
  double _lastWidth = 0.0;
  Offset? _crosshairPosition;
  PriceData? _hoveredCandle;
  double? _hoveredPrice;
  bool _isRightClickDeleting = false; // 右クリック削除処理中フラグ
  bool _isDownloading = false; // データダウンロード中の状態フラグ
  DrawingTool _activeDrawingTool = DrawingTool.none;
  CandleAnchor? _pendingDrawingStartAnchor;
  final UserDrawingLayer3Manager _layer3DrawingManager = UserDrawingLayer3Manager();
  final List<CandleAnchor> _pendingPolylinePoints = [];
  CandleAnchor? _previewAnchor;
  String? _selectedObjectId;
  Type? _selectedObjectType;
  String? _draggingObjectId;
  Type? _draggingObjectType;
  ObjectDragTarget? _draggingObjectTarget;
  Offset? _lastDragPosition;
  
  // ダブルクリック検出用
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  String? get _selectedTrendLineId =>
      _selectedObjectType == TrendLineObject ? _selectedObjectId : null;

  bool get _hasSelectedObject =>
      _selectedObjectId != null && _selectedObjectType != null;

  List<TrendLineObject> get _trendLines => _layer3DrawingManager.trendLines;

  void _clearObjectSelection() {
    _selectedObjectId = null;
    _selectedObjectType = null;
  }

  void _clearPendingDrawingStart() {
    _pendingDrawingStartAnchor = null;
  }

  void _applyObjectSelectionHit(ObjectHitResult hit) {
    _selectedObjectId = hit.objectId;
    _selectedObjectType = hit.objectType;
    _clearPendingDrawingStart();
  }

  void _resetDrawingSession({
    bool clearTool = false,
    bool clearPendingStart = true,
    bool clearPolylineDraft = true,
    bool clearPreview = true,
  }) {
    if (clearTool) {
      _activeDrawingTool = DrawingTool.none;
    }
    if (clearPendingStart) {
      _clearPendingDrawingStart();
    }
    if (clearPolylineDraft) {
      _pendingPolylinePoints.clear();
    }
    if (clearPreview) {
      _previewAnchor = null;
    }
  }

  void _completeSingleDrawCycle() {
    _resetDrawingSession(
      clearTool: true,
      clearPendingStart: true,
      clearPolylineDraft: true,
      clearPreview: true,
    );
  }

  @override
  void initState() {
    super.initState();
    // 设置当前实例
    CandlestickChart._currentInstance = this;
    
    _controller = ChartViewController(
      data: widget.data,
      onUIUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
      klineDataLimit: widget.klineDataLimit,
      selectedTimeframe: widget.selectedTimeframe,
      selectedTradingPair: widget.selectedTradingPair,
    );
    
    // 移動平均線設定を適用
    if (widget.maVisibilitySettings != null) {
      _controller.applyMaVisibilitySettings(widget.maVisibilitySettings!);
    }
    
    if (widget.isWavePointsVisible != null) {
      _controller.isWavePointsVisible = widget.isWavePointsVisible!;
    }
    
    // トレンドフィルタリング設定初期化
    if (widget.isTrendFilteringEnabled != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング設定初期化: ${widget.isTrendFilteringEnabled}');
      _controller.setTrendFilteringEnabled(widget.isTrendFilteringEnabled!);
    }

    if (widget.isCubicCurveVisible != null) {
      // LogService.instance.info('CandlestickChart', '3次曲线設定初期化: ${widget.isCubicCurveVisible}');
      _controller.syncSettingsFromAppSettings(isCubicCurveVisible: widget.isCubicCurveVisible);
    }

    if (widget.isMA60FilteredCurveVisible != null) {
      // LogService.instance.info('CandlestickChart', '60均线过滤曲线設定初期化: ${widget.isMA60FilteredCurveVisible}');
      _controller.syncSettingsFromAppSettings(isMA60FilteredCurveVisible: widget.isMA60FilteredCurveVisible);
    }

    if (widget.isBollingerBandsFilteredCurveVisible != null) {
      _controller.setBollingerBandsFilteredCurveVisible(widget.isBollingerBandsFilteredCurveVisible!);
    }

    // 布林通道設定初期化
    if (widget.isBollingerBandsVisible != null) {
      _controller.setBollingerBandsVisible(widget.isBollingerBandsVisible!);
    }
    if (widget.bbPeriod != null) {
      _controller.setBBPeriod(widget.bbPeriod!);
    }
    if (widget.bbStdDev != null) {
      _controller.setBBStdDev(widget.bbStdDev!);
    }
    if (widget.bbColors != null) {
      _controller.setBBColors(
        upperColor: widget.bbColors!['upper'] != null ? Color(int.parse(widget.bbColors!['upper']!)) : null,
        middleColor: widget.bbColors!['middle'] != null ? Color(int.parse(widget.bbColors!['middle']!)) : null,
        lowerColor: widget.bbColors!['lower'] != null ? Color(int.parse(widget.bbColors!['lower']!)) : null,
      );
    }
    if (widget.bbAlphas != null) {
      _controller.setBBAlphas(
        upperAlpha: widget.bbAlphas!['upper'],
        middleAlpha: widget.bbAlphas!['middle'],
        lowerAlpha: widget.bbAlphas!['lower'],
      );
    }

    if (widget.isMaTrendBackgroundEnabled != null) {
      // LogService.instance.info('CandlestickChart', '移动平均线趋势背景設定初期化: ${widget.isMaTrendBackgroundEnabled}');
      _controller.setMaTrendBackgroundEnabled(widget.isMaTrendBackgroundEnabled!);
    }

    if (widget.isMousePositionZoomEnabled != null) {
      // LogService.instance.info('CandlestickChart', '鼠标位置缩放設定初期化: ${widget.isMousePositionZoomEnabled}');
      _controller.setMousePositionZoomEnabled(widget.isMousePositionZoomEnabled!);
    }

    
    if (widget.trendFilteringThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング閾値初期化: ${widget.trendFilteringThreshold}');
      _controller.setTrendFilteringThreshold(widget.trendFilteringThreshold!);
    }
    if (widget.trendFilteringNearThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング近い距離閾値初期化: ${widget.trendFilteringNearThreshold}');
      _controller.setTrendFilteringNearThreshold(widget.trendFilteringNearThreshold!);
    }
    if (widget.trendFilteringFarThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング遠い距離閾値初期化: ${widget.trendFilteringFarThreshold}');
      _controller.setTrendFilteringFarThreshold(widget.trendFilteringFarThreshold!);
    }
    if (widget.trendFilteringMinGapBars != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング最低バー間隔初期化: ${widget.trendFilteringMinGapBars}');
      _controller.setTrendFilteringMinGapBars(widget.trendFilteringMinGapBars!);
    }
    
    // 初期化後にトレンドフィルタリングを強制更新
    // LogService.instance.info('CandlestickChart', 'initState完了: widget.isTrendFilteringEnabled=${widget.isTrendFilteringEnabled}');
    if (widget.isTrendFilteringEnabled == true) {
      // LogService.instance.info('CandlestickChart', '初期化後トレンドフィルタリング強制更新');
      _controller.setTrendFilteringEnabled(true);
    } else {
      // LogService.instance.info('CandlestickChart', '初期化時トレンドフィルタリング無効');
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
    if (_didDataSnapshotChange(oldWidget.data, widget.data)) {
      _controller.recordCurrentViewState();
      _controller.updateData(widget.data);
    }
    
    // 移動平均線設定更新
    if (widget.maVisibilitySettings != oldWidget.maVisibilitySettings) {
      if (widget.maVisibilitySettings != null) {
        _controller.applyMaVisibilitySettings(widget.maVisibilitySettings!);
      }
    }
    
    // MA色設定更新
    if (widget.maColorSettings != oldWidget.maColorSettings) {
      // LogService.instance.info('CandlestickChart', 'MA色設定更新検知');
      // MA色設定の変更はCandlestickPainterに直接渡されるため、setStateで再描画をトリガー
      setState(() {});
    }
    
    // ウェーブポイント可視性設定更新
    if (widget.isWavePointsVisible != oldWidget.isWavePointsVisible && widget.isWavePointsVisible != null) {
      _controller.isWavePointsVisible = widget.isWavePointsVisible!;
    }
    if (widget.isWavePointsLineVisible != oldWidget.isWavePointsLineVisible && widget.isWavePointsLineVisible != null) {
      _controller.isWavePointsLineVisible = widget.isWavePointsLineVisible!;
    }
    
    

    // トレンドフィルタリング設定更新
    // LogService.instance.debug('CandlestickChart', 'didUpdateWidget: widget.isTrendFilteringEnabled=${widget.isTrendFilteringEnabled}, oldWidget.isTrendFilteringEnabled=${oldWidget.isTrendFilteringEnabled}');
    if (widget.isTrendFilteringEnabled != oldWidget.isTrendFilteringEnabled && widget.isTrendFilteringEnabled != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング設定更新: ${widget.isTrendFilteringEnabled}');
      _controller.setTrendFilteringEnabled(widget.isTrendFilteringEnabled!);
    }

    if (widget.isCubicCurveVisible != oldWidget.isCubicCurveVisible && widget.isCubicCurveVisible != null) {
      // LogService.instance.info('CandlestickChart', '3次曲线設定更新: ${widget.isCubicCurveVisible}');
      _controller.syncSettingsFromAppSettings(isCubicCurveVisible: widget.isCubicCurveVisible);
    }

    if (widget.isMA60FilteredCurveVisible != oldWidget.isMA60FilteredCurveVisible && widget.isMA60FilteredCurveVisible != null) {
      // LogService.instance.info('CandlestickChart', '60均线过滤曲线設定更新: ${widget.isMA60FilteredCurveVisible}');
      _controller.syncSettingsFromAppSettings(isMA60FilteredCurveVisible: widget.isMA60FilteredCurveVisible);
    }

    if (widget.isBollingerBandsFilteredCurveVisible != oldWidget.isBollingerBandsFilteredCurveVisible && widget.isBollingerBandsFilteredCurveVisible != null) {
      _controller.setBollingerBandsFilteredCurveVisible(widget.isBollingerBandsFilteredCurveVisible!);
    }

    // 鼠标位置缩放设置更新
    if (widget.isMousePositionZoomEnabled != oldWidget.isMousePositionZoomEnabled && widget.isMousePositionZoomEnabled != null) {
      // LogService.instance.info('CandlestickChart', '鼠标位置缩放設定更新: ${widget.isMousePositionZoomEnabled}');
      _controller.setMousePositionZoomEnabled(widget.isMousePositionZoomEnabled!);
    }

    if (widget.trendFilteringThreshold != oldWidget.trendFilteringThreshold && widget.trendFilteringThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング閾値更新: ${widget.trendFilteringThreshold}');
      _controller.setTrendFilteringThreshold(widget.trendFilteringThreshold!);
    }
    if (widget.trendFilteringNearThreshold != oldWidget.trendFilteringNearThreshold && widget.trendFilteringNearThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング近い距離閾値更新: ${widget.trendFilteringNearThreshold}');
      _controller.setTrendFilteringNearThreshold(widget.trendFilteringNearThreshold!);
    }
    if (widget.trendFilteringFarThreshold != oldWidget.trendFilteringFarThreshold && widget.trendFilteringFarThreshold != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング遠い距離閾値更新: ${widget.trendFilteringFarThreshold}');
      _controller.setTrendFilteringFarThreshold(widget.trendFilteringFarThreshold!);
    }
    if (widget.trendFilteringMinGapBars != oldWidget.trendFilteringMinGapBars && widget.trendFilteringMinGapBars != null) {
      // LogService.instance.info('CandlestickChart', 'トレンドフィルタリング最低バー間隔更新: ${widget.trendFilteringMinGapBars}');
      _controller.setTrendFilteringMinGapBars(widget.trendFilteringMinGapBars!);
    }
  }

  bool _didDataSnapshotChange(List<PriceData> previous, List<PriceData> next) {
    if (identical(previous, next)) return false;
    if (previous.length != next.length) return true;
    if (next.isEmpty) return false;
    if (previous.first.timestamp != next.first.timestamp) return true;
    return previous.last.timestamp != next.last.timestamp;
  }

  @override
  Widget build(BuildContext context) {
    // LogService.instance.debug('CandlestickChart', 'build開始: filteredWavePoints=${_controller.filteredWavePoints != null ? "存在" : "null"}');
    // LogService.instance.debug('CandlestickChart', 'isTrendFilteringEnabled=${widget.isTrendFilteringEnabled}');
    // LogService.instance.debug('CandlestickChart', 'controller.isTrendFilteringEnabled=${_controller.isTrendFilteringEnabled}');
    // LogService.instance.debug('CandlestickChart', 'wavePoints=${_controller.wavePoints != null ? "存在" : "null"}');
    // LogService.instance.debug('CandlestickChart', 'data.length=${widget.data.length}');
    
    // トレンドフィルタリングが有効だがfilteredWavePointsがnullの場合、強制更新
    if (widget.isTrendFilteringEnabled == true && _controller.filteredWavePoints == null) {
      // LogService.instance.info('CandlestickChart', 'build中: トレンドフィルタリング強制更新実行');
      _controller.setTrendFilteringEnabled(true);
    }
    
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
                // LogService.instance.debug('CandlestickChart', '背景色: ${widget.backgroundColor}');
                
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
                          maAlphas: widget.maAlphas,
                          backgroundColor: widget.backgroundColor, // 背景色を渡す
                          isKlineVisible: widget.isKlineVisible ?? true, // K線表示/非表示
                          selectedTradingPair: widget.selectedTradingPair,
                          cubicCurveResult: _controller.cubicCurveResult,
                          isCubicCurveVisible: widget.isCubicCurveVisible ?? false,
                          ma60FilteredCurveResult: _controller.ma60FilteredCurveResult,
                          isMA60FilteredCurveVisible: widget.isMA60FilteredCurveVisible ?? false,
                          bollingerBandsFilteredCurveResult: _controller.bollingerBandsFilteredCurveResult,
                          isBollingerBandsFilteredCurveVisible: widget.isBollingerBandsFilteredCurveVisible ?? false,
                          bollingerBands: _controller.getBollingerBandsData(),
                          isBollingerBandsVisible: _controller.isBollingerBandsVisible,
                          bbColors: _controller.bbColors,
                          bbAlphas: _controller.bbAlphas,
                          isMaTrendBackgroundEnabled: widget.isMaTrendBackgroundEnabled ?? false,
                          maTrendBackgroundColors: _controller.maTrendBackgroundColors,
                          chartObjects: _buildObjectStickers(),
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
    final bool shouldShowOhlc = widget.isOhlcVisible ?? true;
    Widget headerContent;
    if (shouldShowOhlc && _hoveredCandle != null && _hoveredPrice != null) {
      final pair = widget.selectedTradingPair ?? TradingPair.eurusd;
      final candle = _hoveredCandle!;
      final o = pair.formatPrice(candle.open);
      final h = pair.formatPrice(candle.high);
      final l = pair.formatPrice(candle.low);
      final c = pair.formatPrice(candle.close);
      final v = candle.volume.toStringAsFixed(2);
      headerContent = SelectableText(
        '${candle.formattedDateTime}  O: $o  H: $h  L: $l  C: $c  V: $v',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    } else {
      final pair = widget.selectedTradingPair ?? TradingPair.eurusd;
      headerContent = SelectableText(
        '価格レンジ: ${pair.formatPrice(minPrice)} - ${pair.formatPrice(maxPrice)}',
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
              onPressed: _isDownloading ? null : _handleDownloadRequest,
              icon: _isDownloading 
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
              onPressed: widget.onAutoUpdateToggled,
              icon: Icon(
                widget.isAutoUpdateEnabled == true ? Icons.pause_circle : Icons.play_circle,
                color: widget.isAutoUpdateEnabled == true ? Colors.green : Colors.white,
                size: 20,
              ),
              tooltip: widget.isAutoUpdateEnabled == true ? '自動更新が有効 (クリックで停止)' : '自動更新を有効化 (毎分チェック)',
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
            
            // 布林通道表示制御ボタン
            IconButton(
              onPressed: _toggleBollingerBandsVisibility,
              icon: Icon(
                _controller.isBollingerBandsVisible ? Icons.show_chart : Icons.visibility_off,
                color: _controller.isBollingerBandsVisible ? Colors.blue : Colors.white,
                size: 20,
              ),
              tooltip: _controller.isBollingerBandsVisible ? '布林通道を非表示' : '布林通道を表示',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            
            // 布林通道设置ボタン
            IconButton(
              onPressed: _showBollingerBandsSettings,
              icon: Icon(
                Icons.tune,
                color: _controller.isBollingerBandsVisible ? Colors.blue : Colors.grey,
                size: 20,
              ),
              tooltip: '布林通道参数设置',
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

            PopupMenuButton<DrawingTool>(
              tooltip: '绘制面板',
              onSelected: _setDrawingTool,
              itemBuilder: (context) => const [
                PopupMenuItem(value: DrawingTool.none, child: Text('关闭绘制')),
                PopupMenuItem(value: DrawingTool.trendLine, child: Text('斜线')),
                PopupMenuItem(value: DrawingTool.circle, child: Text('圆圈')),
                PopupMenuItem(value: DrawingTool.rectangle, child: Text('长方形')),
                PopupMenuItem(value: DrawingTool.fibonacci, child: Text('斐波那契')),
                PopupMenuItem(value: DrawingTool.polyline, child: Text('折线图')),
              ],
              child: Icon(
                Icons.draw,
                color: _activeDrawingTool == DrawingTool.none ? Colors.white : Colors.greenAccent,
                size: 20,
              ),
            ),

            if (_activeDrawingTool != DrawingTool.none)
              SelectableText(
                '绘制:${_activeDrawingTool.labelZh}',
                style: TextStyle(color: Colors.greenAccent, fontSize: 10),
              ),

            if (_activeDrawingTool == DrawingTool.polyline && _pendingPolylinePoints.length >= 2)
              IconButton(
                onPressed: _finishPolylineDrawing,
                icon: const Icon(Icons.check, color: Colors.greenAccent, size: 20),
                tooltip: '完成折线',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

            if (_selectedTrendLineId != null) ...[
              IconButton(
                onPressed: () => _adjustSelectedTrendLineLength(0.9),
                icon: const Icon(Icons.compress, color: Colors.white, size: 20),
                tooltip: '斜線長さを短く',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: () => _adjustSelectedTrendLineLength(1.1),
                icon: const Icon(Icons.expand, color: Colors.white, size: 20),
                tooltip: '斜線長さを長く',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: () => _adjustSelectedTrendLineAngle(-5),
                icon: const Icon(Icons.rotate_left, color: Colors.white, size: 20),
                tooltip: '斜線角度を左回転',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: () => _adjustSelectedTrendLineAngle(5),
                icon: const Icon(Icons.rotate_right, color: Colors.white, size: 20),
                tooltip: '斜線角度を右回転',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],

            if (_hasSelectedObject)
              IconButton(
                onPressed: _deleteSelectedObject,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: '删除选中的绘图对象',
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

  // --- Interaction Pipeline (pointer/tap/scale) ---

  void _onPointerHover(PointerEvent event) {
    if (!mounted) return;
    setState(() {
      _crosshairPosition = event.localPosition;

      final geometry = _resolveChartGeometry();
      final double minPrice = _getMinPrice();
      final double maxPrice = _getMaxPrice();

      _hoveredCandle = _controller.getCandleAtX(event.localPosition.dx, _lastWidth);
      _hoveredPrice = _controller.getPriceAtY(event.localPosition.dy, geometry.height, minPrice, maxPrice);

      if (_activeDrawingTool != DrawingTool.none) {
        final chartWidth = geometry.width;
        _previewAnchor = CandleAnchor(
          index: _xToDataIndex(event.localPosition.dx, chartWidth),
          price: _yToPrice(event.localPosition.dy, geometry.height),
        );
      } else {
        _previewAnchor = null;
      }
    });
  }

  void _onPointerExit(PointerExitEvent event) {
    if (!mounted) return;
    setState(() {
      _crosshairPosition = null;
      _hoveredCandle = null;
      _hoveredPrice = null;
      _previewAnchor = null;
    });
  }

  void _refreshUI() {
    if (!mounted) return;
    setState(() {});
  }

  void _mutateState(VoidCallback mutation) {
    if (!mounted) return;
    setState(mutation);
  }

  /// マウスポインター押下イベントを処理（右クリックを含む）
  void _onPointerDown(PointerDownEvent event) =>
      _CandlestickChartInteractionCoordinator.onPointerDown(this, event);

  void _onScaleUpdate(ScaleUpdateDetails details) =>
      _CandlestickChartInteractionCoordinator.onScaleUpdate(this, details);

  void _onScaleStart(ScaleStartDetails details) =>
      _CandlestickChartInteractionCoordinator.onScaleStart(this, details);

  void _onScaleEnd(ScaleEndDetails details) =>
      _CandlestickChartInteractionCoordinator.onScaleEnd(this, details);

  /// マウスホイールイベントを処理（ズーム操作）
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        // スクロール量に基づいて細かいズーム操作を実行
        final double scrollDelta = event.scrollDelta.dy;
        
        // 检查是否启用鼠标位置缩放
        if (_controller.isMousePositionZoomEnabled) {
          // 使用鼠标位置为原点进行缩放
          _controller.zoomWithMousePosition(_lastWidth, -scrollDelta, event.localPosition);
        } else {
          // 使用默认的右侧缩放开
          _controller.zoomWithMouseWheel(_lastWidth, -scrollDelta);
        }
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

  /// 親ウィジェットにデータダウンロードを要求
  void _handleDownloadRequest() async {
    Log.info('CandlestickChart', '=== 主应用下载按钮被点击 ===');
    Log.info('CandlestickChart', '检查下载状态: _isDownloading=$_isDownloading, onDownloadRequested=${widget.onDownloadRequested != null}');
    
    if (_isDownloading || widget.onDownloadRequested == null) {
      Log.warning('CandlestickChart', '下载被跳过: _isDownloading=$_isDownloading, onDownloadRequested=${widget.onDownloadRequested != null}');
      return;
    }

    Log.info('CandlestickChart', '开始执行主应用下载...');
    setState(() {
      _isDownloading = true;
    });

    try {
      Log.info('CandlestickChart', '调用widget.onDownloadRequested...');
      await widget.onDownloadRequested!(showMessages: true);
      Log.info('CandlestickChart', 'widget.onDownloadRequested执行完成');
    } catch (e) {
      Log.error('CandlestickChart', '主应用下载过程中发生错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      Log.info('CandlestickChart', '=== 主应用下载完成 ===');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // 清理当前实例
    if (CandlestickChart._currentInstance == this) {
      CandlestickChart._currentInstance = null;
    }
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
    if (period == 750) {
      return Colors.cyan; // MA750のフォールバック色
    }
    return ChartConstants.maColors[period] ?? Colors.grey;
  }

  /// 移動平均線の説明を取得
  String _getMaDescription(int period) {
    if (period == 750) {
      return '超長期トレンド指標'; // MA750のフォールバック説明
    }
    return ChartConstants.maDescriptions[period] ?? '移動平均線';
  }

  /// 縦線描画モードを切り替え
  void _toggleVerticalLineMode() {
    setState(() {
      _resetDrawingSession(clearTool: true);
      _controller.toggleVerticalLineMode();
    });
  }

  void _setDrawingTool(DrawingTool tool) {
    setState(() {
      _activeDrawingTool = tool;
      _resetDrawingSession();
      if (tool != DrawingTool.none && _controller.isVerticalLineMode) {
        _controller.toggleVerticalLineMode();
      }
      if (tool == DrawingTool.none) {
        _clearObjectSelection();
      }
    });
  }

  /// ウェーブポイント表示を切り替え
  void _toggleWavePointsVisibility() {
    setState(() {
      _controller.toggleWavePointsVisibility();
    });
  }

  /// 布林通道表示切り替え
  void _toggleBollingerBandsVisibility() {
    setState(() {
      _controller.setBollingerBandsVisible(!_controller.isBollingerBandsVisible);
    });
  }

  /// 布林通道设置对话框を表示
  void _showBollingerBandsSettings() {
    showDialog(
      context: context,
      builder: (context) => BollingerBandsSettingsDialog(
        currentPeriod: _controller.bbPeriod,
        currentStdDev: _controller.bbStdDev,
        currentColors: _controller.bbColors.map((key, value) => MapEntry(key, '0x${value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}')),
        currentAlphas: _controller.bbAlphas,
        onSettingsChanged: (period, stdDev, colors, alphas) {
          setState(() {
            _controller.setBBPeriod(period);
            _controller.setBBStdDev(stdDev);
            _controller.setBBColors(
              upperColor: Color(int.parse(colors['upper'] ?? '0xFF2196F3')),
              middleColor: Color(int.parse(colors['middle'] ?? '0xFFFF9800')),
              lowerColor: Color(int.parse(colors['lower'] ?? '0xFF2196F3')),
            );
            _controller.setBBAlphas(
              upperAlpha: alphas['upper'],
              middleAlpha: alphas['middle'],
              lowerAlpha: alphas['lower'],
            );
          });
        },
      ),
    );
  }

  bool _isDoubleTap(Offset localPosition, DateTime now) {
    return _lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500 &&
        (localPosition - _lastTapPosition!).distance < 10;
  }

  void _recordTap(Offset localPosition, DateTime now) {
    _lastTapTime = now;
    _lastTapPosition = localPosition;
  }

  void _resetTapTracking() {
    _lastTapTime = null;
    _lastTapPosition = null;
  }

  double get _chartBodyHeight => (widget.height - 80).clamp(1.0, double.infinity);

  double _resolveChartWidth() {
    return _lastWidth > 0 ? _lastWidth : MediaQuery.of(context).size.width;
  }

  _ChartGeometry _resolveChartGeometry() {
    return _ChartGeometry(width: _resolveChartWidth(), height: _chartBodyHeight);
  }

  bool _handleChartDoubleTap({
    required bool isDoubleClick,
    required double chartX,
    required double chartY,
    required double chartWidth,
    required double chartHeight,
  }) {
    if (!isDoubleClick) return false;

    if (_activeDrawingTool != DrawingTool.none) {
      _handleDrawingTap(chartX, chartY, chartWidth, chartHeight, true);
    } else {
      _handleDoubleClick(chartX, chartY, chartWidth, chartHeight);
    }

    _resetTapTracking();
    return true;
  }

  bool _handleChartTapInDrawingOrSelectionModes({
    required TapUpDetails details,
    required double chartX,
    required double chartY,
    required double chartWidth,
    required double chartHeight,
    required bool isDoubleClick,
  }) {
    if (_activeDrawingTool != DrawingTool.none) {
      _handleDrawingTap(chartX, chartY, chartWidth, chartHeight, isDoubleClick);
      return true;
    }

    if (_handleObjectTapPriority(chartX, chartY, chartWidth, chartHeight)) {
      _resetTapTracking();
      return true;
    }

    if (_controller.isKlineCountMode && details.kind == PointerDeviceKind.mouse) {
      try {
        final selection = _controller.findKlineSelectionAtPosition(chartX, chartWidth);
        if (selection != null) {
          return true;
        }
      } catch (_) {
      }
    }

    if (_controller.isVerticalLineMode) {
      Log.debug('ChartInteraction', 'マウスクリック: globalPosition=${details.globalPosition}, localPosition=${details.localPosition}');
      Log.debug('ChartInteraction', 'チャートサイズ: width=$chartWidth, height=$chartHeight');
      Log.debug('ChartInteraction', '計算されたチャートX座標: $chartX');
      _addVerticalLineAtPosition(chartX, chartWidth);
      return true;
    }

    return false;
  }

  /// チャートクリックイベントを処理
  void _onChartTap(TapUpDetails details) {
    if (_isRightClickDeleting) return; // 右クリック削除中は処理しない
    final Offset localPosition = details.localPosition;
    final double chartX = localPosition.dx;
    final double chartY = localPosition.dy;
    final geometry = _resolveChartGeometry();
    final double chartWidth = geometry.width;
    final double chartHeight = geometry.height;
    final now = DateTime.now();
    final isDoubleClick = _isDoubleTap(localPosition, now);

    if (_handleChartDoubleTap(
      isDoubleClick: isDoubleClick,
      chartX: chartX,
      chartY: chartY,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
    )) {
      return;
    }

    _recordTap(localPosition, now);

    if (!geometry.containsY(chartY)) {
      return;
    }

    if (_handleChartTapInDrawingOrSelectionModes(
      details: details,
      chartX: chartX,
      chartY: chartY,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      isDoubleClick: isDoubleClick,
    )) {
      return;
    }

    if (_hasSelectedObject) {
      setState(() {
        _clearObjectSelection();
      });
    }
  }

  void _handleDrawingTap(
    double chartX,
    double chartY,
    double chartWidth,
    double chartHeight,
    bool isDoubleClick,
  ) {
    final int index = _xToDataIndex(chartX, chartWidth);
    final double price = _yToPrice(chartY, chartHeight);

    if (_activeDrawingTool == DrawingTool.polyline) {
      if (isDoubleClick && _pendingPolylinePoints.length >= 2) {
        _finishPolylineDrawing();
        return;
      }
      setState(() {
        final anchor = CandleAnchor(index: index, price: price);
        _pendingPolylinePoints.add(anchor);
        _previewAnchor = anchor;
      });
      return;
    }

    if (_pendingDrawingStartAnchor == null) {
      setState(() {
        _pendingDrawingStartAnchor = CandleAnchor(index: index, price: price);
        _clearObjectSelection();
      });
      return;
    }

    final anchorStart = _pendingDrawingStartAnchor!;
    final anchorEnd = CandleAnchor(index: index, price: price);
    final int uniqueId = DateTime.now().microsecondsSinceEpoch;

    setState(() {
      final ChartObject? object = Layer3DrawingObjectBuilder.createDrawingObject(
        tool: _activeDrawingTool,
        start: anchorStart,
        end: anchorEnd,
        uniqueId: uniqueId,
      );
      if (object != null) {
        _addDrawingObject(object);
      }

      _completeSingleDrawCycle();
    });
  }

  void _addDrawingObject(ChartObject object) {
    _layer3DrawingManager.addDrawingObject(object);
    if (object is TrendLineObject) {
      _selectedObjectId = object.id;
      _selectedObjectType = TrendLineObject;
    }
  }

  void _finishPolylineDrawing() {
    if (_pendingPolylinePoints.length < 2) return;
    final int uniqueId = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _layer3DrawingManager.addDrawingObject(
        Layer3DrawingObjectBuilder.createPolylineObject(
          points: List<CandleAnchor>.from(_pendingPolylinePoints),
          uniqueId: uniqueId,
        ),
      );
      _completeSingleDrawCycle();
    });
  }

  bool _handleObjectTapPriority(
    double chartX,
    double chartY,
    double chartWidth,
    double chartHeight,
  ) {
    final dragHit = _hitTestObject(chartX, chartY, chartWidth, chartHeight);

    if (dragHit != null) {
      setState(() {
        _applyObjectSelectionHit(dragHit);
      });
      return true;
    }

    return false;
  }

  int _xToDataIndex(double x, double chartWidth) {
    final double unit = (_controller.candleWidth * _controller.scale) + _controller.spacing;
    if (unit <= 0 || widget.data.isEmpty) return 0;
    final double rightEdge = chartWidth - _controller.emptySpaceWidth;
    final double rawIndex = _controller.endIndex - 0.5 - (rightEdge - x) / unit;
    return _clampDataIndex(rawIndex.round());
  }

  double _yToPrice(double y, double chartHeight) {
    final double minPrice = _getMinPrice();
    final double maxPrice = _getMaxPrice();
    final double priceRange = (maxPrice - minPrice).abs();
    if (priceRange < 0.0000001) return maxPrice;
    final double normalized = (y / chartHeight).clamp(0.0, 1.0);
    return maxPrice - normalized * (maxPrice - minPrice);
  }

  ObjectHitResult? _hitTestObject(
    double x,
    double y,
    double chartWidth,
    double chartHeight,
  ) {
    return ChartObjectInteractionService.hitTest(
      objects: _buildObjectStickers(),
      x: x,
      y: y,
      endIndex: _controller.endIndex,
      candleWidth: _controller.candleWidth,
      scale: _controller.scale,
      spacing: _controller.spacing,
      emptySpaceWidth: _controller.emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: _getMinPrice(),
      maxPrice: _getMaxPrice(),
    );
  }

  int get _maxDataIndex => widget.data.isEmpty ? 0 : widget.data.length - 1;

  int _clampDataIndex(int index) => index.clamp(0, _maxDataIndex);

  void _updateDraggingObject(Offset localPosition, double chartWidth, double chartHeight) {
    final String? id = _draggingObjectId;
    final Type? objectType = _draggingObjectType;
    final ObjectDragTarget? target = _draggingObjectTarget;
    if (id == null || objectType == null || target == null) return;

    final int newIndex = _xToDataIndex(localPosition.dx, chartWidth);
    final double newPrice = _yToPrice(localPosition.dy, chartHeight);

    final Offset? previous = _lastDragPosition;
    final double unit = (_controller.candleWidth * _controller.scale) + _controller.spacing;
    final double dx = previous == null ? 0 : localPosition.dx - previous.dx;
    final double dy = previous == null ? 0 : localPosition.dy - previous.dy;
    final int indexDelta = (previous == null || unit <= 0.0000001) ? 0 : (dx / unit).round();

    final double minPrice = _getMinPrice();
    final double maxPrice = _getMaxPrice();
    final double priceRange = (maxPrice - minPrice).abs();
    final double pricePerPixel = chartHeight <= 0.0000001 ? 0 : (priceRange / chartHeight);
    final double priceDelta = previous == null ? 0 : (-dy * pricePerPixel);

    setState(() {
      _layer3DrawingManager.updateObjectDuringDrag(
        id: id,
        objectType: objectType,
        target: target,
        newIndex: newIndex,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: _clampDataIndex,
      );

      _lastDragPosition = localPosition;
    });
  }

  List<ChartObject> _buildObjectStickers() {
    final objects = _buildLayer2AndSystemObjects();
    _appendLayer3UserDrawings(objects);
    _appendPreviewObjects(objects);
    return objects;
  }

  // --- Object Build/Preview Pipeline ---

  List<ChartObject> _buildLayer2AndSystemObjects() {
    final objects = ChartObjectFactory.build(
      controller: _controller,
      trendLines: _trendLines,
      selectedTrendLineId: _selectedTrendLineId,
      includeTrendFiltering: widget.isTrendFilteringEnabled ?? false,
      includeFibonacciForSelectedTrendLine: false,
    );
    return objects;
  }

  void _appendLayer3UserDrawings(List<ChartObject> objects) {
    _layer3DrawingManager.appendLayer3UserDrawings(objects);
  }

  void _appendPreviewObjects(List<ChartObject> objects) {
    final CandleAnchor? start = _pendingDrawingStartAnchor;
    final CandleAnchor? preview = _previewAnchor;

    if (start != null && preview != null) {
      final ChartObject? toolPreview = Layer3DrawingObjectBuilder.createToolPreviewObject(
        tool: _activeDrawingTool,
        start: start,
        preview: preview,
      );
      if (toolPreview != null) {
        objects.add(toolPreview);
      }
    }

    final ChartObject? polylinePreview = Layer3DrawingObjectBuilder.createPolylinePreviewObject(
      tool: _activeDrawingTool,
      pendingPoints: _pendingPolylinePoints,
      preview: preview,
    );
    if (polylinePreview != null) {
      objects.add(polylinePreview);
    }
  }

  bool _removeObjectByTypeAndId(Type objectType, String id) {
    return _layer3DrawingManager.removeByTypeAndId(objectType, id);
  }

  void _adjustSelectedTrendLineLength(double factor) {
    final String? id = _selectedTrendLineId;
    if (id == null) return;
    setState(() {
      _layer3DrawingManager.adjustTrendLineLengthById(
        id: id,
        factor: factor,
        clampDataIndex: _clampDataIndex,
      );
    });
  }

  void _adjustSelectedTrendLineAngle(double deltaDegrees) {
    final String? id = _selectedTrendLineId;
    if (id == null) return;
    setState(() {
      _layer3DrawingManager.adjustTrendLineAngleById(
        id: id,
        deltaDegrees: deltaDegrees,
        clampDataIndex: _clampDataIndex,
      );
    });
  }

  void _deleteSelectedObject() {
    final String? id = _selectedObjectId;
    final Type? objectType = _selectedObjectType;
    if (id == null || objectType == null) return;

    setState(() {
      _removeObjectByTypeAndId(objectType, id);

      _clearObjectSelection();
      _clearPendingDrawingStart();
    });
  }

  /// 指定位置に縦線を追加
  void _addVerticalLineAtPosition(double x, double chartWidth) async {
    await _controller.addVerticalLineAtPosition(x, chartWidth);
    _refreshUI();
  }

  /// ダブルクリック処理：手動高低点の追加/削除
  void _handleDoubleClick(double chartX, double chartY, double chartWidth, double chartHeight) async {
    final double minPrice = _getMinPrice();
    final double maxPrice = _getMaxPrice();
    
    Log.info('ManualHighLow', 'ダブルクリック検出 - 位置: ($chartX, $chartY), 価格範囲: $minPrice - $maxPrice');
    
    // 手動高低点の追加/削除を実行
    await _controller.toggleManualHighLowPointAtPosition(chartX, chartY, chartWidth, chartHeight, minPrice, maxPrice);

    _refreshUI();
  }

  /// すべての縦線をクリア
  void _clearAllVerticalLines() async {
    await _controller.clearAllVerticalLines();
    _refreshUI();
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

  /// 导航到指定索引
  void navigateToIndex(int index) {
    _controller.navigateToIndex(index);
  }

  /// 导航到指定时间戳
  void navigateToTimestamp(int timestamp) {
    _controller.navigateToTimestamp(timestamp);
  }

  /// 导航到开始位置
  void navigateToStart() {
    _controller.navigateToStart();
  }

  /// 导航到结束位置
  void navigateToEnd() {
    _controller.navigateToEnd();
  }

}
