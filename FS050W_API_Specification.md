# +F FS050W Web API 開発者向け仕様書

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

| 接続状態・条件 | モード | LTE (MCG) 側 | NR (SCG) 側 | 状態の解説 |
| :--- | :---: | :---: | :---: | :--- |
| **LTE 単独 (CAなし)**<br>`sysmode=="lte"` | `LTE` | `LTE (B3)` | 非表示 | 通常の LTE 接続 |
| **LTE-Advanced (CAあり)**<br>*(※API判定不可)* | `LTE-A` | `LTE-A (B3+...)` | 非表示 | *(CA検知不可のため表示不可)* |
| **EN-DC 待機 (NSA)**<br>`sysmode=="nsa"` & ENDC=`0` | `EN-DC Ready` | `LTE (B3)` | `待機中 (--)` | EN-DC (5G NSA) エリアで LTE 接続にて待機中 |
| **EN-DC 接続 (NSA)**<br>`sysmode=="nsa"` & ENDC確立 | `EN-DC` | `LTE (B3)` | `NR (n77)` | EN-DC (5G NSA) 通信中 |
| **NR Standalone (SA)**<br>`sysmode=="nr5g"` | `NR SA` | 非表示 | `NR (n77)` | NR SA (Standalone) 通信中 |

---

## 2. API エンドポイント仕様

### (1) CSRF トークン & セッション Cookie 取得
* **エンドポイント**: `GET /goform/x_csrf_token`
* **認証**: 不要
* **レスポンスヘッダー**:
  * `X-Csrf-Token: <token_string>`
  * `Set-Cookie: -webs-session-=<session_id>; path=/`
*(※注記: POSTリクエストを送信するたびにトークンが消費される仕様のため、POST送信の直前には毎回このAPIを実行し、新しいトークンを取得する必要があります。)*

### (2) 一時暗号鍵 (prikey) 取得
* **エンドポイント**: `POST /goform/get_private_key`
* **リクエストヘッダー**: `X-Csrf-Token`, `Cookie`, `Content-Type: application/json`
* **ボディ**: *(空)*
* **レスポンス**: `{"prikey": "xxxxxx", "retcode": 0}`

### (3) チャレンジレスポンス ハッシュ計算アルゴリズム
* 固定ソルト: `key = "0123456789"`
* プレフィックス: `"4cc68e3626e5b94602c325f7c4ca5dee:example.com:"`
$$\text{h1} = \text{HMAC-MD5}(\text{key}, \text{password})$$
$$\text{p1} = \text{MD5}(\text{"4cc68e3626e5b94602c325f7c4ca5dee:example.com:"} + \text{h1})$$
$$\text{p2} = \text{HMAC-MD5}(\text{key}, \text{p1} + \text{prikey})$$

### (4) ログイン実行
* **エンドポイント**: `POST /goform/login2`
* **ボディ**: `{"username": "4cc68e3626e5b94602c325f7c4ca5dee", "password": p2, "prikey": prikey}`
* **レスポンス**: `{"retcode": 0}`

### (5) パラメータ取得 API
* **未認証用**: `POST /goform/get_mgdb_params`
* **認証済用**: `POST /action/get_mgdb_params`
  * **ボディ**: `{"keys": ["mnet_sysmode", "mnet_rsrp", "mnet_operator_name"]}` のように `keys` 配列に取得したいパラメータ文字列を指定します。（空ボディの場合 `{"retcode":101}` となります）
* **CA情報取得用**: `POST /action/mnet_get_ca_list`
  * *(※実機検証の結果、HTTP 404 Not Found となり未実装)*

---

## 3. エンドポイント別アクセス権限 & 規格変換式

