# +F FS050W Web API 開発者向け仕様書 (完全確定版)

**対象機器**: 富士ソフト製 5G モバイルルーター +F FS050W  
**メーカー**: MEIG INCORPORATED (FUJISOFT OEM)  
**デフォルトIP**: `192.168.100.1` (または接続中Wi-FiのDHCPデフォルトゲートウェイ)  
**通信プロトコル**: HTTP/1.1 (Port 80) / HTTPS (Port 443)  
**データフォーマット**: JSON / UTF-8

---

## 1. 接続状態別パラメータマトリクス

> **【重要】キャリアアグリゲーション (CA) 情報の取得制限について**
> 実機での検証の結果、フロントエンドにはCA情報取得用のコードが存在するものの、ルーター本体のバックエンドAPI（`/action/mnet_get_ca_list`）は **HTTP 404 Not Found** を返却します。
> また、`get_mgdb_params` からもCA関連パラメータ（`mnet_ca_mode`, `mnet_ca_list` 等）は返却されません。
> したがって、現在のファームウェアではAPI経由でのCA状態の判定は不可であり、システム上は常に「CAなし (単一キャリア接続)」として扱われます。

| 接続状態・条件                                      |    モード     |   LTE (MCG) 側   |  NR (SCG) 側  | 状態の解説                                 |
| :-------------------------------------------------- | :-----------: | :--------------: | :-----------: | :----------------------------------------- |
| **LTE 単独 (CAなし)**<br>`sysmode=="lte"`           |     `LTE`     |    `LTE (B3)`    |    非表示     | 通常の LTE 接続                            |
| **LTE-Advanced (CAあり)**<br>_(※API判定不可)_       |    `LTE-A`    | `LTE-A (B3+...)` |    非表示     | _(CA検知不可のため表示不可)_               |
| **EN-DC 待機 (NSA)**<br>`sysmode=="nsa"` & ENDC=`0` | `EN-DC Ready` |    `LTE (B3)`    | `待機中 (--)` | EN-DC (5G NSA) エリアで LTE 接続にて待機中 |
| **EN-DC 接続 (NSA)**<br>`sysmode=="nsa"` & ENDC確立 |    `EN-DC`    |    `LTE (B3)`    |  `NR (n77)`   | EN-DC (5G NSA) 通信中                      |
| **NR Standalone (SA)**<br>`sysmode=="nr5g"`         |    `NR SA`    |      非表示      |  `NR (n77)`   | NR SA (Standalone) 通信中                  |

---

## 2. API エンドポイント体系

FS050W には **Web UI向け（`/goform/`, `/action/`）** と **公式アプリ向け（`/public/`, `/private/`）** の2つのAPIルーティング体系が存在します。

```mermaid
graph TD
    subgraph Web_UI_Route ["Web UI 系統"]
        A1["GET /goform/x_csrf_token"] --> A2["POST /goform/get_private_key"]
        A2 --> A3["POST /goform/login2"]
        A3 --> A4["POST /action/get_mgdb_params (詳細電波情報)"]
        A3 --> A5["POST /action/get_device_state (CPU/RAM負荷)"]
    end
    subgraph App_Route ["公式アプリ系統"]
        B1["GET /public/x_csrf_token"] --> B2["POST /public/get_mgdb_params (認証不要・基本/残量)"]
        B1 --> B3["POST /public/get_private_key"]
        B3 --> B4["POST /public/login2"]
        B4 --> B5["POST /private/mnet_set_sim_slot (設定変更)"]
    end
```

### (1) CSRF トークン取得

- **公式アプリ用**: `GET /public/x_csrf_token`
- **Web UI用**: `GET /goform/x_csrf_token`
- **認証**: 不要
- **レスポンスヘッダー**: `X-Csrf-Token: <token_string>`, `Set-Cookie: -webs-session-=<session_id>; ...`
  _(※注記: POSTリクエスト毎にトークンが消費されるため、POST直前に毎回取得が必要)_

### (2) パブリック パラメータ取得 API (公式アプリ仕様・認証不要)

- **エンドポイント**: `POST /public/get_mgdb_params`
- **認証**: 不要 (`X-Csrf-Token` のみ必要)
- **リクエストボディ**:
  ```json
  {
    "keys": [
      "device_battery_level_percent",
      "device_battery_charge_status",
      "device_battery_exist",
      "mnet_operator_name",
      "mnet_sysmode",
      "mnet_sig_level_num",
      "statistics_current_month_used",
      "mnet_sim_slot"
    ]
  }
  ```
