import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models/price_data.dart';
import 'models/timeframe.dart';
import 'models/trading_pair.dart';
import 'models/app_settings.dart';
import 'services/timeframe_data_service.dart';
import 'services/csv_file_watcher.dart';
import 'services/settings_service.dart';
import 'services/log_service.dart';
import 'services/multi_pair_download_service.dart';
import 'widgets/candlestick_chart.dart';
import 'widgets/chart_view_controller.dart';
import 'widgets/components/background_color_picker_dialog.dart';
import 'pages/real_multi_window_launcher.dart';

/// 色プリセットクラス
class ColorPreset {
  final String name;
  final String color; // ARGB hex string
  const ColorPreset({required this.name, required this.color});
}

void main() async {
  // ログサービスの初期化
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.initialize();
  
  // 国際化データ初期化
  await initializeDateFormatting('ja_JP', null);
  
  Log.info('Main', 'アプリケーション起動');
  
  // In a multi-window scenario, the main process can send a command to stdin
  // to request a graceful shutdown.
  // This check ensures we only listen on platforms where stdin is available
  // and the app is likely running as a child process.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Check if running as a child process by looking for the APP_CONFIG define.
    const appConfig = String.fromEnvironment('APP_CONFIG');
    if (appConfig.isNotEmpty) {
      Log.info('Main', 'マルチウィンドウモード起動、APP_CONFIG: $appConfig');
      stdin.transform(utf8.decoder).listen((data) {
        if (data.trim() == 'close_window') {
          Log.info('Main', 'ウィンドウ閉じるコマンドを受信');
          exit(0); // Exit with a success code.
        }
      });
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 環境変数からウィンドウタイトルを取得
    const appConfig = String.fromEnvironment('APP_CONFIG');
    String titleKey = '';
    if (appConfig.isNotEmpty) {
      final parts = appConfig.split(',');
      if (parts.isNotEmpty) {
        titleKey = parts[0];
      }
    }
    final title = titleKey.isEmpty ? 'EUR/USD' : _formatWindowTitle(titleKey);
    
    return MaterialApp(
      title: title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PriceDataHomePage(),
    );
  }

  /// ウィンドウタイトルのフォーマット
  String _formatWindowTitle(String envTitle) {
    // 英文タイトルを日本語表示に変換
    switch (envTitle) {
      case 'EURUSD-m5':
        return 'EUR/USD - 5M';
      case 'EURUSD-m15':
        return 'EUR/USD - 15m';
      case 'EURUSD-m30':
        return 'EUR/USD - 30m';
      case 'EURUSD-h4':
        return 'EUR/USD - 4H';
      default:
        return envTitle;
    }
  }
}

class PriceDataHomePage extends StatefulWidget {
  const PriceDataHomePage({super.key});

  @override
  State<PriceDataHomePage> createState() => _PriceDataHomePageState();
}

class _PriceDataHomePageState extends State<PriceDataHomePage> {
  List<PriceData> _priceData = [];
  bool _isLoading = true;
  String? _errorMessage;
  TradingPair _selectedTradingPair = TradingPair.eurusd;
  Timeframe _selectedTimeframe = Timeframe.m30;
  CsvFileWatcher? _fileWatcher;
  StreamSubscription<void>? _fileChangeSubscription;
  AppSettings? _appSettings;

  // データフロー最適化：自動更新タイマーをここに移動
  Timer? _autoUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// アプリケーションの初期化
  Future<void> _initializeApp() async {
    // まず設定を読み込み
    await _loadSettings();
    
    // 環境変数に基づいて時間周期を設定
    const appConfig = String.fromEnvironment('APP_CONFIG');
    String timeframeEnv = '';
    if (appConfig.isNotEmpty) {
      final parts = appConfig.split(',');
      if (parts.length > 1) {
        timeframeEnv = parts[1];
      }
    }
    
    // 環境変数で時間周期が指定されている場合、環境変数を優先使用
    if (timeframeEnv.isNotEmpty) {
      switch (timeframeEnv) {
        case 'm5':
          _selectedTimeframe = Timeframe.m5;
          break;
        case 'm15':
          _selectedTimeframe = Timeframe.m15;
          break;
        case 'm30':
          _selectedTimeframe = Timeframe.m30;
          break;
        case 'h4':
          _selectedTimeframe = Timeframe.h4;
          break;
        default:
          _selectedTimeframe = Timeframe.m30;
      }
    } else if (_appSettings != null) {
      // そうでなければ保存された設定を使用
      _selectedTradingPair = _appSettings!.selectedTradingPair;
      _selectedTimeframe = _appSettings!.defaultTimeframe;
    }
    
    _loadData();
    _initializeFileWatcher();
    _initializeAutoUpdate(); // 自動更新を初期化
  }

  /// アプリケーション設定の読み込み
  Future<void> _loadSettings() async {
    try {
      _appSettings = await SettingsService.instance.loadSettings();
      Log.info('Settings', '設定読み込み完了: ${_appSettings!.defaultTimeframe.displayName}');
    } catch (e) {
      Log.error('Settings', '設定読み込み失敗: $e');
      _appSettings = AppSettings.getDefault();
    }
  }

  /// アプリケーション設定の保存
  Future<void> _saveSettings() async {
    if (_appSettings == null) return;
    
    try {
      final updatedSettings = _appSettings!.copyWith(
        selectedTradingPair: _selectedTradingPair,
        defaultTimeframe: _selectedTimeframe,
      );
      
      await SettingsService.instance.saveSettings(updatedSettings);
      _appSettings = updatedSettings;
      Log.info('Settings', '設定保存完了: ${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}');
    } catch (e) {
      Log.error('Settings', '設定保存失敗: $e');
    }
  }

  /// 自動更新の初期化
  void _initializeAutoUpdate() {
    if (_appSettings?.isAutoUpdateEnabled == true) {
      _startAutoUpdate();
    }
  }

