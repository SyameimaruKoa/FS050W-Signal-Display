# +F FS050W Web API 開発者向け完全仕様書 (正式確定版)

**対象機器**: 富士ソフト製 5G モバイルルーター +F FS050W  
**メーカー**: MEIG INCORPORATED (FUJISOFT OEM)  
**デフォルトIP**: `192.168.155.1` (または接続中Wi-FiのDHCPデフォルトゲートウェイ)  
**通信プロトコル**: HTTP/1.1 (Port 80) / HTTPS (Port 443)  
**データフォーマット**: JSON / UTF-8  
**実機検証**: 2026年8月20日（実機接続・生データ取得・ハンドオーバー実測済）  

---

## 1. 接続状態別パラメータマトリクス（全6パターン完全対応）

| # | 接続状態・条件 | 常時通知アイコン | UI モード表記 | 4G / アンカー側表記 | 5G NR 側表記 | 状態の解説 |
| :-: | :--- | :---: | :---: | :---: | :---: | :--- |
| **1** | **4G 単独 (CAなし)**<br>`sysmode=="lte"` & CA=無 | `[4G]` | `4G LTE` | `4G LTE (B3)` | 非表示 | 通常の 4G LTE 1波接続 |
| **2** | **4G+ (CAあり)**<br>`sysmode=="lte"` & CA=有 | `[4G+]` | `4G+ LTE` | `4G+ LTE (B3+...)` | 非表示 | 4G キャリアアグリゲーション接続（備え） |
| **3** | **4GN (5G NSA待機 / CAなし)**<br>`sysmode=="nsa"` & ENDC=`--` & CA=無 | `[4GN]` | `4G Ready` | `4G Ready (B3)` | `待機中 (--)` | 5G NSA エリアで 4G 1波で待機中 |
| **4** | **4GN+ (5G NSA待機 / CAあり)**<br>`sysmode=="nsa"` & ENDC=`--` & CA=有 | `[4GN+]` | `4G+ Ready` | `4G+ Ready (B3+...)` | `待機中 (--)` | 5G NSA エリアで 4G CA しつつ待機中（備え） |
| **5** | **5G (転用5G / 通常5G / SA含む)**<br>ENDC/SA確立 & バンド=n28,n1等 | `[5G]` | `5G NR` (または `5G NR SA`) | `4G Anchor (B3)` *(SA時は非表示)* | `5G NR (n28)` | 転用 5G または通常 5G 通信中 |
| **6** | **5G+ (sub6 高速5G / SA含む)**<br>ENDC/SA確立 & バンド=n77,n78等 | `[5G+]` | `5G+ NR+` (または `5G+ NR+ SA`) | `4G Anchor (B3)` *(SA時は非表示)* | `5G+ NR+ (n77)` | sub6 本格 5G 通信中 |

---

## 2. API エンドポイント詳細仕様

### (1) CSRF トークン & セッション Cookie 取得
* **エンドポイント**: `GET /goform/x_csrf_token`
* **認証**: 不要
* **レスポンスヘッダー**:
  * `X-Csrf-Token: <token_string>`
  * `Set-Cookie: -webs-session-=<session_id>; path=/`

### (2) 一時暗号鍵（prikey）取得
* **エンドポイント**: `POST /goform/get_private_key`
* **リクエストヘッダー**: `X-Csrf-Token`, `Cookie`
* **ボディ**: `{}`
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
* **未認証用**: `POST /goform/get_mgdb_params`（RSRP, モード, キャリア名のみ取得可能）
* **認証済用**: `POST /action/get_mgdb_params`（全項目取得可能 / 1秒毎ポーリング）
* **CA取得用**: `POST /action/mnet_get_ca_list`（CAバンドリスト取得）

---

## 3. エンドポイント別アクセス権限 & 規格変換式

