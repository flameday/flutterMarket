import 'package:flutter/material.dart';
import '../constants/chart_constants.dart';
import '../models/price_data.dart';

/// Mixinが依存するホストクラスのインターフェースを定義
abstract class ChartZoomControllerHost {
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  double get scale;
  set scale(double value);
  set startIndex(int value);
  set endIndex(int value);
  double get candleWidth;
  double get spacing;
  double get emptySpaceWidth;
  double get totalCandleWidth;
  int getCandleIndexFromX(double x, double chartWidth);
}

/// チャートのズームとパン操作に関するロジックを管理するMixin
mixin ChartZoomControllerMixin on ChartZoomControllerHost {
  // 鼠标位置缩放设置
  bool _isMousePositionZoomEnabled = false;
  /// K線幅の制限を適用したスケール値を取得
  double _clampScaleForCandleWidth(double newScale) {
    const double minCandleWidth = ChartConstants.minCandleWidth; // 最小K線幅
    const double maxCandleWidth = ChartConstants.maxCandleWidth; // 最大K線幅
    
    final double minScaleForMinWidth = minCandleWidth / candleWidth;
    final double maxScaleForMaxWidth = maxCandleWidth / candleWidth;
    
    return newScale.clamp(minScaleForMinWidth, maxScaleForMaxWidth);
  }

  void onScaleUpdate(ScaleUpdateDetails details, double chartWidth) {
    if (details.scale != 1.0) {
      final double oldScale = scale;
      final double newScale = scale * details.scale;
      final double clampedScale = _clampScaleForCandleWidth(newScale);
      
      if (oldScale != clampedScale) {
        scale = clampedScale;
        adjustCandlesAfterZoom(oldScale, chartWidth);
      }
    }

    if (details.focalPointDelta.dx != 0) {
      handlePanGesture(details.focalPointDelta, chartWidth);
    }
  }

  void handlePanGesture(Offset delta, double chartWidth) {
    if (totalCandleWidth <= 0) return;

    final double dragSensitivity = 1.0;
    final int candleOffset =
        (delta.dx * dragSensitivity / totalCandleWidth).round();

    if (candleOffset != 0) {
      final int visibleCandles = endIndex - startIndex;
      int newStartIndex = startIndex - candleOffset;
      int newEndIndex = endIndex - candleOffset;

      if (newStartIndex < 0) {
        newStartIndex = 0;
        newEndIndex = (newStartIndex + visibleCandles).clamp(0, data.length);
        // 如果endIndex被限制，重新计算startIndex
        if (newEndIndex < newStartIndex + visibleCandles) {
          newStartIndex = (newEndIndex - visibleCandles).clamp(0, data.length);
        }
      }

      final int maxEmptyCandles = ((chartWidth / 2) / totalCandleWidth).floor();
      final int maxEndIndex = data.length + maxEmptyCandles;

      if (newEndIndex > maxEndIndex) {
        newEndIndex = maxEndIndex;
        newStartIndex = newEndIndex - visibleCandles;
      }

      startIndex = newStartIndex;
      endIndex = newEndIndex;
    }
  }

  void adjustCandlesAfterZoom(double oldScale, double chartWidth) {
    if (data.isEmpty) return;

    final double candleDrawingWidth = chartWidth - emptySpaceWidth;

    final double totalCandleWidthOld = (candleWidth * oldScale) + spacing;
    final double totalCandleWidthNew = totalCandleWidth;

    if (totalCandleWidthNew <= 0 || totalCandleWidthOld <= 0) return;

    final int visibleCandlesNew =
        (candleDrawingWidth / totalCandleWidthNew).floor();

    if (endIndex > data.length) {
      final pivotIndex = data.length;
      final double candlesAfterPivotOld = (endIndex - pivotIndex).toDouble();
      final double candlesAfterPivotNew =
          candlesAfterPivotOld * (totalCandleWidthOld / totalCandleWidthNew);
      final int newEndIndex = (pivotIndex + candlesAfterPivotNew).round();

      endIndex = newEndIndex;
      startIndex = endIndex - visibleCandlesNew;
    } else {
      startIndex = endIndex - visibleCandlesNew;
    }

    if (startIndex >= endIndex) {
      startIndex = endIndex - 1;
    }
  }

  void zoomIn(double chartWidth) {
    final double oldScale = scale;
    final double newScale = scale * 1.2;
    final double clampedScale = _clampScaleForCandleWidth(newScale);
    
    if (oldScale != clampedScale) {
      scale = clampedScale;
      adjustCandlesAfterZoom(oldScale, chartWidth);
    }
  }

  void zoomOut(double chartWidth) {
    final double oldScale = scale;
    final double newScale = scale / 1.2;
    final double clampedScale = _clampScaleForCandleWidth(newScale);
    
    if (oldScale != clampedScale) {
      scale = clampedScale;
      adjustCandlesAfterZoom(oldScale, chartWidth);
    }
  }

  /// マウスホイール用の細かいズーム操作
  void zoomWithMouseWheel(double chartWidth, double scrollDelta) {
    const double wheelZoomRatio = 1.25; // マウスホイールのズーム比例
    final double oldScale = scale;
    
    // スクロール量に基づいてスケールを調整
    double newScale;
    if (scrollDelta > 0) {
      // 上向きスクロール = ズームイン
      newScale = scale * wheelZoomRatio;
    } else {
      // 下向きスクロール = ズームアウト
      newScale = scale / wheelZoomRatio;
    }
    
    final double clampedScale = _clampScaleForCandleWidth(newScale);
    
    if (oldScale != clampedScale) {
      scale = clampedScale;
      adjustCandlesAfterZoom(oldScale, chartWidth);
    }
  }

  void scrollLeft() {
    if (startIndex > 0) {
      startIndex--;
      endIndex--;
    }
  }

  void scrollRight(double chartWidth) {
    if (totalCandleWidth <= 0) return;

    final int maxEmptyCandles = ((chartWidth / 2) / totalCandleWidth).floor();
    final int maxEndIndex = data.length + maxEmptyCandles;

    if (endIndex < maxEndIndex) {
      startIndex++;
      endIndex++;
    }
  }

  void adjustViewForResize(double chartWidth) {
    if (data.isEmpty) return;

    // 大量データの場合は表示範囲を制限（最後の1万件を表示）
    const int maxDataLimit = ChartConstants.maxDataLimit;
    if (data.length > maxDataLimit) {
      // 最後の1万件を表示するように設定
      endIndex = data.length;
      startIndex = data.length - maxDataLimit;
      // print('大量データのため最後の$maxDataLimit件を表示: $startIndex - $endIndex');
    } else {
      // データ数が制限以下の場合は全データを表示
      endIndex = data.length;
      startIndex = 0;
    }

    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    if (totalCandleWidth <= 0) {
      if (data.length > 200) {
        startIndex = (endIndex - 200).clamp(0, data.length);
      } else {
        startIndex = 0;
      }
      return;
    }

    final int visibleCandlesNew = (candleDrawingWidth / totalCandleWidth).floor();
    // 表示可能なK線数が制限より少ない場合は調整
    if (visibleCandlesNew < (endIndex - startIndex)) {
      startIndex = (endIndex - visibleCandlesNew).clamp(0, data.length);
    }
  }

  void resetView(double chartWidth, {bool preserveScale = false}) {
    if (!preserveScale) {
      scale = 1.0;
    }
    
    // 大量データの場合は表示範囲を制限（最後の1万件を表示）
    const int maxDataLimit = ChartConstants.maxDataLimit;
    if (data.length > maxDataLimit) {
      // 最後の1万件を表示するように設定
      endIndex = data.length;
      startIndex = data.length - maxDataLimit;
      // print('大量データのため最後の$maxDataLimit件を表示: $startIndex - $endIndex');
    } else {
      // データ数が制限以下の場合は全データを表示
      endIndex = data.length;
      startIndex = 0;
    }

    if (chartWidth > 0) {
      final candleDrawingWidth = chartWidth - emptySpaceWidth;
      if (totalCandleWidth > 0) {
        final int visibleCandles =
            (candleDrawingWidth / totalCandleWidth).floor();
        // 表示可能なK線数が制限より少ない場合は調整
        if (visibleCandles < (endIndex - startIndex)) {
          startIndex = (endIndex - visibleCandles).clamp(0, data.length);
        }
      }
    } else {
      // Fallback for when width is not available yet
      if (data.length > 200) {
        startIndex = (endIndex - 200).clamp(0, data.length);
      } else {
        startIndex = 0;
      }
    }
  }

  // 鼠标位置缩放相关方法
  
  /// 获取鼠标位置缩放是否启用
  bool get isMousePositionZoomEnabled => _isMousePositionZoomEnabled;
  
  /// 设置鼠标位置缩放是否启用
  void setMousePositionZoomEnabled(bool enabled) {
    _isMousePositionZoomEnabled = enabled;
  }
  
  /// 切换鼠标位置缩放设置
  void toggleMousePositionZoom() {
    _isMousePositionZoomEnabled = !_isMousePositionZoomEnabled;
  }
  
  /// 以鼠标位置为原点进行缩放
  void zoomWithMousePosition(double chartWidth, double scrollDelta, Offset mousePosition) {
    if (!_isMousePositionZoomEnabled) {
      // 如果未启用鼠标位置缩放，使用默认的右侧缩放
      zoomWithMouseWheel(chartWidth, scrollDelta);
      return;
    }
    
    const double wheelZoomRatio = 1.25;
    final double oldScale = scale;
    
    // 计算缩放前的鼠标位置对应的K线索引
    final int mouseCandleIndex = getCandleIndexFromX(mousePosition.dx, chartWidth);
    
    // 计算新的缩放比例
    double newScale;
    if (scrollDelta > 0) {
      newScale = scale * wheelZoomRatio;
    } else {
      newScale = scale / wheelZoomRatio;
    }
    
    final double clampedScale = _clampScaleForCandleWidth(newScale);
    
    if (oldScale != clampedScale) {
      scale = clampedScale;
      adjustCandlesAfterZoomWithMousePosition(oldScale, chartWidth, mouseCandleIndex);
    }
  }
  
  /// 以鼠标位置为原点调整缩放后的K线显示范围
  void adjustCandlesAfterZoomWithMousePosition(double oldScale, double chartWidth, int pivotCandleIndex) {
    if (data.isEmpty) return;

    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final double totalCandleWidthOld = (candleWidth * oldScale) + spacing;
    final double totalCandleWidthNew = totalCandleWidth;

    if (totalCandleWidthNew <= 0 || totalCandleWidthOld <= 0) return;

    // 计算缩放前后可见K线数量的变化
    final int visibleCandlesOld = (candleDrawingWidth / totalCandleWidthOld).floor();
    final int visibleCandlesNew = (candleDrawingWidth / totalCandleWidthNew).floor();

    // 计算鼠标位置在可见K线中的相对位置
    final int relativeMousePosition = pivotCandleIndex - startIndex;
    
    // 确保鼠标位置在有效范围内
    if (relativeMousePosition < 0 || relativeMousePosition >= visibleCandlesOld) {
      // 如果鼠标位置超出范围，使用默认的右侧缩放
      adjustCandlesAfterZoom(oldScale, chartWidth);
      return;
    }
    
    // 计算鼠标位置的相对比例
    final double mouseRatio = relativeMousePosition / visibleCandlesOld;
    
    // 以鼠标位置为中心计算新的显示范围
    final int newRelativeMousePosition = (visibleCandlesNew * mouseRatio).round();
    final int newStartIndex = pivotCandleIndex - newRelativeMousePosition;
    final int newEndIndex = newStartIndex + visibleCandlesNew;
    
    // 边界检查
    if (newStartIndex < 0) {
      startIndex = 0;
      endIndex = visibleCandlesNew;
    } else if (newEndIndex > data.length) {
      endIndex = data.length;
      startIndex = (endIndex - visibleCandlesNew).clamp(0, data.length);
    } else {
      startIndex = newStartIndex;
      endIndex = newEndIndex;
    }
    
    // 最终边界检查
    if (startIndex >= endIndex) {
      startIndex = (endIndex - 1).clamp(0, data.length);
    }
  }
}