  /// 自動更新を開始
  void _startAutoUpdate() {
    _stopAutoUpdate(); // 既存のタイマーを停止
    
    final intervalMinutes = _appSettings?.autoUpdateIntervalMinutes ?? 1;
    _autoUpdateTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      _performAutoUpdate();
    });
    
    Log.info('AutoUpdate', '自動更新を開始: $intervalMinutes分間隔');
  }

  /// 自動更新を停止
  void _stopAutoUpdate() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
    Log.info('AutoUpdate', '自動更新を停止');
  }

  /// 自動更新を実行
  void _performAutoUpdate() async {
    try {
      Log.info('AutoUpdate', '自動更新を実行中...');
      
      // 先尝试下载新数据，而不是仅仅重新加载
      Log.info('AutoUpdate', '开始执行数据下载...');
      await _performDataDownload();
      
      // 下载完成后，重新加载数据
      Log.info('AutoUpdate', '下载完成，重新加载数据...');
      await _loadData();
      
      Log.info('AutoUpdate', '自動更新完了');
    } catch (e) {
      Log.error('AutoUpdate', '自動更新中にエラー: $e');
    }
  }
  
  /// 执行数据下载
  Future<void> _performDataDownload() async {
    try {
      Log.info('AutoUpdate', '=== 开始执行数据下载 ===');
      Log.info('AutoUpdate', '当前交易对: ${_selectedTradingPair.displayName}');
      Log.info('AutoUpdate', '当前时间周期: ${_selectedTimeframe.displayName}');
      
      // 使用ChartViewController的下载逻辑
      // 这里我们需要创建一个临时的ChartViewController来执行下载
      final tempController = ChartViewController(
        data: _priceData,
        onUIUpdate: () {},
        klineDataLimit: _appSettings?.klineDataLimit,
        selectedTimeframe: _selectedTimeframe,
        selectedTradingPair: _selectedTradingPair,
      );
      
      await tempController.downloadAndLoadData();
      Log.info('AutoUpdate', '=== 数据下载完成 ===');
    } catch (e) {
      Log.error('AutoUpdate', '数据下载过程中发生错误: $e');
    }
  }

  /// ダウンロード要求のハンドラー
  Future<void> _handleDownloadRequest({bool showMessages = true}) async {
    Log.info('Main', '=== 主应用下载请求处理器被调用 ===');
    Log.info('Main', 'showMessages: $showMessages');
    Log.info('Main', '当前交易对: ${_selectedTradingPair.displayName}');
    Log.info('Main', '当前时间周期: ${_selectedTimeframe.displayName}');
    
    try {
      // 使用与自动更新相同的逻辑：先下载，再加载
      Log.info('Main', '开始执行数据下载...');
      await _performDataDownload();
      
      Log.info('Main', '下载完成，重新加载数据...');
      await _loadData();
      
      Log.info('Main', '手动下载完成');
    } catch (e) {
      Log.error('Main', '主应用下载请求处理过程中发生错误: $e');
    }
    
    Log.info('Main', '=== 主应用下载请求处理完成 ===');
  }

  /// 自動更新切り替えのハンドラー
  void _handleAutoUpdateToggle() {
    final isEnabled = _appSettings?.isAutoUpdateEnabled ?? false;
    if (isEnabled) {
      _startAutoUpdate();
    } else {
      _stopAutoUpdate();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 選択された時間周期に基づいてデータを読み込み
      final data = await TimeframeDataService.loadDataForTimeframe(
        _selectedTimeframe, 
        tradingPair: _selectedTradingPair,
        klineDataLimit: _appSettings?.klineDataLimit,
      );

      // データがない場合は、2015年1月1日から自動的にダウンロード
      if (data.isEmpty) {
        Log.info('DataLoad', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}データが見つからない、2015年1月1日から自動ダウンロードを開始...');
        await _autoDownloadFrom2015();
        
        // データを再度読み込んでみて
        final newData = await TimeframeDataService.loadDataForTimeframe(
          _selectedTimeframe, 
          tradingPair: _selectedTradingPair,
          klineDataLimit: _appSettings?.klineDataLimit,
        );
        setState(() {
          _priceData = newData;
          _isLoading = false;
        });
        
        Log.info('DataLoad', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}自動ダウンロード後のデータ読み込み完了: ${newData.length}件');
        if (newData.isNotEmpty) {
          final firstTime = DateTime.fromMillisecondsSinceEpoch(newData.first.timestamp, isUtc: true);
          final lastTime = DateTime.fromMillisecondsSinceEpoch(newData.last.timestamp, isUtc: true);
          Log.info('DataLoad', 'データ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
        }
      } else {
      setState(() {
        _priceData = data;
        _isLoading = false;
      });
      
        Log.info('DataLoad', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}データの読み込み完了: ${data.length}件');
      if (data.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
          Log.info('DataLoad', 'データ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 2015年1月1日からデータを自動ダウンロード
  Future<void> _autoDownloadFrom2015() async {
    try {
      Log.info('AutoDownload', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}の自動ダウンロードを開始...');
      
      final startDate = DateTime(2015, 1, 1);
      final endDate = DateTime.now();
      
      // MultiPairDownloadServiceを使用してデータをダウンロード
      final results = await MultiPairDownloadService.downloadSpecificPairs(
        pairs: [_selectedTradingPair],
        timeframes: [_selectedTimeframe],
        startDate: startDate,
        endDate: endDate,
        progressKey: 'auto_download_${_selectedTradingPair.dukascopyCode}_${_selectedTimeframe.dukascopyCode}',
      );
      
      // 检查下载结果
      bool hasSuccess = false;
      for (final result in results) {
        if (result['status'] == 'success') {
          hasSuccess = true;
          Log.info('AutoDownload', '${result['pair'].displayName} ${result['timeframe'].displayName}のダウンロード成功');
        } else {
          Log.error('AutoDownload', '${result['pair'].displayName} ${result['timeframe'].displayName}のダウンロード失敗: ${result['message']}');
        }
      }
      
      if (hasSuccess) {
        Log.info('AutoDownload', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}の自動ダウンロード完了');
      } else {
        Log.error('AutoDownload', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}の自動ダウンロード失敗');
      }
      
    } catch (e) {
      Log.error('AutoDownload', '自動ダウンロード中にエラーが発生: $e');
    }
  }

  /// ファイル監視器の初期化
  void _initializeFileWatcher() {
    // すべての時間周期でファイル監視を開始
    final timeframeStr = _selectedTimeframe.dukascopyCode;
    _fileWatcher = CsvFileWatcher.getInstance(timeframeStr);
    
    // ファイル変更を監視
    _fileChangeSubscription = _fileWatcher!.onFileChanged.listen((_) {
      Log.info('FileWatcher', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}CSVファイルの変更を検出、検証してデータを再読み込み...');
      _validateAndReloadData();
    });
    
    // 監視を開始
    _fileWatcher!.startWatching();
    Log.info('FileWatcher', '${_selectedTradingPair.displayName} ${_selectedTimeframe.displayName}CSVファイル監視器が起動しました');
  }

  /// ファイル監視器の更新（周期変更時）
  void _updateFileWatcher() {
    // 現在の監視器を停止
    _fileChangeSubscription?.cancel();
    _fileWatcher?.stopWatching();
    
    // 監視器を再初期化
    _initializeFileWatcher();
  }

  /// データの検証と再読み込み
  void _validateAndReloadData() async {
    try {
      // 現在のデータ量を記録
      final currentDataCount = _priceData.length;
      Log.info('DataValidation', '現在のデータ量: $currentDataCount');
      
      // データを再読み込み
      await _loadData();
      
      // 新しいデータがあるかチェック
      if (_priceData.length > currentDataCount) {
        final newDataCount = _priceData.length - currentDataCount;
        Log.info('DataValidation', '新しいデータを検出: $newDataCount件、総データ量: ${_priceData.length}件');
        
        // 通知を表示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText('新しいデータを検出: $newDataCount件'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (_priceData.length == currentDataCount) {
        Log.info('DataValidation', 'データ量に変化なし、ファイル内容の更新の可能性');
      } else {
        Log.warning('DataValidation', 'データ量が減少、ファイルが置き換えられた可能性');
      }
    } catch (e) {
      Log.error('DataValidation', 'データ検証中にエラー: $e');
    }
  }

  @override
  void dispose() {
    // ファイル監視器をクリーンアップ
    _fileChangeSubscription?.cancel();
    _stopAutoUpdate(); // 自動更新タイマーを停止
    _fileWatcher?.stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // 元の色に戻す
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40, // AppBarの高さを最小限に
        actions: [
          // マルチウィンドウ起動ボタン（メインウィンドウのみ表示）
          if (!_isMultiWindowMode())
            IconButton(
              onPressed: _openRealMultiWindow,
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: 'マルチウィンドウマネージャーを開く',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            onPressed: _showBackgroundColorPicker,
            icon: const Icon(Icons.palette, size: 20),
            tooltip: '背景色を変更',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleTrendFiltering,
            icon: Icon(
              _appSettings?.isTrendFilteringEnabled == true ? Icons.trending_up : Icons.trending_flat,
              size: 20,
              color: _appSettings?.isTrendFilteringEnabled == true ? Colors.green : Colors.grey,
            ),
            tooltip: 'トレンドフィルタリング',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleCubicCurve,
            icon: Icon(
              _appSettings?.isCubicCurveVisible == true ? Icons.show_chart : Icons.show_chart_outlined,
              size: 20,
              color: _appSettings?.isCubicCurveVisible == true ? Colors.purple : Colors.grey,
            ),
            tooltip: '3次曲线',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleMA60FilteredCurve,
            icon: Icon(
              _appSettings?.isMA60FilteredCurveVisible == true ? Icons.timeline : Icons.timeline_outlined,
              size: 20,
              color: _appSettings?.isMA60FilteredCurveVisible == true ? Colors.cyan : Colors.grey,
            ),
            tooltip: '60均线过滤曲线',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleBollingerBandsFilteredCurve,
            icon: Icon(
              _appSettings?.isBollingerBandsFilteredCurveVisible == true ? Icons.timeline : Icons.timeline_outlined,
              size: 20,
              color: _appSettings?.isBollingerBandsFilteredCurveVisible == true ? Colors.purple : Colors.grey,
            ),
            tooltip: '布林线过滤曲线',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleMaTrendBackground,
            icon: Icon(
              _appSettings?.isMaTrendBackgroundEnabled == true ? Icons.color_lens : Icons.color_lens_outlined,
              size: 20,
              color: _appSettings?.isMaTrendBackgroundEnabled == true ? Colors.orange : Colors.grey,
            ),
            tooltip: '移动平均线趋势背景',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleMousePositionZoom,
            icon: Icon(
              _appSettings?.isMousePositionZoomEnabled == true ? Icons.zoom_in_map : Icons.zoom_out_map,
              size: 20,
              color: _appSettings?.isMousePositionZoomEnabled == true ? Colors.teal : Colors.grey,
            ),
            tooltip: '缩放原点（鼠标位置/右侧）',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _toggleKlineVisibility,
            icon: Icon(
              _appSettings?.isKlineVisible == true ? Icons.candlestick_chart : Icons.candlestick_chart_outlined,
              size: 20,
              color: _appSettings?.isKlineVisible == true ? Colors.blue : Colors.grey,
            ),
            tooltip: _appSettings?.isKlineVisible == true ? 'K線を非表示' : 'K線を表示',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.settings, size: 20),
            tooltip: '設定',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            onPressed: _showTimeNavigationDialog,
            icon: const Icon(Icons.access_time, size: 20),
            tooltip: '时间导航',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '${_selectedTimeframe.displayName}データをリロード',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  bool _isMultiWindowMode() {
    const appConfig = String.fromEnvironment('APP_CONFIG');
    return appConfig.isNotEmpty;
  }

  Widget _buildAppBarTitle() {
    // マルチウィンドウモードで実行されているかチェック（環境変数で判断）
    final isMultiWindowMode = _isMultiWindowMode();
    
    // メインウィンドウでもマルチウィンドウモードでも、周期選択コントロールを表示
      return Row(
        children: [
        // 品种选择下拉框
        DropdownButton<TradingPair>(
          value: _selectedTradingPair,
          onChanged: (TradingPair? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTradingPair = newValue;
              });
              _loadData();
              _updateFileWatcher(); // ファイル監視器を更新
              _saveSettings(); // 設定を保存
            }
          },
          items: TradingPair.values.map<DropdownMenuItem<TradingPair>>((TradingPair pair) {
            return DropdownMenuItem<TradingPair>(
              value: pair,
              child: SelectableText(
                pair.displayName,
                style: const TextStyle(fontSize: 16),
              ),
            );
          }).toList(),
          underline: Container(),
          dropdownColor: Theme.of(context).colorScheme.surface,
        ),
        const SizedBox(width: 8),
        // 时间周期选择下拉框
          DropdownButton<Timeframe>(
            value: _selectedTimeframe,
            onChanged: (Timeframe? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedTimeframe = newValue;
                });
                _loadData();
              _updateFileWatcher(); // ファイル監視器を更新
              _saveSettings(); // 設定を保存
              }
            },
            items: Timeframe.values.map<DropdownMenuItem<Timeframe>>((Timeframe timeframe) {
              return DropdownMenuItem<Timeframe>(
                value: timeframe,
                child: SelectableText(
                  timeframe.displayName,
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: Theme.of(context).colorScheme.surface,
        ),
        // マルチウィンドウモードで現在のウィンドウ情報を表示
        if (isMultiWindowMode) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
            ),
            child: const SelectableText(
              'マルチウィンドウモード',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 真のマルチウィンドウマネージャーを開く
  /// 移動平均線表示設定の構築
  List<Widget> _buildMaVisibilitySettings(void Function(void Function()) dialogSetState) {
    if (_appSettings == null) return [];

    final maPeriods = _appSettings!.maPeriods;
    final maVisibility = _appSettings!.maVisibility;

    return maPeriods.map((period) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: maVisibility[period] ?? false,
              onChanged: (bool? value) {
                if (_appSettings != null) {
                  dialogSetState(() {
                    final newVisibility = Map<int, bool>.from(maVisibility);
                    newVisibility[period] = value ?? false;
                    _appSettings = _appSettings!.copyWith(maVisibility: newVisibility);
                  });
                  // 立即更新主UI以预览效果
                  setState(() {});
                }
              },
            ),
            SelectableText('MA$period'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await _showMaColorPicker(period);
                dialogSetState(() {}); // ダイアログを閉じた後に親ダイアログを更新
              },
              child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _getMaColor(period),
                shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// 移動平均線の色を取得
  Color _getMaColor(int period) {
    Color baseColor;
    
    if (_appSettings?.maColors != null && _appSettings!.maColors.containsKey(period)) {
      try {
        baseColor = Color(int.parse(_appSettings!.maColors[period]!));
      } catch (e) {
        LogService.instance.error('MA色解析', 'MA色解析エラー: $e');
        baseColor = Colors.grey;
      }
    } else {
      // デフォルト色
      final colors = {
        2: Colors.red,
        3: Colors.orange,
        10: Colors.yellow,
        13: Colors.green,
        30: Colors.blue,
        60: Colors.purple,
        150: Colors.pink,
        300: Colors.brown,
        750: Colors.cyan, // MA750のデフォルト色
      };
      baseColor = colors[period] ?? Colors.grey;
    }
    
    // 透明度を適用
    final alpha = _appSettings?.maAlphas[period] ?? 1.0;
    return baseColor.withValues(alpha: alpha);
  }

  /// MA色選択ダイアログを表示
  Future<void> _showMaColorPicker(int period) async {
    final currentColor = _appSettings?.maColors[period] ?? '0xFFFF0000';
    final currentAlpha = _appSettings?.maAlphas[period] ?? 1.0;
    
    String selectedColor = currentColor;
    double selectedAlpha = currentAlpha;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: SelectableText('MA$period の色と透明度を設定'),
              content: SizedBox(
                width: 350,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // 色選択グリッド
                    const SelectableText('色を選択:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _maColorPresets.length,
                        itemBuilder: (context, index) {
                          final preset = _maColorPresets[index];
                          final isSelected = selectedColor == preset.color;
                          
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = preset.color;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(int.parse(preset.color)).withValues(alpha: selectedAlpha),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 透明度スライダー
                    const SelectableText('透明度:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SelectableText('0%'),
                        Expanded(
                          child: Slider(
                            value: selectedAlpha,
                            min: 0.0,
                            max: 1.0,
                            divisions: 100,
                            onChanged: (double value) {
                              setDialogState(() {
                                selectedAlpha = value;
                              });
                            },
                          ),
                        ),
                        SelectableText('${(selectedAlpha * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // プレビュー
                    const SelectableText('プレビュー:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(selectedColor)).withValues(alpha: selectedAlpha),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: SelectableText(
                          'MA$period',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 手動色入力
                    const SelectableText('手動色入力 (例: #FF0000):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '#FF0000',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (String value) {
                        if (value.startsWith('#') && value.length == 7) {
                          try {
                            final hexColor = '0xFF${value.substring(1)}';
                            setDialogState(() {
                              selectedColor = hexColor;
                            });
                          } catch (e) {
                            // 無効な色の場合は無視
                          }
                        }
                      },
                    ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const SelectableText('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final newMaColors = Map<int, String>.from(_appSettings?.maColors ?? {});
                      final newMaAlphas = Map<int, double>.from(_appSettings?.maAlphas ?? {});
                      newMaColors[period] = selectedColor;
                      newMaAlphas[period] = selectedAlpha;
                      _appSettings = _appSettings?.copyWith(
                        maColors: newMaColors,
                        maAlphas: newMaAlphas,
                      );
                    });
                    _saveSettings();
                    Navigator.of(context).pop();
                  },
                  child: const SelectableText('適用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// MA色プリセット
  static const List<ColorPreset> _maColorPresets = [
    ColorPreset(name: '赤', color: '0xFFFF0000'),
    ColorPreset(name: 'オレンジ', color: '0xFFFFA500'),
    ColorPreset(name: '黄', color: '0xFFFFFF00'),
    ColorPreset(name: '緑', color: '0xFF00FF00'),
    ColorPreset(name: '青', color: '0xFF0000FF'),
    ColorPreset(name: '紫', color: '0xFF800080'),
    ColorPreset(name: 'ピンク', color: '0xFFFFC0CB'),
    ColorPreset(name: '茶', color: '0xFFA52A2A'),
    ColorPreset(name: 'シアン', color: '0xFF00FFFF'),
    ColorPreset(name: 'マゼンタ', color: '0xFFFF00FF'),
    ColorPreset(name: 'ライム', color: '0xFF00FF00'),
    ColorPreset(name: 'ネイビー', color: '0xFF000080'),
    ColorPreset(name: 'テアル', color: '0xFF008080'),
    ColorPreset(name: 'オリーブ', color: '0xFF808000'),
    ColorPreset(name: 'マルーン', color: '0xFF800000'),
    ColorPreset(name: 'シルバー', color: '0xFFC0C0C0'),
  ];

  /// 設定ダイアログを表示
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, dialogSetState) {
          return AlertDialog(
            title: const SelectableText('アプリケーション設定'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // デフォルト時間周期設定
                    const SelectableText('デフォルト時間周期:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Timeframe>(
                      initialValue: _appSettings?.defaultTimeframe ?? _selectedTimeframe,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: Timeframe.values.map<DropdownMenuItem<Timeframe>>((Timeframe timeframe) {
                        return DropdownMenuItem<Timeframe>(
                          value: timeframe,
                          child: SelectableText(timeframe.displayName),
                        );
                      }).toList(),
                      onChanged: (Timeframe? newValue) {
                        if (newValue != null && _appSettings != null) {
                          dialogSetState(() {
                            _appSettings = _appSettings!.copyWith(defaultTimeframe: newValue);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 自動更新設定
                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isAutoUpdateEnabled ?? true,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                              dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isAutoUpdateEnabled: value ?? true);
                              });
                              // 設定を即時保存し、UIを更新します
                              SettingsService.instance.saveSettings(_appSettings!);
                              setState(() {});
                            }
                          },
                        ),
                        const SelectableText('自動更新を有効にする'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ウェーブポイント設定
                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isWavePointsVisible ?? true,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                              dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isWavePointsVisible: value ?? true);
                              });
                              // 立即更新主UI以预览效果
                              setState(() {});
                            }
                          },
                        ),
                        const SelectableText('ウェーブポイントを表示'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isWavePointsLineVisible ?? false,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                              dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isWavePointsLineVisible: value ?? false);
                              });
                              // 立即更新主UI以预览效果
                              setState(() {});
                            }
                          },
                        ),
                        const SelectableText('ウェーブポイント接続線を表示'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 移動平均線設定
                    const SelectableText('移動平均線表示設定:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._buildMaVisibilitySettings(dialogSetState),
                    const SizedBox(height: 16),


                    // トレンドフィルタリング設定
                    const SelectableText('トレンドフィルタリング設定:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isTrendFilteringEnabled ?? false,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                              dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isTrendFilteringEnabled: value ?? false);
                              });
                              // 立即更新主UI以预览效果
                              setState(() {});
                            }
                          },
                        ),
                        const SelectableText('トレンドフィルタリングを有効にする'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3次曲线设置
                    const SelectableText('3次曲线设置:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isCubicCurveVisible ?? false,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                          dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isCubicCurveVisible: value ?? false);
                          });
                          // 立即更新主UI以预览效果
                          setState(() {});
                        }
                      },
                        ),
                        const SelectableText('显示3次曲线'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 60均线过滤曲线设置
                    const SelectableText('60均线过滤曲线设置:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _appSettings?.isMA60FilteredCurveVisible ?? false,
                          onChanged: (bool? value) {
                            if (_appSettings != null) {
                          dialogSetState(() {
                                _appSettings = _appSettings!.copyWith(isMA60FilteredCurveVisible: value ?? false);
                          });
                          // 立即更新主UI以预览效果
                          setState(() {});
                        }
                      },
                        ),
                        const SelectableText('显示60均线过滤曲线'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // 近い距離の閾値
                    const SelectableText('近い距離の閾値:'),
                    Row(
                      children: [
                        const SelectableText('0.1%'),
                        Expanded(
                          child: Slider(
                            value: (_appSettings?.trendFilteringNearThreshold ?? 0.01) * 100,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            onChanged: (double value) {
                              if (_appSettings != null) {
                                dialogSetState(() {
                                  _appSettings = _appSettings!.copyWith(trendFilteringNearThreshold: value / 100);
                                });
                              }
                            },
                          ),
                        ),
                        SelectableText('${((_appSettings?.trendFilteringNearThreshold ?? 0.01) * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                    
                    // 遠い距離の閾値
                    const SelectableText('遠い距離の閾値:'),
                    Row(
                      children: [
                        const SelectableText('0.5%'),
                        Expanded(
                          child: Slider(
                            value: (_appSettings?.trendFilteringFarThreshold ?? 0.02) * 100,
                            min: 0.5,
                            max: 10.0,
                            divisions: 95,
                            onChanged: (double value) {
                              if (_appSettings != null) {
                                dialogSetState(() {
                                  _appSettings = _appSettings!.copyWith(trendFilteringFarThreshold: value / 100);
                                });
                              }
                            },
                          ),
                        ),
                        SelectableText('${((_appSettings?.trendFilteringFarThreshold ?? 0.02) * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                    
                    // 最低バー間隔
                    const SelectableText('最低バー間隔:'),
                    Row(
                      children: [
                        const SelectableText('1'),
                        Expanded(
                          child: Slider(
                            value: (_appSettings?.trendFilteringMinGapBars ?? 5).toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            onChanged: (double value) {
                              if (_appSettings != null) {
                                dialogSetState(() {
                                  _appSettings = _appSettings!.copyWith(trendFilteringMinGapBars: value.round());
                                });
                              }
                            },
                          ),
                        ),
                        SelectableText('${_appSettings?.trendFilteringMinGapBars ?? 5}バー'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // K線データ制限設定
                    const SelectableText('K線データ制限設定:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SelectableText('読み込みK線数: '),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: (_appSettings?.klineDataLimit ?? 1000).toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onChanged: (String value) {
                              final int? newLimit = int.tryParse(value);
                              if (newLimit != null && newLimit > 0 && _appSettings != null) {
                                dialogSetState(() {
                                  _appSettings = _appSettings!.copyWith(klineDataLimit: newLimit);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SelectableText('条'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 設定ファイル情報
                    const SelectableText('設定ファイル情報:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: SettingsService.instance.getSettingsFileInfo(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final info = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText('パス: ${info['path']}'),
                              SelectableText('サイズ: ${info['size']} バイト'),
                              if (info['lastModified'] != null) SelectableText('最終変更: ${info['lastModified']}'),
                            ],
                          );
                        }
                        return const SelectableText('読み込み中...');
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // 設定をデフォルト値にリセット
                  await SettingsService.instance.resetToDefault();
                  await _loadSettings();
                  dialogSetState(() {});
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: SelectableText('設定がデフォルト値にリセットされました')),
                    );
                  }
                },
                child: const SelectableText('リセット'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const SelectableText('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 設定を保存
                  if (_appSettings != null) {
                    final oldKlineDataLimit = _appSettings!.klineDataLimit;
                    await SettingsService.instance.saveSettings(_appSettings!);
                    
                    // デフォルト時間周期が変更された場合、現在の選択を更新
                    if (_appSettings!.defaultTimeframe != _selectedTimeframe) {
                      setState(() {
                        // 状態を更新してUIに反映
                        _selectedTimeframe = _appSettings!.defaultTimeframe;
                      });
                      _loadData();
                      _updateFileWatcher();
                    }
                    // K線データ制限が変更された場合、データを再読み込み
                    else if (oldKlineDataLimit != _appSettings!.klineDataLimit) {
                      _loadData();
                    }
                    
                    // 自動更新設定の変更を適用
                    if (_appSettings!.isAutoUpdateEnabled) {
                      _startAutoUpdate();
                    } else {
                      _stopAutoUpdate();
                    }
                    
                    // チャート設定（MA表示、ウェーブポイント表示など）を適用するためメインページを強制更新
                    setState(() {});
                  }
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: SelectableText('設定が保存されました')),
                    );
                  }
                },
                child: const SelectableText('保存'),
              ),
            ],
          );
        });
      },
    );
  }

  /// 时间导航对话框
  void _showTimeNavigationDialog() {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const SelectableText('时间导航'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 快速导航按钮
                    const SelectableText('快速导航:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToTime('start');
                          },
                          icon: const Icon(Icons.first_page),
                          label: const SelectableText('最开始'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToTime('end');
                          },
                          icon: const Icon(Icons.last_page),
                          label: const SelectableText('最末尾'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 自定义时间选择
                    const SelectableText('自定义时间:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // 日期选择
                    ListTile(
                      title: const SelectableText('选择日期'),
                      subtitle: SelectableText('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2015, 1, 1),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != selectedDate) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    
                    // 时间选择
                    ListTile(
                      title: const SelectableText('选择时间'),
                      subtitle: SelectableText('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null && picked != selectedTime) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 跳转按钮
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _navigateToCustomTime(selectedDate, selectedTime);
                      },
                      icon: const Icon(Icons.navigation),
                      label: const SelectableText('跳转到指定时间'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const SelectableText('取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  /// 导航到指定时间
  void _navigateToTime(String type) {
    if (_priceData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: SelectableText('没有数据可导航')),
      );
      return;
    }

    try {
      if (type == 'start') {
        CandlestickChart.navigateToStart();
        Log.info('TimeNavigation', '导航到开始位置');
      } else if (type == 'end') {
        CandlestickChart.navigateToEnd();
        Log.info('TimeNavigation', '导航到结束位置');
      }
    } catch (e) {
      Log.warning('TimeNavigation', '导航失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: SelectableText('图表未初始化，无法导航')),
      );
    }
  }

  /// 导航到自定义时间
  void _navigateToCustomTime(DateTime date, TimeOfDay time) {
    if (_priceData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: SelectableText('没有数据可导航')),
      );
      return;
    }

    try {
      // 创建目标时间戳
      final targetDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final targetTimestamp = targetDateTime.millisecondsSinceEpoch;

      // 使用静态方法导航到时间戳
      CandlestickChart.navigateToTimestamp(targetTimestamp);
      
      // 查找最接近的时间点用于显示结果
      int closestIndex = 0;
      int minDifference = (targetTimestamp - _priceData[0].timestamp).abs();
      
      for (int i = 1; i < _priceData.length; i++) {
        final difference = (targetTimestamp - _priceData[i].timestamp).abs();
        if (difference < minDifference) {
          minDifference = difference;
          closestIndex = i;
        }
      }
      
      // 显示导航结果
      final actualTime = DateTime.fromMillisecondsSinceEpoch(_priceData[closestIndex].timestamp, isUtc: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('已导航到: ${actualTime.toString().substring(0, 19)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      Log.info('TimeNavigation', '导航到自定义时间: ${actualTime.toString().substring(0, 19)}');
    } catch (e) {
      Log.warning('TimeNavigation', '自定义时间导航失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: SelectableText('图表未初始化，无法导航')),
      );
    }
  }


  /// 背景色選択ダイアログを表示
  void _showBackgroundColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackgroundColorPickerDialog(
          currentColor: _appSettings?.backgroundColor ?? '0xFF1E1E1E',
          onColorSelected: (String selectedColor) {
            setState(() {
              _appSettings = _appSettings?.copyWith(
                backgroundColor: selectedColor,
              );
            });
            _saveSettings();
            
            // 成功メッセージを表示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: SelectableText('背景色が変更されました'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  /// トレンドフィルタリングの切り替え
  void _toggleTrendFiltering() {
    LogService.instance.info('Main', 'トレンドフィルタリング切り替え開始');
    
    setState(() {
      final currentEnabled = _appSettings?.isTrendFilteringEnabled ?? false;
      LogService.instance.info('Main', '現在の状態: $currentEnabled -> ${!currentEnabled}');
      
      _appSettings = _appSettings?.copyWith(
        isTrendFilteringEnabled: !currentEnabled,
      );
      
      LogService.instance.info('Main', '設定更新後: ${_appSettings?.isTrendFilteringEnabled}');
      LogService.instance.info('Main', '新しい設定値: isTrendFilteringEnabled=${_appSettings?.isTrendFilteringEnabled}');
    });
    
    _saveSettings();
    
    // 状態メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isTrendFilteringEnabled == true 
            ? 'トレンドフィルタリングが有効になりました' 
            : 'トレンドフィルタリングが無効になりました'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    
    LogService.instance.info('Main', 'トレンドフィルタリング切り替え完了');
  }

  /// 3次曲线显示/隐藏的切换
  void _toggleCubicCurve() {
    LogService.instance.info('Main', '3次曲线切换开始');
    
    setState(() {
      final currentVisible = _appSettings?.isCubicCurveVisible ?? false;
      LogService.instance.info('Main', '当前3次曲线显示状态: $currentVisible -> ${!currentVisible}');
      
      _appSettings = _appSettings?.copyWith(
        isCubicCurveVisible: !currentVisible,
      );
      
      LogService.instance.info('Main', '设置更新后: ${_appSettings?.isCubicCurveVisible}');
    });

    // 保存设置
    _saveSettings();

    // 状态消息を表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isCubicCurveVisible == true 
            ? '3次曲线已启用' 
            : '3次曲线已禁用'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    
    LogService.instance.info('Main', '3次曲线切换完成');
  }

  /// 60均线过滤曲线显示/隐藏的切换
  void _toggleMA60FilteredCurve() {
    LogService.instance.info('Main', '60均线过滤曲线切换开始');
    
    setState(() {
      final currentVisible = _appSettings?.isMA60FilteredCurveVisible ?? false;
      LogService.instance.info('Main', '当前60均线过滤曲线显示状态: $currentVisible -> ${!currentVisible}');
      
      _appSettings = _appSettings?.copyWith(
        isMA60FilteredCurveVisible: !currentVisible,
      );
      
      LogService.instance.info('Main', '设置更新后: ${_appSettings?.isMA60FilteredCurveVisible}');
    });

    // 保存设置
    _saveSettings();

    // 状态消息を表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isMA60FilteredCurveVisible == true 
            ? '60均线过滤曲线已启用' 
            : '60均线过滤曲线已禁用'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    
    LogService.instance.info('Main', '60均线过滤曲线切换完成');
  }

  /// 布林线过滤曲线显示/隐藏的切换
  void _toggleBollingerBandsFilteredCurve() {
    LogService.instance.info('Main', '布林线过滤曲线切换开始');
    
    setState(() {
      final currentVisible = _appSettings?.isBollingerBandsFilteredCurveVisible ?? false;
      LogService.instance.info('Main', '当前布林线过滤曲线显示状态: $currentVisible -> ${!currentVisible}');
      
      _appSettings = _appSettings?.copyWith(
        isBollingerBandsFilteredCurveVisible: !currentVisible,
      );

      LogService.instance.info('Main', '布林线过滤曲线设置更新完成: ${_appSettings?.isBollingerBandsFilteredCurveVisible}');
    });
    
    _saveSettings();
    
    LogService.instance.info('Main', '布林线过滤曲线切换完成');
  }

  /// 移动平均线趋势背景切换
  void _toggleMaTrendBackground() {
    LogService.instance.info('Main', '移动平均线趋势背景切换开始');
    
    setState(() {
      final currentEnabled = _appSettings?.isMaTrendBackgroundEnabled ?? false;
      LogService.instance.info('Main', '当前移动平均线趋势背景状态: $currentEnabled -> ${!currentEnabled}');
      
      _appSettings = _appSettings?.copyWith(
        isMaTrendBackgroundEnabled: !currentEnabled,
      );
      
      LogService.instance.info('Main', '设置更新后: ${_appSettings?.isMaTrendBackgroundEnabled}');
    });

    // 保存设置
    _saveSettings();

    // 显示状态消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isMaTrendBackgroundEnabled == true 
            ? '移动平均线趋势背景已启用（浅绿色：13>60>300，浅红色：13<60<300）' 
            : '移动平均线趋势背景已禁用'
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    LogService.instance.info('Main', '移动平均线趋势背景切换完成');
  }

  /// 鼠标位置缩放切换
  void _toggleMousePositionZoom() {
    LogService.instance.info('Main', '鼠标位置缩放切换开始');
    
    setState(() {
      final currentEnabled = _appSettings?.isMousePositionZoomEnabled ?? false;
      LogService.instance.info('Main', '当前鼠标位置缩放状态: $currentEnabled -> ${!currentEnabled}');
      
      _appSettings = _appSettings?.copyWith(
        isMousePositionZoomEnabled: !currentEnabled,
      );
      
      LogService.instance.info('Main', '设置更新后: ${_appSettings?.isMousePositionZoomEnabled}');
    });

    // 保存设置
    _saveSettings();

    // 显示状态消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isMousePositionZoomEnabled == true 
            ? '缩放原点已切换为鼠标位置' 
            : '缩放原点已切换为右侧'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    
    LogService.instance.info('Main', '鼠标位置缩放切换完成');
  }

  /// K線表示/非表示の切り替え
  void _toggleKlineVisibility() {
    LogService.instance.info('Main', 'K線表示切り替え開始');
    
    setState(() {
      final currentVisible = _appSettings?.isKlineVisible ?? true;
      LogService.instance.info('Main', '現在のK線表示状態: $currentVisible -> ${!currentVisible}');
      
      _appSettings = _appSettings?.copyWith(
        isKlineVisible: !currentVisible,
      );
      
      LogService.instance.info('Main', '設定更新後: ${_appSettings?.isKlineVisible}');
    });
    
    _saveSettings();
    
    // 状態メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(
          _appSettings?.isKlineVisible == true 
            ? 'K線が表示されました' 
            : 'K線が非表示になりました'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    
    LogService.instance.info('Main', 'K線表示切り替え完了');
  }

  void _openRealMultiWindow() async {
    try {
      // マルチウィンドウマネージャーページにナビゲート
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RealMultiWindowLauncher(
            originalKlineDataList: _priceData,
            defaultTimeframe: _selectedTimeframe,
            onDataUpdate: (List<PriceData> updatedData) {
              setState(() {
                _priceData = updatedData;
                Log.info('DataUpdate', 'main.dartでデータが更新されました: ${updatedData.length}件');
              });
            },
          ),
        ),
      );
    } catch (e) {
      Log.error('MultiWindow', '=== 真のマルチウィンドウを開くのに失敗: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('真のマルチウィンドウを開くのに失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            SelectableText('データを読み込み中...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            SelectableText(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const SelectableText('再試行'),
            ),
          ],
        ),
      );
    }

    // 背景色を取得（CandlestickChart用）
    final chartBackgroundColor = _appSettings?.backgroundColor ?? '0xFF1E1E1E';
    Color chartBackgroundColorValue;
    try {
      chartBackgroundColorValue = Color(int.parse(chartBackgroundColor));
      LogService.instance.debug('背景色設定', '背景色設定: $chartBackgroundColor -> $chartBackgroundColorValue');
    } catch (e) {
      chartBackgroundColorValue = const Color(0xFF1E1E1E);
      LogService.instance.error('背景色解析', '背景色解析エラー: $e');
    }

    return CandlestickChart(
      data: _priceData,
      height: MediaQuery.of(context).size.height - 40 - MediaQuery.of(context).padding.top, // AppBarの高さ40pxを考慮
      backgroundColor: chartBackgroundColorValue, // 背景色を渡す
      maVisibilitySettings: _appSettings?.maVisibility,
      maColorSettings: _appSettings?.maColors,
      maAlphas: _appSettings?.maAlphas,
      isWavePointsVisible: _appSettings?.isWavePointsVisible,
      isWavePointsLineVisible: _appSettings?.isWavePointsLineVisible,
      isKlineVisible: _appSettings?.isKlineVisible,
      isTrendFilteringEnabled: _appSettings?.isTrendFilteringEnabled,
      trendFilteringThreshold: _appSettings?.trendFilteringThreshold,
      trendFilteringNearThreshold: _appSettings?.trendFilteringNearThreshold,
      trendFilteringFarThreshold: _appSettings?.trendFilteringFarThreshold,
      trendFilteringMinGapBars: _appSettings?.trendFilteringMinGapBars,
      isCubicCurveVisible: _appSettings?.isCubicCurveVisible,
        isMA60FilteredCurveVisible: _appSettings?.isMA60FilteredCurveVisible,
        isBollingerBandsFilteredCurveVisible: _appSettings?.isBollingerBandsFilteredCurveVisible,
        isBollingerBandsVisible: _appSettings?.isBollingerBandsVisible,
      bbPeriod: _appSettings?.bbPeriod,
      bbStdDev: _appSettings?.bbStdDev,
      bbColors: _appSettings?.bbColors,
      bbAlphas: _appSettings?.bbAlphas,
      isMaTrendBackgroundEnabled: _appSettings?.isMaTrendBackgroundEnabled,
      isMousePositionZoomEnabled: _appSettings?.isMousePositionZoomEnabled,
      isAutoUpdateEnabled: _appSettings?.isAutoUpdateEnabled,
      autoUpdateIntervalMinutes: _appSettings?.autoUpdateIntervalMinutes,
      klineDataLimit: _appSettings?.klineDataLimit,
      onDownloadRequested: _handleDownloadRequest,
      onAutoUpdateToggled: _handleAutoUpdateToggle,
      selectedTimeframe: _selectedTimeframe,
      selectedTradingPair: _selectedTradingPair,
    );
  }
}