| パラメータ | API Key | 未認証 (`/goform/`) | 認証済 (`/action/`) | 規格変換式 | 単位 |
| :--- | :--- | :---: | :---: | :--- | :---: |
| **接続モード** | `mnet_sysmode` | ◯ | ◯ | そのまま文字列 (`"lte"`, `"nsa"`, `"nr5g"`) | - |
| **キャリア名** | `mnet_operator_name` | ◯ | ◯ | そのまま文字列 (`"Rakuten"` 等) | - |
| **4G LTE RSRP** | `mnet_rsrp` | ◯ | ◯ | $\text{Raw} - 141$ *(5G SA時は $\text{Raw} - 157$)* | dBm |
| **4G LTE RSSI** | `mnet_rssi` | ✕ | ◯ | $\text{Raw} - 111$ | dBm |
| **4G LTE RSRQ** | `mnet_rsrq` | ✕ | ◯ | $(\text{Raw} - 40) / 2$ | dB |
| **4G LTE SINR** | `mnet_sinr` | ✕ | ◯ | 浮動小数そのまま | dB |
| **4G LTE Band** | `mnet_wnw_band` | ✕ | ◯ | `"B" + val` (例: `"3"` $\to$ `B3`) | - |
| **4G LTE PCI** | `mnet_wnw_pci` | ✕ | ◯ | そのまま整数 (例: `29`, `57`, `315`) | - |
| **4G LTE EARFCN**| `mnet_wnw_earfcn`| ✕ | ◯ | そのまま整数 (例: `1750`) | - |
| **5G NR RSRP** | `mnet_endc_rsrp` | ◯ | ◯ | $\text{Raw} - 157$ *(待機時は `0` $\to$ `--`)* | dBm |
| **5G NR RSRQ** | `mnet_endc_rsrq` | ✕ | ◯ | $(\text{Raw} - 1) / 2 - 43$ *(待機時は `--`)* | dB |
| **5G NR SNR** | `mnet_endc_snr` | ✕ | ◯ | $(\text{Raw} - 1) / 2 - 23$ *(187.5dBバグ補正)* | dB |
| **5G NR Band** | `mnet_wnw_psband`| ✕ | ◯ | `"n" + val` (例: `"77"` $\to$ `n77`) | - |
| **5G NR PCI** | `mnet_wnw_pspci` | ✕ | ◯ | そのまま整数 (例: `723`, `454`) | - |
| **5G NR-ARFCN** | `mnet_wnw_psnrarfcn`| ✕ | ◯ | そのまま整数 (例: `650000`) | - |
| **バッテリー残量**| `battery_percent`| ✕ | ◯ | `"0"` 〜 `"100"` | % |
| **充電ステータス**| `battery_charging`| ✕ | ◯ | `"0"`: 放電中, `"1"`: 充電中 | - |

---

## 4. 周波数帯 & 中心周波数（MHz）算出式 (3GPP 規格準拠)

* **4G LTE EARFCN $\to$ 中心周波数（3GPP TS 36.101）**:
  * Band 3: $1805 + 0.1 \times (\text{EARFCN} - 1200)\text{ MHz}$ *(例: EARFCN 1750 $\to 1860.0\text{ MHz}$ / 1.7GHz帯)*
  * Band 1, 8, 18, 19, 21, 26, 28, 41, 42 計算式内蔵。
* **5G NR-ARFCN $\to$ 中心周波数（3GPP TS 38.104）**:
  * sub6 帯 (n77, n78, n79): $3000 + 0.015 \times (\text{ARFCN} - 600000)\text{ MHz}$ *(例: ARFCN 650000 $\to 3750.0\text{ MHz}$ / 3.7GHz帯 sub6)*
  * 転用帯 (n28, n3, n1): $0 + 0.005 \times (\text{ARFCN} - 0)\text{ MHz}$ *(例: 700MHz帯)*

---

## 5. Web UI (`#rfparam`) 実 DOM 構造

```html
<div cellpadding="0" cellspacing="0" class="layui-table" lay-even="" lay-skin="nob" id="rfparam">
    <div class="rfparam_tr"><div class="content_label">キャリアアグリゲーション</div><div class="content_option"> </div></div>
    <div class="rfparam_tr"><div class="content_label">RSRP</div><div class="content_option">-103.0dBm </div></div>
    <div class="rfparam_tr"><div class="content_label">RSSI</div><div class="content_option">-72.0dBm </div></div>
    <div class="rfparam_tr"><div class="content_label">RSRQ</div><div class="content_option">-12.0dB </div></div>
    <div class="rfparam_tr"><div class="content_label">SINR</div><div class="content_option">12.3dB </div></div>
    <div class="rfparam_tr"><div class="content_label">Band</div><div class="content_option">B3</div></div>
    <div class="rfparam_tr"><div class="content_label">PCI</div><div class="content_option">202</div></div>
    <div class="rfparam_tr"><div class="content_label">ENDC RSRP</div><div class="content_option">--</div></div>
    <div class="rfparam_tr"><div class="content_label">ENDC RSRQ</div><div class="content_option">--</div></div>
    <div class="rfparam_tr"><div class="content_label">ENDC SNR</div><div class="content_option">--</div></div>
    <div class="rfparam_tr"><div class="content_label">ENDC Band</div><div class="content_option">--</div></div>
    <div class="rfparam_tr"><div class="content_label">ENDC PCI</div><div class="content_option">--</div></div>
</div>
```
