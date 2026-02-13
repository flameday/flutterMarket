import 'dart:convert';
import 'dart:io';
import 'log_service.dart';
import 'path_service.dart';

class WavePointsService {
  static final WavePointsService _instance = WavePointsService._internal();
  factory WavePointsService() => _instance;
  WavePointsService._internal();

  static WavePointsService get instance => _instance;

  Future<File> get _localFile async {
    final filePath = await PathService.instance.getConfigFilePath('wave_points.json');
    return File(filePath);
  }

  /// 手動ウェーブポイントデータを保存
  Future<bool> saveManualWavePoints(Map<int, String> manualWavePoints) async {
    try {
      final file = await _localFile;
      final Map<String, dynamic> data = {
        'manualWavePoints': manualWavePoints.map((key, value) => MapEntry(key.toString(), value)),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(json.encode(data));
      return true;
    } catch (e) {
      Log.error('WavePointsService', 'Error saving manual wave points: $e');
      return false;
    }
  }

  /// 手動ウェーブポイントデータを読み込み
  Future<Map<int, String>> loadManualWavePoints() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {};
      }
      final contents = await file.readAsString();
      final Map<String, dynamic> data = json.decode(contents);
      
      final Map<String, dynamic>? manualWavePointsData = data['manualWavePoints'];
      if (manualWavePointsData != null) {
        return manualWavePointsData.map((key, value) => MapEntry(int.parse(key), value as String));
      }
      return {};
    } catch (e) {
      Log.error('WavePointsService', 'Error loading manual wave points: $e');
      return {};
    }
  }

  /// 手動ウェーブポイントを追加
  Future<bool> addManualWavePoint(int timestamp, String type) async {
    try {
      final currentPoints = await loadManualWavePoints();
      currentPoints[timestamp] = type;
      return saveManualWavePoints(currentPoints);
    } catch (e) {
      Log.error('WavePointsService', 'Error adding manual wave point: $e');
      return false;
    }
  }

  /// 手動ウェーブポイントを削除
  Future<bool> removeManualWavePoint(int timestamp) async {
    try {
      final currentPoints = await loadManualWavePoints();
      currentPoints[timestamp] = 'removed';
      return saveManualWavePoints(currentPoints);
    } catch (e) {
      Log.error('WavePointsService', 'Error removing manual wave point: $e');
      return false;
    }
  }

  /// すべての手動ウェーブポイントをクリア
  Future<bool> clearAllManualWavePoints() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      Log.error('WavePointsService', 'Error clearing manual wave points: $e');
      return false;
    }
  }

  /// ウェーブポイント統計情報を取得
  Future<Map<String, dynamic>> getWavePointsStats() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {
          'totalPoints': 0,
          'highPoints': 0,
          'lowPoints': 0,
          'removedPoints': 0,
          'lastUpdated': null,
        };
      }
      
      final contents = await file.readAsString();
      final Map<String, dynamic> data = json.decode(contents);
      final Map<String, dynamic>? manualWavePointsData = data['manualWavePoints'];
      
      if (manualWavePointsData == null) {
        return {
          'totalPoints': 0,
          'highPoints': 0,
          'lowPoints': 0,
          'removedPoints': 0,
          'lastUpdated': data['lastUpdated'],
        };
      }
      
      int highPoints = 0;
      int lowPoints = 0;
      int removedPoints = 0;
      
      for (final type in manualWavePointsData.values) {
        switch (type) {
          case 'high':
            highPoints++;
            break;
          case 'low':
            lowPoints++;
            break;
          case 'removed':
            removedPoints++;
            break;
        }
      }
      
      return {
        'totalPoints': manualWavePointsData.length,
        'highPoints': highPoints,
        'lowPoints': lowPoints,
        'removedPoints': removedPoints,
        'lastUpdated': data['lastUpdated'],
      };
    } catch (e) {
      Log.error('WavePointsService', 'Error getting wave points stats: $e');
      return {
        'totalPoints': 0,
        'highPoints': 0,
        'lowPoints': 0,
        'removedPoints': 0,
        'lastUpdated': null,
      };
    }
  }
}
