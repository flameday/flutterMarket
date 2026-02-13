import 'dart:async';
import 'dart:io';
import 'log_service.dart';
import 'path_service.dart';

/// 竖线配置文件监控服务
/// 监控vertical_lines.json文件的变化，并在文件更新时通知所有监听器
class VerticalLineFileWatcher {
  static VerticalLineFileWatcher? _instance;
  static VerticalLineFileWatcher get instance => _instance ??= VerticalLineFileWatcher._internal();
  
  VerticalLineFileWatcher._internal();
  
  static const String _fileName = 'vertical_lines.json';
  late StreamSubscription<FileSystemEvent> _subscription;
  final StreamController<void> _fileChangedController = StreamController<void>.broadcast();
  bool _isWatching = false;
  String? _lastFileContent;
  DateTime? _lastModified;

  /// 文件变化事件流
  Stream<void> get onFileChanged => _fileChangedController.stream;

  /// 开始监控竖线配置文件
  Future<void> startWatching() async {
    if (_isWatching) {
      Log.info('VerticalLineFileWatcher', '竖线配置文件监控器已运行中');
      return;
    }

    try {
      // 获取竖线配置文件路径
      final filePath = await _getFilePath();
      final file = File(filePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        Log.warning('VerticalLineFileWatcher', '竖线配置文件不存在: $filePath');
        // 创建空文件
        await file.writeAsString('[]');
        Log.info('VerticalLineFileWatcher', '创建空的竖线配置文件: $filePath');
      }

      // 记录初始文件状态
      await _updateFileState(file);

      // 获取文件所在目录
      final directory = file.parent;
      
      // 开始监控目录变化
      _subscription = directory.watch(events: FileSystemEvent.modify, recursive: false).listen(
        (FileSystemEvent event) {
          if (event.path == filePath) {
            _handleFileChange(event);
          }
        },
        onError: (error) {
          Log.error('VerticalLineFileWatcher', '文件监控错误: $error');
        },
      );

      _isWatching = true;
      Log.info('VerticalLineFileWatcher', '竖线配置文件监控器启动成功: $filePath');
    } catch (e) {
      Log.error('VerticalLineFileWatcher', '竖线配置文件监控器启动失败: $e');
    }
  }

  /// 停止监控
  Future<void> stopWatching() async {
    if (!_isWatching) return;

    try {
      await _subscription.cancel();
      _isWatching = false;
      Log.info('VerticalLineFileWatcher', '竖线配置文件监控器已停止');
    } catch (e) {
      Log.error('VerticalLineFileWatcher', '停止监控器失败: $e');
    }
  }

  /// 处理文件变化事件
  Future<void> _handleFileChange(FileSystemEvent event) async {
    try {
      final file = File(event.path);
      
      // 检查文件是否真的发生了变化
      if (!await _hasFileChanged(file)) {
        return;
      }

      // 更新文件状态
      await _updateFileState(file);

      // 通知所有监听器
      _fileChangedController.add(null);
      Log.info('VerticalLineFileWatcher', '竖线配置文件已更新，通知所有监听器');
    } catch (e) {
      Log.error('VerticalLineFileWatcher', '处理文件变化失败: $e');
    }
  }

  /// 检查文件是否真的发生了变化
  Future<bool> _hasFileChanged(File file) async {
    try {
      final stat = await file.stat();
      final currentModified = stat.modified;
      
      // 如果修改时间没有变化，文件内容可能也没有变化
      if (_lastModified != null && currentModified == _lastModified) {
        return false;
      }

      // 读取文件内容进行比较
      final currentContent = await file.readAsString();
      if (_lastFileContent == currentContent) {
        return false;
      }

      return true;
    } catch (e) {
      Log.error('VerticalLineFileWatcher', '检查文件变化失败: $e');
      return false;
    }
  }

  /// 更新文件状态
  Future<void> _updateFileState(File file) async {
    try {
      final stat = await file.stat();
      _lastModified = stat.modified;
      _lastFileContent = await file.readAsString();
    } catch (e) {
      Log.error('VerticalLineFileWatcher', '更新文件状态失败: $e');
    }
  }

  /// 获取竖线配置文件路径
  Future<String> _getFilePath() async {
    return PathService.instance.getConfigFilePath(_fileName);
  }

  /// 手动触发文件变化通知（用于测试）
  void triggerFileChange() {
    _fileChangedController.add(null);
    Log.info('VerticalLineFileWatcher', '手动触发文件变化通知');
  }

  /// 释放资源
  void dispose() {
    stopWatching();
    _fileChangedController.close();
  }
}
