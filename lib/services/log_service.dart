import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'path_service.dart';

/// ログレベル列挙型
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// ログサービスクラス
class LogService {
  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._internal();
  
  LogService._internal();
  
  File? _logFile;
  final List<String> _logBuffer = [];
  Timer? _flushTimer;
  static const int _bufferSize = 100; // バッファサイズ
  static const Duration _flushInterval = Duration(seconds: 5); // フラッシュ間隔
  
  /// ログサービスの初期化
  Future<void> initialize() async {
    try {
      // 使用统一的路径管理服务
      final now = DateTime.now();
      final logFileName = 'flutter_drawer_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
      final logFilePath = await PathService.instance.getLogFilePath(logFileName);
      _logFile = File(logFilePath);
      
      // 定期的なフラッシュを開始
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBuffer());
      
      await _writeLog('INFO', 'LogService', 'ログサービス初期化完了 - ログファイル: $logFilePath');
    } catch (e) {
      // 初期化に失敗した場合、少なくともprintが動作することを保証
      // ignore: avoid_print
      print('ログサービス初期化失敗: $e');
    }
  }
  
  /// ログの書き込み
  Future<void> _writeLog(String level, String tag, String message, [StackTrace? stackTrace]) async {
    try {
      // 行号情報を取得
      String locationInfo = '';
      if (stackTrace != null) {
        locationInfo = _extractLocationInfo(stackTrace);
      }
      
      if (_logFile == null) {
        // ignore: avoid_print
        print('[$level] $tag$locationInfo: $message');
        return;
      }
      
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [$level] $tag$locationInfo: $message\n';
      
      _logBuffer.add(logEntry);
      
      // バッファが満杯の場合、即座にフラッシュ
      if (_logBuffer.length >= _bufferSize) {
        await _flushBuffer();
      }
    } catch (e) {
      // ignore: avoid_print
      print('ログ書き込み失敗: $e');
    }
  }
  
  /// スタックトレースから位置情報を抽出
  String _extractLocationInfo(StackTrace stackTrace) {
    try {
      final lines = stackTrace.toString().split('\n');
      // 通常、最初の行は現在のメソッド、2行目が呼び出し元
      if (lines.length >= 2) {
        final callerLine = lines[1].trim();
        // 例: "#1      _CandlestickChartState._performAutoUpdate (package:flutter_drawer_app/candlestick_chart.dart:747:5)"
        
        // 関数名を抽出
        String functionName = '';
        final functionMatch = RegExp(r'#\d+\s+([^(]+)').firstMatch(callerLine);
        if (functionMatch != null) {
          functionName = functionMatch.group(1)?.trim() ?? '';
        }
        
        // ファイル名と行号を抽出
        final locationMatch = RegExp(r'\(([^:]+):(\d+):(\d+)\)').firstMatch(callerLine);
        if (locationMatch != null) {
          final filePath = locationMatch.group(1);
          final lineNumber = locationMatch.group(2);
          final columnNumber = locationMatch.group(3);
          
          // ファイル名のみを抽出（パスが長い場合）
          final fileName = filePath?.split('/').last ?? filePath ?? 'unknown';
          
          // 関数名が空でない場合は含める
          if (functionName.isNotEmpty) {
            return ' ($fileName:$lineNumber:$columnNumber in $functionName)';
          } else {
            return ' ($fileName:$lineNumber:$columnNumber)';
          }
        }
      }
    } catch (e) {
      // 位置情報の抽出に失敗した場合は無視
    }
    return '';
  }
  
  /// バッファをファイルにフラッシュ
  Future<void> _flushBuffer() async {
    if (_logBuffer.isEmpty || _logFile == null) return;
    
    try {
      await _logFile!.writeAsString(_logBuffer.join(''), mode: FileMode.append, encoding: utf8);
      _logBuffer.clear();
    } catch (e) {
      // ignore: avoid_print
      print('ログバッファフラッシュ失敗: $e');
    }
  }
  
  /// デバッグログ
  void debug(String tag, String message) {
    _writeLog('DEBUG', tag, message, StackTrace.current);
  }
  
  /// 情報ログ
  void info(String tag, String message) {
    _writeLog('INFO', tag, message, StackTrace.current);
  }
  
  /// 警告ログ
  void warning(String tag, String message) {
    _writeLog('WARNING', tag, message, StackTrace.current);
  }
  
  /// エラーログ
  void error(String tag, String message) {
    _writeLog('ERROR', tag, message, StackTrace.current);
  }
  
  /// ログファイルパスを取得
  String? get logFilePath => _logFile?.path;
  
  /// 古いログファイルのクリーンアップ（最近7日間を保持）
  Future<void> cleanupOldLogs() async {
    try {
      final logDirPath = await PathService.instance.getLogDirectory();
      final logDir = Directory(logDirPath);
      
      if (!await logDir.exists()) return;
      
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 7));
      
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            await _writeLog('INFO', 'LogService', '古いログファイルを削除: ${entity.path}');
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('古いログファイルのクリーンアップ失敗: $e');
    }
  }
  
  /// ログサービスの終了
  Future<void> dispose() async {
    await _flushBuffer();
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}

/// グローバルログ関数、使用の利便性のため
class Log {
  static void debug(String tag, String message) {
    LogService.instance.debug(tag, message);
  }
  
  static void info(String tag, String message) {
    LogService.instance.info(tag, message);
  }
  
  static void warning(String tag, String message) {
    LogService.instance.warning(tag, message);
  }
  
  static void error(String tag, String message) {
    LogService.instance.error(tag, message);
  }
}
