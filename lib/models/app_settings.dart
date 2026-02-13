import 'timeframe.dart';
import 'trading_pair.dart';

/// アプリケーション設定データモデル
class AppSettings {
  final TradingPair selectedTradingPair;
  final Timeframe defaultTimeframe;
  final bool isAutoUpdateEnabled;
  final int autoUpdateIntervalMinutes;
  final bool isWavePointsVisible;
  final bool isWavePointsLineVisible;
  final bool isFormattedWaveVisible;
  final bool isKlineVisible; // K線表示/非表示
  final String selectedInterpolationMethod;
  final Map<int, bool> maVisibility;
  final Map<int, String> maColors; // MA色設定
  final Map<int, double> maAlphas; // MA透明度設定
  final List<int> maPeriods;
  final bool isTrendFilteringEnabled; // トレンドフィルタリング有効/無効
  final double trendFilteringThreshold; // トレンドフィルタリング閾値
  final double trendFilteringNearThreshold; // 近い距離の閾値
  final double trendFilteringFarThreshold; // 遠い距離の閾値
  final int trendFilteringMinGapBars; // 最低バー間隔
  final bool isCubicCurveVisible; // 3次曲线显示/隐藏
  final bool isMA60FilteredCurveVisible; // 60均线过滤曲线显示/隐藏
  final bool isBollingerBandsFilteredCurveVisible; // 布林线过滤曲线显示/隐藏
  final bool isBollingerBandsVisible; // 布林通道显示/隐藏
  final int bbPeriod; // 布林通道期间
  final double bbStdDev; // 布林通道标准偏差倍率
  final Map<String, String> bbColors; // 布林通道色设定
  final Map<String, double> bbAlphas; // 布林通道透明度设定
  final bool isGridVisible;
  final bool isCrosshairVisible;
  final String themeMode; // 'light', 'dark', 'system'
  final double chartZoomLevel;
  final bool isMultiWindowMode;
  final Map<String, bool> windowStates;
  final int klineDataLimit;
  final String backgroundColor; // 背景色設定
  final bool isMaTrendBackgroundEnabled; // 基于移动平均线的趋势背景设置
  final bool isMousePositionZoomEnabled; // 以鼠标位置为缩放原点
  final DateTime lastUpdated;

  const AppSettings({
    this.selectedTradingPair = TradingPair.eurusd,
    this.defaultTimeframe = Timeframe.m30,
    this.isAutoUpdateEnabled = true,
    this.autoUpdateIntervalMinutes = 1,
    this.isWavePointsVisible = true,
    this.isWavePointsLineVisible = false,
    this.isFormattedWaveVisible = false,
    this.isKlineVisible = true, // デフォルトでK線を表示
    this.selectedInterpolationMethod = 'chaikin',
    this.maVisibility = const {2: false, 3: false, 10: false, 13: false, 30: true, 60: false, 150: true, 300: false, 750: false},
    this.maColors = const {
      2: '0xFFFF0000', // 赤
      3: '0xFFFFA500', // オレンジ
      10: '0xFFFFFF00', // 黄
      13: '0xFF00FF00', // 緑
      30: '0xFF0000FF', // 青
      60: '0xFF800080', // 紫
      150: '0xFFFFC0CB', // ピンク
      300: '0xFFA52A2A', // 茶
      750: '0xFFFF0000', // 赤
    },
    this.maAlphas = const {
      2: 1.0, 3: 1.0, 10: 1.0, 13: 1.0, 30: 1.0, 60: 1.0, 150: 1.0, 300: 1.0, 750: 1.0
    },
      this.maPeriods = const [2, 3, 10, 13, 30, 60, 150, 300, 750],
      this.isTrendFilteringEnabled = false,
      this.trendFilteringThreshold = 0.005, // デフォルト0.5%
      this.trendFilteringNearThreshold = 0.005, // デフォルト0.5%
      this.trendFilteringFarThreshold = 0.015, // デフォルト1.5%
      this.trendFilteringMinGapBars = 3, // デフォルト3バー
    this.isCubicCurveVisible = false, // デフォルトで3次曲线を非表示
    this.isMA60FilteredCurveVisible = false, // デフォルトで60均线过滤曲线を非表示
    this.isBollingerBandsFilteredCurveVisible = false, // デフォルトで布林线过滤曲线を非表示
    this.isBollingerBandsVisible = false, // デフォルトで布林通道を非表示
    this.bbPeriod = 20, // デフォルト20期間
    this.bbStdDev = 1.3, // デフォルト2倍標準偏差
    this.bbColors = const {
      'upper': '0xFF2196F3', // 青
      'middle': '0xFFFF9800', // オレンジ
      'lower': '0xFF2196F3', // 青
    },
    this.bbAlphas = const {
      'upper': 0.7,
      'middle': 0.8,
      'lower': 0.7,
    },
    this.isGridVisible = true,
    this.isCrosshairVisible = true,
    this.themeMode = 'system',
    this.chartZoomLevel = 1.0,
    this.isMultiWindowMode = false,
    this.windowStates = const {},
    this.klineDataLimit = 1000,
    this.backgroundColor = '0xFF1E1E1E', // デフォルトは暗い背景
    this.isMaTrendBackgroundEnabled = false, // 默认关闭移动平均线趋势背景
    this.isMousePositionZoomEnabled = false, // 默认以右侧为缩放原点
    required this.lastUpdated,
  });

