@echo off
echo Building Flutter Drawer App for Debug...

REM 清理之前的构建
echo Cleaning previous build...
flutter clean

REM 获取依赖
echo Getting dependencies...
flutter pub get

REM 构建Windows应用
echo Building Windows application...
flutter build windows --debug

REM 检查构建是否成功
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

REM 创建调试目录
set DEBUG_DIR=debug
if exist %DEBUG_DIR% rmdir /s /q %DEBUG_DIR%
mkdir %DEBUG_DIR%

REM 复制exe文件
echo Copying executable...
copy "build\windows\x64\runner\Debug\flutter_drawer_app.exe" "%DEBUG_DIR%\"

REM 复制data目录
echo Copying data directory...
if exist data (
    xcopy "data" "%DEBUG_DIR%\data\" /E /I /Y
) else (
    echo Warning: data directory not found!
)

REM 复制必要的DLL文件
echo Copying required DLLs...
copy "build\windows\x64\runner\Debug\flutter_windows.dll" "%DEBUG_DIR%\" 2>nul
copy "build\windows\x64\runner\Debug\*.dll" "%DEBUG_DIR%\" 2>nul

REM 复制flutter_assets目录
echo Copying Flutter assets...
if exist "build\windows\x64\runner\Debug\data\flutter_assets" (
    xcopy "build\windows\x64\runner\Debug\data\flutter_assets" "%DEBUG_DIR%\data\flutter_assets\" /E /I /Y
)

REM 复制其他必要文件
echo Copying additional files...
if exist "build\windows\x64\runner\Debug\icudtl.dat" (
    copy "build\windows\x64\runner\Debug\icudtl.dat" "%DEBUG_DIR%\"
)

REM 创建启动脚本
echo Creating startup script...
echo @echo off > "%DEBUG_DIR%\start.bat"
echo echo Starting Flutter Drawer App (Debug)... >> "%DEBUG_DIR%\start.bat"
echo flutter_drawer_app.exe >> "%DEBUG_DIR%\start.bat"
echo pause >> "%DEBUG_DIR%\start.bat"

echo.
echo Debug build completed successfully!
echo Debug files are in the '%DEBUG_DIR%' directory.
echo.
pause
