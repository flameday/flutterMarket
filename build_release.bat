@REM @echo off
@REM echo Building Flutter Drawer App for Release...

@REM @REM REM 清理之前的构建
@REM @REM echo Cleaning previous build...
@REM @REM flutter clean

@REM @REM REM 获取依赖
@REM @REM echo Getting dependencies...
@REM @REM flutter pub get

@REM REM 构建Windows应用
@REM echo Building Windows application...
@REM flutter build windows --release -v
xcopy "data\" "build\windows\x64\runner\Release\data\" /E /I /Y
echo Build completed successfully!
echo Release files are in the 'build\windows\x64\runner\Release' directory.
pause
@REM REM 检查构建是否成功
@REM if %ERRORLEVEL% neq 0 (
@REM     echo Build failed!
@REM     pause
@REM     exit /b 1
@REM )

@REM REM 创建发布目录
@REM set RELEASE_DIR=release
@REM if exist %RELEASE_DIR% rmdir /s /q %RELEASE_DIR%
@REM mkdir %RELEASE_DIR%

@REM REM 复制exe文件
@REM echo Copying executable...
@REM copy "build\windows\x64\runner\Release\flutter_drawer_app.exe" "%RELEASE_DIR%\"

@REM REM 复制data目录
@REM echo Copying data directory...
@REM if exist data (
@REM     xcopy "data" "%RELEASE_DIR%\data\" /E /I /Y
@REM ) else (
@REM     echo Warning: data directory not found!
@REM )

@REM REM 复制必要的DLL文件
@REM echo Copying required DLLs...
@REM copy "build\windows\x64\runner\Release\flutter_windows.dll" "%RELEASE_DIR%\" 2>nul
@REM copy "build\windows\x64\runner\Release\*.dll" "%RELEASE_DIR%\" 2>nul

@REM REM 复制flutter_assets目录
@REM echo Copying Flutter assets...
@REM if exist "build\windows\x64\runner\Release\data\flutter_assets" (
@REM     xcopy "build\windows\x64\runner\Release\data\flutter_assets" "%RELEASE_DIR%\data\flutter_assets\" /E /I /Y
@REM )

@REM REM 复制其他必要文件
@REM echo Copying additional files...
@REM if exist "build\windows\x64\runner\Release\icudtl.dat" (
@REM     copy "build\windows\x64\runner\Release\icudtl.dat" "%RELEASE_DIR%\"
@REM )

@REM REM 创建启动脚本
@REM echo Creating startup script...
@REM echo @echo off > "%RELEASE_DIR%\start.bat"
@REM echo echo Starting Flutter Drawer App... >> "%RELEASE_DIR%\start.bat"
@REM echo flutter_drawer_app.exe >> "%RELEASE_DIR%\start.bat"
@REM echo pause >> "%RELEASE_DIR%\start.bat"

@REM REM 创建README文件
@REM echo Creating README...
@REM echo Flutter Drawer App - Release Build > "%RELEASE_DIR%\README.txt"
@REM echo. >> "%RELEASE_DIR%\README.txt"
@REM echo This is a release build of the Flutter Drawer App. >> "%RELEASE_DIR%\README.txt"
@REM echo. >> "%RELEASE_DIR%\README.txt"
@REM echo To run the application: >> "%RELEASE_DIR%\README.txt"
@REM echo 1. Double-click start.bat, or >> "%RELEASE_DIR%\README.txt"
@REM echo 2. Double-click flutter_drawer_app.exe >> "%RELEASE_DIR%\README.txt"
@REM echo. >> "%RELEASE_DIR%\README.txt"
@REM echo Data files are stored in the 'data' directory. >> "%RELEASE_DIR%\README.txt"
@REM echo Logs and configuration files will be created automatically. >> "%RELEASE_DIR%\README.txt"

@REM echo.
@REM echo Build completed successfully!
@REM echo Release files are in the '%RELEASE_DIR%' directory.
@REM echo.
@REM pause
