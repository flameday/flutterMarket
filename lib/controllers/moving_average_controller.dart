import 'package:flutter/material.dart';
import '../constants/chart_constants.dart';
import '../models/price_data.dart';
import '../services/log_service.dart';
import '../services/ma_trend_background_service.dart';

abstract class MovingAverageControllerHost {
  void notifyUIUpdate();
}

/// 移動平均線に関するロジックを管理するMixin
mixin MovingAverageControllerMixin on MovingAverageControllerHost {
  late List<PriceData> _dataForMA;
  final Map<int, List<double>> _movingAverages = {};
  final List<int> _maPeriods = ChartConstants.maPeriods;
  final Map<int, bool> _maVisibility = {
    for (int period in ChartConstants.maPeriods) period: true
  };
  
  // トレンド背景の表示設定
  bool _showRisingBackground = false;
  bool _showFallingBackground = false;
  
  // 移动平均线趋势背景设置
  bool _isMaTrendBackgroundEnabled = false;
  List<Color?> _maTrendBackgroundColors = [];

  /// Mixinを初期化
  void initMovingAverages(List<PriceData> data) {
    _dataForMA = data;
    if (_dataForMA.isNotEmpty) {
      _calculateMovingAverages();
    }
  }

  /// データ更新時に呼び出される
  void onDataUpdatedForMA(List<PriceData> newData) {
    // 性能最適化：データが同じ場合は再計算しない
    if (_dataForMA.length == newData.length && 
        _dataForMA.isNotEmpty && 
        _dataForMA.last.timestamp == newData.last.timestamp) {
      return;
    }
    
    _dataForMA = newData;
    if (_dataForMA.isNotEmpty) {
      _calculateMovingAverages();
    }
  }

  /// 移動平均線を計算する
  void _calculateMovingAverages() {
    if (_dataForMA.isEmpty) return;
    
    // 性能監視：計算開始時間
    final stopwatch = Stopwatch()..start();
    
    _movingAverages.clear();
    
    for (int period in _maPeriods) {
      _movingAverages[period] = _calculateMA(period);
    }
    
    // 计算移动平均线趋势背景颜色
    _calculateMaTrendBackgroundColors();
    
    stopwatch.stop();
    Log.info('MovingAverageController', '移動平均線計算完了: ${_maPeriods.join(', ')} (${stopwatch.elapsedMilliseconds}ms, データ量: ${_dataForMA.length})');
    
    // 性能警告：計算時間が長すぎる場合
    if (stopwatch.elapsedMilliseconds > 100) {
      Log.warning('MovingAverageController', '移動平均線計算時間が長い: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
  
  /// 指定期間の移動平均線を計算
  List<double> _calculateMA(int period) {
    if (_dataForMA.isEmpty || period <= 0) return [];
    
    List<double> ma = [];
    
    for (int i = 0; i < _dataForMA.length; i++) {
      if (i < period - 1) {
        ma.add(double.nan);
      } else {
        double sum = 0.0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += _dataForMA[j].close;
        }
        ma.add(sum / period);
      }
    }
    
    return ma;
  }

  /// 计算移动平均线趋势背景颜色
  void _calculateMaTrendBackgroundColors() {
    if (!_isMaTrendBackgroundEnabled) {
      _maTrendBackgroundColors.clear();
      return;
    }

    try {
      final List<double>? ma13 = _movingAverages[13];
      final List<double>? ma60 = _movingAverages[60];
      final List<double>? ma300 = _movingAverages[300];

      if (ma13 == null || ma60 == null || ma300 == null) {
        LogService.instance.warning('MovingAverageController', '移动平均线数据不完整，无法计算趋势背景');
        _maTrendBackgroundColors.clear();
        return;
      }

      _maTrendBackgroundColors = MaTrendBackgroundService.instance.calculateTrendBackgroundColors(
        ma13: ma13,
        ma60: ma60,
        ma300: ma300,
      );

      LogService.instance.info('MovingAverageController', '移动平均线趋势背景颜色计算完成: ${_maTrendBackgroundColors.length}个点');
    } catch (e) {
      LogService.instance.error('MovingAverageController', '计算移动平均线趋势背景颜色失败: $e');
      _maTrendBackgroundColors.clear();
    }
  }
  
  // --- Public Getters and Methods ---

  List<double>? getMovingAverage(int period) {
    return _movingAverages[period];
  }
  
  List<int> get maPeriods => List.unmodifiable(_maPeriods);
  
  bool isMaVisible(int period) {
    return _maVisibility[period] ?? false;
  }
  
  void setMaVisibility(int period, bool visible) {
    _maVisibility[period] = visible;
    notifyUIUpdate();
  }
  
  void setAllMaVisibility(bool visible) {
    for (int period in _maPeriods) {
      _maVisibility[period] = visible;
    }
    notifyUIUpdate();
  }
  
  void toggleMaVisibility(int period) {
    if (_maVisibility.containsKey(period)) {
      _maVisibility[period] = !_maVisibility[period]!;
      notifyUIUpdate();
    }
  }
  
  void applyMaVisibilitySettings(Map<int, bool> visibilitySettings) {
    bool changed = false;
    for (int period in _maPeriods) {
      if (visibilitySettings.containsKey(period)) {
        if (_maVisibility[period] != visibilitySettings[period]!) {
          _maVisibility[period] = visibilitySettings[period]!;
          changed = true;
        }
      }
    }
    if (changed) {
      notifyUIUpdate();
    }
  }
  
  Map<int, bool> get maVisibility => Map.unmodifiable(_maVisibility);
  
  // トレンド背景の表示状態を取得
  bool get showRisingBackground => _showRisingBackground;
  bool get showFallingBackground => _showFallingBackground;
  
  // トレンド背景の表示状態を切り替え
  void toggleRisingBackground() {
    _showRisingBackground = !_showRisingBackground;
  }
  
  void toggleFallingBackground() {
    _showFallingBackground = !_showFallingBackground;
  }
  
  // トレンド背景の表示状態を設定
  void setRisingBackground(bool visible) {
    _showRisingBackground = visible;
  }
  
  void setFallingBackground(bool visible) {
    _showFallingBackground = visible;
  }

  // 移动平均线趋势背景相关方法
  
  /// 获取移动平均线趋势背景是否启用
  bool get isMaTrendBackgroundEnabled => _isMaTrendBackgroundEnabled;
  
  /// 设置移动平均线趋势背景是否启用
  void setMaTrendBackgroundEnabled(bool enabled) {
    if (_isMaTrendBackgroundEnabled != enabled) {
      _isMaTrendBackgroundEnabled = enabled;
      if (enabled && _dataForMA.isNotEmpty) {
        _calculateMaTrendBackgroundColors();
      } else {
        _maTrendBackgroundColors.clear();
      }
      notifyUIUpdate();
    }
  }
  
  /// 切换移动平均线趋势背景设置
  void toggleMaTrendBackground() {
    setMaTrendBackgroundEnabled(!_isMaTrendBackgroundEnabled);
  }
  
  /// 获取指定索引的移动平均线趋势背景颜色
  Color? getMaTrendBackgroundColor(int index) {
    if (!_isMaTrendBackgroundEnabled || index < 0 || index >= _maTrendBackgroundColors.length) {
      return null;
    }
    return _maTrendBackgroundColors[index];
  }
  
  /// 获取所有移动平均线趋势背景颜色
  List<Color?> get maTrendBackgroundColors => List.unmodifiable(_maTrendBackgroundColors);
}