- **用途**: バッテリー残量(%)、充電ステータス、アンテナ本数、SIM状態、当月/当日通信量などをログインなしで即時取得。

### (3) 一時暗号鍵 (prikey) 取得

- **エンドポイント**: `POST /public/get_private_key` (または `POST /goform/get_private_key`)
- **ボディ**: `None` または `{}`
- **レスポンス**: `{"prikey": "xxxxxx", "retcode": 0}`

### (4) ログイン認証アルゴリズム (HMAC-MD5 チャレンジレスポンス)

- 固定ソルト: `key = "0123456789"`
- プレフィックス: `"4cc68e3626e5b94602c325f7c4ca5dee:example.com:"`
  $$\text{h1} = \text{HMAC-MD5}(\text{key}, \text{password})$$
  $$\text{p1} = \text{MD5}(\text{"4cc68e3626e5b94602c325f7c4ca5dee:example.com:"} + \text{h1})$$
  $$\text{p2} = \text{HMAC-MD5}(\text{key}, \text{p1} + \text{prikey})$$

- **エンドポイント**: `POST /public/login2` (または `POST /goform/login2`)
- **ボディ**: `{"username": "4cc68e3626e5b94602c325f7c4ca5dee", "password": p2, "prikey": prikey}`
- **レスポンス**: `{"retcode": 0}` (ヘッダーに `Set-Cookie` と `X-MG-Private` が返却)

### (5) プライベート設定変更・個別取得 API (認証必須)

- **システム負荷・CPU/RAM 取得**: `POST /action/get_device_state`
  - ボディ: `{}`
  - レスポンス例:
    ```json
    {
      "cpuusage": 9,
      "totalram": 677158912,
      "usageram": 393211904,
      "freeram": 283947008,
      "uptime": 7396,
      "procs": 404,
      "retcode": 0
    }
    ```
- **SIMスロット切り替え**: `POST /private/mnet_set_sim_slot`
  - ボディ: `{"mnet_sim_slot": "1"}` (1: SIM1 / 2: SIM2/eSIM)
- **詳細パラメータ取得**: `POST /action/get_mgdb_params`
  - ボディ: `{"keys": ["mnet_rsrp", "mnet_sinr", "mnet_wnw_band", "mnet_wnw_pci", ...]}`

---

## 3. 主要パラメータ一覧 & 規格変換式

