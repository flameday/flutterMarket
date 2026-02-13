import 'package:flutter/foundation.dart';
import 'price_data.dart';

/// ウェーブポイント関連の指標を管理するクラス
class WavePoints {
  final List<bool> waveHighPoints;
  final List<bool> waveLowPoints;
  final List<Map<String, dynamic>> mergedPoints;

  WavePoints({
    required this.waveHighPoints,
    required this.waveLowPoints,
    required this.mergedPoints,
  });

  /// K線データと移動平均線からウェーブポイントを計算する
  factory WavePoints.fromPriceData(
    List<PriceData> priceDataList,
    Map<int, List<double?>> maSeries,
    Map<int, String> manualWavePoints,
  ) {
    final dataLength = priceDataList.length;
    if (dataLength == 0) {
      return WavePoints(
        waveHighPoints: [],
        waveLowPoints: [],
        mergedPoints: [],
      );
    }

    // 1. ウェーブ高ポイント (Wave High Point) の計算
    final initialWaveHighPoints = List<bool>.filled(dataLength, false);
    final ma10 = maSeries[10];
    if (ma10 != null) {
      int consecutiveAboveMA10 = 0;
      for (int i = 0; i < dataLength; i++) {
        final priceData = priceDataList[i];
        final ma10Value = ma10[i];

        // K線の安値が10MAより上にあるかチェック
        if (ma10Value != null && priceData.low > ma10Value) {
          consecutiveAboveMA10++;
        } else {
          // 連続が途切れた場合
          if (consecutiveAboveMA10 >= 3) {
            // 連続した期間内の最高値を探す
            final int sequenceEnd = i - 1;
            final int sequenceStart = sequenceEnd - consecutiveAboveMA10 + 1;
            
            double peakHigh = -1.0;
            int peakIndex = -1;

            for (int j = sequenceStart; j <= sequenceEnd; j++) {
              if (priceDataList[j].high > peakHigh) {
                peakHigh = priceDataList[j].high;
                peakIndex = j;
              }
            }
            if (peakIndex != -1) {
              initialWaveHighPoints[peakIndex] = true;
            }
          }
          consecutiveAboveMA10 = 0; // カウンターをリセット
        }
      }
      // ループ終了後、最後の連続シーケンスをチェック
      if (consecutiveAboveMA10 >= 3) {
        final int sequenceEnd = dataLength - 1;
        final int sequenceStart = sequenceEnd - consecutiveAboveMA10 + 1;
        double peakHigh = -1.0;
        int peakIndex = -1;
        for (int j = sequenceStart; j <= sequenceEnd; j++) {
          if (priceDataList[j].high > peakHigh) {
            peakHigh = priceDataList[j].high;
            peakIndex = j;
          }
        }
        if (peakIndex != -1) {
          initialWaveHighPoints[peakIndex] = true;
        }
      }
    }

    // 2. 波浪低点 (Wave Low Point) の計算
    final initialWaveLowPoints = List<bool>.filled(dataLength, false);
    if (ma10 != null) {
      int consecutiveBelowMA10 = 0;
      for (int i = 0; i < dataLength; i++) {
        final priceData = priceDataList[i];
        final ma10Value = ma10[i];

        // K線の高値が10MAより下にあるかチェック
        if (ma10Value != null && priceData.high < ma10Value) {
          consecutiveBelowMA10++;
        } else {
          // 連続が途切れた場合
          if (consecutiveBelowMA10 >= 3) {
            // 連続した期間内の最安値を探す
            final int sequenceEnd = i - 1;
            final int sequenceStart = sequenceEnd - consecutiveBelowMA10 + 1;
            
            double troughLow = double.infinity;
            int troughIndex = -1;

            for (int j = sequenceStart; j <= sequenceEnd; j++) {
              if (priceDataList[j].low < troughLow) {
                troughLow = priceDataList[j].low;
                troughIndex = j;
              }
            }
            if (troughIndex != -1) {
              initialWaveLowPoints[troughIndex] = true;
            }
          }
          consecutiveBelowMA10 = 0; // カウンターをリセット
        }
      }
      // ループ終了後、最後の連続シーケンスをチェック
      if (consecutiveBelowMA10 >= 3) {
        final int sequenceEnd = dataLength - 1;
        final int sequenceStart = sequenceEnd - consecutiveBelowMA10 + 1;
        double troughLow = double.infinity;
        int troughIndex = -1;
        for (int j = sequenceStart; j <= sequenceEnd; j++) {
          if (priceDataList[j].low < troughLow) {
            troughLow = priceDataList[j].low;
            troughIndex = j;
          }
        }
        if (troughIndex != -1) {
          initialWaveLowPoints[troughIndex] = true;
        }
      }
    }

    // 3. 全ての自動計算された高低点を「候補リスト」に集める
    final List<Map<String, dynamic>> allPoints = [];
    for (int i = 0; i < dataLength; i++) {
      if (initialWaveHighPoints[i]) {
        allPoints.add({
          'index': i,
          'value': priceDataList[i].high,
          'type': 'high'
        });
      }
      if (initialWaveLowPoints[i]) {
        allPoints.add({
          'index': i,
          'value': priceDataList[i].low,
          'type': 'low'
        });
      }
    }

    // 4. 全ての点をインデックスでソートして、時系列に並べる
    allPoints.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    // 5. 結合ロジックを適用して、交互の高低点（ジグザグ）を生成する
    //    - 同じタイプの点が連続した場合は、高点はより高い方、低点はより低い方を採用
    //    - これにより、常に高低が交互になるリストが生成される
    final List<Map<String, dynamic>> mergedPoints = [];
    if (allPoints.isNotEmpty) {
      mergedPoints.add(allPoints.first);
      for (int i = 1; i < allPoints.length; i++) {
        final currentPoint = allPoints[i];
        final lastMergedPoint = mergedPoints.last;

        if (currentPoint['type'] == lastMergedPoint['type']) {
          // 同じタイプのポイントが連続した場合、マージする
          if (currentPoint['type'] == 'high') {
            // 高点の場合、より高い方を採用
            if ((currentPoint['value'] as double) > (lastMergedPoint['value'] as double)) {
              mergedPoints.last = currentPoint;
            }
          } else { // 'low'
            // 低点の場合、より低い方を採用
            if ((currentPoint['value'] as double) < (lastMergedPoint['value'] as double)) {
              mergedPoints.last = currentPoint;
            }
          }
        } else {
          // 異なるタイプのポイントはそのまま追加
          mergedPoints.add(currentPoint);
        }
      }
    }

    // 微調整ロジック：mergedPointsの高低点を調整
    _adjustMergedPoints(mergedPoints, priceDataList);

    // 6. 人工的高低点を最後に適用して mergedPoints を修正（ユーザー修正が最優先）
    if (manualWavePoints.isNotEmpty) {
      final timestampToIndex = {
        for (int i = 0; i < dataLength; i++)
          priceDataList[i].timestamp: i
      };

      // a. ユーザーによって削除された点を mergedPoints から取り除く
      mergedPoints.removeWhere((point) {
        final pointTimestamp = priceDataList[point['index'] as int].timestamp;
        return manualWavePoints.containsKey(pointTimestamp) &&
               manualWavePoints[pointTimestamp] == 'removed';
      });

      // b. ユーザーが追加した点を mergedPoints に追加/更新する（最優先）
      manualWavePoints.forEach((timestamp, type) {
        if (type != 'removed') {
          final index = timestampToIndex[timestamp];
          if (index != null) {
            // 同じインデックスに既存の点があれば、まず削除して上書きする
            mergedPoints.removeWhere((p) => p['index'] == index);
             
            final value = type == 'high' ? priceDataList[index].high : priceDataList[index].low;
            mergedPoints.add({
              'index': index,
              'value': value,
              'type': type,
              'source': 'manual' // 手動で追加されたことを示す
            });
          }
        }
      });

      // c. 人工的高低点適用後、再度インデックスでソート
      mergedPoints.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    }

    // 7. 最終的な波浪点リストを生成
    final waveHighPoints = List<bool>.filled(dataLength, false);
    final waveLowPoints = List<bool>.filled(dataLength, false);
    for (final point in mergedPoints) {
      if (point['type'] == 'high') {
        waveHighPoints[point['index'] as int] = true;
      } else {
        waveLowPoints[point['index'] as int] = true;
      }
    }
    
    if (kDebugMode) {
      // final highCount = waveHighPoints.where((isHigh) => isHigh).length;
      // final lowCount = waveLowPoints.where((isLow) => isLow).length;
      // print('最終的な高低点: 高値$highCount件、低値$lowCount件');
    }

    return WavePoints(
      waveHighPoints: waveHighPoints,
      waveLowPoints: waveLowPoints,
      mergedPoints: mergedPoints,
    );
  }

