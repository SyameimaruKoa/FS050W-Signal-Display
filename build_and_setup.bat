@echo off
rem ============================================================================
rem FS050W Signal Display ビルド・環境構築バッチ
rem ※詳しい使い方のヘルプは本スクリプト下部に定義されています (ラベル: SHOW_HELP)
rem ============================================================================

if "%~1"=="" goto SHOW_HELP_PAUSE
if "%~1"=="-h" goto SHOW_HELP
if "%~1"=="--help" goto SHOW_HELP
if "%~1"=="/?" goto SHOW_HELP

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_and_setup.ps1" %*
exit /b %ERRORLEVEL%

:SHOW_HELP_PAUSE
call :SHOW_HELP
echo.
pause
exit /b 0

:SHOW_HELP
echo ============================================================================
echo  FS050W Signal Display コマンドラインツール 使い方
echo ============================================================================
echo.
echo [使用法]
echo   build_and_setup.bat [オプション]
echo.
echo [主なオプション]
echo   -CheckEnv        開発環境（Java, Git, Flutter, Android SDK, ADB）の状態を診断
echo   -InstallFlutter  Flutter SDK を自動取得してユーザー環境変数 PATH を設定
echo   -BuildApk        単体テスト実行後、ユニバーサル リリース版 APK をビルド
echo   -BuildSplitApk   単体テスト実行後、アーキテクチャ別 (arm64-v8a等) リリース版 APK をビルド
echo   -InstallApk      ビルド済み APK を接続中の Android 端末にインストール
echo   -Run             Android 端末でアプリを起動
echo   -h, --help       このヘルプを表示
echo.
echo [実行例]
echo   build_and_setup.bat -CheckEnv
echo   build_and_setup.bat -InstallFlutter
echo   build_and_setup.bat -BuildSplitApk
echo   build_and_setup.bat -BuildApk
echo ============================================================================
exit /b 0
