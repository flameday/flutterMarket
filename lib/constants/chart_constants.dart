import 'package:flutter/material.dart';

/// チャート関連の定数を管理するクラス
class ChartConstants {
  // プライベートコンストラクタ
  ChartConstants._();
  
  // --- 移動平均線設定 ---
  static const List<int> maPeriods = [2, 3, 10, 13, 30, 60, 150, 300, 750];
  
  static const Map<int, Color> maColors = {
    2: Colors.blue,
    3: Colors.cyan,
    10: Colors.black,
    13: Colors.orange,
    30: Colors.purple,
    60: Colors.pink,
    150: Colors.brown,
    300: Colors.grey,
    750: Colors.red,
  };
  
  static const Map<int, String> maDescriptions = {
    2: '超短期トレンド',
    3: '短期トレンド',
    10: '短期トレンド',
    13: '短期トレンド',
    30: '中期トレンド',
    60: '中期トレンド',
    150: '長期トレンド',
    300: '超長期トレンド',
    750: '超超長期トレンド',
  };
  
  // --- チャート設定 ---
  static const double defaultCandleWidth = 4.0;
  static const double defaultSpacing = 0.2;
  static const double defaultEmptySpaceWidth = 50.0;
  static const double minScale = 0.5;
  static const double maxScale = 3.0;
  static const double minCandleWidth = 0.4;
  static const double maxCandleWidth = 50.0;
  static const double zoomRatio = 1.25;
  
  // --- 性能設定 ---
  static const int maxDataLimit = 100000;
  static const int maxDrawCandles = 200000;
  static const int maxGridLines = 6;
  static const int maxTimeGridLines = 8;
  static const int maxPriceLabels = 4;
  static const int maxTimeLabels = 4;
  
  // --- フォント設定 ---
  static const double labelFontSize = 11.0;
  static const double crosshairFontSize = 11.0;
  
  // --- 線の設定 ---
  static const double maLineWidth = 1.5;
  static const double gridLineWidth = 0.5;
  static const double crosshairLineWidth = 1.0;
  
  // --- ダッシュ線設定 ---
  static const double dashWidth = 5.0;
  static const double dashSpace = 3.0;
}
