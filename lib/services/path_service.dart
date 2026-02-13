import 'dart:io';

/// 统一路径管理服务
/// 所有日志和配置文件都放在exe同级目录下
class PathService {
  static PathService? _instance;
  static PathService get instance => _instance ??= PathService._internal();
  
  PathService._internal();
  
  String? _exeDirectory;
  
  /// 获取exe同级目录路径
  Future<String> getExeDirectory() async {
    if (_exeDirectory != null) {
      return _exeDirectory!;
    }
    
    try {
      // 获取当前工作目录（通常是exe所在目录）
      final currentDir = Directory.current.path;
      _exeDirectory = currentDir;
      
      // 确保目录存在
      final dir = Directory(_exeDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      return _exeDirectory!;
    } catch (e) {
      // 如果获取失败，使用当前目录作为备选
      _exeDirectory = Directory.current.path;
      return _exeDirectory!;
    }
  }
  
  /// 获取日志目录路径
  Future<String> getLogDirectory() async {
    final exeDir = await getExeDirectory();
    final logDir = '$exeDir/logs';
    
    // 确保日志目录存在
    final dir = Directory(logDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return logDir;
  }
  
  /// 获取配置文件目录路径
  Future<String> getConfigDirectory() async {
    final exeDir = await getExeDirectory();
    final configDir = '$exeDir/config';
    
    // 确保配置目录存在
    final dir = Directory(configDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return configDir;
  }
  
  /// 获取数据目录路径
  Future<String> getDataDirectory() async {
    final exeDir = await getExeDirectory();
    final dataDir = '$exeDir/data';
    
    // 确保数据目录存在
    final dir = Directory(dataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return dataDir;
  }
  
  /// 获取日志文件路径
  Future<String> getLogFilePath(String fileName) async {
    final logDir = await getLogDirectory();
    return '$logDir/$fileName';
  }
  
  /// 获取配置文件路径
  Future<String> getConfigFilePath(String fileName) async {
    final configDir = await getConfigDirectory();
    return '$configDir/$fileName';
  }
  
  /// 获取数据文件路径
  Future<String> getDataFilePath(String fileName) async {
    final dataDir = await getDataDirectory();
    return '$dataDir/$fileName';
  }
}
