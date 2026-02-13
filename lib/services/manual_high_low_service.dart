import 'dart:convert';
import 'dart:io';
import '../models/manual_high_low_point.dart';
import '../services/log_service.dart';
import 'path_service.dart';

/// 手動高低点サービス
class ManualHighLowService {
  static const String _fileName = 'manual_high_low_points.json';

  /// 高低点データを保存
  static Future<void> saveHighLowPoints(List<ManualHighLowPoint> points) async {
    try {
      final filePath = await PathService.instance.getConfigFilePath(_fileName);
      final file = File(filePath);
      final jsonString = jsonEncode(points.map((point) => point.toJson()).toList());
      await file.writeAsString(jsonString, encoding: utf8);
      
      Log.info('ManualHighLowService', '高低点データを保存しました: ${points.length}個 - ファイル: $filePath');
    } catch (e) {
      Log.error('ManualHighLowService', '高低点データの保存に失敗しました: $e');
    }
  }

  /// 高低点データを読み込み
  static Future<List<ManualHighLowPoint>> loadHighLowPoints() async {
    try {
      final filePath = await PathService.instance.getConfigFilePath(_fileName);
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString(encoding: utf8);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      final points = jsonList.map((json) => ManualHighLowPoint.fromJson(json)).toList();
      Log.info('ManualHighLowService', '高低点データを読み込みました: ${points.length}個 - ファイル: $filePath');
      return points;
    } catch (e) {
      Log.error('ManualHighLowService', '高低点データの読み込みに失敗しました: $e');
      return [];
    }
  }

  /// 高低点を追加
  static Future<void> addHighLowPoint(ManualHighLowPoint point) async {
    try {
      final List<ManualHighLowPoint> points = await loadHighLowPoints();
      points.add(point);
      await saveHighLowPoints(points);
      Log.info('ManualHighLowService', '高低点を追加しました: ${point.isHigh ? "高値" : "安値"} - ${point.price}');
    } catch (e) {
      Log.error('ManualHighLowService', '高低点の追加に失敗しました: $e');
    }
  }

  /// 高低点を削除
  static Future<void> removeHighLowPoint(String id) async {
    try {
      final List<ManualHighLowPoint> points = await loadHighLowPoints();
      points.removeWhere((point) => point.id == id);
      await saveHighLowPoints(points);
      Log.info('ManualHighLowService', '高低点を削除しました: $id');
    } catch (e) {
      Log.error('ManualHighLowService', '高低点の削除に失敗しました: $e');
    }
  }

  /// すべての高低点を削除
  static Future<void> clearAllHighLowPoints() async {
    try {
      await saveHighLowPoints([]);
      Log.info('ManualHighLowService', 'すべての高低点を削除しました');
    } catch (e) {
      Log.error('ManualHighLowService', '高低点の全削除に失敗しました: $e');
    }
  }

  /// タイムスタンプに基づいて高低点を検索
  static Future<List<ManualHighLowPoint>> getHighLowPointsByTimestamp(int timestamp) async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      return allPoints.where((point) => point.timestamp == timestamp).toList();
    } catch (e) {
      Log.error('ManualHighLowService', 'タイムスタンプによる高低点検索に失敗しました: $e');
      return [];
    }
  }

  /// 時間範囲に基づいて高低点を検索
  static Future<List<ManualHighLowPoint>> getHighLowPointsByTimeRange(
    int startTimestamp, 
    int endTimestamp
  ) async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      return allPoints.where((point) => 
        point.timestamp >= startTimestamp && point.timestamp <= endTimestamp
      ).toList();
    } catch (e) {
      Log.error('ManualHighLowService', '時間範囲による高低点検索に失敗しました: $e');
      return [];
    }
  }

  /// 高値のみを取得
  static Future<List<ManualHighLowPoint>> getHighPoints() async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      return allPoints.where((point) => point.isHigh).toList();
    } catch (e) {
      Log.error('ManualHighLowService', '高値の取得に失敗しました: $e');
      return [];
    }
  }

  /// 安値のみを取得
  static Future<List<ManualHighLowPoint>> getLowPoints() async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      return allPoints.where((point) => !point.isHigh).toList();
    } catch (e) {
      Log.error('ManualHighLowService', '安値の取得に失敗しました: $e');
      return [];
    }
  }

  /// 指定された価格範囲内の高低点を検索
  static Future<List<ManualHighLowPoint>> getHighLowPointsByPriceRange(
    double minPrice, 
    double maxPrice
  ) async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      return allPoints.where((point) => 
        point.price >= minPrice && point.price <= maxPrice
      ).toList();
    } catch (e) {
      Log.error('ManualHighLowService', '価格範囲による高低点検索に失敗しました: $e');
      return [];
    }
  }

  /// 最も近い高低点を検索
  static Future<ManualHighLowPoint?> findNearestHighLowPoint(
    int timestamp, 
    double price, 
    double maxDistance
  ) async {
    try {
      final List<ManualHighLowPoint> allPoints = await loadHighLowPoints();
      ManualHighLowPoint? nearestPoint;
      double minDistance = double.infinity;

      for (final point in allPoints) {
        // 時間距離と価格距離を組み合わせた距離を計算
        final timeDistance = (point.timestamp - timestamp).abs() / 1000.0; // 秒単位
        final priceDistance = (point.price - price).abs();
        
        // 正規化された距離を計算（時間と価格の重みを調整可能）
        final distance = (timeDistance / 3600.0) + (priceDistance / 100.0); // 時間は時間単位、価格は100単位で正規化
        
        if (distance < minDistance && distance <= maxDistance) {
          minDistance = distance;
          nearestPoint = point;
        }
      }

      if (nearestPoint != null) {
        Log.info('ManualHighLowService', '最も近い高低点を検索: ${nearestPoint.isHigh ? "高値" : "安値"} - 距離: $minDistance');
      }
      
      return nearestPoint;
    } catch (e) {
      Log.error('ManualHighLowService', '最も近い高低点の検索に失敗しました: $e');
      return null;
    }
  }
}