| パラメータ名                 | API Key / フィールド名             | 未認証 (`/public/`) | 認証済 (`/action/`) | 規格変換式 / 返却値の例                             | 単位  |
| :--------------------------- | :--------------------------------- | :-----------------: | :-----------------: | :-------------------------------------------------- | :---: |
| **CPU 使用率**               | `cpuusage` (`get_device_state`)    |          ✕          |          ◯          | 数値そのまま (例: `9`)                              |   %   |
| **全 RAM 容量**              | `totalram` (`get_device_state`)    |          ✕          |          ◯          | 整数 (Bytes) (例: `677158912` $\to$ 約645.8 MB)     | Bytes |
| **使用中 RAM 容量**          | `usageram` (`get_device_state`)    |          ✕          |          ◯          | 整数 (Bytes) (例: `393211904` $\to$ 約375.0 MB)     | Bytes |
| **空き RAM 容量**            | `freeram` (`get_device_state`)     |          ✕          |          ◯          | 整数 (Bytes) (例: `283947008` $\to$ 約270.8 MB)     | Bytes |
| **稼働時間 (Uptime)**        | `uptime` (`get_device_state`)      |          ✕          |          ◯          | 稼働秒数 (秒) (例: `7396` $\to$ 2時間3分16秒)       |  秒   |
| **実行プロセス数**           | `procs` (`get_device_state`)       |          ✕          |          ◯          | 整数 (例: `404`)                                    |  個   |
| **System Mode**              | `mnet_sysmode`                     |          ◯          |          ◯          | 文字列 (`"lte"`, `"nsa"`, `"nr5g"`)                 |   -   |
| **PLMN (Operator)**          | `mnet_operator_name`               |          ◯          |          ◯          | 文字列 (`"Rakuten"`, `"au"` 等)                     |   -   |
| **アンテナピクト**           | `mnet_sig_level_num`               |          ◯          |          ◯          | `"0"` 〜 `"5"` (電波レベル本数)                     |  本   |
| **LTE RSRP**                 | `mnet_rsrp`                        |          ◯          |          ◯          | $\text{Raw} - 141$ _(NR SA時は $\text{Raw} - 157$)_ |  dBm  |
| **LTE RSSI**                 | `mnet_rssi`                        |          ◯          |          ◯          | $\text{Raw} - 111$                                  |  dBm  |
| **LTE RSRQ**                 | `mnet_rsrq`                        |          ✕          |          ◯          | $(\text{Raw} - 40) / 2$                             |  dB   |
| **LTE SINR**                 | `mnet_sinr`                        |          ✕          |          ◯          | 浮動小数そのまま                                    |  dB   |
| **LTE Operating Band**       | `mnet_wnw_band`                    |          ✕          |          ◯          | `"B" + val` (例: `"3"` $\to$ `B3`)                  |   -   |
| **LTE PCI**                  | `mnet_wnw_pci`                     |          ✕          |          ◯          | 整数 (例: `29`, `188`)                              |   -   |
| **LTE EARFCN**               | `mnet_wnw_earfcn`                  |          ✕          |          ✕          | _(※現行FWではmgdbにキーが存在せず取得不可)_         |   -   |
| **NR RSRP**                  | `mnet_endc_rsrp`                   |          ◯          |          ◯          | $\text{Raw} - 157$ _(待機時は `0` $\to$ `--`)_      |  dBm  |
| **NR RSRQ**                  | `mnet_endc_rsrq`                   |          ✕          |          ◯          | $(\text{Raw} - 1) / 2 - 43$ _(待機時は `--`)_       |  dB   |
| **NR SINR**                  | `mnet_endc_snr`                    |          ✕          |          ◯          | $(\text{Raw} - 1) / 2 - 23$ _(187.5dBバグ補正)_     |  dB   |
| **NR Operating Band**        | `mnet_wnw_psband`                  |          ✕          |          ◯          | `"n" + val` (例: `"77"` $\to$ `n77`)                |   -   |
| **NR PCI**                   | `mnet_wnw_pspci`                   |          ✕          |          ◯          | 整数 (例: `723`)                                    |   -   |
| **NR-ARFCN**                 | `mnet_wnw_psnrarfcn`               |          ✕          |          ✕          | _(※現行FWではmgdbにキーが存在せず取得不可)_         |   -   |
| **バッテリー残量 (%)**       | `device_battery_level_percent`     |          ◯          |          ◯          | `"0"` 〜 `"100"`                                    |   %   |
| **充電ステータス**           | `device_battery_charge_status`     |          ◯          |          ◯          | `"charging"` (充電中), `"discharging"` 等           |   -   |
| **バッテリー装着有無**       | `device_battery_exist`             |          ◯          |          ◯          | `"present"` (装着), `"none"` 等                     |   -   |
| **バッテリーレベル (0~4)**   | `device_battery_level`             |          ✕          |          ◯          | `"0"` 〜 `"4"` (バー数)                             |   -   |
| **バッテリー容量**           | `device_battery_capacity`          |          ✕          |          ◯          | 整数 (例: `"4000"`)                                 |  mAh  |
| **バッテリー電圧**           | `device_battery_voltage`           |          ✕          |          ◯          | 整数 (例: `"4036"`)                                 |  mV   |
| **バッテリー電流**           | `device_battery_current`           |          ✕          |          ◯          | 整数 (例: `"299"`)                                  |  mA   |
| **バッテリー温度**           | `device_battery_temperature`       |          ✕          |          ◯          | 整数 (例: `"38"`)                                   |   ℃   |
| **いたわり充電設定**         | `device_charge_long_life`          |          ◯          |          ◯          | `"enable"` または `"disable"`                       |   -   |
| **省電力モード**             | `device_power_saving_mode`         |          ◯          |          ◯          | `"eco"`, `"normal"` 等                              |   -   |
| **動作モード**               | `device_op_mode`                   |          ◯          |          ◯          | `"mobile"`, `"car"`, `"home"` 等                    |   -   |
| **選択中SIMスロット**        | `mnet_sim_slot`                    |          ◯          |          ◯          | `"1"` (物理SIM1), `"2"` (SIM2/eSIM)                 |   -   |
| **SIM1 / SIM2 状態**         | `mnet_sim_card1_state` / `2`       |          ◯          |          ◯          | `"1"`: 装着/有効, `"0"`: 未装着                     |   -   |
| **eSIM有効状態**             | `esim_enable`                      |          ◯          |          ◯          | `"1"`: 有効, `"0"`: 無効                            |   -   |
| **当月通信量 (SIM/eSIM)**    | `statistics_current_month_used`    |          ◯          |          ◯          | バイト数文字列 (Byte)                               | Bytes |
| **当日通信量 (SIM/eSIM)**    | `data_usage_one_day_sim` / `_esim` |          ◯          |          ◯          | バイト数文字列 (Byte)                               | Bytes |
| **トータル通信量**           | `data_usage_total_sim` / `_esim`   |          ◯          |          ◯          | バイト数文字列 (Byte)                               | Bytes |
| **Wi-Fi SSID (2.4G/5G)**     | `wifi_ssid_0` / `_1` / `_2`        |          ◯          |          ◯          | SSID文字列                                          |   -   |
| **Wi-Fi 接続台数**           | `wifi_client_0` / `_1` / `_2`      |          ◯          |          ◯          | 接続中のクライアント端末数                          |  台   |
| **端末IMEI**                 | `device_imei`                      |          ◯          |          ◯          | 15桁の端末識別番号                                  |   -   |
| **ファームウェアバージョン** | `device_software_version`          |          ◯          |          ◯          | 例: `"V2.0.11"`                                     |   -   |

