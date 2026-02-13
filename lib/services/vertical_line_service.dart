import 'dart:convert';
import 'dart:io';
import '../models/vertical_line.dart';
import 'log_service.dart';
import 'path_service.dart';

/// 縦線データ管理サービス
class VerticalLineService {
  static const String _fileName = 'vertical_lines.json';

  /// ファイルパスを取得
  static Future<String> get _filePath async {
    return PathService.instance.getConfigFilePath(_fileName);
  }

  /// 縦線データをJSONファイルに保存
  static Future<void> saveVerticalLines(List<VerticalLine> verticalLines) async {
    try {
      final List<Map<String, dynamic>> jsonList = 
          verticalLines.map((line) => line.toJson()).toList();
      
      final String jsonString = jsonEncode(jsonList);
      final File file = File(await _filePath);
      
      await file.writeAsString(jsonString);
    } catch (e) {
      Log.error('VerticalLineService', '縦線データ保存失敗: $e');
    }
  }

  /// JSONファイルから縦線データを読み込み
  static Future<List<VerticalLine>> loadVerticalLines() async {
    try {
      final File file = File(await _filePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final String jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      return jsonList
          .map((json) => VerticalLine.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.error('VerticalLineService', '縦線データ読み込み失敗: $e');
      return [];
    }
  }

  /// 縦線を追加
  static Future<void> addVerticalLine(VerticalLine verticalLine) async {
    final List<VerticalLine> existingLines = await loadVerticalLines();
    existingLines.add(verticalLine);
    await saveVerticalLines(existingLines);
  }

  /// 縦線を削除
  static Future<void> removeVerticalLine(String id) async {
    final List<VerticalLine> existingLines = await loadVerticalLines();
    existingLines.removeWhere((line) => line.id == id);
    await saveVerticalLines(existingLines);
  }

  /// 縦線を更新
  static Future<void> updateVerticalLine(VerticalLine verticalLine) async {
    final List<VerticalLine> existingLines = await loadVerticalLines();
    final int index = existingLines.indexWhere((line) => line.id == verticalLine.id);
    
    if (index != -1) {
      existingLines[index] = verticalLine;
      await saveVerticalLines(existingLines);
    }
  }

  /// すべての縦線をクリア
  static Future<void> clearAllVerticalLines() async {
    await saveVerticalLines([]);
  }

  /// K線タイムスタンプに基づいて縦線を検索
  static Future<List<VerticalLine>> getVerticalLinesByTimestamp(int timestamp) async {
    final List<VerticalLine> allLines = await loadVerticalLines();
    return allLines.where((line) => line.timestamp == timestamp).toList();
  }

  /// 時間範囲に基づいて縦線を検索
  static Future<List<VerticalLine>> getVerticalLinesByTimeRange(
    int startTimestamp, 
    int endTimestamp
  ) async {
    final List<VerticalLine> allLines = await loadVerticalLines();
    return allLines.where((line) => 
      line.timestamp >= startTimestamp && line.timestamp <= endTimestamp
    ).toList();
  }
  // 根据时间戳删除竖线（跨窗口删除支持）
  static Future<bool> removeVerticalLineByTimestamp(int timestamp) async {
    try {
      final List<VerticalLine> allLines = await loadVerticalLines();
      final List<VerticalLine> linesToRemove = allLines.where((line) => 
        line.timestamp == timestamp
      ).toList();

      if (linesToRemove.isEmpty) {
        Log.info('VerticalLineService', '根据时间戳删除竖线 - 未找到时间戳为 $timestamp 的竖线');
        return false;
      }

      // 删除找到的竖线
      final List<VerticalLine> remainingLines = allLines.where((line) => 
        line.timestamp != timestamp
      ).toList();

      await saveVerticalLines(remainingLines);
      Log.info('VerticalLineService', '成功根据时间戳删除 ${linesToRemove.length} 条竖线');
      return true;
    } catch (e) {
      Log.error('VerticalLineService', '根据时间戳删除竖线失败: $e');
      return false;
    }
  }

  /// 根据时间戳范围删除竖线（跨窗口删除支持）
  static Future<int> removeVerticalLinesByTimestampRange(int startTimestamp, int endTimestamp) async {
    try {
      final List<VerticalLine> allLines = await loadVerticalLines();
      final List<VerticalLine> linesToRemove = allLines.where((line) => 
        line.timestamp >= startTimestamp && line.timestamp <= endTimestamp
      ).toList();

      if (linesToRemove.isEmpty) {
        Log.info('VerticalLineService', '根据时间戳范围删除竖线 - 在范围 $startTimestamp 到 $endTimestamp 内未找到竖线');
        return 0;
      }

      // 删除找到的竖线
      final List<VerticalLine> remainingLines = allLines.where((line) => 
        line.timestamp < startTimestamp || line.timestamp > endTimestamp
      ).toList();

      await saveVerticalLines(remainingLines);
      Log.info('VerticalLineService', '成功根据时间戳范围删除 ${linesToRemove.length} 条竖线');
      return linesToRemove.length;
    } catch (e) {
      Log.error('VerticalLineService', '根据时间戳范围删除竖线失败: $e');
      return 0;
    }
  }
}
