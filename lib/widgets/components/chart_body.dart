import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/price_data.dart';
import '../../services/chart_object_factory.dart';
import '../../widgets/chart_view_controller.dart';
import '../candlestick_painter.dart';

/// チャートボディコンポーネント
class ChartBody extends StatelessWidget {
  final List<PriceData> data;
  final ChartViewController controller;
  final double height;
  final Offset? crosshairPosition;
  final PriceData? hoveredCandle;
  final double? hoveredPrice;
  final Function(PointerHoverEvent) onPointerHover;
  final Function(PointerExitEvent) onPointerExit;
  final Function(PointerDownEvent) onPointerDown;
  final Function(ScaleUpdateDetails) onScaleUpdate;
  final Function(ScaleStartDetails) onScaleStart;
  final Function(ScaleEndDetails) onScaleEnd;
  final Function(TapUpDetails) onChartTap;
  final Function(PointerSignalEvent) onPointerSignal;

  const ChartBody({
    super.key,
    required this.data,
    required this.controller,
    required this.height,
    this.crosshairPosition,
    this.hoveredCandle,
    this.hoveredPrice,
    required this.onPointerHover,
    required this.onPointerExit,
    required this.onPointerDown,
    required this.onScaleUpdate,
    required this.onScaleStart,
    required this.onScaleEnd,
    required this.onChartTap,
    required this.onPointerSignal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double currentWidth = constraints.maxWidth;
        final double minPrice = _getMinPrice();
        final double maxPrice = _getMaxPrice();

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              // メインチャート
              Positioned.fill(
                child: Listener(
                  onPointerHover: onPointerHover,
                  onPointerDown: onPointerDown,
                  child: GestureDetector(
                    onScaleUpdate: onScaleUpdate,
                    onScaleStart: onScaleStart,
                    onScaleEnd: onScaleEnd,
                    onTapUp: onChartTap,
                    child: Listener(
                      onPointerSignal: onPointerSignal,
                      child: CustomPaint(
                        painter: CandlestickPainter(
                          data: data,
                          candleWidth: controller.candleWidth * controller.scale,
                          spacing: controller.spacing,
                          minPrice: minPrice,
                          maxPrice: maxPrice,
                          startIndex: controller.startIndex,
                          endIndex: controller.endIndex,
                          chartHeight: height - 80,
                          chartWidth: currentWidth,
                          emptySpaceWidth: controller.emptySpaceWidth,
                          crosshairPosition: crosshairPosition,
                          hoveredCandle: hoveredCandle,
                          hoveredPrice: hoveredPrice,
                          movingAverages: _getMovingAveragesData(),
                          maVisibility: controller.maVisibility,
                          verticalLines: controller.getVisibleVerticalLines(),
                          selectionStartX: controller.selectionStartX,
                          selectionEndX: controller.selectionEndX,
                          selectedKlineCount: controller.selectedKlineCount,
                          klineSelections: controller.getVisibleKlineSelections(),
                          mergedWavePoints: controller.getMergedWavePoints(),
                          isWavePointsVisible: controller.isWavePointsVisible,
                          isWavePointsLineVisible: controller.isWavePointsLineVisible,
                          manualHighLowPoints: controller.getVisibleManualHighLowPoints(),
                          isManualHighLowVisible: true,
                          chartObjects: ChartObjectFactory.build(
                            controller: controller,
                          ),
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getMinPrice() {
    if (data.isEmpty) return 0.0;
    
    final visibleData = data.sublist(
      controller.startIndex.clamp(0, data.length),
      controller.endIndex.clamp(0, data.length),
    );
    
    if (visibleData.isEmpty) return 0.0;
    
    return visibleData.map((candle) => candle.low).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxPrice() {
    if (data.isEmpty) return 0.0;
    
    final visibleData = data.sublist(
      controller.startIndex.clamp(0, data.length),
      controller.endIndex.clamp(0, data.length),
    );
    
    if (visibleData.isEmpty) return 0.0;
    
    return visibleData.map((candle) => candle.high).reduce((a, b) => a > b ? a : b);
  }

  Map<int, List<double>> _getMovingAveragesData() {
    Map<int, List<double>> maData = {};
    
    for (int period in controller.maPeriods) {
      if (controller.isMaVisible(period)) {
        final List<double>? ma = controller.getMovingAverage(period);
        if (ma != null) {
          maData[period] = ma;
        }
      }
    }
    
    return maData;
  }

}
