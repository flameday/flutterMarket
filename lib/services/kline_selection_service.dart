import 'dart:convert';
import 'dart:io';
import '../models/kline_selection.dart';
import '../models/price_data.dart';
import 'log_service.dart';
import 'path_service.dart';

/// K線選択区域サービスクラス
class KlineSelectionService {
  static const String _fileName = 'kline_selections.json';
  static KlineSelectionService? _instance;
  
  KlineSelectionService._();
  
  static KlineSelectionService get instance {
    _instance ??= KlineSelectionService._();
    return _instance!;
  }

  /// ファイルパスを取得
  Future<String> _getFilePath() async {
    return PathService.instance.getConfigFilePath(_fileName);
  }

  /// すべてのK線選択区域を読み込み
  Future<List<KlineSelection>> loadSelections() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => KlineSelection.fromJson(json)).toList();
    } catch (e) {
      Log.error('KlineSelectionService', 'K線選択区域の読み込みに失敗しました: $e');
      return [];
    }
  }

  /// すべてのK線選択区域を保存
  Future<bool> saveSelections(List<KlineSelection> selections) async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      
      final jsonList = selections.map((selection) => selection.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      Log.error('KlineSelectionService', 'K線選択区域の保存に失敗しました: $e');
      return false;
    }
  }

  /// 新しいK線選択区域を追加
  Future<bool> addSelection(KlineSelection selection) async {
    try {
      final selections = await loadSelections();
      selections.add(selection);
      return await saveSelections(selections);
    } catch (e) {
      Log.error('KlineSelectionService', 'K線選択区域の追加に失敗しました: $e');
      return false;
    }
  }

  /// K線選択区域を削除
  Future<bool> removeSelection(String id) async {
    try {
      final selections = await loadSelections();
      selections.removeWhere((selection) => selection.id == id);
      return await saveSelections(selections);
    } catch (e) {
      Log.error('KlineSelectionService', 'K線選択区域の削除に失敗しました: $e');
      return false;
    }
  }

  /// すべてのK線選択区域をクリア
  Future<bool> clearAllSelections() async {
    try {
      return await saveSelections([]);
    } catch (e) {
      Log.error('KlineSelectionService', 'K線選択区域のクリアに失敗しました: $e');
      return false;
    }
  }

  /// IDに基づいてK線選択区域を検索
  Future<KlineSelection?> findSelectionById(String id) async {
    try {
      final selections = await loadSelections();
      return selections.firstWhere(
        (selection) => selection.id == id,
        orElse: () => throw StateError('指定されたIDの選択区域が見つかりません'),
      );
    } catch (e) {
      return null;
    }
  }

  /// 指定した時間範囲内のK線選択区域を取得
  Future<List<KlineSelection>> getSelectionsInRange(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final selections = await loadSelections();
      return selections.where((selection) {
        return (selection.startTime.isBefore(endTime) || 
                selection.startTime.isAtSameMomentAs(endTime)) &&
               (selection.endTime.isAfter(startTime) || 
                selection.endTime.isAtSameMomentAs(startTime));
      }).toList();
    } catch (e) {
      Log.error('KlineSelectionService', '時間範囲内のK線選択区域の取得に失敗しました: $e');
      return [];
    }
  }

  /// 指定したK線インデックス範囲内の選択区域を取得
  /// 注意：このメソッドはK線データが必要です（インデックスをタイムスタンプに変換するため）
  Future<List<KlineSelection>> getSelectionsInIndexRange(
    int startIndex,
    int endIndex,
    List<PriceData> data,
  ) async {
    try {
      if (data.isEmpty || startIndex < 0 || endIndex >= data.length) {
        return [];
      }
      
      final selections = await loadSelections();
      final int startTimestamp = data[startIndex].timestamp;
      final int endTimestamp = data[endIndex].timestamp;
      
      return selections.where((selection) {
        return selection.startTimestamp <= endTimestamp && 
               selection.endTimestamp >= startTimestamp;
      }).toList();
    } catch (e) {
      Log.error('KlineSelectionService', 'インデックス範囲内のK線選択区域の取得に失敗しました: $e');
      return [];
    }
  }
}