---

## 4. 全パラメータ別 ポーリングレート・実測更新周期一覧 (実機確定仕様)

### (1) API サーバーの応答限界 (HTTP / Web サーバー層の実測値)

- **往復遅延 (RTT)**: 1リクエスト（Token取得 + POST取得）あたりの平均所要時間は **`12.38 ms`**（最小 `8.53 ms` / 最大 `33.27 ms`）。
- **最大処理スループット**: **`80.6 req/sec`**。
- **スロットリング**: 50ms以下の超高頻度で連続ポーリングを行っても、429 Too Many Requests やコネクション切断は発生せず安定して応答します。

### (2) 全カテゴリ別 パラメータ実測更新周期・特性一覧

通信トラフィック負荷試験下において、各パラメータの値が実際に変化した最短時間間隔の実測データです。

#### 1. CPU・RAM・システム負荷系 (`/action/get_device_state`)

ルーター内部のシステム監視デーモン（`/proc/` サンプラー）が **正確に「約3.0秒周期」** でサンプリングを行っています。

| パラメータ名       | フィールド |     実測最小変化間隔      | 平均変化間隔 | 内部更新特性                            |
| :----------------- | :--------- | :-----------------------: | :----------: | :-------------------------------------- |
| **CPU 使用率**     | `cpuusage` | **`2935.1 ms` (約2.9秒)** |  約 3.1 秒   | 内部サンプリング周期 約3秒 ごとに更新   |
| **RAM 使用量**     | `usageram` | **`2985.1 ms` (約3.0秒)** |  約 5.5 秒   | メモリ確保/解放に応じて約3秒周期で更新  |
| **RAM 空き容量**   | `freeram`  | **`2985.1 ms` (約3.0秒)** |  約 5.5 秒   | `usageram` の増減と連動                 |
| **稼働時間**       | `uptime`   | **`2954.4 ms` (約3.0秒)** |  約 3.0 秒   | 内部カウンタは約3秒刻みでインクリメント |
| **実行プロセス数** | `procs`    | **`3006.4 ms` (約3.0秒)** |  約 3.0 秒   | プロセス生成/終了時に約3秒周期で反映    |

#### 2. 電波・モデム系 (`mgdb` パラメータ)

モデム内部の物理層（RIL/モデムファームウェア）による測定周期です。

