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
  final bool isOhlcVisible; // 右上O/H/L/C表示
  final bool isKlineVisible; // K線表示/非表示
  final Map<int, bool> maVisibility;
  final Map<int, String> maColors; // MA色設定
  final Map<int, double> maAlphas; // MA透明度設定
  final List<int> maPeriods;
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
  final double highLowMarkerSize;
  final String highLowMarkerShape;
  final String highMarkerColor;
  final String lowMarkerColor;
  final double highLowMarkerOffset;
    final bool? _isStrategyMergeConsecutiveEnabled;
    final bool? _isStrategySupplementOnlyEnabled;
    final bool? _isStrategyPolylineVisible;
    final String? _strategyPolylineColor;
    final double? _strategyPolylineWidth;
  final DateTime lastUpdated;

    bool get isStrategyMergeConsecutiveEnabled =>
      _isStrategyMergeConsecutiveEnabled ?? true;
    bool get isStrategySupplementOnlyEnabled =>
      _isStrategySupplementOnlyEnabled ?? false;
      bool get isStrategyPolylineVisible => _isStrategyPolylineVisible ?? false;
      String get strategyPolylineColor => _strategyPolylineColor ?? '#FFEB3B';
      double get strategyPolylineWidth => _strategyPolylineWidth ?? 2.0;

  const AppSettings({
    this.selectedTradingPair = TradingPair.eurusd,
    this.defaultTimeframe = Timeframe.m30,
    this.isAutoUpdateEnabled = true,
    this.autoUpdateIntervalMinutes = 1,
    this.isWavePointsVisible = true,
    this.isWavePointsLineVisible = false,
    this.isOhlcVisible = true,
    this.isKlineVisible = true, // デフォルトでK線を表示
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
    this.highLowMarkerSize = 8.0,
    this.highLowMarkerShape = 'triangle',
    this.highMarkerColor = '#FF9800',
    this.lowMarkerColor = '#2196F3',
    this.highLowMarkerOffset = 0.0,
    bool? isStrategyMergeConsecutiveEnabled = true,
    bool? isStrategySupplementOnlyEnabled = false,
    bool? isStrategyPolylineVisible = false,
    String? strategyPolylineColor = '#FFEB3B',
    double? strategyPolylineWidth = 2.0,
    required this.lastUpdated,
  })  : _isStrategyMergeConsecutiveEnabled = isStrategyMergeConsecutiveEnabled,
      _isStrategySupplementOnlyEnabled = isStrategySupplementOnlyEnabled,
      _isStrategyPolylineVisible = isStrategyPolylineVisible,
      _strategyPolylineColor = strategyPolylineColor,
      _strategyPolylineWidth = strategyPolylineWidth;

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
      isOhlcVisible: json['isOhlcVisible'] ?? defaults.isOhlcVisible,
      isKlineVisible: json['isKlineVisible'] ?? defaults.isKlineVisible,
      maVisibility: _parseMaVisibility(json['maVisibility']) ?? defaults.maVisibility,
      maColors: _parseMaColors(json['maColors']) ?? defaults.maColors,
      maAlphas: _parseMaAlphas(json['maAlphas']) ?? defaults.maAlphas,
      maPeriods: _parseMaPeriods(json['maPeriods']) ?? defaults.maPeriods,
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
      highLowMarkerSize: (json['highLowMarkerSize'] ?? defaults.highLowMarkerSize).toDouble(),
      highLowMarkerShape: json['highLowMarkerShape'] ?? defaults.highLowMarkerShape,
      highMarkerColor: json['highMarkerColor'] ?? defaults.highMarkerColor,
      lowMarkerColor: json['lowMarkerColor'] ?? defaults.lowMarkerColor,
      highLowMarkerOffset: (json['highLowMarkerOffset'] ?? defaults.highLowMarkerOffset).toDouble(),
      isStrategyMergeConsecutiveEnabled: _parseBool(
        json['isStrategyMergeConsecutiveEnabled'],
        defaults.isStrategyMergeConsecutiveEnabled,
      ),
      isStrategySupplementOnlyEnabled: _parseBool(
        json['isStrategySupplementOnlyEnabled'],
        defaults.isStrategySupplementOnlyEnabled,
      ),
      isStrategyPolylineVisible: _parseBool(
        json['isStrategyPolylineVisible'],
        defaults.isStrategyPolylineVisible,
      ),
      strategyPolylineColor:
          _parseString(json['strategyPolylineColor'], defaults.strategyPolylineColor),
      strategyPolylineWidth:
          _parseDouble(json['strategyPolylineWidth'], defaults.strategyPolylineWidth),
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
      'isOhlcVisible': isOhlcVisible,
      'isKlineVisible': isKlineVisible,
      'maVisibility': maVisibility.map((key, value) => MapEntry(key.toString(), value)),
      'maColors': maColors.map((key, value) => MapEntry(key.toString(), value)),
      'maAlphas': maAlphas.map((key, value) => MapEntry(key.toString(), value)),
      'maPeriods': maPeriods,
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
      'highLowMarkerSize': highLowMarkerSize,
      'highLowMarkerShape': highLowMarkerShape,
      'highMarkerColor': highMarkerColor,
      'lowMarkerColor': lowMarkerColor,
      'highLowMarkerOffset': highLowMarkerOffset,
      'isStrategyMergeConsecutiveEnabled': isStrategyMergeConsecutiveEnabled,
      'isStrategySupplementOnlyEnabled': isStrategySupplementOnlyEnabled,
      'isStrategyPolylineVisible': isStrategyPolylineVisible,
      'strategyPolylineColor': strategyPolylineColor,
      'strategyPolylineWidth': strategyPolylineWidth,
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
    bool? isOhlcVisible,
    bool? isKlineVisible,
    Map<int, bool>? maVisibility,
    Map<int, String>? maColors,
    Map<int, double>? maAlphas,
    List<int>? maPeriods,
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
    double? highLowMarkerSize,
    String? highLowMarkerShape,
    String? highMarkerColor,
    String? lowMarkerColor,
    double? highLowMarkerOffset,
    bool? isStrategyMergeConsecutiveEnabled,
    bool? isStrategySupplementOnlyEnabled,
    bool? isStrategyPolylineVisible,
    String? strategyPolylineColor,
    double? strategyPolylineWidth,
  }) {
    return AppSettings(
      selectedTradingPair: selectedTradingPair ?? this.selectedTradingPair,
      defaultTimeframe: defaultTimeframe ?? this.defaultTimeframe,
      isAutoUpdateEnabled: isAutoUpdateEnabled ?? this.isAutoUpdateEnabled,
      autoUpdateIntervalMinutes: autoUpdateIntervalMinutes ?? this.autoUpdateIntervalMinutes,
      isWavePointsVisible: isWavePointsVisible ?? this.isWavePointsVisible,
      isWavePointsLineVisible: isWavePointsLineVisible ?? this.isWavePointsLineVisible,
      isOhlcVisible: isOhlcVisible ?? this.isOhlcVisible,
      isKlineVisible: isKlineVisible ?? this.isKlineVisible,
      maVisibility: maVisibility ?? this.maVisibility,
      maColors: maColors ?? this.maColors,
      maAlphas: maAlphas ?? this.maAlphas,
      maPeriods: maPeriods ?? this.maPeriods,
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
      highLowMarkerSize: highLowMarkerSize ?? this.highLowMarkerSize,
      highLowMarkerShape: highLowMarkerShape ?? this.highLowMarkerShape,
      highMarkerColor: highMarkerColor ?? this.highMarkerColor,
      lowMarkerColor: lowMarkerColor ?? this.lowMarkerColor,
      highLowMarkerOffset: highLowMarkerOffset ?? this.highLowMarkerOffset,
      isStrategyMergeConsecutiveEnabled: isStrategyMergeConsecutiveEnabled ?? this.isStrategyMergeConsecutiveEnabled,
      isStrategySupplementOnlyEnabled: isStrategySupplementOnlyEnabled ?? this.isStrategySupplementOnlyEnabled,
      isStrategyPolylineVisible: isStrategyPolylineVisible ?? this.isStrategyPolylineVisible,
      strategyPolylineColor: strategyPolylineColor ?? this.strategyPolylineColor,
      strategyPolylineWidth: strategyPolylineWidth ?? this.strategyPolylineWidth,
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

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  static String _parseString(dynamic value, String defaultValue) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return defaultValue;
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return defaultValue;
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
