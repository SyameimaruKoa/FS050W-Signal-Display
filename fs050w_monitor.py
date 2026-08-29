import argparse
import json
import hashlib
import hmac
import urllib.request
import urllib.error
import http.cookiejar
import sys


def main():
    parser = argparse.ArgumentParser(
        description="富士ソフト +F FS050W 全パラメータ（CPU/RAM・電波・バッテリー・通信量・SIM・Wi-Fi・端末情報）一括取得・表示スクリプト",
        epilog="例: python fs050w_monitor.py --ip 192.168.100.1 --password admin",
    )
    parser.add_argument(
        "--ip",
        type=str,
        default="192.168.100.1",
        help="ルーターのIPアドレス (デフォルト: 192.168.100.1)",
    )
    parser.add_argument(
        "--password",
        "-p",
        type=str,
        help="ルーターのログインパスワード",
    )
    args = parser.parse_args()

    IP = args.ip
    PASS = args.password

    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    opener.addheaders = [
        ("User-Agent", "Mozilla/5.0"),
        ("Referer", f"http://{IP}/common/home.html"),
        ("Origin", f"http://{IP}"),
        ("Content-Type", "application/json"),
    ]

    csrf_token = ""

    def get_token():
        nonlocal csrf_token
        req = urllib.request.Request(f"http://{IP}/public/x_csrf_token", method="GET")
        try:
            with opener.open(req, timeout=5) as resp:
                csrf_token = resp.headers.get("X-Csrf-Token", "")
        except Exception as e:
            print(f"トークン取得エラー: {e}")
            sys.exit(1)

    def do_post(url, payload=None):
        req = urllib.request.Request(url, method="POST")
        req.add_header("X-Csrf-Token", csrf_token)
        data = json.dumps(payload).encode("utf-8") if payload is not None else b""
        try:
            with opener.open(req, data=data, timeout=5) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            print(f"APIリクエストエラー ({url}): {e}")
            return None

    print(f"ルーター ({IP}) に接続してログイン中...")
    get_token()
    prikey_data = do_post(f"http://{IP}/public/get_private_key", {})
    if not prikey_data or "prikey" not in prikey_data:
        print("プライベートキー取得失敗")
        sys.exit(1)

    prikey = prikey_data["prikey"]
    key = b"0123456789"
    h1 = hmac.new(key, PASS.encode("utf-8"), hashlib.md5).hexdigest()
    prefix = b"4cc68e3626e5b94602c325f7c4ca5dee:example.com:"
    p1 = hashlib.md5(prefix + h1.encode("utf-8")).hexdigest()
    p2 = hmac.new(key, (p1 + prikey).encode("utf-8"), hashlib.md5).hexdigest()

    get_token()
    login_resp = do_post(
        f"http://{IP}/public/login2",
        {
            "username": "4cc68e3626e5b94602c325f7c4ca5dee",
            "password": p2,
            "prikey": prikey,
        },
    )

    if not login_resp or login_resp.get("retcode") != 0:
        print("ログイン失敗。パスワードを確認してください。")
        sys.exit(1)

    print("ログイン成功。全パラメータを取得中...\n")

    # 1. 内部DB (mgdb) から取得
    all_keys = [
        # --- 接続モード・回線 ---
        "mnet_sysmode",
        "mnet_operator_name",
        "mnet_sig_level_num",
        "mnet_roaming_using",
        # --- 4G LTE 電波詳細 ---
        "mnet_rsrp",
        "mnet_rssi",
        "mnet_rsrq",
        "mnet_sinr",
        "mnet_wnw_band",
        "mnet_wnw_pci",
        "mnet_wnw_earfcn",
        # --- 5G NR (ENDC) 電波詳細 ---
        "mnet_endc_rsrp",
        "mnet_endc_rsrq",
        "mnet_endc_snr",
        "mnet_wnw_psband",
        "mnet_wnw_pspci",
        "mnet_wnw_psnrarfcn",
        # --- バッテリー・電源 ---
        "device_battery_level_percent",
        "device_battery_charge_status",
        "device_battery_exist",
        "device_battery_level",
        "device_battery_capacity",
        "device_battery_voltage",
        "device_battery_current",
        "device_battery_temperature",
        "device_charge_long_life",
        "device_power_saving_mode",
        "device_op_mode",
        # --- SIM / eSIM ---
        "mnet_sim_slot",
        "mnet_sim_card1_state",
        "mnet_sim_card2_state",
        "esim_enable",
        "current_sim_iccid",
        "current_esim_iccid",
        # --- 通信量統計 ---
        "statistics_current_month_used",
        "data_usage_one_day_sim",
        "data_usage_three_days_sim",
        "data_usage_total_sim",
        "statistics_e_current_month_used",
        "data_usage_one_day_esim",
        "data_usage_three_days_esim",
        "data_usage_total_esim",
        # --- Wi-Fi 状態 ---
        "wifi_ssid_0",
        "wifi_state_0",
        "wifi_client_0",
        "wifi_freq_0",
        "wifi_ssid_1",
        "wifi_state_1",
        "wifi_client_1",
        "wifi_freq_1",
        # --- 端末情報 ---
        "device_product_name",
        "device_nickname",
        "device_imei",
        "device_software_version",
        "device_hardware_version",
        "usb_tethering_using",
    ]

    get_token()
    res = do_post(f"http://{IP}/action/get_mgdb_params", {"keys": all_keys})
    d = res.get("data", {}) if res else {}

    # 2. CPU / RAM / 稼働状態 (/action/get_device_state) から取得
    get_token()
    state_res = do_post(f"http://{IP}/action/get_device_state", {})
    s_data = state_res if state_res and state_res.get("retcode") == 0 else {}

    def format_bytes(b_str):
        try:
            b = int(b_str)
            if b >= 1024**3:
                return f"{b / (1024**3):.2f} GB ({b:,} B)"
            elif b >= 1024**2:
                return f"{b / (1024**2):.2f} MB ({b:,} B)"
            elif b >= 1024:
                return f"{b / 1024:.2f} KB ({b:,} B)"
            return f"{b} B"
        except:
            return b_str

    def format_uptime(sec_val):
        try:
            sec = int(sec_val)
            days = sec // 86400
            hours = (sec % 86400) // 3600
            minutes = (sec % 3600) // 60
            seconds = sec % 60
            parts = []
            if days > 0:
                parts.append(f"{days}日")
            if hours > 0:
                parts.append(f"{hours}時間")
            if minutes > 0:
                parts.append(f"{minutes}分")
            parts.append(f"{seconds}秒")
            return " ".join(parts)
        except:
            return str(sec_val)

    print("=" * 60)
    print("           +F FS050W 完全ステータス一覧 (全項目)")
    print("=" * 60)

    print("\n[ 1. CPU & RAM システム負荷 ]")
    cpu_usage = s_data.get("cpuusage", "N/A")
    total_ram = s_data.get("totalram", 0)
    usage_ram = s_data.get("usageram", 0)
    free_ram = s_data.get("freeram", 0)
    procs = s_data.get("procs", "N/A")
    uptime = s_data.get("uptime", "N/A")

    ram_pct_str = f" ({usage_ram / total_ram * 100:.1f} %)" if total_ram else ""
    print(f"  CPU 使用率        : {cpu_usage} %")
    print(
        f"  RAM 使用状況      : {format_bytes(usage_ram)} / {format_bytes(total_ram)}{ram_pct_str}"
    )
    print(f"  RAM 空き容量      : {format_bytes(free_ram)}")
    print(f"  稼働時間 (Uptime) : {format_uptime(uptime)}")
    print(f"  実行プロセス数    : {procs}")

    print("\n[ 2. 接続回線 & 基本ステータス ]")
    print(f"  System Mode       : {d.get('mnet_sysmode', 'N/A')}")
    print(f"  PLMN (キャリア)   : {d.get('mnet_operator_name', 'N/A')}")
    print(f"  アンテナ本数      : {d.get('mnet_sig_level_num', 'N/A')} / 5 本")
    print(f"  動作モード        : {d.get('device_op_mode', 'N/A')}")

    print("\n[ 3. 4G LTE 電波詳細 (MCG) ]")
    rsrp_raw = d.get("mnet_rsrp")
    rsrp_dbm = (
        f"{int(rsrp_raw) - 141} dBm (Raw: {rsrp_raw})"
        if rsrp_raw and rsrp_raw.isdigit()
        else "N/A"
    )
    rssi_raw = d.get("mnet_rssi")
    rssi_dbm = (
        f"{int(rssi_raw) - 111} dBm (Raw: {rssi_raw})"
        if rssi_raw and rssi_raw.isdigit()
        else "N/A"
    )
    rsrq_raw = d.get("mnet_rsrq")
    rsrq_db = (
        f"{(int(rsrq_raw) - 40) / 2.0} dB (Raw: {rsrq_raw})"
        if rsrq_raw and rsrq_raw.isdigit()
        else "N/A"
    )
    print(f"  LTE Band          : B{d.get('mnet_wnw_band', 'N/A')}")
    print(f"  LTE PCI           : {d.get('mnet_wnw_pci', 'N/A')}")
    print(f"  LTE EARFCN        : {d.get('mnet_wnw_earfcn', 'N/A')}")
    print(f"  LTE RSRP          : {rsrp_dbm}")
    print(f"  LTE RSSI          : {rssi_dbm}")
    print(f"  LTE RSRQ          : {rsrq_db}")
    print(f"  LTE SINR          : {d.get('mnet_sinr', 'N/A')} dB")

    print("\n[ 4. 5G NR 電波詳細 (SCG / ENDC) ]")
    endc_rsrp_raw = d.get("mnet_endc_rsrp")
    endc_rsrp = (
        f"{int(endc_rsrp_raw) - 157} dBm"
        if endc_rsrp_raw and endc_rsrp_raw.isdigit() and int(endc_rsrp_raw) > 0
        else "未接続 / 待機中 (--)"
    )
    print(
        f"  NR Band           : n{d.get('mnet_wnw_psband', 'N/A') if d.get('mnet_wnw_psband') != '0' else '--'}"
    )
    print(
        f"  NR PCI            : {d.get('mnet_wnw_pspci', 'N/A') if d.get('mnet_wnw_pspci') != '0' else '--'}"
    )
    print(f"  NR-ARFCN          : {d.get('mnet_wnw_psnrarfcn', 'N/A')}")
    print(f"  NR RSRP           : {endc_rsrp}")
    print(f"  NR RSRQ           : {d.get('mnet_endc_rsrq', 'N/A')}")
    print(f"  NR SINR (SNR)     : {d.get('mnet_endc_snr', 'N/A')}")

    print("\n[ 5. バッテリー & 電源詳細 ]")
    print(
        f"  バッテリー残量    : {d.get('device_battery_level_percent', 'N/A')} % (バー: {d.get('device_battery_level', 'N/A')}/4)"
    )
    print(f"  充電ステータス    : {d.get('device_battery_charge_status', 'N/A')}")
    print(f"  バッテリー装着    : {d.get('device_battery_exist', 'N/A')}")
    print(f"  バッテリー電圧    : {d.get('device_battery_voltage', 'N/A')} mV")
    print(f"  充放電電流        : {d.get('device_battery_current', 'N/A')} mA")
    print(f"  バッテリー温度    : {d.get('device_battery_temperature', 'N/A')} ℃")
    print(f"  バッテリー設計容量: {d.get('device_battery_capacity', 'N/A')} mAh")
    print(f"  いたわり充電(70%) : {d.get('device_charge_long_life', 'N/A')}")
    print(f"  省電力モード      : {d.get('device_power_saving_mode', 'N/A')}")

    print("\n[ 6. SIM / eSIM スロット状態 ]")
    print(f"  選択中スロット    : SIM {d.get('mnet_sim_slot', 'N/A')}")
    print(
        f"  SIM1 (物理) 装着  : {'装着' if d.get('mnet_sim_card1_state') == '1' else '未装着'}"
    )
    print(
        f"  SIM2 (eSIM) 状態  : {'装着/有効' if d.get('mnet_sim_card2_state') == '1' else '無効'}"
    )

    print("\n[ 7. データ通信量統計 ]")
    print(
        f"  SIM1 当月使用量   : {format_bytes(d.get('statistics_current_month_used', '0'))}"
    )
    print(
        f"  eSIM 当月使用量   : {format_bytes(d.get('statistics_e_current_month_used', '0'))}"
    )

    print("\n[ 8. Wi-Fi 設定 & 接続台数 ]")
    print(
        f"  2.4GHz SSID       : {d.get('wifi_ssid_0', 'N/A')} (接続: {d.get('wifi_client_0', '0')} 台)"
    )
    print(
        f"  5GHz SSID         : {d.get('wifi_ssid_1', 'N/A')} (接続: {d.get('wifi_client_1', '0')} 台)"
    )

    print("\n[ 9. 端末識別情報 ]")
    print(
        f"  製品名            : {d.get('device_product_name', 'N/A')} ({d.get('device_nickname', 'N/A')})"
    )
    print(f"  IMEI              : {d.get('device_imei', 'N/A')}")
    print(f"  ソフトウェアFW    : {d.get('device_software_version', 'N/A')}")
    print(f"  ハードウェアVer   : {d.get('device_hardware_version', 'N/A')}")
    print("=" * 60)


if __name__ == "__main__":
    main()
