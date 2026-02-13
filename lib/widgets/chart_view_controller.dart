import 'dart:async';

import '../constants/chart_constants.dart';
import '../models/price_data.dart';
import '../services/csv_data_service.dart';
import '../services/dukascopy_download_service.dart';
import '../services/timeframe_data_service.dart';
import '../services/log_service.dart';
import '../models/timeframe.dart';
import '../models/trading_pair.dart';
import '../controllers/vertical_line_controller.dart';
import '../controllers/kline_selection_controller.dart';
import '../controllers/moving_average_controller.dart';
import '../controllers/chart_zoom_controller.dart';
import '../controllers/wave_points_controller.dart';
import '../controllers/manual_high_low_controller.dart';
import '../controllers/bollinger_bands_controller.dart';
import '../services/trend_filtering_service.dart';
import '../services/bollinger_bands_filtering_service.dart';

/// Mixin制約を満たすための抽象基底クラス
abstract class _ChartControllerBase implements 
    VerticalLineControllerHost, 
    KlineSelectionControllerHost, 
    ChartZoomControllerHost,
    WavePointsControllerHost,
    ManualHighLowControllerHost,
    MovingAverageControllerHost,
    BollingerBandsControllerHost {
  
  /// UI の更新を通知する (サブクラスで実装する必要があります)
  @override
  void notifyUIUpdate();
  @override
  List<PriceData> get data;
  
  @override
  int get startIndex;
  
  @override
  int get endIndex;
  
  @override
  set startIndex(int value);
  
  @override
  set endIndex(int value);
  
  @override
  double get scale;
  
  @override
  set scale(double value);
  
  @override
  double get candleWidth;
  
  @override
  double get spacing;
  
  @override
  double get emptySpaceWidth;
  
  @override
  double get totalCandleWidth;
  
  @override
  int getCandleIndexFromX(double x, double chartWidth);
}

