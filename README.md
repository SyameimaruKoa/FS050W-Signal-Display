# +F FS050W Signal Monitor (FS050W 電波監視アプリ)

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-green.svg)](https://www.android.com)
[![Version](https://img.shields.io/badge/Version-0.0.2-orange.svg)](https://github.com/SyameimaruKoa/FS050W-Signal-Monitor)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

富士ソフト製 5G/4G モバイルルーター **「+F FS050W」** の電波状態・セル情報・通信品質をリアルタイムに取得・可視化・常駐監視する Android アプリケーションです。

---

## 📱 主な機能

### 1. リアルタイム電波ダッシュボード (Dashboard)
- **5G NR (Sub-6 / SA / NSA) & 4G LTE セル情報表示**:
  - RSRP（電波受信強度 / dBm）
  - RSRQ（受信信号品質 / dB）
  - SINR / SNR（信号対雑音比 / dB）
  - Band（n77, n78, n79, B1, B3, B8, B18, B19, B26, B28, B41, B42 等）および周波数（MHz）
  - PCI（Physical Cell ID）
  - 接続事業者（キャリア名）
- **視覚的カラーインジケーター**: 電波強度・品質を「極めて優秀」「良好」「普通」「やや弱い」「圏外」の5段階カラーゲージで直感的に把握。
- **5G SA / NSA 自動判別**: 5G SA（Standalone）接続時は自動で不要な4Gアンカーセルカードを非表示化。
- **ルーターバッテリー残量表示**: バッテリー残量パーセントおよび給電・充電中ステータス（⚡）をリアルタイム表示。

### 2. ロック画面・ステータスバー常駐通知 (Foreground Service)
- **完全サイレント常駐**: 1秒〜数秒ごとの定期更新時にも音・バイブ・点滅・ポップアップを一切発生させず、静かにステータスバー・通知シェードに常駐。
- **状態変化ラッチ通知**: 5G+エリア突入時や基地局ハンドオーバー（PCI/Band切替）時、電波危険低下時のみ、重複なしでピンポイントにイベント通知を発行。

### 3. リアルタイム同期タイムシリーズグラフ (Sync Graph)
- **3連時間軸同期チャート**: RSRP、RSRQ、SINR の推移を同一の時間軸で並べてリアルタイム描画。
- **スパン切り替え**: 1分・3分・5分・10分の表示期間をワンタップで切り替え可能。
- **安定描画**: チャートホバー時やスパン変更時にもグラフが横ブレ・ゼブラ化しない固定境界レンダリング。

### 4. 有機EL向け HUD 全画面常時表示モード (HUD Mode)
- **Immersive Fullscreen**: ナビゲーションバーやステータスバーを隠した完全全画面表示。
- **省電力・焼き付き防止**: ピュアブラック（True Black）背景と、有機ELディスプレイ（OLED）のピクセル焼き付きを防止する微細ジッター（Anti-burn-in）アニメーションを搭載。
- 画面をタップするだけで即座に通常モードへ復帰。

### 5. アプリ内診断ログViewer & エクスポート (Diagnostics Log)
- ルーター（`192.168.155.1`）とのHTTP通信結果、CSRFトークン取得状態、APIレスポンスコード等の診断ログをアプリ内で確認可能。
- ワンタップでクリップボードへコピーしてトラブルシューティングに活用可能。

### 6. 柔軟な設定と自動保存 (Settings)
- ルーターIPアドレス設定（デフォルト: `192.168.155.1`）
- Web管理パスワード設定（未認証フォールバックによるパスワードレス取得にも対応）
- フォアグラウンド / バックグラウンドのポーリング間隔の個別指定（1秒〜30秒）
- 常駐通知スタイル設定、各種アラート・バイブレーションのON/OFF
- 全ての設定変更は即座に永続化（自動保存）。

---

## 🛠 動作環境

- **対応OS**: Android 8.0 以上 (API レベル 26 以上)
  - Android 14 / 15 / 16 (Samsung One UI, Google Pixel, AOSP) 動作確認済み
- **対応ルーター**: 富士ソフト +F FS050W (Wi-Fi接続)
- **開発フレームワーク**: Flutter 3.0+ / Dart 3.0+

---

## 🚀 ビルドとインストール

### 1. リポジトリのクローン
```bash
git clone https://github.com/SyameimaruKoa/FS050W-Signal-Monitor.git
cd FS050W-Signal-Monitor
```

### 2. 依存パッケージの取得
```bash
flutter pub get
```

### 3. デバッグ実行（実機またはエミュレーター）
```bash
# 接続されている端末・エミュレーターで実行
flutter run
```

### 4. リリースAPKのビルド
```bash
flutter build apk --release
```
生成されたAPKファイルは `build/app/outputs/flutter-apk/app-release.apk` に出力されます。

---

## 💻 Android Studio エミュレーターでの動作確認

本アプリは Android Studio の標準エミュレーター（AVD: Pixel 8 / Pixel 10a / Android 14+）での実行に対応しています。

1. **PCを FS050W の Wi-Fi に接続** します。
2. Android Studio の **Device Manager** から AVD（例: `Pixel_10a`）を起動します。
3. エミュレーターはホストPCのネットワークブリッジを経由してルーター（`192.168.155.1`）と通信可能です。
4. 初回起動時のセットアップ画面でルーターIP（`192.168.155.1`）を入力し「監視を開始する」をタップすると、エミュレーター上で実機ルーターの電波データがリアルタイムに表示されます。

---

## 📝 リリースノート (Changelog)

### v0.0.2 (2026-08-21)
- **エミュレーター対応**: Android Studio 標準エミュレーター（Pixel / Android 37+）での動作検証および対応。
- **常駐通知の安定化**:
  - 1秒ごとの電波取得時に発生していた通知のチラつき・再描画点滅・音/バイブの連続発火を完全解消。
  - 状態変化ラッチ（Latch）を導入し、5G+突入やハンドオーバー時のみ1度だけ通知を発行するよう最適化。
  - 常駐通知を `FlutterForegroundTask`（`NotificationChannelImportance.LOW` / 完全サイレント）に一本化。
- **同期グラフの改善**:
  - ホバー時のグラフ横ブレ・10分スパン上のゼブラ表示バグを修正。
- **バッテリー・充電状態の表示**:
  - ダッシュボードの接続バーにルーターのバッテリー残量（%）と充電アイコン（⚡）を追加。
- **HUDモードの拡張**:
  - 全画面（Immersive Fullscreen）化、RSRP/RSRQ/SINR/Band/PCI/キャリア等の包括表示、有機EL焼き付き防止アニメーションを実装。
- **診断ログViewer機能**:
  - 通信状態の把握・ログエクスポート用モーダルを追加。
- **UIレイアウトの調整**:
  - 評価文言の変更に伴う数値の左右ズレを固定幅レイアウトで防止。
  - 設定画面のチェックボタンを廃止し、変更時の自動即時保存に統一。

### v0.0.1 (2026-08-20)
- 初回テストリリース

---

## 📄 ライセンス

本プロジェクトは MIT License の下で公開されています。
