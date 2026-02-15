import '../models/price_data.dart';
import '../models/vertical_line.dart';

abstract class VerticalLineControllerHost {
  void notifyUIUpdate();
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  int getCandleIndexFromX(double x, double chartWidth);
  void toggleVerticalLineMode();
}

mixin VerticalLineControllerMixin on VerticalLineControllerHost {
  final List<VerticalLine> _verticalLines = [];
  bool isVerticalLineMode = false;

  List<VerticalLine> get verticalLines => List.unmodifiable(_verticalLines);

  void initVerticalLines() {
    _verticalLines.clear();
  }

  Future<void> addVerticalLineAtPosition(double x, double chartWidth) async {
    if (data.isEmpty) return;
    final int index = getCandleIndexFromX(x, chartWidth);
    if (index < 0 || index >= data.length) return;

    final int timestamp = data[index].timestamp;
    final int existingIndex = _verticalLines.indexWhere((line) => line.timestamp == timestamp);
    if (existingIndex >= 0) {
      _verticalLines[existingIndex] = _verticalLines[existingIndex].copyWith(createdAt: DateTime.now());
    } else {
      _verticalLines.add(
        VerticalLine(
          id: 'vl-$timestamp',
          timestamp: timestamp,
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyUIUpdate();
  }

  Future<bool> removeVerticalLineNearPosition(double x, double chartWidth) async {
    if (_verticalLines.isEmpty || data.isEmpty) return false;

    final int targetIndex = getCandleIndexFromX(x, chartWidth);
    if (targetIndex < 0 || targetIndex >= data.length) return false;

    int bestLineIndex = -1;
    int bestDistance = 1 << 30;

    for (int i = 0; i < _verticalLines.length; i++) {
      final int lineTimestamp = _verticalLines[i].timestamp;
      final int lineIndex = _findNearestIndexByTimestamp(lineTimestamp);
      if (lineIndex < 0) continue;
      final int distance = (lineIndex - targetIndex).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestLineIndex = i;
      }
    }

    if (bestLineIndex < 0 || bestDistance > 2) {
      return false;
    }

    _verticalLines.removeAt(bestLineIndex);
    notifyUIUpdate();
    return true;
  }

  Future<void> clearAllVerticalLines() async {
    if (_verticalLines.isEmpty) return;
    _verticalLines.clear();
    notifyUIUpdate();
  }

  List<VerticalLine> getVisibleVerticalLines() {
    if (_verticalLines.isEmpty || data.isEmpty) return const [];

    final int safeStart = startIndex.clamp(0, data.length - 1);
    final int safeEndExclusive = endIndex.clamp(0, data.length);
    if (safeEndExclusive <= safeStart) return const [];

    final int minTs = data[safeStart].timestamp;
    final int maxTs = data[safeEndExclusive - 1].timestamp;

    return _verticalLines
        .where((line) => line.timestamp >= minTs && line.timestamp <= maxTs)
        .toList(growable: false);
  }

  void disposeVerticalLineController() {
    _verticalLines.clear();
  }

  int _findNearestIndexByTimestamp(int timestamp) {
    if (data.isEmpty) return -1;

    int low = 0;
    int high = data.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final int value = data[mid].timestamp;
      if (value == timestamp) return mid;
      if (value < timestamp) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (low >= data.length) return data.length - 1;
    if (high < 0) return 0;

    final int lowDiff = (data[low].timestamp - timestamp).abs();
    final int highDiff = (data[high].timestamp - timestamp).abs();
    return lowDiff < highDiff ? low : high;
  }
}