class ChartViewController extends _ChartControllerBase
    with 
    MovingAverageControllerMixin, 
    VerticalLineControllerMixin, 
    KlineSelectionControllerMixin,
    ChartZoomControllerMixin,
    WavePointsControllerMixin,
    ManualHighLowControllerMixin,
    BollingerBandsControllerMixin {
  
  // --- Configuration ---
  @override
  List<PriceData> data;
  
  @override
  final double candleWidth = ChartConstants.defaultCandleWidth;
  
  @override
  final double spacing = ChartConstants.defaultSpacing;
  
  @override
  final double emptySpaceWidth = ChartConstants.defaultEmptySpaceWidth;
  
  final double minScale = ChartConstants.minScale;
  final double maxScale = ChartConstants.maxScale;

  // --- State ---
  @override
  int startIndex = 0;
  
  @override
  int endIndex = 0;
  
  @override
  double scale = 1.0;

  double? _recordedScale;
  int? _recordedStartIndex;
  int? _recordedEndIndex;
  
  bool _isLoadingData = false;
  
  // UI更新回调函数
  Function()? _onUIUpdate;
  
  // 数据限制
  int? _klineDataLimit;
  
  // 时间周期和交易对
  Timeframe? _selectedTimeframe;
  TradingPair? _selectedTradingPair;

  // トレンドフィルタリング関連
  bool _isTrendFilteringEnabled = false;
  double _trendFilteringThreshold = 0.005; // デフォルト0.5%
  double _trendFilteringNearThreshold = 0.01; // デフォルト1%
  double _trendFilteringFarThreshold = 0.02; // デフォルト2%
  int _trendFilteringMinGapBars = 5; // デフォルト5バー
  FilteredWavePoints? _filteredWavePoints;

  // 布林线过滤曲线関連
  bool _isBollingerBandsFilteredCurveVisible = false;
  BollingerBandsFilteredCurveResult? _bollingerBandsFilteredCurveResult;

  int get dataLength => data.length;
  
  // 当前时间周期
  String _currentTimeframe = '5m'; // 默认5分钟
  
  @override
  String get currentTimeframe => _currentTimeframe;
  
  void setTimeframe(String timeframe) {
    _currentTimeframe = timeframe;
    Log.info('ChartViewController', '时间周期设置为: $timeframe');
  }

  /// 记录当前渲染视图状态（缩放比例与绘制起点）
  void recordCurrentViewState() {
    _recordedScale = scale;
    _recordedStartIndex = startIndex;
    _recordedEndIndex = endIndex;
  }

  ChartViewController({
    required this.data, 
    Function()? onUIUpdate, 
    int? klineDataLimit,
    Timeframe? selectedTimeframe,
    TradingPair? selectedTradingPair,
  }) {
    _onUIUpdate = onUIUpdate;
    _klineDataLimit = klineDataLimit;
    _selectedTimeframe = selectedTimeframe;
    _selectedTradingPair = selectedTradingPair;
    
    if (data.isNotEmpty) {
      // 最新のK線が右端に表示されるように初期化
      endIndex = data.length;
      startIndex = (endIndex - 200).clamp(0, data.length);
      
      initMovingAverages(data);
      initVerticalLines();
      initKlineSelections();
      initWavePoints();
      initManualHighLowPoints();
      initBollingerBands(data);
    }
  }
  
  /// 移動平均線可視性設定を適用
  @override
  void applyMaVisibilitySettings(Map<int, bool> visibilitySettings) {
    // Mixinのメソッドを呼び出し
    super.applyMaVisibilitySettings(visibilitySettings);
  }

  @override
  void toggleVerticalLineMode() {
    // 縦線モードに入る場合、まずK線統計モードを終了することを保証
    if (!isVerticalLineMode) {
      if (isKlineCountMode) {
        isKlineCountMode = false;
        clearSelection();
      }
    }
    isVerticalLineMode = !isVerticalLineMode;
  }

  void toggleKlineCountMode() {
    // K線統計モードに入る場合、まず縦線モードを終了することを保証
    if (!isKlineCountMode) {
      if (isVerticalLineMode) {
        isVerticalLineMode = false;
      }
    }
    isKlineCountMode = !isKlineCountMode;
    if (!isKlineCountMode) {
      clearSelection();
    }
  }

  /// データを更新する（デフォルトで現在の表示位置と縮尺を維持）
  void updateData(List<PriceData> newData, {bool preserveView = true}) {
    final double baseScale = _recordedScale ?? scale;
    final int baseStartIndex = _recordedStartIndex ?? startIndex;
    final int baseEndIndex = _recordedEndIndex ?? endIndex;

    final int oldLength = data.length;
    final int oldStartIndex = baseStartIndex;
    final int oldEndIndex = baseEndIndex;
    final int oldVisibleCandles = (oldEndIndex - oldStartIndex).clamp(1, 1000000);
    final bool wasFollowingLatest = oldEndIndex >= oldLength;

    data = newData;

    if (data.isEmpty) {
      startIndex = 0;
      endIndex = 0;
      return;
    }

    // 移動平均線を再計算
    onDataUpdatedForMA(data);
    // 波浪点を再計算
    onDataUpdatedForWavePoints();
    // 布林通道を再計算
    onDataUpdatedForBB(data);

    if (!preserveView) {
      // 大量データの場合は表示範囲を制限
      const int maxDataLimit = ChartConstants.maxDataLimit;
      if (data.length > maxDataLimit) {
        endIndex = data.length;
        startIndex = data.length - maxDataLimit;
      } else {
        endIndex = data.length;
        startIndex = 0;
      }
      return;
    }

    // 保持缩放比例
    scale = baseScale;

    // 静默更新：保持当前窗口；若原本跟随最新K线，则继续跟随最新
    int newStartIndex = oldStartIndex;
    int newEndIndex = oldEndIndex;
    final int lengthDelta = data.length - oldLength;

    if (wasFollowingLatest && lengthDelta != 0) {
      newStartIndex += lengthDelta;
      newEndIndex += lengthDelta;
    }

    if (newEndIndex <= 0) {
      newEndIndex = data.length;
    }

    if (newStartIndex < 0) {
      newStartIndex = 0;
    }

    if (newStartIndex >= data.length) {
      newEndIndex = data.length;
      newStartIndex = (newEndIndex - oldVisibleCandles).clamp(0, data.length - 1);
    }

    if (newEndIndex <= newStartIndex) {
      newEndIndex = (newStartIndex + 1).clamp(1, data.length);
    }

    startIndex = newStartIndex;
    endIndex = newEndIndex;

    // 更新一次记录，供下一次重绘/刷新使用
    recordCurrentViewState();
  }

  @override
  double get totalCandleWidth => (candleWidth * scale) + spacing;

  @override
  Map<int, List<double?>> getMovingAveragesData() {
    Map<int, List<double?>> maData = {};
    for (int period in maPeriods) {
      final List<double>? ma = getMovingAverage(period);
      if (ma != null) {
        maData[period] = ma.cast<double?>();
      }
    }
    return maData;
  }

  PriceData? getCandleAtX(double dx, double chartWidth) {
    if (data.isEmpty) return null;

    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    
    // ポインターがキャンドルの描画可能領域内にあるかチェック
    if (dx < 0 || dx > candleDrawingWidth) {
      return null;
    }

    final int visibleCandles = endIndex - startIndex;
    if (visibleCandles <= 0) return null;

    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    final double relativeX = dx - startX;
    final int candleIndexOffset = (relativeX / totalCandleWidth).floor();
    final int dataIndex = startIndex + candleIndexOffset;

    if (dataIndex >= 0 && dataIndex < data.length) {
      return data[dataIndex];
    }
    return null;
  }

  double getPriceAtY(double dy, double chartHeight, double minPrice, double maxPrice) {
    if (maxPrice == minPrice) return minPrice;
    final double priceRange = maxPrice - minPrice;
    // dy is from top, so we need to invert it.
    final double normalizedY = (chartHeight - dy) / chartHeight;
    return minPrice + (normalizedY * priceRange);
  }

  /// dukascopy-nodeでデータをダウンロードして読み込む
  Future<void> downloadAndLoadData() async {
    if (_isLoadingData) {
      LogService.instance.warning('ChartViewController', '数据正在加载中，跳过本次下载');
      return;
    }
    
    _isLoadingData = true;
    LogService.instance.info('ChartViewController', '=== 开始下载和加载数据 ===');
    
    // 记录下载前的最新K线时间戳
    DateTime? beforeLatestTime;
    if (data.isNotEmpty) {
      beforeLatestTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
      LogService.instance.info('ChartViewController', '下载前UI最新K线时间: $beforeLatestTime');
    } else {
      LogService.instance.info('ChartViewController', '下载前UI无数据');
    }
    
    try {
      // 从CSV文件获取最新K線の日付
      DateTime? downloadStartDate;
      
      // 直接从CSV文件获取最新日期，不应用任何数据限制
      LogService.instance.info('ChartViewController', '从CSV文件获取最新K线日期...');
      final timeframe = _selectedTimeframe ?? Timeframe.m5;
      final tradingPair = _selectedTradingPair ?? TradingPair.eurusd;
      final directoryName = timeframe.getDirectoryName(tradingPair);
      final csvFiles = await CsvDataService.findCsvFiles(directoryName);
      
      DateTime? csvLatestTime;
      if (csvFiles.isNotEmpty) {
        // 直接从CSV文件读取所有数据，不应用限制
        final allCsvData = await CsvDataService.loadFromMultipleCsvs(csvFiles, klineDataLimit: null);
        if (allCsvData.isNotEmpty) {
          csvLatestTime = CsvDataService.getLatestCandleTime(allCsvData);
          if (csvLatestTime != null) {
            LogService.instance.info('ChartViewController', 'CSV文件最新K线时间: $csvLatestTime');
            LogService.instance.info('ChartViewController', 'CSV文件总数据量: ${allCsvData.length}件');
            
            if (allCsvData.isNotEmpty) {
              final firstTime = DateTime.fromMillisecondsSinceEpoch(allCsvData.first.timestamp, isUtc: true);
              final lastTime = DateTime.fromMillisecondsSinceEpoch(allCsvData.last.timestamp, isUtc: true);
              LogService.instance.info('ChartViewController', 'CSV文件完整数据范围: $firstTime ～ $lastTime');
            }
          }
        }
      }
      
      // 计算下载开始日期
      LogService.instance.info('ChartViewController', '=== 下载逻辑 ===');
      LogService.instance.info('ChartViewController', 'CSV最新K线时间: $csvLatestTime');
      
      if (csvLatestTime != null) {
        // 从CSV最新时间的下一天开始下载
        final csvLatestDate = DateTime.utc(csvLatestTime.year, csvLatestTime.month, csvLatestTime.day);
        downloadStartDate = csvLatestDate.add(const Duration(days: 0));
        LogService.instance.info('ChartViewController', '从CSV最新日期的下一天开始下载');
        LogService.instance.info('ChartViewController', '下载开始日期: $downloadStartDate');
      } else {
        // CSV文件没有数据，从今天开始下载
        final now = DateTime.now().toUtc();
        final todayDate = DateTime.utc(now.year, now.month, now.day);
        downloadStartDate = todayDate;
        LogService.instance.info('ChartViewController', 'CSV文件没有数据，从今天开始下载: $downloadStartDate');
      }
      
      // 从下一天开始下载7日分のデータをダウンロードし、他の時間周期CSVを自動マージ生成
      LogService.instance.info('ChartViewController', '从下一天开始下载7天数据: $downloadStartDate');
      await DukascopyDownloadService.downloadAndMergeData(downloadStartDate, 7, tradingPair: _selectedTradingPair ?? TradingPair.eurusd);
      
      LogService.instance.info('ChartViewController', '数据下载和CSV生成完成');
      
      // 下载完成后，重新从CSV文件加载所有数据
      LogService.instance.info('ChartViewController', '重新从CSV文件加载所有数据...');
      final beforeDataCount = data.length;
      LogService.instance.info('ChartViewController', '重新加载前数据量: $beforeDataCount');
      
      // 重新加载数据
      final reloadedData = await TimeframeDataService.loadDataForTimeframe(
        _selectedTimeframe ?? Timeframe.m5, 
        tradingPair: _selectedTradingPair ?? TradingPair.eurusd,
        klineDataLimit: _klineDataLimit,
      );
      
      LogService.instance.info('ChartViewController', '重新加载完成，获得数据: ${reloadedData.length}条');
      
      if (reloadedData.isNotEmpty) {
        // 更新数据
        data = reloadedData;
        
        // 基于时间戳判断是否有新数据
        final newLatestTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
        final afterDataCount = data.length;
        
        LogService.instance.info('ChartViewController', '重新加载后数据量: $afterDataCount');
        LogService.instance.info('ChartViewController', '下载前UI最新K线时间: $beforeLatestTime');
        LogService.instance.info('ChartViewController', '下载后UI最新K线时间: $newLatestTime');
        
        // 判断是否有新数据
        bool hasNewData = false;
        if (beforeLatestTime == null) {
          hasNewData = true;
          LogService.instance.info('ChartViewController', '首次加载数据，视为有新数据');
        } else if (newLatestTime.isAfter(beforeLatestTime)) {
          hasNewData = true;
          LogService.instance.info('ChartViewController', '检测到新K线数据: $beforeLatestTime -> $newLatestTime');
        } else {
          LogService.instance.info('ChartViewController', '没有新K线数据: 最新时间未变化');
        }
        
        if (hasNewData) {
          LogService.instance.info('ChartViewController', '下载完成，有新K线数据，总数据量: $afterDataCount条');
        } else {
          LogService.instance.info('ChartViewController', '下载完成，无新K线数据，总数据量: $afterDataCount条');
        }
        
        // 移動平均線を再計算
        onDataUpdatedForMA(data);
        // ウェーブポイントを再計算
        onDataUpdatedForWavePoints();
        // 布林通道を再計算
        onDataUpdatedForBB(data);
        
        // 应用klineDataLimit限制（如果设置了的话）
        LogService.instance.info('ChartViewController', '检查数据限制: klineDataLimit=$_klineDataLimit, 当前数据量=${data.length}');
        
        if (_klineDataLimit != null && _klineDataLimit! > 0 && data.length > _klineDataLimit!) {
          LogService.instance.info('ChartViewController', '应用数据限制: ${data.length} -> $_klineDataLimit (取最新数据)');
          
          // 始终取最新的K线数据
          final int startIndex = data.length - _klineDataLimit!;
          data = data.sublist(startIndex);
          
          LogService.instance.info('ChartViewController', '数据限制应用后: ${data.length}条');
          if (data.isNotEmpty) {
            final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
            final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
            LogService.instance.info('ChartViewController', '限制后数据时间范围: $firstTime ～ $lastTime');
          }
        } else {
          LogService.instance.info('ChartViewController', '数据限制条件不满足: klineDataLimit=$_klineDataLimit, data.length=${data.length}');
        }
        
        // 表示範囲を調整（最新データを表示、大量データの場合は最後の制限件数を表示）
        const int maxDataLimit = ChartConstants.maxDataLimit;
        
        // 大量データの場合は最後の1万件を表示
        if (data.length > maxDataLimit) {
          endIndex = data.length;
          startIndex = data.length - maxDataLimit;
        } else {
          // データ数が制限以下の場合は全データを表示
          endIndex = data.length;
          if (startIndex >= data.length) {
            startIndex = 0;
          }
        }
        
        // データの連続性を確認
        if (data.length >= 2) {
          final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
          final secondLastTime = DateTime.fromMillisecondsSinceEpoch(data[data.length - 2].timestamp, isUtc: true);
          final timeDiff = lastTime.difference(secondLastTime);
          
          // 時間の連続性をチェック
          if (timeDiff.inMinutes > 5) {
            Log.warning('ChartViewController', '警告: K線時間に${timeDiff.inMinutes}分のギャップがあります');
          }
        }
      }
    } catch (e) {
      Log.error('ChartViewController', 'データダウンロードエラー: $e');
    } finally {
      _isLoadingData = false;
    }
  }

  /// データ読み込み中かどうか
  bool get isLoadingData => _isLoadingData;
  
  /// X座標からK線インデックスを計算
  @override
  int getCandleIndexFromX(double x, double chartWidth) {
    if (data.isEmpty) return -1;
    
    // スケールを考慮したK線の幅と間隔
    final double scaledCandleWidth = candleWidth * scale;
    final double totalWidth = scaledCandleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    
    // 右端から左に向かってK線を配置（右端が原点）
    final double rightEdgeX = candleDrawingWidth;
    final double startX = rightEdgeX - (visibleCandles * totalWidth);

    // クリック位置がK線描画範囲内かチェック
    if (x < startX || x > rightEdgeX) {
      return -1; // 範囲外
    }

    // X座標から相対位置を計算
    final double relativeX = x - startX;
    final int indexInVisible = (relativeX / totalWidth).floor();
    
    // インデックスが有効範囲内かチェック
    if (indexInVisible < 0 || indexInVisible >= visibleCandles) {
      return -1;
    }
    
    final int candleIndex = startIndex + indexInVisible;
    
    // 最終的なインデックスがデータ範囲内かチェック
    if (candleIndex < 0 || candleIndex >= data.length) {
      return -1;
    }
    return candleIndex;
  }

  /// UI更新通知の実装
  @override
  void notifyUIUpdate() {
    _onUIUpdate?.call();
  }

  /// UI更新コールバックを設定する
  void setOnUIUpdate(Function()? callback) {
    _onUIUpdate = callback;
  }

  // ==================== トレンドフィルタリング関連 ====================

  /// トレンドフィルタリングが有効かどうか
  bool get isTrendFilteringEnabled => _isTrendFilteringEnabled;

  /// トレンドフィルタリング閾値
  double get trendFilteringThreshold => _trendFilteringThreshold;

  /// フィルタリングされた高低点データを取得
  FilteredWavePoints? get filteredWavePoints => _filteredWavePoints;

  /// トレンドフィルタリングを有効/無効にする
  void setTrendFilteringEnabled(bool enabled) {
    LogService.instance.info('ChartViewController', 'setTrendFilteringEnabled呼び出し: $enabled');
    
    if (_isTrendFilteringEnabled != enabled) {
      _isTrendFilteringEnabled = enabled;
      LogService.instance.info('ChartViewController', 'トレンドフィルタリング状態変更: ${enabled ? "有効" : "無効"}');
    } else {
      LogService.instance.info('ChartViewController', 'トレンドフィルタリング状態変更なし: $enabled');
    }
    
    // 状態に関係なく、有効な場合は常に更新を実行
    if (enabled) {
      LogService.instance.info('ChartViewController', 'トレンドフィルタリング強制更新実行');
      _updateFilteredWavePoints();
      notifyUIUpdate();
    }
  }

  /// トレンドフィルタリング閾値を設定
  void setTrendFilteringThreshold(double threshold) {
    if (_trendFilteringThreshold != threshold) {
      _trendFilteringThreshold = threshold;
      Log.info('ChartViewController', 'トレンドフィルタリング閾値: ${(threshold * 100).toStringAsFixed(2)}%');
      if (_isTrendFilteringEnabled) {
        _updateFilteredWavePoints();
        notifyUIUpdate();
      }
    }
  }

  /// トレンドフィルタリング近い距離閾値を設定
  void setTrendFilteringNearThreshold(double threshold) {
    if (_trendFilteringNearThreshold != threshold) {
      _trendFilteringNearThreshold = threshold;
      if (_isTrendFilteringEnabled) {
        _updateFilteredWavePoints();
        notifyUIUpdate();
      }
    }
  }

  /// トレンドフィルタリング遠い距離閾値を設定
  void setTrendFilteringFarThreshold(double threshold) {
    if (_trendFilteringFarThreshold != threshold) {
      _trendFilteringFarThreshold = threshold;
      if (_isTrendFilteringEnabled) {
        _updateFilteredWavePoints();
        notifyUIUpdate();
      }
    }
  }

  /// トレンドフィルタリング最低バー間隔を設定
  void setTrendFilteringMinGapBars(int minGapBars) {
    if (_trendFilteringMinGapBars != minGapBars) {
      _trendFilteringMinGapBars = minGapBars;
      if (_isTrendFilteringEnabled) {
        _updateFilteredWavePoints();
        notifyUIUpdate();
      }
    }
  }

  /// フィルタリングされた高低点を更新
  void _updateFilteredWavePoints() {
    LogService.instance.info('ChartViewController', '_updateFilteredWavePoints開始');
    LogService.instance.info('ChartViewController', 'isTrendFilteringEnabled: $_isTrendFilteringEnabled');
    LogService.instance.info('ChartViewController', 'wavePoints: ${wavePoints != null ? "存在" : "null"}');
    LogService.instance.info('ChartViewController', 'data.length: ${data.length}');
    
    if (!_isTrendFilteringEnabled) {
      LogService.instance.info('ChartViewController', 'トレンドフィルタリング無効、_filteredWavePointsをnullに設定');
      _filteredWavePoints = null;
      return;
    }
    
    // wavePointsがnullの場合は計算を試行
    if (wavePoints == null) {
      LogService.instance.info('ChartViewController', 'wavePointsがnull、計算を試行');
      onDataUpdatedForWavePoints();
      
      if (wavePoints == null) {
        LogService.instance.warning('ChartViewController', 'wavePoints計算後もnull、_filteredWavePointsをnullに設定');
        _filteredWavePoints = null;
        return;
      }
    }

    try {
      LogService.instance.info('ChartViewController', '移動平均データ取得開始');
      final maData = getMovingAveragesData();
      LogService.instance.info('ChartViewController', '移動平均データ取得完了: ${maData.keys.toList()}');
      
      final ma150Series = maData[150];
      LogService.instance.info('ChartViewController', '150均線データ: ${ma150Series != null ? "存在" : "null"}');
      
      if (ma150Series == null || ma150Series.isEmpty) {
        LogService.instance.warning('ChartViewController', '150均線データが利用できません');
        _filteredWavePoints = null;
        return;
      }

      LogService.instance.info('ChartViewController', 'トレンドフィルタリング実行開始');
      LogService.instance.info('ChartViewController', '元の高低点: ${wavePoints!.mergedPoints.length}個');
      LogService.instance.info('ChartViewController', '閾値: ${(_trendFilteringThreshold * 100).toStringAsFixed(2)}%');
      
      _filteredWavePoints = TrendFilteringService.instance.filterByMA150(
        wavePoints!,
        data,
        ma150Series,
        nearThreshold: _trendFilteringNearThreshold,
        farThreshold: _trendFilteringFarThreshold,
        minGapBars: _trendFilteringMinGapBars,
      );

      LogService.instance.info('ChartViewController', 
        'フィルタリング完了: 元${wavePoints!.mergedPoints.length}個 → フィルタ後${_filteredWavePoints!.totalFilteredPoints}個 (フィルタ率${(_filteredWavePoints!.filteringRate * 100).toStringAsFixed(1)}%)');
      LogService.instance.info('ChartViewController', 'トレンドライン数: ${_filteredWavePoints!.trendLines.length}本');
      LogService.instance.info('ChartViewController', '滑らかな折線: ${_filteredWavePoints!.smoothTrendLine != null ? "存在" : "null"}');
    } catch (e) {
      LogService.instance.error('ChartViewController', 'トレンドフィルタリング失敗: $e');
      _filteredWavePoints = null;
    }
  }

  /// 動的閾値を計算して設定
  void calculateAndSetDynamicThreshold() {
    try {
      final maData = getMovingAveragesData();
      final ma150Series = maData[150];
      
      if (ma150Series == null || ma150Series.isEmpty) {
        Log.warning('ChartViewController', '150均線データが利用できません');
        return;
      }

      final dynamicThreshold = TrendFilteringService.instance.calculateDynamicThreshold(
        data,
        ma150Series,
      );

      setTrendFilteringThreshold(dynamicThreshold);
    } catch (e) {
      Log.error('ChartViewController', '動的閾値計算失敗: $e');
    }
  }

  /// 导航到指定索引
  void navigateToIndex(int targetIndex) {
    if (data.isEmpty || targetIndex < 0 || targetIndex >= data.length) {
      LogService.instance.warning('ChartViewController', '无效的导航索引: $targetIndex');
      return;
    }

    // 使用当前显示范围来计算可见K线数量
    final int currentVisibleCandles = endIndex - startIndex;
    final int visibleCandles = currentVisibleCandles > 0 ? currentVisibleCandles : 100; // 默认100个K线
    
    // 计算目标索引应该显示在图表中心
    final int centerOffset = visibleCandles ~/ 2;
    int newStartIndex = targetIndex - centerOffset;
    int newEndIndex = targetIndex + centerOffset;
    
    // 边界检查 - 确保不超出数据范围
    if (newStartIndex < 0) {
      newStartIndex = 0;
      newEndIndex = (newStartIndex + visibleCandles).clamp(0, data.length);
    }
    
    if (newEndIndex > data.length) {
      newEndIndex = data.length;
      newStartIndex = (newEndIndex - visibleCandles).clamp(0, data.length);
    }
    
    // 最终边界检查
    if (newStartIndex < 0) newStartIndex = 0;
    if (newEndIndex > data.length) newEndIndex = data.length;
    if (newEndIndex <= newStartIndex) {
      newStartIndex = 0;
      newEndIndex = visibleCandles.clamp(0, data.length);
    }
    
    startIndex = newStartIndex;
    endIndex = newEndIndex;
    
    LogService.instance.info('ChartViewController', '导航到索引: $targetIndex, 显示范围: $startIndex - $endIndex, 可见K线: $visibleCandles');
    notifyUIUpdate();
  }

  /// 设置鼠标位置缩放
  @override
  void setMousePositionZoomEnabled(bool enabled) {
    super.setMousePositionZoomEnabled(enabled);
  }

  /// 导航到指定时间戳
  void navigateToTimestamp(int timestamp) {
    if (data.isEmpty) {
      LogService.instance.warning('ChartViewController', '没有数据可导航');
      return;
    }

    // 查找最接近的时间戳
    int closestIndex = 0;
    int minDifference = (timestamp - data[0].timestamp).abs();
    
    for (int i = 1; i < data.length; i++) {
      final difference = (timestamp - data[i].timestamp).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestIndex = i;
      }
    }
    
    navigateToIndex(closestIndex);
  }

  /// 导航到开始位置
  void navigateToStart() {
    if (data.isEmpty) return;
    
    // 使用当前显示范围来计算可见K线数量
    final int currentVisibleCandles = endIndex - startIndex;
    final int visibleCandles = currentVisibleCandles > 0 ? currentVisibleCandles : 100;
    
    // 从开始位置显示
    startIndex = 0;
    endIndex = visibleCandles.clamp(0, data.length);
    
    LogService.instance.info('ChartViewController', '导航到开始位置, 显示范围: $startIndex - $endIndex');
    notifyUIUpdate();
  }

  /// 导航到结束位置
  void navigateToEnd() {
    if (data.isEmpty) return;
    
    // 使用当前显示范围来计算可见K线数量
    final int currentVisibleCandles = endIndex - startIndex;
    final int visibleCandles = currentVisibleCandles > 0 ? currentVisibleCandles : 100;
    
    // 从结束位置显示
    endIndex = data.length;
    startIndex = (endIndex - visibleCandles).clamp(0, data.length);
    
    LogService.instance.info('ChartViewController', '导航到结束位置, 显示范围: $startIndex - $endIndex');
    notifyUIUpdate();
  }

  // ==================== 布林线过滤曲线関連 ====================

  /// 布林线过滤曲线が有効かどうか
  bool get isBollingerBandsFilteredCurveVisible => _isBollingerBandsFilteredCurveVisible;

  /// 布林线过滤曲线結果を取得
  BollingerBandsFilteredCurveResult? get bollingerBandsFilteredCurveResult => _bollingerBandsFilteredCurveResult;

  /// 布林线过滤曲线を有効/無効にする
  void setBollingerBandsFilteredCurveVisible(bool visible) {
    LogService.instance.info('ChartViewController', 'setBollingerBandsFilteredCurveVisible呼び出し: $visible');
    
    if (_isBollingerBandsFilteredCurveVisible != visible) {
      _isBollingerBandsFilteredCurveVisible = visible;
      LogService.instance.info('ChartViewController', '布林线过滤曲线状態変更: ${visible ? "有効" : "無効"}');
    } else {
      LogService.instance.info('ChartViewController', '布林线过滤曲线状態変更なし: $visible');
    }
    
    // 状態に関係なく、有効な場合は常に更新を実行
    if (visible) {
      LogService.instance.info('ChartViewController', '布林线过滤曲线強制更新実行');
      _updateBollingerBandsFilteredCurve();
      notifyUIUpdate();
    }
  }

  /// 布林线过滤曲线を更新
  void _updateBollingerBandsFilteredCurve() {
    LogService.instance.info('ChartViewController', '_updateBollingerBandsFilteredCurve開始');
    LogService.instance.info('ChartViewController', 'isBollingerBandsFilteredCurveVisible: $_isBollingerBandsFilteredCurveVisible');
    LogService.instance.info('ChartViewController', 'wavePoints: ${wavePoints != null ? "存在" : "null"}');
    LogService.instance.info('ChartViewController', 'data.length: ${data.length}');
    
    if (!_isBollingerBandsFilteredCurveVisible) {
      LogService.instance.info('ChartViewController', '布林线过滤曲线無効、_bollingerBandsFilteredCurveResultをnullに設定');
      _bollingerBandsFilteredCurveResult = null;
      return;
    }
    
    // wavePointsがnullの場合は計算を試行
    if (wavePoints == null) {
      LogService.instance.info('ChartViewController', 'wavePointsがnull、計算を試行');
      onDataUpdatedForWavePoints();
      
      if (wavePoints == null) {
        LogService.instance.warning('ChartViewController', 'wavePoints計算後もnull、_bollingerBandsFilteredCurveResultをnullに設定');
        _bollingerBandsFilteredCurveResult = null;
        return;
      }
    }

    try {
      LogService.instance.info('ChartViewController', '布林通道データ取得開始');
      final bbData = getBollingerBandsData();
      LogService.instance.info('ChartViewController', '布林通道データ取得完了: ${bbData.keys.toList()}');
      
      if (bbData.isEmpty) {
        LogService.instance.warning('ChartViewController', '布林通道データが利用できません');
        _bollingerBandsFilteredCurveResult = null;
        return;
      }

      LogService.instance.info('ChartViewController', '布林线过滤曲线実行開始');
      LogService.instance.info('ChartViewController', '元の高低点: ${wavePoints!.mergedPoints.length}个');
      LogService.instance.info('ChartViewController', '布林通道期間: $bbPeriod, 标准偏差: $bbStdDev');
      
      _bollingerBandsFilteredCurveResult = BollingerBandsFilteringService.instance.filterWavePointsByBollingerBands(
        wavePoints: wavePoints!.mergedPoints,
        priceDataList: data,
        bollingerBands: bbData,
        bbPeriod: bbPeriod,
        bbStdDev: bbStdDev,
      );

      LogService.instance.info('ChartViewController', 
        '布林线过滤曲线完成: 元${wavePoints!.mergedPoints.length}个 → 过滤后${_bollingerBandsFilteredCurveResult!.filteredPointsCount}个 '
        '(过滤率${(_bollingerBandsFilteredCurveResult!.filteringRate * 100).toStringAsFixed(1)}%)');
    } catch (e) {
      LogService.instance.error('ChartViewController', '布林线过滤曲线失敗: $e');
      _bollingerBandsFilteredCurveResult = null;
    }
  }

  /// リソースのクリーンアップ
  void dispose() {
    disposeVerticalLineController();
    disposeManualHighLowController();
    // 注意: 他のコントローラのdisposeメソッドは、それぞれのミックスインに実装する必要があります。
  }
}