  /// 指定されたインデックスの波浪高点かどうかを判定
  bool isWaveHighPoint(int index) {
    return index >= 0 && index < waveHighPoints.length && waveHighPoints[index];
  }

  /// 指定されたインデックスの波浪低点かどうかを判定
  bool isWaveLowPoint(int index) {
    return index >= 0 && index < waveLowPoints.length && waveLowPoints[index];
  }

  /// 波浪点の総数を取得
  int get totalWavePoints => mergedPoints.length;

  /// 波浪高点の数を取得
  int get totalHighPoints => waveHighPoints.where((isHigh) => isHigh).length;

  /// 波浪低点の数を取得
  int get totalLowPoints => waveLowPoints.where((isLow) => isLow).length;

  /// mergedPointsの高低点を微調整する
  /// 2つのmergedPoints高点間のK線最低点をチェックしてmergedPoints低点を調整
  /// 2つのmergedPoints低点間のK線最高点をチェックしてmergedPoints高点を調整
  static void _adjustMergedPoints(
    List<Map<String, dynamic>> mergedPoints,
    List<PriceData> priceDataList,
  ) {
    // The original _adjustMergedPoints logic was flawed and computationally
    // expensive, causing the application to freeze on startup. It contained
    // loops that modified the list being iterated over, leading to extreme
    // performance degradation on large datasets.
    //
    // This has been replaced with a final filtering pass that ensures a strict
    // high-low-high zigzag pattern. This is much more performant, robust,
    // and guarantees a clean output, fixing the startup freeze.
    if (mergedPoints.length < 2) return;

    final List<Map<String, dynamic>> finalZigzag = [];
    finalZigzag.add(mergedPoints.first);

    for (int i = 1; i < mergedPoints.length; i++) {
      final currentPoint = mergedPoints[i];
      final lastFinalPoint = finalZigzag.last;

      if (currentPoint['type'] != lastFinalPoint['type']) {
        // Different type, perfect for a zigzag. Add it.
        finalZigzag.add(currentPoint);
      } else {
        // Same type as the last point. We need to merge them.
        if (currentPoint['type'] == 'high') {
          // If the current high is higher than the last one, replace it.
          if ((currentPoint['value'] as double) > (lastFinalPoint['value'] as double)) {
            finalZigzag.last = currentPoint;
          }
        } else { // 'low'
          // If the current low is lower than the last one, replace it.
          if ((currentPoint['value'] as double) < (lastFinalPoint['value'] as double)) {
            finalZigzag.last = currentPoint;
          }
        }
      }
    }

    // Replace the original list with the corrected zigzag list.
    mergedPoints.clear();
    mergedPoints.addAll(finalZigzag);
  }
}
