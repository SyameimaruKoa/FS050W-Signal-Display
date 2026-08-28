# +F FS050W Signal Display (FS050W 電波監視・エンジニアリング表示アプリ)

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)
[![Android](<https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-green.svg>)](https://www.android.com)
[![Version](https://img.shields.io/badge/Version-1.5.0-orange.svg)](https://github.com/SyameimaruKoa/FS050W-Signal-Display/releases)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](https://github.com/SyameimaruKoa/FS050W-Signal-Display/releases)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

富士ソフト製 5G/4G モバイルルーター **「+F FS050W」** の電波状態・セル情報・バッテリー詳細・ハードウェア統計をリアルタイムに取得・可視化・常駐監視する Android アプリケーションです。

---

## 📸 スクリーンショット

|                 機能                 |                       スクリーンショット                       |
| :----------------------------------: | :------------------------------------------------------------: |
|   **ダッシュボード & 共通AppBar**    |   <img src="assets/screenshots/dashboard.png" width="220" />   |
| **バッテリー・システム詳細モーダル** | <img src="assets/screenshots/battery_modal.png" width="220" /> |
|            **同期グラフ**            |  <img src="assets/screenshots/sync_graph.png" width="220" />   |
|         **HUD / PiP (小窓)**         |   <img src="assets/screenshots/hud_mode.png" width="220" />    |
|           **設定・その他**           |   <img src="assets/screenshots/settings.png" width="220" />    |

---

## 📱 主な機能

### 1. 全画面共通 AppBar (`Fs050wAppBar`) & バッテリー簡易表示

- **全画面統一ヘッダー**: ダッシュボード、リアルタイム同期グラフ、設定画面の全画面で共通のAppBarを表示。
- **アンテナピクトアイコン**: 電波強度に応じたバー表示 + 5G/4G/e4G 世代バッジを常時表示。
- **バッテリー簡易ステータス**: `🔋 100% ⚡ 39℃ 0mA`（未装着時は`--`）を一目で確認可能。いたわり充電（70%制限）有効時は70%を100%とした換算値で直感的に表示。
- **ワンタップ展開**: AppBarタイトルエリアをタップすることで「ルーター詳細統計・バッテリー情報」モーダルを素早く呼び出し可能。

### 2. ルーター詳細統計 & バッテリー情報モーダル (`BatterySystemDetailSheet`)

- **残り予想使用 / 充電完了時間**:
  - バッテリー容量（4000mAh）と充放電電流から計算。いたわり充電有効時は70%上限（2800mAh）を考慮して算出。
- **バッテリー詳細ステータス**:
  - 残量プログレスバー（いたわり充電時は70%を100%換算 + 実残量表示）
  - バッテリー温度（℃）、電圧（V / mV）、入出力電流（mA / 計算残容量 mAh）、動作状態（充電中/放電中/未装着）。
- **ルーターハードウェア & システム状態**:
  - CPU使用率（%）プログレスバー
  - RAM使用率（使用量 MB / 総容量 MB、%）プログレスバー
  - 稼働時間（日・時間・分・秒）
  - 実行プロセス数

### 3. 公式アプリAPIへの全面改修 & 認証別リフレッシュレート

- **公式エンドポイント統合**:
  - `POST /action/get_mgdb_params`（電波品質 + バッテリー詳細）
  - `POST /action/get_device_state`（稼働時間、CPU、RAM、プロセス数）
- **ポーリングレートの分離**:
  - 実測に基づき、未ログイン時は1秒を無効化（3秒/5秒/10秒）。
  - ログイン時は1秒/2秒/3秒/5秒の超高速更新に対応。認証状態に応じてタイマーを動的切り替え。

### 4. リアルタイム電波ダッシュボード (Dashboard)

- **5G NR (Sub-6 / SA / NSA) & 4G LTE セル情報表示**:
  - RSRP（電波受信強度 / dBm）
  - RSRQ（受信信号品質 / dB）
  - SINR / SNR（信号対雑音比 / dB）
  - Band（n77, n78, n79, B1, B3, B8, B18, B19, B26, B28, B41, B42 等）および周波数（MHz）
  - PCI（Physical Cell ID）
  - 接続事業者（キャリア名）
- **6段階シームレスカラーゲージ**: 電波強度・品質を「極めて優秀」「良好」「普通」「やや弱い」「微弱」「圏外寸前」の6段階グラデーションで直感的に把握。
- **5G SA / NSA 自動判別**: 5G SA（Standalone）接続時は自動で不要な4Gアンカーセルカードを非表示化。

### 5. バッテリー高温警告 & イベントハプティクス

- **バッテリー高温警告**:
  - 設定温度（38℃〜50℃、デフォルト: 45℃）以上になった場合にPiP / オーバーレイへ赤色警告表示、Native 3連アラートバイブレーション、画面上部LEDランプをトリガー。
- **5G+ (Sub6) 突入 & 基地局ハンドオーバー検知**:
  - 5G Sub6 エリア突入時や基地局（PCI）切り替わり時に触覚フィードバック（バイブレーション）とLEDランプでお知らせ。

### 6. PiP (Picture-in-Picture) & フローティングオーバーレイ

- **PiP 7種アスペクト比対応**: 16:9, 9:16, 1:1, 4:3, 3:4, 21:9, 9:21 に対応。ホーム画面遷移時の自動小窓化にも対応。
- **フローティングオーバーレイ**: 他アプリ使用中も画面最前面に電波・バッテリー情報を常時フローティング表示（カード型 / コンパクト行型、透過度・サイズ調整可能）。
- **バッテリー・温度表示**: 小窓・オーバーレイ内でも電波情報の隣にバッテリー残量と温度を常時表示。

### 7. リアルタイム同期タイムシリーズグラフ (Sync Graph)

- **3連時間軸同期チャート**: RSRP、RSRQ、SINR の推移を同一の時間軸で並べてリアルタイム描画。
- **スパン切り替え**: 1分・3分・5分・10分の表示期間をワンタップで切り替え可能。

### 8. 有機EL向け HUD 全画面常時表示モード (HUD Mode)

- **Immersive Fullscreen**: ナビゲーションバーやステータスバーを隠した完全全画面表示。
- **省電力・焼き付き防止**: ピュアブラック（True Black）背景と、有機ELディスプレイ（OLED）のピクセル焼き付きを防止する微細ジッター（Anti-burn-in）アニメーションを搭載。

---

## 🛠 動作環境

**バージョン:** v1.5.0 (Release)  
**バージョン:** v2.0.0 (Release)  
**ターゲットOS:** Android 8.0 以上 (API 26+)  
**対応アーキテクチャ:** arm64-v8a, armeabi-v7a, x86_64

- Android 14 / 15 / 16 / 17 (Samsung One UI, Google Pixel, AOSP) 動作確認済み
- **対応ルーター**: 富士ソフト +F FS050W (Wi-Fi接続)
- **開発フレームワーク**: Flutter 3.0+ / Dart 3.0+

---

## 🚀 ビルドとインストール

### 1. リポジトリのクローン

```bash
git clone https://github.com/SyameimaruKoa/FS050W-Signal-Display.git
cd FS050W-Signal-Display
```

### 2. 依存パッケージの取得

```bash
flutter pub get
```

### 3. リリースAPKのビルド

```bash
# アーキテクチャ別（ABI別）分割ビルド（推奨: ファイルサイズ大幅削減）
flutter build apk --release --split-per-abi
```

生成されたAPKファイルは `build/app/outputs/flutter-apk/` に出力されます：

- `app-arm64-v8a-release.apk`: 最近の一般的な64bit Androidスマートフォン向け（推奨）
- `app-armeabi-v7a-release.apk`: 古い32bit Android端末向け
- `app-x86_64-release.apk`: エミュレーター / PC向け

---

## 📝 更新履歴

詳細な全バージョンの更新履歴は [CHANGELOG.md](CHANGELOG.md) をご覧ください。

---

## 📄 ライセンス

本プロジェクトは MIT License の下で公開されています。