| パラメータ | API Key | 未認証 | 認証済 | 規格変換式 | 単位 |
| :--- | :--- | :---: | :---: | :--- | :---: |
| **System Mode** | `mnet_sysmode` | ◯ | ◯ | 文字列 (`"lte"`, `"nsa"`, `"nr5g"`) | - |
| **PLMN (Operator)** | `mnet_operator_name` | ◯ | ◯ | 文字列 (`"Rakuten"` 等) | - |
| **LTE RSRP** | `mnet_rsrp` | ◯ | ◯ | $\text{Raw} - 141$ *(NR SA時は $\text{Raw} - 157$)* | dBm |
| **LTE RSSI** | `mnet_rssi` | ✕ | ◯ | $\text{Raw} - 111$ | dBm |
| **LTE RSRQ** | `mnet_rsrq` | ✕ | ◯ | $(\text{Raw} - 40) / 2$ | dB |
| **LTE SINR** | `mnet_sinr` | ✕ | ◯ | 浮動小数そのまま | dB |
| **LTE Operating Band** | `mnet_wnw_band` | ✕ | ◯ | `"B" + val` (例: `"3"` $\to$ `B3`) | - |
| **LTE PCI** | `mnet_wnw_pci` | ✕ | ◯ | 整数 (例: `29`) | - |
| **LTE EARFCN**| `mnet_wnw_earfcn`| ✕ | ◯ | 整数 (例: `1750`) | - |
| **NR RSRP** | `mnet_endc_rsrp` | ◯ | ◯ | $\text{Raw} - 157$ *(待機時は `0` $\to$ `--`)* | dBm |
| **NR RSRQ** | `mnet_endc_rsrq` | ✕ | ◯ | $(\text{Raw} - 1) / 2 - 43$ *(待機時は `--`)* | dB |
| **NR SINR** | `mnet_endc_snr` | ✕ | ◯ | $(\text{Raw} - 1) / 2 - 23$ *(187.5dBバグ補正)* | dB |
| **NR Operating Band** | `mnet_wnw_psband`| ✕ | ◯ | `"n" + val` (例: `"77"` $\to$ `n77`) | - |
| **NR PCI** | `mnet_wnw_pspci` | ✕ | ◯ | 整数 (例: `723`) | - |
| **NR-ARFCN** | `mnet_wnw_psnrarfcn`| ✕ | ◯ | 整数 (例: `650000`) | - |
| **Battery Level**| `battery_percent`| ✕ | ◯ | `"0"` 〜 `"100"` | % |
| **Charging Status**| `battery_charging`| ✕ | ◯ | `"0"`: 放電中, `"1"`: 充電中 | - |

---

## 4. 周波数帯 & 中心周波数 (MHz) 算出式 (3GPP 規格準拠)

* **LTE EARFCN $\to$ 中心周波数 (3GPP TS 36.101)**:
  * Band 3: $1805 + 0.1 \times (\text{EARFCN} - 1200)\text{ MHz}$ *(例: EARFCN 1750 $\to 1860.0\text{ MHz}$ / 1.7GHz帯)*
  * Band 1, 8, 18, 19, 21, 26, 28, 41, 42 計算式内蔵。
* **NR-ARFCN $\to$ 中心周波数 (3GPP TS 38.104)**:
  * Sub-6GHz 帯 (n77, n78, n79): $3000 + 0.015 \times (\text{ARFCN} - 600000)\text{ MHz}$ *(例: ARFCN 650000 $\to 3750.0\text{ MHz}$)*
  * Sub-3GHz 帯 (n28, n3, n1): $0 + 0.005 \times (\text{ARFCN} - 0)\text{ MHz}$ *(例: 700MHz帯)*

---

## 5. モデム更新頻度 & リフレッシュレート特性

### (1) ルーター内部の更新周期 (mgdb キャッシュ特性)
* **モデム内部デーモン**: ルーター内部の RIL (Radio Interface Layer) は、基地局の物理層測定値（RSRP, RSRQ, SINR, PCI）を内部メモリデータベース (`mgdb`) に **約1〜3秒周期** で更新・同期しています。
* **公式 Web UI 既定周期**: ルーター公式管理画面は、**3000ms (3秒)** 間隔で `/action/get_mgdb_params` をポーリングしています。

### (2) 最短リフレッシュレートとパラメータ感度特性
* **SINR (最機敏パラメータ)**: 電波環境の変化に応じて最も素早く変動し、移動中やフェージング発生時には **最短1秒間隔** で `mgdb` の値がリアルタイムに更新されます。
* **RSRP / RSRQ (平滑化パラメータ)**: モデム内部で移動平均等の平滑化フィルタ (Layer 3 Filtering) が適用されているため、電波強度が安定している環境では **3〜5秒間同一値が返却** される場合があります。

### (3) 未接続時・待機時の PCI 仕様 (ハンドオーバー判定)
* **PCI `0`**: EN-DC 待機中やセル未捕捉時、`mnet_wnw_pspci` / `mnet_wnw_pci` は `"0"` または空文字として返却されます。
* **ハンドオーバー判定条件**: PCI `0` は未接続/待機状態を表すため、**`新PCI > 0` かつ `旧PCI > 0` かつ `新PCI != 旧PCI`** の場合のみハンドオーバー（セル切り替わり）として判定する必要があります。
