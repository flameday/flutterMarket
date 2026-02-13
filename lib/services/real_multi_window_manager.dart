import 'dart:io';
import 'dart:convert';
import 'log_service.dart';

/// 真のマルチウィンドウマネージャー
/// Process.startを使用して独立したFlutterプロセスウィンドウを作成
class RealMultiWindowManager {
  // ウィンドウID定数
  static const String m5WindowId = 'm5_chart';
  // static const String m30WindowId = 'm30_chart';
  static const String h4WindowId = 'h4_chart';

  // ウィンドウ設定 - 各ウィンドウに対応するデフォルト周期があるが、動的周期選択をサポート
  static const Map<String, Map<String, dynamic>> _windowConfigs = {
    m5WindowId: {
      'title': 'EURUSD-m5',
      'displayTitle': 'EUR/USD-5m',
      'timeframe': 'm5',
      'width': 1200.0,
      'height': 800.0,
      'minWidth': 800.0,
      'minHeight': 600.0,
      'defaultPeriod': 5, // 5分
      'supportsTimeframeSelection': true, // 周期選択をサポート
    },
    // m30WindowId: {
    //   'title': 'EURUSD-m30',
    //   'displayTitle': 'EUR/USD 30m',
    //   'timeframe': 'm30',
    //   'width': 1200.0,
    //   'height': 800.0,
    //   'minWidth': 800.0,
    //   'minHeight': 600.0,
    //   'defaultPeriod': 30, // 30M
    //   'supportsTimeframeSelection': true, // 周期選択をサポート
    // },
    h4WindowId: {
      'title': 'EURUSD-h4',
      'displayTitle': 'EUR/USD-4h',
      'timeframe': 'h4',
      'width': 1200.0,
      'height': 800.0,
      'minWidth': 800.0,
      'minHeight': 600.0,
      'defaultPeriod': 240, // 4時間 = 240分
      'supportsTimeframeSelection': true, // 周期選択をサポート
    },
  };

  // 実行中のプロセスを保存
  static final Map<String, Process> _runningProcesses = {};

