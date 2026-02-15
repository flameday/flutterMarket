import '../models/price_data.dart';
import '../models/wave_points.dart';

abstract class WavePointsControllerHost {
  void notifyUIUpdate();
  List<PriceData> get data;
  Map<int, List<double?>> getMovingAveragesData();
}

mixin WavePointsControllerMixin on WavePointsControllerHost {
  WavePoints? wavePoints;
  bool isWavePointsVisible = false;
  bool isWavePointsLineVisible = false;

  final Map<int, String> _manualWavePoints = {};

  void initWavePoints() {
    _recomputeWavePoints(notify: false);
  }

  void onDataUpdatedForWavePoints() {
    _recomputeWavePoints(notify: false);
  }

  void toggleWavePointsVisibility() {
    isWavePointsVisible = !isWavePointsVisible;
    notifyUIUpdate();
  }

  void toggleWavePointsLineVisibility() {
    isWavePointsLineVisible = !isWavePointsLineVisible;
    notifyUIUpdate();
  }

  List<Map<String, dynamic>> getMergedWavePoints() {
    return wavePoints?.mergedPoints ?? const [];
  }

  void _recomputeWavePoints({required bool notify}) {
    if (data.isEmpty) {
      wavePoints = null;
      if (notify) notifyUIUpdate();
      return;
    }

    wavePoints = WavePoints.fromPriceData(
      data,
      getMovingAveragesData(),
      _manualWavePoints,
    );

    if (notify) {
      notifyUIUpdate();
    }
  }
}
