import '../models/price_data.dart';
import '../models/kline_selection.dart';
import '../services/kline_selection_service.dart';

/// Mixinが依存するホストクラスのインターフェースを定義
abstract class KlineSelectionControllerHost {
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  int getCandleIndexFromX(double x, double chartWidth);
}

/// K線統計モードに関するロジックを管理するMixin
mixin KlineSelectionControllerMixin on KlineSelectionControllerHost {
  bool isKlineCountMode = false;
  double? _selectionStartX;
  double? _selectionEndX;
  int _selectedKlineCount = 0;
  List<KlineSelection> _klineSelections = [];

  /// Mixinを初期化
  Future<void> initKlineSelections() async {
    try {
      _klineSelections = await KlineSelectionService.instance.loadSelections();
      // print('K線選択区域を読み込み: ${_klineSelections.length}個');
    } catch (e) {
      // print('K線選択区域読み込み失敗: $e');
      _klineSelections = [];
    }
  }

  void startSelection(double x) {
    if (isKlineCountMode) {
      _selectionStartX = x;
      _selectionEndX = x;
      _selectedKlineCount = 0;
    }
  }

  void updateSelection(double x) {
    if (isKlineCountMode && _selectionStartX != null) {
      _selectionEndX = x;
    }
  }

  void finishSelection(double chartWidth) {
    if (isKlineCountMode && _selectionStartX != null && _selectionEndX != null) {
      final double startX = _selectionStartX!;
      final double endX = _selectionEndX!;
      
      final double minX = startX < endX ? startX : endX;
      final double maxX = startX < endX ? endX : startX;
      
      final int startCandleIndex = getCandleIndexFromX(minX, chartWidth);
      final int endCandleIndex = getCandleIndexFromX(maxX, chartWidth);
      
      if (startCandleIndex >= 0 && endCandleIndex >= 0 && startCandleIndex <= endCandleIndex) {
        _selectedKlineCount = endCandleIndex - startCandleIndex + 1;
      } else {
        _selectedKlineCount = 0;
      }
    }
  }

  void clearSelection() {
    _selectionStartX = null;
    _selectionEndX = null;
    _selectedKlineCount = 0;
  }

  double? get selectionStartX => _selectionStartX;
  double? get selectionEndX => _selectionEndX;
  int get selectedKlineCount => _selectedKlineCount;

  Future<bool> saveCurrentSelection(double chartWidth) async {
    if (_selectedKlineCount <= 0 || _selectionStartX == null || _selectionEndX == null) {
      return false;
    }

    try {
      final double startX = _selectionStartX!;
      final double endX = _selectionEndX!;
      
      final double minX = startX < endX ? startX : endX;
      final double maxX = startX < endX ? endX : startX;
      
      final int startCandleIndex = getCandleIndexFromX(minX, chartWidth);
      final int endCandleIndex = getCandleIndexFromX(maxX, chartWidth);
      
      if (startCandleIndex >= 0 && endCandleIndex >= 0 && startCandleIndex <= endCandleIndex) {
        final String id = DateTime.now().millisecondsSinceEpoch.toString();
        final DateTime startTime = DateTime.fromMillisecondsSinceEpoch(data[startCandleIndex].timestamp);
        final DateTime endTime = DateTime.fromMillisecondsSinceEpoch(data[endCandleIndex].timestamp);
        
        final KlineSelection selection = KlineSelection(
          id: id,
          startTimestamp: data[startCandleIndex].timestamp,
          endTimestamp: data[endCandleIndex].timestamp,
          klineCount: _selectedKlineCount,
          startTime: startTime,
          endTime: endTime,
          createdAt: DateTime.now(),
        );
        
        final bool success = await KlineSelectionService.instance.addSelection(selection);
        if (success) {
          _klineSelections.add(selection);
        }
        return success;
      }
    } catch (e) {
      // print('K線選択区域の保存に失敗しました: $e');
    }
    return false;
  }

  List<KlineSelection> getVisibleKlineSelections() {
    if (data.isEmpty) return [];
    
    // インデックスの境界チェック
    final int safeStartIndex = startIndex.clamp(0, data.length - 1);
    final int safeEndIndex = endIndex.clamp(0, data.length);
    
    if (safeStartIndex >= safeEndIndex) return [];
    
    // 表示範囲内のタイムスタンプ範囲を取得
    final int startTimestamp = data[safeStartIndex].timestamp;
    final int endTimestamp = data[safeEndIndex - 1].timestamp;
    
    return _klineSelections.where((selection) {
      return selection.startTimestamp <= endTimestamp && 
            selection.endTimestamp >= startTimestamp;
    }).toList();
  }

  Future<bool> removeKlineSelection(String id) async {
    try {
      final bool success = await KlineSelectionService.instance.removeSelection(id);
      if (success) {
        _klineSelections.removeWhere((selection) => selection.id == id);
      }
      return success;
    } catch (e) {
      // print('K線選択区域の削除に失敗しました: $e');
      return false;
    }
  }

  Future<bool> clearAllKlineSelections() async {
    try {
      final bool success = await KlineSelectionService.instance.clearAllSelections();
      if (success) {
        _klineSelections.clear();
      }
      return success;
    } catch (e) {
      // print('K線選択区域のクリアに失敗しました: $e');
      return false;
    }
  }

  KlineSelection? findKlineSelectionAtPosition(double x, double chartWidth) {
    final int candleIndex = getCandleIndexFromX(x, chartWidth);
    if (candleIndex < 0 || candleIndex >= data.length) return null;
    
    final int timestamp = data[candleIndex].timestamp;
    
    try {
      return _klineSelections.firstWhere(
        (selection) => timestamp >= selection.startTimestamp && 
                      timestamp <= selection.endTimestamp,
      );
    } catch (e) {
      return null;
    }
  }

  List<KlineSelection> get klineSelections => List.unmodifiable(_klineSelections);
}
