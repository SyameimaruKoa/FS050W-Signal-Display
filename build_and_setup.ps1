<#
.SYNOPSIS
    FS050W 電波監視アプリ 環境構築 & ビルド自動化スクリプト

.DESCRIPTION
    富士ソフト製 5G モバイルルーター「+F FS050W」専用 Android 電波監視アプリの
    開発環境チェック、Flutter SDK インストール、テスト実行、APK ビルド、端末インストールを行います。

.PARAMETER CheckEnv
    インストール済みツールの状態（Java, Git, Flutter, Android SDK, ADB）を診断します。

.PARAMETER InstallFlutter
    Flutter SDK (最新 Stable 版) をユーザーフォルダに自動ダウンロード・配置し、PATH を設定します。

.PARAMETER BuildApk
    依存パッケージ取得、単体テスト実行後、リリース版 APK (app-release.apk) をビルドします。

.PARAMETER InstallApk
    ビルド済み APK を USB/Wi-Fi で接続されている Android 端末へインストールします。

.PARAMETER Run
    接続中 Android 端末でアプリを直接起動・デバッグ実行します。

.PARAMETER ShowHelp
    ヘルプを表示します。(-h, --help も同様に機能します)

.EXAMPLE
    .\build_and_setup.ps1 -CheckEnv
    環境の状態を確認します。

.EXAMPLE
    .\build_and_setup.ps1 -InstallFlutter
    Flutter SDK をダウンロードして環境を構築します。

.EXAMPLE
    .\build_and_setup.ps1 -BuildApk
    単体テストを実行し、リリース用 APK をビルドします。
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [Parameter(ParameterSetName = 'Check')]
    [switch]$CheckEnv,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$InstallFlutter,

    [Parameter(ParameterSetName = 'Build')]
    [switch]$BuildApk,

    [Parameter(ParameterSetName = 'InstallApp')]
    [switch]$InstallApk,

    [Parameter(ParameterSetName = 'RunApp')]
    [switch]$Run,

    [Parameter(ParameterSetName = 'Help')]
    [Alias('h', 'help')]
    [switch]$ShowHelp
)

#region Helper Functions
function Show-DetailedHelp {
    Get-Help $MyInvocation.PSCommandPath -Detailed
}

function Write-InfoLog([string]$msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-SuccessLog([string]$msg) {
    Write-Host "[SUCCESS] $msg" -ForegroundColor Green
}

function Write-WarnLog([string]$msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-ErrorLog([string]$msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}
#endregion

#region Parameter Validation
if ($PSBoundParameters.Count -eq 0 -or $ShowHelp) {
    Show-DetailedHelp
    exit 0
}
#endregion

#region Environment Diagnostic
if ($CheckEnv) {
    Write-InfoLog "開発環境の診断を開始します..."
    
    # 1. Java
    try {
        $javaVersion = java -version 2>&1 | Out-String
        Write-SuccessLog "Java JDK: 検出済`n$($javaVersion.Trim())"
    } catch {
        Write-ErrorLog "Java JDK が見つかりません。"
    }

    # 2. Git
    try {
        $gitVer = git --version
        Write-SuccessLog "Git: $gitVer"
    } catch {
        Write-ErrorLog "Git が見つかりません。"
    }

    # 3. ADB (Platform-Tools)
    try {
        $adbVer = adb --version 2>&1 | Out-String
        Write-SuccessLog "ADB: 検出済`n$($adbVer.Trim())"
    } catch {
        Write-WarnLog "ADB が見つかりません。"
    }

    # 4. Flutter
    try {
        $flutterVer = flutter --version 2>&1 | Out-String
        Write-SuccessLog "Flutter SDK: 検出済`n$($flutterVer.Trim())"
    } catch {
        Write-WarnLog "Flutter SDK が見つかりません。'-InstallFlutter' オプションで導入できます。"
    }

    # 5. Android SDK
    $localSdk = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $localSdk) {
        Write-SuccessLog "Android SDK ディレクトリ: $localSdk"
    } else {
        Write-WarnLog "Android SDK ($localSdk) が未初期化です。Android Studio を一度起動して SDK コンポーネントをダウンロードしてください。"
    }

    exit 0
}
#endregion

#region Flutter Installation
if ($InstallFlutter) {
    Write-InfoLog "Flutter SDK (Stable) のセットアップを開始します..."
    $targetDir = "$env:USERPROFILE\flutter"

    if (Test-Path $targetDir) {
        Write-WarnLog "既に $targetDir が存在します。git pull で更新を試みます..."
        Push-Location $targetDir
        git pull
        Pop-Location
    } else {
        Write-InfoLog "GitHub から Flutter SDK (stable) を取得中 ($targetDir)..."
        git clone https://github.com/flutter/flutter.git -b stable $targetDir
    }

    $flutterBin = "$targetDir\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notmatch [regex]::Escape($flutterBin)) {
        Write-InfoLog "ユーザー環境変数 PATH に $flutterBin を追加中..."
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
        $env:Path = "$env:Path;$flutterBin"
    }

    Write-SuccessLog "Flutter SDK の配置が完了しました。'flutter doctor' を実行します..."
    & "$flutterBin\flutter.bat" doctor
    exit 0
}
#endregion

#region Build APK
if ($BuildApk) {
    Write-InfoLog "リリース版 APK のビルドプロセスを開始します..."

    Write-InfoLog "1. 依存パッケージ取得 (flutter pub get)..."
    flutter pub get

    Write-InfoLog "2. 単体テスト実行 (flutter test)..."
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorLog "単体テストに失敗したためビルドを中止します。"
        exit $LASTEXITCODE
    }

    Write-InfoLog "3. APK ビルド (flutter build apk --release)..."
    flutter build apk --release

    if ($LASTEXITCODE -eq 0) {
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            Write-SuccessLog "🎉 APK ビルドが正常に完了しました！ 出力先: $apkPath"
        }
    } else {
        Write-ErrorLog "APK ビルド中にエラーが発生しました。"
    }
    exit $LASTEXITCODE
}
#endregion

#region Install APK
if ($InstallApk) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        Write-ErrorLog "ビルド済み APK が見つかりません。先に '-BuildApk' を実行してください。"
        exit 1
    }

    Write-InfoLog "接続中 Android 端末へ APK をインストール中..."
    adb install -r $apkPath
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessLog "インストールが完了しました！"
    } else {
        Write-ErrorLog "インストールに失敗しました。端末のUSBデバッグ接続を確認してください。"
    }
    exit $LASTEXITCODE
}
#endregion

#region Run App
if ($Run) {
    Write-InfoLog "Android 端末でアプリを起動します..."
    flutter run
    exit $LASTEXITCODE
}
#endregion