  /// マルチウィンドウサポートをチェック
  static Future<bool> isMultiWindowSupported() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return true;
      }
      return false;
    } catch (e) {
      Log.error('RealMultiWindowManager', 'マルチウィンドウサポートチェック失敗: $e');
      return false;
    }
  }

  /// ウィンドウ設定を取得
  static Map<String, dynamic>? getWindowConfig(String windowId) {
    return _windowConfigs[windowId];
  }

  /// すべてのウィンドウ設定を取得
  static Map<String, Map<String, dynamic>> getAllWindowConfigs() {
    return Map.from(_windowConfigs);
  }

  /// ウィンドウが周期選択をサポートするかチェック
  static bool supportsTimeframeSelection(String windowId) {
    final config = _windowConfigs[windowId];
    return config?['supportsTimeframeSelection'] ?? false;
  }

  /// Flutter実行ファイルパスを検索
  static Future<String> _findFlutterPath() async {
    try {
      // まず 'where' コマンドを使用してflutterを検索
      final result = await Process.run('where', ['flutter']);
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final paths = result.stdout.toString().trim().split('\n');
        // .batファイルを優先検索、Windows上でより信頼性が高いため
        for (final path in paths) {
          if (path.trim().toLowerCase().endsWith('.bat')) {
            final finalPath = path.trim();
            Log.debug('RealMultiWindowManager', 'Flutterバッチファイルパスを発見: $finalPath');
            return finalPath;
          }
        }
        // .batファイルが見つからない場合、最初の結果を使用
        if (paths.isNotEmpty) {
          final finalPath = paths.first.trim();
          Log.debug('RealMultiWindowManager', '.batファイルが見つからない、最初の結果を使用: $finalPath');
          return finalPath;
        }
      }
    } catch (e) {
      Log.warning('RealMultiWindowManager', 'whereコマンド失敗: $e');
    }

    // whereコマンドが失敗した場合、一般的なFlutterインストールパスを試行
    final commonPaths = [
      r'C:\flutter\flutter\bin\flutter.bat',
      r'C:\flutter\bin\flutter.bat',
      r'C:\src\flutter\bin\flutter.bat',
      r'C:\tools\flutter\bin\flutter.bat',
      r'C:\Users\%USERNAME%\flutter\bin\flutter.bat',
    ];

    for (final path in commonPaths) {
      final expandedPath = path.replaceAll('%USERNAME%', Platform.environment['USERNAME'] ?? '');
      if (await File(expandedPath).exists()) {
        Log.debug('RealMultiWindowManager', 'Flutterパスを発見: $expandedPath');
        return expandedPath;
      }
    }

    // すべて見つからない場合、デフォルトのflutterコマンドを返す
    Log.info('RealMultiWindowManager', 'Flutterパスが見つからない、デフォルトコマンドを使用');
    return 'flutter';
  }

  /// 新しいウィンドウを作成
  static Future<bool> createWindow({
    required String windowId,
    required Map<String, dynamic> data,
    int? screenIndex,
  }) async {
    try {
      Log.info('RealMultiWindowManager', 'ウィンドウ作成 $windowId');

      final config = _windowConfigs[windowId];
      if (config == null) {
        Log.error('RealMultiWindowManager', '未知のウィンドウID: $windowId');
        return false;
      }

      // ウィンドウが既に実行されているかチェック
      if (_runningProcesses.containsKey(windowId)) {
        final process = _runningProcesses[windowId]!;
        try {
          // 終了コードを取得しようと試行、プロセスがまだ実行中の場合例外が発生
          await process.exitCode.timeout(const Duration(milliseconds: 100));
          // 終了コードを取得できる場合、プロセスが終了したことを意味
          _runningProcesses.remove(windowId);
        } catch (e) {
          // プロセスはまだ実行中
          Log.info('RealMultiWindowManager', 'ウィンドウ $windowId は既に実行中');
          return true;
        }
      }

      // 現在の作業ディレクトリを取得
      final currentDir = Directory.current.path;
      Log.debug('RealMultiWindowManager', '現在の作業ディレクトリ: $currentDir');

      // Flutterパスを見つけようと試行
      String flutterPath = await _findFlutterPath();
      Log.debug('RealMultiWindowManager', 'Flutterパス: $flutterPath');

      // 設定文字列を準備
      final appConfig = '${config['title']},${config['timeframe']}';

      // Flutterプロセスを直接起動
      final process = await Process.start(
        flutterPath,
        [
          'run',
          '-d',
          'windows',
          '--dart-define=APP_CONFIG=$appConfig',
        ],
        workingDirectory: currentDir,
        runInShell: true, // 修正：Windowsで.batファイルを実行するにはshellが必要です
        environment: {
          'APP_CONFIG': appConfig,
          'LANG': 'ja_JP.UTF-8',
          'LC_ALL': 'ja_JP.UTF-8',
        },
      );

      _runningProcesses[windowId] = process;

      // プロセス終了を監視
      process.exitCode.then((exitCode) {
        _runningProcesses.remove(windowId);
        Log.info('RealMultiWindowManager', 'ウィンドウプロセス終了: $windowId, 終了コード: $exitCode');
      });

      // プロセス出力を監視、エラーがあるかチェック
      process.stdout.listen((data) {
        final output = utf8.decode(data, allowMalformed: true);
        Log.debug('RealMultiWindowManager', '[$windowId] stdout: $output');
      });
      
      process.stderr.listen((data) {
        final error = utf8.decode(data, allowMalformed: true);
        Log.warning('RealMultiWindowManager', '[$windowId] stderr: $error');
      });

      Log.info('RealMultiWindowManager', 'ウィンドウ作成 $windowId 成功');
      
      // 少し待機してFlutterプロセスが起動する時間を与える
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true;
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ウィンドウ作成失敗: $e');
      return false;
    }
  }

  /// ウィンドウを閉じる
  static Future<bool> closeWindow(String windowId) async {
    try {
      Log.info('RealMultiWindowManager', 'ウィンドウを閉じる $windowId');

      if (_runningProcesses.containsKey(windowId)) {
        final process = _runningProcesses[windowId]!;
        process.kill();
        _runningProcesses.remove(windowId);
        Log.info('RealMultiWindowManager', 'ウィンドウ $windowId は閉じられました');
        return true;
      } else {
        Log.info('RealMultiWindowManager', 'ウィンドウ $windowId は実行されていません');
        return true;
      }
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ウィンドウを閉じるのに失敗: $e');
      return false;
    }
  }

  /// すべてのディスプレイ情報を取得
  static Future<List<Map<String, dynamic>>> getScreens() async {
    try {
      // 簡略版、メインディスプレイ情報を返す
      return [
        {
          'x': 0.0,
          'y': 0.0,
          'width': 1920.0,
          'height': 1080.0,
          'name': 'メインディスプレイ',
        }
      ];
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ディスプレイ情報取得失敗: $e');
      return [];
    }
  }

  /// 指定されたディスプレイ上にウィンドウを作成
  static Future<bool> createWindowOnScreen({
    required String windowId,
    required Map<String, dynamic> data,
    required int screenIndex,
  }) async {
    try {
      final screens = await getScreens();
      if (screenIndex >= screens.length) {
        Log.warning('RealMultiWindowManager', 'ディスプレイインデックスが範囲外: $screenIndex');
        return false;
      }

      // ウィンドウを作成（位置はシステムが自動管理）
      return await createWindow(
        windowId: windowId,
        data: data,
        screenIndex: screenIndex,
      );
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ディスプレイ上にウィンドウを作成するのに失敗: $e');
      return false;
    }
  }

  /// すべてのウィンドウを同時に作成
  static Future<Map<String, bool>> createAllWindows({
    required Map<String, dynamic> data,
    bool distributeToScreens = true,
  }) async {
    final results = <String, bool>{};

    try {
      if (distributeToScreens) {
        // ディスプレイ情報を取得
        final screens = await getScreens();
        Log.info('RealMultiWindowManager', '${screens.length} 個のディスプレイを検出');

        // 利用可能なディスプレイ上にウィンドウを分散
        final windowIds = [m5WindowId, h4WindowId];

        for (int i = 0; i < windowIds.length; i++) {
          final windowId = windowIds[i];
          final screenIndex = i < screens.length ? i : 0; // ディスプレイが足りない場合、最初のものを使用

          results[windowId] = await createWindowOnScreen(
            windowId: windowId,
            data: data,
            screenIndex: screenIndex,
          );
        }
      } else {
        // メインディスプレイ上にすべてのウィンドウを作成
        final windowIds = [m5WindowId, h4WindowId];

        for (final windowId in windowIds) {
          results[windowId] = await createWindow(
            windowId: windowId,
            data: data,
          );
        }
      }

      Log.info('RealMultiWindowManager', 'ウィンドウ作成結果: $results');
      return results;
    } catch (e) {
      Log.error('RealMultiWindowManager', 'すべてのウィンドウ作成失敗: $e');
      return results;
    }
  }

  /// すべてのウィンドウを閉じる
  static Future<Map<String, bool>> closeAllWindows() async {
    final results = <String, bool>{};

    try {
      for (final windowId in _windowConfigs.keys) {
        results[windowId] = await closeWindow(windowId);
      }

      Log.info('RealMultiWindowManager', 'ウィンドウを閉じる結果: $results');
      return results;
    } catch (e) {
      Log.error('RealMultiWindowManager', 'すべてのウィンドウを閉じるのに失敗: $e');
      return results;
    }
  }

  /// ウィンドウが開いているかチェック
  static Future<bool> isWindowOpen(String windowId) async {
    try {
      return _runningProcesses.containsKey(windowId);
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ウィンドウ状態チェック失敗: $e');
      return false;
    }
  }

  /// すべてのウィンドウ状態を取得
  static Future<Map<String, bool>> getAllWindowStates() async {
    final states = <String, bool>{};

    try {
      for (final windowId in _windowConfigs.keys) {
        states[windowId] = await isWindowOpen(windowId);
      }

      return states;
    } catch (e) {
      Log.error('RealMultiWindowManager', 'ウィンドウ状態取得失敗: $e');
      return states;
    }
  }

}
