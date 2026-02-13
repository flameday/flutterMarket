import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/price_data.dart';
import '../services/log_service.dart';

abstract class BollingerBandsControllerHost {
  void notifyUIUpdate();
}

/// 布林通道に関するロジックを管理するMixin
mixin BollingerBandsControllerMixin on BollingerBandsControllerHost {
  late List<PriceData> _dataForBB;
  final Map<String, List<double>> _bollingerBands = {};
  
  // 布林通道の設定
  int _bbPeriod = 20; // デフォルト20期間
  double _bbStdDev = 1.3; // デフォルト2倍標準偏差
  bool _isBollingerBandsVisible = false; // 表示状態
  
  // 布林通道の色設定
  Color _bbUpperColor = Colors.blue.withValues(alpha: 0.3);
  Color _bbMiddleColor = Colors.orange.withValues(alpha: 0.3);
  Color _bbLowerColor = Colors.blue.withValues(alpha: 0.3);
  
  // 布林通道の透明度設定
  double _bbUpperAlpha = 0.7;
  double _bbMiddleAlpha = 0.8;
  double _bbLowerAlpha = 0.7;

  /// Mixinを初期化
  void initBollingerBands(List<PriceData> data) {
    _dataForBB = data;
    if (_dataForBB.isNotEmpty) {
      _calculateBollingerBands();
    }
  }

  /// データ更新時に呼び出される
  void onDataUpdatedForBB(List<PriceData> newData) {
    // 性能最適化：データが同じ場合は再計算しない
    if (_dataForBB.length == newData.length && 
        _dataForBB.isNotEmpty && 
        _dataForBB.last.timestamp == newData.last.timestamp) {
      return;
    }
    
    _dataForBB = newData;
    if (_dataForBB.isNotEmpty) {
      _calculateBollingerBands();
    }
  }

  /// 布林通道を計算する
  void _calculateBollingerBands() {
    if (_dataForBB.isEmpty) return;
    
    // 性能監視：計算開始時間
    final stopwatch = Stopwatch()..start();
    
    _bollingerBands.clear();
    
    // 上軌、中軌、下軌を計算
    _bollingerBands['upper'] = _calculateBBUpper();
    _bollingerBands['middle'] = _calculateBBMiddle();
    _bollingerBands['lower'] = _calculateBBLower();
    
    stopwatch.stop();
    LogService.instance.info('BollingerBandsController', 
      '布林通道計算完了: 期間$_bbPeriod, 標準偏差$_bbStdDev (${stopwatch.elapsedMilliseconds}ms, データ量: ${_dataForBB.length})');
    
    // 性能警告：計算時間が長すぎる場合
    if (stopwatch.elapsedMilliseconds > 100) {
      LogService.instance.warning('BollingerBandsController', 
        '布林通道計算時間が長い: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
  
  /// 布林通道の中軌（移動平均線）を計算
  List<double> _calculateBBMiddle() {
    if (_dataForBB.isEmpty || _bbPeriod <= 0) return [];
    
    List<double> middle = [];
    
    for (int i = 0; i < _dataForBB.length; i++) {
      if (i < _bbPeriod - 1) {
        middle.add(double.nan);
      } else {
        double sum = 0.0;
        for (int j = i - _bbPeriod + 1; j <= i; j++) {
          sum += _dataForBB[j].close;
        }
        middle.add(sum / _bbPeriod);
      }
    }
    
    return middle;
  }
  
  /// 布林通道の上軌を計算
  List<double> _calculateBBUpper() {
    final middle = _calculateBBMiddle();
    if (middle.isEmpty) return [];
    
    List<double> upper = [];
    
    for (int i = 0; i < _dataForBB.length; i++) {
      if (i < _bbPeriod - 1) {
        upper.add(double.nan);
      } else {
        // 標準偏差を計算
        double sum = 0.0;
        for (int j = i - _bbPeriod + 1; j <= i; j++) {
          final diff = _dataForBB[j].close - middle[i];
          sum += diff * diff;
        }
        final variance = sum / _bbPeriod;
        final stdDev = variance.isNaN ? 0.0 : math.sqrt(variance);
        
        upper.add(middle[i] + (_bbStdDev * stdDev));
      }
    }
    
    return upper;
  }
  
  /// 布林通道の下軌を計算
  List<double> _calculateBBLower() {
    final middle = _calculateBBMiddle();
    if (middle.isEmpty) return [];
    
    List<double> lower = [];
    
    for (int i = 0; i < _dataForBB.length; i++) {
      if (i < _bbPeriod - 1) {
        lower.add(double.nan);
      } else {
        // 標準偏差を計算
        double sum = 0.0;
        for (int j = i - _bbPeriod + 1; j <= i; j++) {
          final diff = _dataForBB[j].close - middle[i];
          sum += diff * diff;
        }
        final variance = sum / _bbPeriod;
        final stdDev = variance.isNaN ? 0.0 : math.sqrt(variance);
        
        lower.add(middle[i] - (_bbStdDev * stdDev));
      }
    }
    
    return lower;
  }

  /// 布林通道データを取得
  Map<String, List<double>> getBollingerBandsData() {
    return Map.from(_bollingerBands);
  }

  /// 布林通道の表示状態を取得
  bool get isBollingerBandsVisible => _isBollingerBandsVisible;

  /// 布林通道の表示状態を設定
  void setBollingerBandsVisible(bool visible) {
    if (_isBollingerBandsVisible != visible) {
      _isBollingerBandsVisible = visible;
      LogService.instance.info('BollingerBandsController', 
        '布林通道表示状態変更: ${visible ? "表示" : "非表示"}');
      notifyUIUpdate();
    }
  }

  /// 布林通道の期間を取得
  int get bbPeriod => _bbPeriod;

  /// 布林通道の期間を設定
  void setBBPeriod(int period) {
    if (_bbPeriod != period && period > 0) {
      _bbPeriod = period;
      LogService.instance.info('BollingerBandsController', '布林通道期間変更: $period');
      if (_dataForBB.isNotEmpty) {
        _calculateBollingerBands();
        notifyUIUpdate();
      }
    }
  }

  /// 布林通道の標準偏差倍率を取得
  double get bbStdDev => _bbStdDev;

  /// 布林通道の標準偏差倍率を設定
  void setBBStdDev(double stdDev) {
    if (_bbStdDev != stdDev && stdDev > 0) {
      _bbStdDev = stdDev;
      LogService.instance.info('BollingerBandsController', '布林通道標準偏差倍率変更: $stdDev');
      if (_dataForBB.isNotEmpty) {
        _calculateBollingerBands();
        notifyUIUpdate();
      }
    }
  }

  /// 布林通道の色設定を取得
  Map<String, Color> get bbColors => {
    'upper': _bbUpperColor,
    'middle': _bbMiddleColor,
    'lower': _bbLowerColor,
  };

  /// 布林通道の色設定を設定
  void setBBColors({
    Color? upperColor,
    Color? middleColor,
    Color? lowerColor,
  }) {
    bool changed = false;
    
    if (upperColor != null && _bbUpperColor != upperColor) {
      _bbUpperColor = upperColor;
      changed = true;
    }
    
    if (middleColor != null && _bbMiddleColor != middleColor) {
      _bbMiddleColor = middleColor;
      changed = true;
    }
    
    if (lowerColor != null && _bbLowerColor != lowerColor) {
      _bbLowerColor = lowerColor;
      changed = true;
    }
    
    if (changed) {
      LogService.instance.info('BollingerBandsController', '布林通道色設定変更');
      notifyUIUpdate();
    }
  }

  /// 布林通道の透明度設定を取得
  Map<String, double> get bbAlphas => {
    'upper': _bbUpperAlpha,
    'middle': _bbMiddleAlpha,
    'lower': _bbLowerAlpha,
  };

  /// 布林通道の透明度設定を設定
  void setBBAlphas({
    double? upperAlpha,
    double? middleAlpha,
    double? lowerAlpha,
  }) {
    bool changed = false;
    
    if (upperAlpha != null && _bbUpperAlpha != upperAlpha) {
      _bbUpperAlpha = upperAlpha.clamp(0.0, 1.0);
      changed = true;
    }
    
    if (middleAlpha != null && _bbMiddleAlpha != middleAlpha) {
      _bbMiddleAlpha = middleAlpha.clamp(0.0, 1.0);
      changed = true;
    }
    
    if (lowerAlpha != null && _bbLowerAlpha != lowerAlpha) {
      _bbLowerAlpha = lowerAlpha.clamp(0.0, 1.0);
      changed = true;
    }
    
    if (changed) {
      LogService.instance.info('BollingerBandsController', '布林通道透明度設定変更');
      notifyUIUpdate();
    }
  }

  /// 布林通道の設定をリセット
  void resetBollingerBandsSettings() {
    _bbPeriod = 20;
    _bbStdDev = 1.3;
    _isBollingerBandsVisible = false;
    _bbUpperColor = Colors.blue.withValues(alpha: 0.7);
    _bbMiddleColor = Colors.orange.withValues(alpha: 0.8);
    _bbLowerColor = Colors.blue.withValues(alpha: 0.7);
    _bbUpperAlpha = 0.7;
    _bbMiddleAlpha = 0.8;
    _bbLowerAlpha = 0.7;
    
    LogService.instance.info('BollingerBandsController', '布林通道設定をリセット');
    
    if (_dataForBB.isNotEmpty) {
      _calculateBollingerBands();
      notifyUIUpdate();
    }
  }
}
