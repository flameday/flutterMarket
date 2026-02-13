# Flutter Drawer App 构建说明

## 构建脚本

本项目提供了两个构建脚本来简化构建过程：

### 1. 调试构建 (build_debug.bat)
用于开发环境的调试构建：
```bash
build_debug.bat
```

**功能：**
- 清理之前的构建
- 获取依赖
- 构建Windows调试版本
- 自动复制data目录到exe目录
- 复制所有必要的DLL和资源文件
- 创建独立的debug目录

### 2. 发布构建 (build_release.bat)
用于生产环境的发布构建：
```bash
build_release.bat
```

**功能：**
- 清理之前的构建
- 获取依赖
- 构建Windows发布版本
- 自动复制data目录到exe目录
- 复制所有必要的DLL和资源文件
- 创建独立的release目录
- 包含启动脚本和说明文档

## 目录结构

构建完成后，会创建以下目录结构：

```
debug/ 或 release/
├── flutter_drawer_app.exe    # 主程序
├── flutter_windows.dll       # Flutter运行时
├── icudtl.dat               # ICU数据文件
├── data/                    # 数据目录
│   ├── EURUSD/
│   │   ├── m5/
│   │   ├── m30/
│   │   └── h4/
│   ├── USDJPY/
│   └── ...
├── data/flutter_assets/     # Flutter资源
└── start.bat               # 启动脚本
```

## 数据目录说明

- **data/**: 包含所有品种的历史数据
- **config/**: 应用程序配置文件（运行时自动创建）
- **logs/**: 应用程序日志文件（运行时自动创建）

## 运行应用程序

### 方法1：使用启动脚本
双击 `start.bat` 文件

### 方法2：直接运行
双击 `flutter_drawer_app.exe` 文件

## 注意事项

1. **数据目录**: 确保在构建前，`data/` 目录包含所需的历史数据文件
2. **依赖文件**: 构建脚本会自动复制所有必要的DLL和资源文件
3. **路径管理**: 应用程序使用相对路径，所有文件都在同一目录下
4. **配置文件**: 首次运行时会在exe目录下自动创建 `config/` 和 `logs/` 目录

## 手动构建

如果需要手动构建，可以使用以下命令：

```bash
# 清理
flutter clean

# 获取依赖
flutter pub get

# 构建
flutter build windows --release  # 或 --debug

# 手动复制data目录
xcopy "data" "build\windows\x64\runner\Release\data\" /E /I /Y
```

## 故障排除

1. **构建失败**: 检查Flutter环境是否正确安装
2. **运行时错误**: 确保所有DLL文件都在同一目录下
3. **数据加载失败**: 检查data目录是否包含正确的CSV文件
4. **国际化错误**: 确保已正确初始化日期格式化

## 版本信息

- Flutter版本: 3.x
- Dart版本: 3.x
- 目标平台: Windows x64