| パラメータ名       | API Key                  |       実測最小変化間隔        | 平均変化間隔 | 内部更新特性                                            |
| :----------------- | :----------------------- | :---------------------------: | :----------: | :------------------------------------------------------ |
| **品質・雑音比**   | `mnet_sinr`              |   **`1004.8 ms` (約1.0秒)**   |  約 4.6 秒   | 物理層生測定値。**最短1秒周期** で機敏に更新。          |
| **受信電力**       | `mnet_rsrp`              | **約 3.0 〜 5.0 秒** (変動時) |  約 22.4 秒  | Layer 3移動平均フィルタにより電波安定時は同一値を保持。 |
| **受信品質**       | `mnet_rsrq`, `mnet_rssi` |       約 3.0 〜 5.0 秒        |      -       | RSRPと同様にモデム内部で平滑化。                        |
| **アンテナピクト** | `mnet_sig_level_num`     |        RSRP変動と連動         |      -       | RSRPのしきい値跨ぎ時に即時連動更新。                    |
| **接続Band / PCI** | `mnet_wnw_band`, `_pci`  |        イベント時即時         |      -       | 基地局（セル）切り替わり時に即時更新。                  |

#### 3. バッテリー・電源・温度系 (`mgdb` パラメータ)

電源管理IC (PMIC) のADCサンプリング周期です。

| パラメータ名           | API Key                        |   実測最小変化間隔   | 内部更新特性                                        |
| :--------------------- | :----------------------------- | :------------------: | :-------------------------------------------------- |
| **バッテリー電圧**     | `device_battery_voltage`       | **約 3.0 〜 5.0 秒** | 電圧急変時（充電開始/切断時）に約3〜5秒周期で反映。 |
| **充放電電流**         | `device_battery_current`       |   約 3.0 〜 5.0 秒   | 負荷電流の変動に応じて約3〜5秒周期で反映。          |
| **バッテリー温度**     | `device_battery_temperature`   |   約 3.0 〜 5.0 秒   | サーミスタ温度変化に応じて反映。                    |
| **バッテリー残量 (%)** | `device_battery_level_percent` |    約 1分 〜 数分    | 残量%の増減変化時のみ更新。                         |
| **充電ステータス**     | `device_battery_charge_status` |    状態変化時即時    | ケーブル挿抜・いたわり充電トリガー時に即時更新。    |

#### 4. 通信量統計系 (`mgdb` パラメータ)

パケットカウンタから内部DB（mgdb）への同期周期です。

| パラメータ名   | API Key                         |     実測最小変化間隔      | 平均変化間隔 | 内部更新特性                                                         |
| :------------- | :------------------------------ | :-----------------------: | :----------: | :------------------------------------------------------------------- |
| **当月通信量** | `statistics_current_month_used` | **`5014.1 ms` (約5.0秒)** |  約 15.3 秒  | トラフィック発生時、**約5〜15秒周期** のバッチ処理でmgdbに加算同期。 |

#### 5. 静的・イベントドリブン系（接続状態・設定）

- **対象**: `wifi_client_0` (Wi-Fi接続台数), `mnet_sim_slot` (選択SIM), `device_op_mode` (動作モード), `device_imei`, `device_software_version` 等
- **更新特性**: ポーリング周期に依存せず、**「端末がWi-Fiに接続/切断された時」「SIM切替を実行した時」などのイベント発生時に即時更新** されます。

---

### (3) 用途別の推奨ポーリングレート

- **`1.0 秒 (1000 ms)` 【リアルタイム電波監視・ハンドオーバー追従】 (推奨)**
  - SINRの最短内部更新周期（約1秒）に完全に追従でき、セル切り替わりや電波品質の変動をリアルタイムに描画可能。APIサーバーの負荷（RTT 12ms）に対しても極めて安全。
- **`3.0 秒 (3000 ms)` 【CPU/RAM監視・標準ダッシュボード】**
  - ルーター内部のシステムサンプリング周期（`約3.0秒`）および公式Web UI既定周期（`3000 ms`）と完全に一致。CPU/RAMおよび通常ステータスを無駄なく表示する最適値。
- **`5.0 〜 10.0 秒` 【バックグラウンド・省電力】**
  - 常時監視時の通信トラフィックおよびスマホ側のCPU負荷を最小化。

---

### (4) 未接続時・待機時の PCI 仕様 (誤ハンドオーバー防止規定)

- **PCI `0` または空文字**: 5G NSA待機中（ENDC非接続）やセル未捕捉時、`mnet_wnw_pspci` / `mnet_wnw_pci` は `"0"` または空文字として返却されます。
- **ハンドオーバー判定条件**: PCI `0` は未接続/待機状態を表すため、**`新PCI > 0` かつ `旧PCI > 0` かつ `新PCI != 旧PCI`** の場合のみハンドオーバー（セル切り替わり）として判定する必要があります。
