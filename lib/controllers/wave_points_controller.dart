import '../models/price_data.dart';
import '../models/wave_points.dart';
import '../models/wave_point.dart';
import '../services/wave_points_service.dart';
import '../services/wave_interpolation_service.dart';
import '../services/cubic_curve_fitting_service.dart';
import '../services/ma60_filtering_service.dart';
import '../services/log_service.dart';

/// Mixinが依存するホストクラスのインターフェースを定義
abstract class WavePointsControllerHost {
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  Map<int, List<double?>> getMovingAveragesData();
  void notifyUIUpdate();
}

/// 波浪点に関するロジックを管理するMixin
mixin WavePointsControllerMixin on WavePointsControllerHost {
  WavePoints? _wavePoints;
  bool _isWavePointsVisible = true;
  bool _isWavePointsLineVisible = false;
  Map<int, String> _manualWavePoints = {};
  
  // フォーマットされた波データ
  Map<String, List<WavePoint>>? _formattedWaves;
  String _selectedInterpolationMethod = 'chaikin';
  bool _isFormattedWaveVisible = false;

  // 3次曲线相关
  CubicCurveResult? _cubicCurveResult;
  bool _isCubicCurveVisible = false;

  // 60均线过滤曲线相关
  MA60FilteredCurveResult? _ma60FilteredCurveResult;
  bool _isMA60FilteredCurveVisible = false;

  /// Mixinを初期化
  Future<void> initWavePoints() async {
    try {
      _manualWavePoints = await WavePointsService.instance.loadManualWavePoints();
      Log.info('WavePointsController', '手動ウェーブポイントを読み込み: ${_manualWavePoints.length}個');
      Log.info('WavePointsController', '初期化時選択方法: $_selectedInterpolationMethod');
      _calculateWavePoints();
    } catch (e) {
      Log.error('WavePointsController', '手動ウェーブポイント読み込み失敗: $e');
      _manualWavePoints = {};
    }
  }

  /// 3次曲线计算
  void _calculateCubicCurve() {
    if (_wavePoints == null || _wavePoints!.mergedPoints.isEmpty) {
      LogService.instance.warning('WavePointsController', '波浪点数据为空，无法计算3次曲线');
      _cubicCurveResult = null;
      return;
    }

    try {
      _cubicCurveResult = CubicCurveFittingService.instance.generateCubicCurve(
        wavePoints: _wavePoints!,
        priceDataList: data,
        windowDays: 7,
      );
      LogService.instance.info('WavePointsController', '3次曲线计算完成: ${_cubicCurveResult!.points.length}个点, R²=${_cubicCurveResult!.rSquared.toStringAsFixed(4)}');
    } catch (e) {
      LogService.instance.error('WavePointsController', '3次曲线计算失败: $e');
      _cubicCurveResult = null;
    }
  }

  /// 切换3次曲线显示状态
  void toggleCubicCurveVisibility() {
    _isCubicCurveVisible = !_isCubicCurveVisible;
    LogService.instance.info('WavePointsController', '3次曲线显示状态切换: $_isCubicCurveVisible');
    
    // 如果启用显示且还没有计算过，则计算3次曲线
    if (_isCubicCurveVisible && _cubicCurveResult == null) {
      _calculateCubicCurve();
    }
    
    notifyUIUpdate();
  }

  /// 获取3次曲线结果
  CubicCurveResult? get cubicCurveResult => _cubicCurveResult;

  /// 获取3次曲线显示状态
  bool get isCubicCurveVisible => _isCubicCurveVisible;

  /// 60均线过滤曲线计算
  void _calculateMA60FilteredCurve() {
    if (_wavePoints == null || _wavePoints!.mergedPoints.isEmpty) {
      LogService.instance.warning('WavePointsController', '波浪点数据为空，无法计算60均线过滤曲线');
      _ma60FilteredCurveResult = null;
      return;
    }

    try {
      // 获取60均线数据
      final maData = getMovingAveragesData();
      final ma60Series = maData[60];
      
      if (ma60Series == null || ma60Series.isEmpty) {
        LogService.instance.warning('WavePointsController', '60均线数据为空，无法计算60均线过滤曲线');
        _ma60FilteredCurveResult = null;
        return;
      }

      _ma60FilteredCurveResult = MA60FilteringService.instance.generateMA60FilteredCurve(
        wavePoints: _wavePoints!,
        priceDataList: data,
        ma60Series: ma60Series,
      );
      LogService.instance.info('WavePointsController', '60均线过滤曲线计算完成: ${_ma60FilteredCurveResult!.points.length}个点');
    } catch (e) {
      LogService.instance.error('WavePointsController', '60均线过滤曲线计算失败: $e');
      _ma60FilteredCurveResult = null;
    }
  }

  /// 切换60均线过滤曲线显示状态
  void toggleMA60FilteredCurveVisibility() {
    _isMA60FilteredCurveVisible = !_isMA60FilteredCurveVisible;
    LogService.instance.info('WavePointsController', '60均线过滤曲线显示状态切换: $_isMA60FilteredCurveVisible');
    
    // 如果启用显示且还没有计算过，则计算60均线过滤曲线
    if (_isMA60FilteredCurveVisible && _ma60FilteredCurveResult == null) {
      _calculateMA60FilteredCurve();
    }
    
    notifyUIUpdate();
  }

  /// 获取60均线过滤曲线结果
  MA60FilteredCurveResult? get ma60FilteredCurveResult => _ma60FilteredCurveResult;

  /// 获取60均线过滤曲线显示状态
  bool get isMA60FilteredCurveVisible => _isMA60FilteredCurveVisible;

  /// 設定から初期値を同期（外部から呼び出し可能）
  void syncSettingsFromAppSettings({
    String? selectedInterpolationMethod,
    bool? isFormattedWaveVisible,
    bool? isWavePointsVisible,
    bool? isWavePointsLineVisible,
    bool? isTrendFilteringEnabled,
    bool? isCubicCurveVisible,
    bool? isMA60FilteredCurveVisible,
  }) {
    bool settingsChanged = false;
    
    if (selectedInterpolationMethod != null && selectedInterpolationMethod != _selectedInterpolationMethod) {
      Log.info('WavePointsController', '設定同期: 選択方法 $_selectedInterpolationMethod -> $selectedInterpolationMethod');
      _selectedInterpolationMethod = selectedInterpolationMethod;
      settingsChanged = true;
    }
    
    if (isFormattedWaveVisible != null && isFormattedWaveVisible != _isFormattedWaveVisible) {
      Log.info('WavePointsController', '設定同期: フォーマット波表示 $_isFormattedWaveVisible -> $isFormattedWaveVisible');
      _isFormattedWaveVisible = isFormattedWaveVisible;
      settingsChanged = true;
    }
    
    if (isWavePointsVisible != null && isWavePointsVisible != _isWavePointsVisible) {
      Log.info('WavePointsController', '設定同期: ウェーブポイント表示 $_isWavePointsVisible -> $isWavePointsVisible');
      _isWavePointsVisible = isWavePointsVisible;
      settingsChanged = true;
    }
    
    if (isWavePointsLineVisible != null && isWavePointsLineVisible != _isWavePointsLineVisible) {
      Log.info('WavePointsController', '設定同期: ウェーブポイント線表示 $_isWavePointsLineVisible -> $isWavePointsLineVisible');
      _isWavePointsLineVisible = isWavePointsLineVisible;
      settingsChanged = true;
    }

    if (isCubicCurveVisible != null && isCubicCurveVisible != _isCubicCurveVisible) {
      Log.info('WavePointsController', '設定同期: 3次曲线显示 $_isCubicCurveVisible -> $isCubicCurveVisible');
      _isCubicCurveVisible = isCubicCurveVisible;
      settingsChanged = true;
      
      // 如果启用显示且还没有计算过，则计算3次曲线
      if (_isCubicCurveVisible && _cubicCurveResult == null) {
        _calculateCubicCurve();
      }
    }

    if (isMA60FilteredCurveVisible != null && isMA60FilteredCurveVisible != _isMA60FilteredCurveVisible) {
      Log.info('WavePointsController', '設定同期: 60均线过滤曲线显示 $_isMA60FilteredCurveVisible -> $isMA60FilteredCurveVisible');
      _isMA60FilteredCurveVisible = isMA60FilteredCurveVisible;
      settingsChanged = true;
      
      // 如果启用显示且还没有计算过，则计算60均线过滤曲线
      if (_isMA60FilteredCurveVisible && _ma60FilteredCurveResult == null) {
        _calculateMA60FilteredCurve();
      }
    }
    
    if (settingsChanged && _wavePoints != null) {
      Log.info('WavePointsController', '設定同期完了 - フォーマット波再生成');
      _generateFormattedWaves();
    }
  }

  /// ウェーブポイントを計算する（性能最適化版）
  void _calculateWavePoints() {
    // 最適化：既に計算済みでデータに変化がない場合、再計算しない
    if (_wavePoints != null) {
      Log.info('WavePointsController', 'ウェーブポイント既に計算済み、スキップ');
      return;
    }

    if (data.isEmpty) {
      Log.warning('WavePointsController', 'データが空のためウェーブポイント計算をスキップ');
      _wavePoints = null;
      return;
    }

    try {
      // 性能監視：計算開始時間
      final stopwatch = Stopwatch()..start();
      
      final maData = getMovingAveragesData();
      _wavePoints = WavePoints.fromPriceData(data, maData, _manualWavePoints);
      
      Log.info('WavePointsController', 'WavePoints生成完成: 高值点=${_wavePoints!.totalHighPoints}, 低值点=${_wavePoints!.totalLowPoints}');
      Log.info('WavePointsController', 'mergedPoints数量: ${_wavePoints!.mergedPoints.length}');
      Log.info('WavePointsController', '現在の選択方法: $_selectedInterpolationMethod');
      Log.info('WavePointsController', 'フォーマット波表示状態: $_isFormattedWaveVisible');
      
      // 只有在格式化波浪可见时才生成格式化波浪
      if (_isFormattedWaveVisible) {
        Log.info('WavePointsController', 'フォーマット波表示中 - 生成開始');
        _generateFormattedWaves();
      } else {
        Log.info('WavePointsController', 'フォーマット波非表示 - 生成スキップ');
      }

      // 3次曲线を生成（如果启用显示）
      if (_isCubicCurveVisible) {
        Log.info('WavePointsController', '3次曲线表示中 - 生成開始');
        _calculateCubicCurve();
      } else {
        Log.info('WavePointsController', '3次曲线非表示 - 生成スキップ');
      }

      // 60均线过滤曲线を生成（如果启用显示）
      if (_isMA60FilteredCurveVisible) {
        Log.info('WavePointsController', '60均线过滤曲线表示中 - 生成開始');
        _calculateMA60FilteredCurve();
      } else {
        Log.info('WavePointsController', '60均线过滤曲线非表示 - 生成スキップ');
      }
      
      stopwatch.stop();
      Log.info('WavePointsController', 'ウェーブポイント計算完了: 高値${_wavePoints!.totalHighPoints}個, 安値${_wavePoints!.totalLowPoints}個 (${stopwatch.elapsedMilliseconds}ms, データ量: ${data.length})');
      
      // 性能警告：計算時間が長すぎる場合
      if (stopwatch.elapsedMilliseconds > 200) {
        Log.warning('WavePointsController', 'ウェーブポイント計算時間が長い: ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      Log.error('WavePointsController', 'ウェーブポイント計算失敗: $e');
      _wavePoints = null;
    }
  }

  /// データ更新時にウェーブポイントを再計算
  void onDataUpdatedForWavePoints() {
    // キャッシュを強制クリアして、次回呼び出し時に再計算
    _wavePoints = null;
    _formattedWaves = null; // 格式化波浪缓存也清除
    _calculateWavePoints();
  }

  /// フォーマット波キャッシュをクリア（外部から呼び出し可能）
  void clearFormattedWavesCache() {
    Log.info('WavePointsController', 'フォーマット波キャッシュクリア');
    _formattedWaves = null;
  }

  /// 強制的にフォーマット波を再生成（外部から呼び出し可能）
  void forceRegenerateFormattedWaves() {
    Log.info('WavePointsController', '強制フォーマット波再生成開始');
    if (_wavePoints != null) {
      _generateFormattedWaves();
    } else {
      Log.warning('WavePointsController', 'ウェーブポイントが未計算のため強制再生成をスキップ');
    }
  }
  
  /// 生成格式化波浪
  void _generateFormattedWaves() {
    if (_wavePoints == null) return;
    
    try {
      // 生成不同插值方法的波浪线
      // 尝试获取150日均线数据用于MA趋势过滤
      List<double>? ma150Values;
      try {
        // 从宿主类获取移动平均线数据
        final maData = getMovingAveragesData();
        if (maData.containsKey(150)) {
          final ma150Data = maData[150];
          if (ma150Data != null && ma150Data.isNotEmpty) {
            // 过滤掉null值并转换为double
            // Ensure the length matches the original data length, filling gaps with a sentinel if needed, though MA calculation should already handle this.
            ma150Values = ma150Data.map((e) => e ?? double.nan).toList();
            if (ma150Values.length != data.length) {
              Log.warning('WavePointsController', 'MA150 length (${ma150Values.length}) does not match data length (${data.length}). MA-based filtering might be incorrect.');
              ma150Values = null; // Invalidate if lengths don't match
            }
            Log.info('WavePointsController', '成功获取150日均线数据: ${ma150Values?.length ?? 0}个点');
          } else {
            Log.warning('WavePointsController', '150日均线数据为空');
          }
        } else {
          Log.warning('WavePointsController', '未找到150日均线数据');
        }
      } catch (e) {
        Log.warning('WavePointsController', '获取MA数据失败: $e');
        ma150Values = null;
      }
      
      // 只生成用户选择的方法，提高性能
      Log.info('WavePointsController', 'MAデータ状況確認: ma150Values=${ma150Values != null ? "${ma150Values.length}個" : "null"}, 選択方法=$_selectedInterpolationMethod');
      _formattedWaves = WaveInterpolationService.generateFormattedWavesFromWavePoints(
        _wavePoints!,
        data,
        maValues: ma150Values,
        maPeriod: 150,
        selectedMethod: _selectedInterpolationMethod, // 只生成选择的方法
      );
      
      Log.info('WavePointsController', '格式化波浪生成完成: ${_formattedWaves!.keys.join(', ')}');
      Log.info('WavePointsController', '当前选择的插值方法: $_selectedInterpolationMethod');
      Log.info('WavePointsController', 'linear方法数据点数: ${_formattedWaves!['linear']?.length ?? 0}');
      Log.info('WavePointsController', '格式化波浪可见性: $_isFormattedWaveVisible');
    } catch (e) {
      Log.error('WavePointsController', '格式化波浪生成失败: $e');
      _formattedWaves = null;
    }

    // 生成完成后，通知UI更新
    notifyUIUpdate();
  }

  /// ウェーブポイントの表示/非表示を切り替え
  void toggleWavePointsVisibility() {
    _isWavePointsVisible = !_isWavePointsVisible;
    notifyUIUpdate();
  }

  /// ウェーブポイントが表示されているかどうか
  bool get isWavePointsVisible => _isWavePointsVisible;
  set isWavePointsVisible(bool value) {
    if (_isWavePointsVisible != value) {
      _isWavePointsVisible = value;
      notifyUIUpdate();
    }
  }

  /// ウェーブポイント接続線の表示/非表示を切り替え
  void toggleWavePointsLineVisibility() {
    _isWavePointsLineVisible = !_isWavePointsLineVisible;
    notifyUIUpdate();
  }

  /// ウェーブポイント接続線が表示されているかどうか
  bool get isWavePointsLineVisible => _isWavePointsLineVisible;
  set isWavePointsLineVisible(bool value) {
    if (_isWavePointsLineVisible != value) {
      _isWavePointsLineVisible = value;
      notifyUIUpdate();
    }
  }
  
  /// 格式化波浪数据
  Map<String, List<Map<String, dynamic>>>? get formattedWaves {
    if (_formattedWaves == null) return null;
    
    // 转换WavePoint为Map格式
    Map<String, List<Map<String, dynamic>>> result = {};
    _formattedWaves!.forEach((key, value) {
      result[key] = value.map((point) => {
        'timestamp': point.timestamp,
        'price': point.price,
        'type': point.type,
      }).toList();
    });
    
    Log.info('WavePointsController', 'formattedWaves getter返回: ${result.keys.join(', ')}');
    Log.info('WavePointsController', 'linear方法返回数据点数: ${result['linear']?.length ?? 0}');
    
    return result;
  }
  
  /// 选中的插值方法
  String get selectedInterpolationMethod => _selectedInterpolationMethod;
  set selectedInterpolationMethod(String value) {
    Log.info('WavePointsController', '選択方法変更呼び出し: $_selectedInterpolationMethod -> $value');
    Log.info('WavePointsController', '現在のフォーマット波表示状態: $_isFormattedWaveVisible');
    Log.info('WavePointsController', 'ウェーブポイント存在: ${_wavePoints != null}');
    
    if (_selectedInterpolationMethod != value) {
      Log.info('WavePointsController', '選択方法変更検出: $_selectedInterpolationMethod -> $value');
      _selectedInterpolationMethod = value;
      Log.info('WavePointsController', '選択方法変更確認: $_selectedInterpolationMethod, フォーマット波表示: $_isFormattedWaveVisible');
      
      // 根本的解決策：選択方法が変更された場合は、表示状態に関係なく強制再生成
      if (_wavePoints != null) {
        Log.info('WavePointsController', '選択方法変更による強制再生成開始');
        _generateFormattedWaves();
      } else {
        Log.warning('WavePointsController', 'ウェーブポイントが未計算のため再生成をスキップ');
      }
    } else {
      Log.info('WavePointsController', '選択方法変更なし（同じ値）: $value');
    }
  }
  
  /// 格式化波浪是否可见
  bool get isFormattedWaveVisible => _isFormattedWaveVisible;
  set isFormattedWaveVisible(bool value) {
    final wasVisible = _isFormattedWaveVisible;
    Log.info('WavePointsController', 'フォーマット波表示状態変更: $wasVisible -> $value');
    _isFormattedWaveVisible = value;
    
    // 如果从不可见变为可见，需要生成格式化波浪
    if (!wasVisible && value && _wavePoints != null) {
      Log.info('WavePointsController', 'フォーマット波表示ON - 生成開始');
      _generateFormattedWaves();
    } else if (wasVisible != value) {
      // 如果只是切换可见性（例如从可见到不可见），也需要通知UI更新
      Log.info('WavePointsController', 'フォーマット波表示状態変更 - UI更新');
      notifyUIUpdate();
    }
  }
  
  /// 切换格式化波浪显示
  void toggleFormattedWaveVisibility() {
    final wasVisible = _isFormattedWaveVisible;
    _isFormattedWaveVisible = !_isFormattedWaveVisible;
    
    // 如果从不可见变为可见，需要生成格式化波浪
    if (!wasVisible && _isFormattedWaveVisible && _wavePoints != null) {
      _generateFormattedWaves();
    }
  }

  /// ウェーブポイントデータを取得
  WavePoints? get wavePoints => _wavePoints;

  /// 表示範囲内のウェーブ高値を取得
  List<int> getVisibleWaveHighPoints() {
    if (_wavePoints == null) return [];
    // より効率的な方法：計算済みのmergedPointsをフィルタリング
    return _wavePoints!.mergedPoints
        .where((p) => p['type'] == 'high' && (p['index'] as int) >= startIndex && (p['index'] as int) < endIndex)
        .map((p) => p['index'] as int)
        .toList();
  }

  /// 表示範囲内のウェーブ安値を取得
  List<int> getVisibleWaveLowPoints() {
    if (_wavePoints == null) return [];
    return _wavePoints!.mergedPoints
        .where((p) => p['type'] == 'low' && (p['index'] as int) >= startIndex && (p['index'] as int) < endIndex)
        .map((p) => p['index'] as int)
        .toList();
  }

  /// 全てのウェーブ高値のインデックスを取得
  List<int> getAllWaveHighPointIndices() {
    if (_wavePoints == null) return [];
    return _wavePoints!.mergedPoints.where((p) => p['type'] == 'high').map((p) => p['index'] as int).toList();
  }

  /// 全てのウェーブ安値のインデックスを取得
  List<int> getAllWaveLowPointIndices() {
    if (_wavePoints == null) return [];
    return _wavePoints!.mergedPoints.where((p) => p['type'] == 'low').map((p) => p['index'] as int).toList();
  }

  /// 全てのウェーブポイントのリストを取得（描画最適化用）
  List<Map<String, dynamic>> getMergedWavePoints() {
    if (_wavePoints == null) return [];
    return _wavePoints!.mergedPoints;
  }

  /// 指定されたインデックスがウェーブ高値かどうか
  bool isWaveHighPoint(int index) {
    return _wavePoints?.isWaveHighPoint(index) ?? false;
  }

  /// 指定されたインデックスがウェーブ安値かどうか
  bool isWaveLowPoint(int index) {
    return _wavePoints?.isWaveLowPoint(index) ?? false;
  }

  /// 手動でウェーブポイントを追加
  Future<bool> addManualWavePoint(int index, String type) async {
    if (index < 0 || index >= data.length) return false;
    
    try {
      final timestamp = data[index].timestamp;
      final success = await WavePointsService.instance.addManualWavePoint(timestamp, type);
      if (success) {
        _manualWavePoints[timestamp] = type;
        _calculateWavePoints(); // 再計算
        Log.info('WavePointsController', '手動ウェーブポイント追加成功: インデックス$index, タイプ$type');
      }
      return success;
    } catch (e) {
      Log.error('WavePointsController', '手動ウェーブポイント追加失敗: $e');
      return false;
    }
  }

  /// 手動でウェーブポイントを削除
  Future<bool> removeManualWavePoint(int index) async {
    if (index < 0 || index >= data.length) return false;
    
    try {
      final timestamp = data[index].timestamp;
      final success = await WavePointsService.instance.removeManualWavePoint(timestamp);
      if (success) {
        _manualWavePoints[timestamp] = 'removed';
        _calculateWavePoints(); // 再計算
        Log.info('WavePointsController', '手動ウェーブポイント削除成功: インデックス$index');
      }
      return success;
    } catch (e) {
      Log.error('WavePointsController', '手動ウェーブポイント削除失敗: $e');
      return false;
    }
  }

  /// すべての手動ウェーブポイントをクリア
  Future<bool> clearAllManualWavePoints() async {
    try {
      final success = await WavePointsService.instance.clearAllManualWavePoints();
      if (success) {
        _manualWavePoints.clear();
        _calculateWavePoints(); // 再計算
        Log.info('WavePointsController', 'すべての手動ウェーブポイントクリア成功');
      }
      return success;
    } catch (e) {
      Log.error('WavePointsController', 'すべての手動ウェーブポイントクリア失敗: $e');
      return false;
    }
  }

  /// ウェーブポイント統計情報を取得
  Future<Map<String, dynamic>> getWavePointsStats() async {
    return await WavePointsService.instance.getWavePointsStats();
  }

  /// 指定されたインデックスのウェーブポイント情報を取得
  Map<String, dynamic>? getWavePointInfo(int index) {
    if (_wavePoints == null || index < 0 || index >= data.length) return null;
    
    final priceData = data[index];
    final isHigh = isWaveHighPoint(index);
    final isLow = isWaveLowPoint(index);
    
    if (!isHigh && !isLow) return null;
    
    return {
      'index': index,
      'timestamp': priceData.timestamp,
      'type': isHigh ? 'high' : 'low',
      'value': isHigh ? priceData.high : priceData.low,
      'time': DateTime.fromMillisecondsSinceEpoch(priceData.timestamp),
    };
  }

  /// 波浪点の総数を取得
  int get totalWavePoints => _wavePoints?.totalWavePoints ?? 0;

  /// 波浪高点の数を取得
  int get totalHighPoints => _wavePoints?.totalHighPoints ?? 0;

  /// 波浪低点の数を取得
  int get totalLowPoints => _wavePoints?.totalLowPoints ?? 0;
}
