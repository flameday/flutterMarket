import '../models/chart_object.dart';
import 'chart_object_layer2_indicator_builder.dart';
import 'chart_object_layer3_interaction_builder.dart';
import '../widgets/chart_view_controller.dart';

class ChartObjectFactory {
  const ChartObjectFactory._();

  static List<ChartObject> build({
    required ChartViewController controller,
    List<TrendLineObject> trendLines = const [],
    String? selectedTrendLineId,
    bool includeTrendFiltering = false,
    bool includeFibonacciForSelectedTrendLine = false,
  }) {
    final objects = <ChartObject>[];

    ChartObjectLayer2IndicatorBuilder.append(
      objects,
      controller: controller,
      includeTrendFiltering: includeTrendFiltering,
    );

    ChartObjectLayer3InteractionBuilder.append(
      objects,
      controller: controller,
      trendLines: trendLines,
      selectedTrendLineId: selectedTrendLineId,
      includeFibonacciForSelectedTrendLine: includeFibonacciForSelectedTrendLine,
    );

    return objects;
  }
}