  /// JSONからAppSettingsインスタンスを作成
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.getDefault();
    return AppSettings(
      selectedTradingPair: _parseTradingPair(json['selectedTradingPair']) ?? defaults.selectedTradingPair,
      defaultTimeframe: _parseTimeframe(json['defaultTimeframe']) ?? defaults.defaultTimeframe,
      isAutoUpdateEnabled: json['isAutoUpdateEnabled'] ?? defaults.isAutoUpdateEnabled,
      autoUpdateIntervalMinutes: json['autoUpdateIntervalMinutes'] ?? defaults.autoUpdateIntervalMinutes,
      isWavePointsVisible: json['isWavePointsVisible'] ?? defaults.isWavePointsVisible,
      isWavePointsLineVisible: json['isWavePointsLineVisible'] ?? defaults.isWavePointsLineVisible,
      isFormattedWaveVisible: json['isFormattedWaveVisible'] ?? defaults.isFormattedWaveVisible,
      isKlineVisible: json['isKlineVisible'] ?? defaults.isKlineVisible,
      selectedInterpolationMethod: json['selectedInterpolationMethod'] ?? defaults.selectedInterpolationMethod,
      maVisibility: _parseMaVisibility(json['maVisibility']) ?? defaults.maVisibility,
      maColors: _parseMaColors(json['maColors']) ?? defaults.maColors,
      maAlphas: _parseMaAlphas(json['maAlphas']) ?? defaults.maAlphas,
      maPeriods: _parseMaPeriods(json['maPeriods']) ?? defaults.maPeriods,
      isTrendFilteringEnabled: json['isTrendFilteringEnabled'] ?? defaults.isTrendFilteringEnabled,
      trendFilteringThreshold: (json['trendFilteringThreshold'] ?? defaults.trendFilteringThreshold).toDouble(),
      trendFilteringNearThreshold: (json['trendFilteringNearThreshold'] ?? defaults.trendFilteringNearThreshold).toDouble(),
      trendFilteringFarThreshold: (json['trendFilteringFarThreshold'] ?? defaults.trendFilteringFarThreshold).toDouble(),
      trendFilteringMinGapBars: json['trendFilteringMinGapBars'] ?? defaults.trendFilteringMinGapBars,
      isCubicCurveVisible: json['isCubicCurveVisible'] ?? defaults.isCubicCurveVisible,
      isMA60FilteredCurveVisible: json['isMA60FilteredCurveVisible'] ?? defaults.isMA60FilteredCurveVisible,
      isBollingerBandsFilteredCurveVisible: json['isBollingerBandsFilteredCurveVisible'] ?? defaults.isBollingerBandsFilteredCurveVisible,
      isBollingerBandsVisible: json['isBollingerBandsVisible'] ?? defaults.isBollingerBandsVisible,
      bbPeriod: json['bbPeriod'] ?? defaults.bbPeriod,
      bbStdDev: (json['bbStdDev'] ?? defaults.bbStdDev).toDouble(),
      bbColors: Map<String, String>.from(json['bbColors'] ?? defaults.bbColors),
      bbAlphas: Map<String, double>.from(json['bbAlphas'] ?? defaults.bbAlphas),
      isGridVisible: json['isGridVisible'] ?? defaults.isGridVisible,
      isCrosshairVisible: json['isCrosshairVisible'] ?? defaults.isCrosshairVisible,
      themeMode: json['themeMode'] ?? defaults.themeMode,
      chartZoomLevel: (json['chartZoomLevel'] ?? defaults.chartZoomLevel).toDouble(),
      isMultiWindowMode: json['isMultiWindowMode'] ?? defaults.isMultiWindowMode,
      windowStates: _parseWindowStates(json['windowStates']) ?? defaults.windowStates,
      klineDataLimit: json['klineDataLimit'] ?? defaults.klineDataLimit,
      backgroundColor: json['backgroundColor'] ?? defaults.backgroundColor,
      isMaTrendBackgroundEnabled: json['isMaTrendBackgroundEnabled'] ?? defaults.isMaTrendBackgroundEnabled,
      isMousePositionZoomEnabled: json['isMousePositionZoomEnabled'] ?? defaults.isMousePositionZoomEnabled,
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'selectedTradingPair': selectedTradingPair.dukascopyCode,
      'defaultTimeframe': defaultTimeframe.dukascopyCode,
      'isAutoUpdateEnabled': isAutoUpdateEnabled,
      'autoUpdateIntervalMinutes': autoUpdateIntervalMinutes,
      'isWavePointsVisible': isWavePointsVisible,
      'isWavePointsLineVisible': isWavePointsLineVisible,
      'isFormattedWaveVisible': isFormattedWaveVisible,
      'isKlineVisible': isKlineVisible,
      'selectedInterpolationMethod': selectedInterpolationMethod,
      'maVisibility': maVisibility.map((key, value) => MapEntry(key.toString(), value)),
      'maColors': maColors.map((key, value) => MapEntry(key.toString(), value)),
      'maAlphas': maAlphas.map((key, value) => MapEntry(key.toString(), value)),
      'maPeriods': maPeriods,
      'isTrendFilteringEnabled': isTrendFilteringEnabled,
      'trendFilteringThreshold': trendFilteringThreshold,
      'trendFilteringNearThreshold': trendFilteringNearThreshold,
      'trendFilteringFarThreshold': trendFilteringFarThreshold,
      'trendFilteringMinGapBars': trendFilteringMinGapBars,
      'isCubicCurveVisible': isCubicCurveVisible,
      'isMA60FilteredCurveVisible': isMA60FilteredCurveVisible,
      'isBollingerBandsFilteredCurveVisible': isBollingerBandsFilteredCurveVisible,
      'isBollingerBandsVisible': isBollingerBandsVisible,
      'bbPeriod': bbPeriod,
      'bbStdDev': bbStdDev,
      'bbColors': bbColors,
      'bbAlphas': bbAlphas,
      'isGridVisible': isGridVisible,
      'isCrosshairVisible': isCrosshairVisible,
      'themeMode': themeMode,
      'chartZoomLevel': chartZoomLevel,
      'isMultiWindowMode': isMultiWindowMode,
      'windowStates': windowStates,
      'klineDataLimit': klineDataLimit,
      'backgroundColor': backgroundColor,
      'isMaTrendBackgroundEnabled': isMaTrendBackgroundEnabled,
      'isMousePositionZoomEnabled': isMousePositionZoomEnabled,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// コピーを作成し指定フィールドを更新
  AppSettings copyWith({
    TradingPair? selectedTradingPair,
    Timeframe? defaultTimeframe,
    bool? isAutoUpdateEnabled,
    int? autoUpdateIntervalMinutes,
    bool? isWavePointsVisible,
    bool? isWavePointsLineVisible,
    bool? isFormattedWaveVisible,
    bool? isKlineVisible,
    String? selectedInterpolationMethod,
    Map<int, bool>? maVisibility,
    Map<int, String>? maColors,
    Map<int, double>? maAlphas,
    List<int>? maPeriods,
    bool? isTrendFilteringEnabled,
    double? trendFilteringThreshold,
    double? trendFilteringNearThreshold,
    double? trendFilteringFarThreshold,
    int? trendFilteringMinGapBars,
    bool? isCubicCurveVisible,
    bool? isMA60FilteredCurveVisible,
    bool? isBollingerBandsFilteredCurveVisible,
    bool? isBollingerBandsVisible,
    int? bbPeriod,
    double? bbStdDev,
    Map<String, String>? bbColors,
    Map<String, double>? bbAlphas,
    bool? isGridVisible,
    bool? isCrosshairVisible,
    String? themeMode,
    double? chartZoomLevel,
    bool? isMultiWindowMode,
    Map<String, bool>? windowStates,
    int? klineDataLimit,
    String? backgroundColor,
    bool? isMaTrendBackgroundEnabled,
    bool? isMousePositionZoomEnabled,
  }) {
    return AppSettings(
      selectedTradingPair: selectedTradingPair ?? this.selectedTradingPair,
      defaultTimeframe: defaultTimeframe ?? this.defaultTimeframe,
      isAutoUpdateEnabled: isAutoUpdateEnabled ?? this.isAutoUpdateEnabled,
      autoUpdateIntervalMinutes: autoUpdateIntervalMinutes ?? this.autoUpdateIntervalMinutes,
      isWavePointsVisible: isWavePointsVisible ?? this.isWavePointsVisible,
      isWavePointsLineVisible: isWavePointsLineVisible ?? this.isWavePointsLineVisible,
      isFormattedWaveVisible: isFormattedWaveVisible ?? this.isFormattedWaveVisible,
      isKlineVisible: isKlineVisible ?? this.isKlineVisible,
      selectedInterpolationMethod: selectedInterpolationMethod ?? this.selectedInterpolationMethod,
      maVisibility: maVisibility ?? this.maVisibility,
      maColors: maColors ?? this.maColors,
      maAlphas: maAlphas ?? this.maAlphas,
      maPeriods: maPeriods ?? this.maPeriods,
      isTrendFilteringEnabled: isTrendFilteringEnabled ?? this.isTrendFilteringEnabled,
      trendFilteringThreshold: trendFilteringThreshold ?? this.trendFilteringThreshold,
      trendFilteringNearThreshold: trendFilteringNearThreshold ?? this.trendFilteringNearThreshold,
      trendFilteringFarThreshold: trendFilteringFarThreshold ?? this.trendFilteringFarThreshold,
      trendFilteringMinGapBars: trendFilteringMinGapBars ?? this.trendFilteringMinGapBars,
      isCubicCurveVisible: isCubicCurveVisible ?? this.isCubicCurveVisible,
      isMA60FilteredCurveVisible: isMA60FilteredCurveVisible ?? this.isMA60FilteredCurveVisible,
      isBollingerBandsFilteredCurveVisible: isBollingerBandsFilteredCurveVisible ?? this.isBollingerBandsFilteredCurveVisible,
      isBollingerBandsVisible: isBollingerBandsVisible ?? this.isBollingerBandsVisible,
      bbPeriod: bbPeriod ?? this.bbPeriod,
      bbStdDev: bbStdDev ?? this.bbStdDev,
      bbColors: bbColors ?? this.bbColors,
      bbAlphas: bbAlphas ?? this.bbAlphas,
      isGridVisible: isGridVisible ?? this.isGridVisible,
      isCrosshairVisible: isCrosshairVisible ?? this.isCrosshairVisible,
      themeMode: themeMode ?? this.themeMode,
      chartZoomLevel: chartZoomLevel ?? this.chartZoomLevel,
      isMultiWindowMode: isMultiWindowMode ?? this.isMultiWindowMode,
      windowStates: windowStates ?? this.windowStates,
      klineDataLimit: klineDataLimit ?? this.klineDataLimit,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isMaTrendBackgroundEnabled: isMaTrendBackgroundEnabled ?? this.isMaTrendBackgroundEnabled,
      isMousePositionZoomEnabled: isMousePositionZoomEnabled ?? this.isMousePositionZoomEnabled,
      lastUpdated: DateTime.now(),
    );
  }

  /// 取引ペアを解析
  static TradingPair? _parseTradingPair(dynamic value) {
    if (value == null) return null;

    switch (value.toString()) {
      case 'eurusd':
        return TradingPair.eurusd;
      case 'usdjpy':
        return TradingPair.usdjpy;
      case 'gbpjpy':
        return TradingPair.gbpjpy;
      case 'xauusd':
        return TradingPair.xauusd;
      case 'gbpusd':
        return TradingPair.gbpusd;
      case 'audusd':
        return TradingPair.audusd;
      case 'usdcad':
        return TradingPair.usdcad;
      case 'nzdusd':
        return TradingPair.nzdusd;
      case 'eurjpy':
        return TradingPair.eurjpy;
      case 'eurgbp':
        return TradingPair.eurgbp;
      default:
        return null;
    }
  }

  /// 時間周期を解析
  static Timeframe? _parseTimeframe(dynamic value) {
    if (value == null) return null;

    switch (value.toString()) {
      case 'm5':
        return Timeframe.m5;
      case 'm15':
        return Timeframe.m15;
      case 'm30':
        return Timeframe.m30;
      case 'h4':
        return Timeframe.h4;
      default:
        return null;
    }
  }

  /// 移動平均線の可視性を解析
  static Map<int, bool>? _parseMaVisibility(dynamic value) {
    if (value == null) return null;

    final Map<int, bool> result = {};
    if (value is Map) {
      value.forEach((key, val) {
        final intKey = int.tryParse(key.toString());
        if (intKey != null && val is bool) {
          result[intKey] = val;
        }
      });
    }

    return result;
  }

  /// 移動平均線の色を解析
  static Map<int, String>? _parseMaColors(dynamic value) {
    if (value == null) return null;

    final Map<int, String> result = {};
    if (value is Map) {
      value.forEach((key, val) {
        final intKey = int.tryParse(key.toString());
        if (intKey != null && val is String) {
          result[intKey] = val;
        }
      });
    }

    return result;
  }

  /// 移動平均線の透明度を解析
  static Map<int, double>? _parseMaAlphas(dynamic value) {
    if (value == null) return null;

    final Map<int, double> result = {};
    if (value is Map) {
      value.forEach((key, val) {
        final intKey = int.tryParse(key.toString());
        if (intKey != null) {
          if (val is double) {
            result[intKey] = val;
          } else if (val is num) {
            result[intKey] = val.toDouble();
          }
        }
      });
    }

    return result;
  }

  /// 移動平均線周期を解析
  static List<int>? _parseMaPeriods(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => int.tryParse(e.toString()))
          .where((e) => e != null)
          .cast<int>()
          .toList();
    } else {
      return null;
    }
  }

  /// ウィンドウ状態を解析
  static Map<String, bool>? _parseWindowStates(dynamic value) {
    if (value == null) return null;

    final Map<String, bool> result = {};
    if (value is Map) {
      value.forEach((key, val) {
        if (key is String && val is bool) {
          result[key] = val;
        }
      });
    }

    return result;
  }

  /// デフォルト設定を取得
  static AppSettings getDefault() {
    return AppSettings(
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AppSettings(defaultTimeframe: $defaultTimeframe, isAutoUpdateEnabled: $isAutoUpdateEnabled, lastUpdated: $lastUpdated)';
  }
}
