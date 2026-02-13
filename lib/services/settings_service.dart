import 'dart:convert';
import 'dart:io';
import '../models/app_settings.dart';
import '../models/timeframe.dart';
import 'log_service.dart';
import 'path_service.dart';

/// 設定管理サービス
/// アプリケーション設定の保存、読み込み、管理を担当
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static SettingsService get instance => _instance;

  static const String _settingsFileName = 'app_settings.json';
  AppSettings? _cachedSettings;

  /// 設定ファイルパスを取得
  Future<String> get _settingsFilePath async {
    return await PathService.instance.getConfigFilePath(_settingsFileName);
  }

  /// 設定の読み込み
  Future<AppSettings> loadSettings() async {
    try {
      // キャッシュがある場合、直接返す
      if (_cachedSettings != null) {
        return _cachedSettings!;
      }

      final filePath = await _settingsFilePath;
      final file = File(filePath);

      if (!await file.exists()) {
        Log.info('SettingsService', '設定ファイルが存在しません、デフォルト設定を使用');
        _cachedSettings = AppSettings.getDefault();
        return _cachedSettings!;
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        Log.info('SettingsService', '設定ファイルが空です、デフォルト設定を使用');
        _cachedSettings = AppSettings.getDefault();
        return _cachedSettings!;
      }

      final Map<String, dynamic> jsonData = json.decode(contents);
      _cachedSettings = AppSettings.fromJson(jsonData);
      
      Log.info('SettingsService', '設定読み込み成功: ${_cachedSettings!.defaultTimeframe.displayName}');
      return _cachedSettings!;
    } catch (e) {
      Log.error('SettingsService', '設定読み込み失敗: $e、デフォルト設定を使用');
      _cachedSettings = AppSettings.getDefault();
      return _cachedSettings!;
    }
  }

  /// 設定の保存
  Future<bool> saveSettings(AppSettings settings) async {
    try {
      final filePath = await _settingsFilePath;
      final file = File(filePath);

      // キャッシュを更新
      _cachedSettings = settings;

      // JSONに変換して保存
      final jsonString = json.encode(settings.toJson());
      await file.writeAsString(jsonString);

      Log.info('SettingsService', '設定保存成功: ${settings.defaultTimeframe.displayName}');
      return true;
    } catch (e) {
      Log.error('SettingsService', '設定保存失敗: $e');
      return false;
    }
  }

  /// 設定の更新（増分更新）
  Future<bool> updateSettings(AppSettings Function(AppSettings) updater) async {
    try {
      final currentSettings = await loadSettings();
      final updatedSettings = updater(currentSettings);
      return await saveSettings(updatedSettings);
    } catch (e) {
      Log.error('SettingsService', '設定更新失敗: $e');
      return false;
    }
  }

  /// 設定をデフォルト値にリセット
  Future<bool> resetToDefault() async {
    try {
      final defaultSettings = AppSettings.getDefault();
      return await saveSettings(defaultSettings);
    } catch (e) {
      Log.error('SettingsService', '設定リセット失敗: $e');
      return false;
    }
  }

  /// 現在キャッシュされた設定を取得
  AppSettings? get currentSettings => _cachedSettings;

  /// キャッシュをクリア
  void clearCache() {
    _cachedSettings = null;
  }

  /// 設定ファイルの存在をチェック
  Future<bool> settingsFileExists() async {
    try {
      final filePath = await _settingsFilePath;
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      Log.error('SettingsService', '設定ファイル存在チェック失敗: $e');
      return false;
    }
  }

  /// 設定ファイルを削除
  Future<bool> deleteSettingsFile() async {
    try {
      final filePath = await _settingsFilePath;
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        _cachedSettings = null;
        Log.info('SettingsService', '設定ファイルが削除されました');
        return true;
      }
      return false;
    } catch (e) {
      Log.error('SettingsService', '設定ファイル削除失敗: $e');
      return false;
    }
  }

  /// 設定ファイル情報を取得
  Future<Map<String, dynamic>> getSettingsFileInfo() async {
    try {
      final filePath = await _settingsFilePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        return {
          'exists': false,
          'path': filePath,
          'size': 0,
          'lastModified': null,
        };
      }

      final stat = await file.stat();
      return {
        'exists': true,
        'path': filePath,
        'size': stat.size,
        'lastModified': stat.modified,
      };
    } catch (e) {
      Log.error('SettingsService', '設定ファイル情報取得失敗: $e');
      return {
        'exists': false,
        'path': 'unknown',
        'size': 0,
        'lastModified': null,
        'error': e.toString(),
      };
    }
  }

  /// 設定をJSON文字列にエクスポート
  Future<String?> exportSettings() async {
    try {
      final settings = await loadSettings();
      return json.encode(settings.toJson());
    } catch (e) {
      Log.error('SettingsService', '設定エクスポート失敗: $e');
      return null;
    }
  }

  /// JSON文字列から設定をインポート
  Future<bool> importSettings(String jsonString) async {
    try {
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final settings = AppSettings.fromJson(jsonData);
      return await saveSettings(settings);
    } catch (e) {
      Log.error('SettingsService', '設定インポート失敗: $e');
      return false;
    }
  }

  /// 設定の有効性を検証
  bool validateSettings(AppSettings settings) {
    try {
      // 時間周期が有効かチェック
      if (!Timeframe.values.contains(settings.defaultTimeframe)) {
        return false;
      }

      // 自動更新間隔が合理的かチェック
      if (settings.autoUpdateIntervalMinutes < 1 || settings.autoUpdateIntervalMinutes > 60) {
        return false;
      }

      // ズームレベルが合理的かチェック
      if (settings.chartZoomLevel < 0.1 || settings.chartZoomLevel > 10.0) {
        return false;
      }

      // テーマモードが有効かチェック
      if (!['light', 'dark', 'system'].contains(settings.themeMode)) {
        return false;
      }

      return true;
    } catch (e) {
      Log.error('SettingsService', '設定の検証に失敗しました: $e');
      return false;
    }
  }
}
