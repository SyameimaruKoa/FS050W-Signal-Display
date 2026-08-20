import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
    const SettingsScreen({super.key});

    @override
    State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
    late TextEditingController _ipController;
    late TextEditingController _passController;
    late AppSettings _settings;
    bool _isPasswordVisible = false;

    @override
    void initState() {
        super.initState();
        final apiService = context.read<ApiService>();
        _settings = apiService.settings;
        _ipController = TextEditingController(text: _settings.routerIp);
        _passController = TextEditingController(text: _settings.webPassword);
    }

    @override
    void dispose() {
        _ipController.dispose();
        _passController.dispose();
        super.dispose();
    }

    Future<void> _save() async {
        _settings.routerIp = _ipController.text.trim();
        _settings.webPassword = _passController.text;

        await StorageService.saveSettings(_settings);
        if (mounted) {
            context.read<ApiService>().updateSettings(_settings);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("設定を保存しました")),
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(
                    "⚙ 設定",
                    style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.check, color: Colors.greenAccent),
                        onPressed: _save,
                        tooltip: "保存",
                    ),
                ],
            ),
            body: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                    _buildSectionHeader("1. 接続設定", Icons.router),
                    _buildCard([
                        TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                                labelText: "ルーター IP アドレス",
                                hintText: "192.168.155.1",
                                prefixIcon: Icon(Icons.dns),
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: (v) => _save(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _passController,
                            decoration: InputDecoration(
                                labelText: "Web管理パスワード",
                                hintText: "設定したWebパスワード",
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () {
                                        setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                        });
                                    },
                                ),
                            ),
                            obscureText: !_isPasswordVisible,
                            onChanged: (v) => _save(),
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("パスワードレス自動試行"),
                            subtitle: const Text("未認証で取得可能な項目を自動フォールバック取得"),
                            value: _settings.autoPasswordless,
                            onChanged: (val) {
                                setState(() => _settings.autoPasswordless = val);
                                _save();
                            },
                        ),
                    ]),

                    const SizedBox(height: 16),
                    _buildSectionHeader("2. ポーリング設定", Icons.timer),
                    _buildCard([
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("フォアグラウンド更新間隔"),
                            trailing: DropdownButton<int>(
                                value: _settings.foregroundIntervalSeconds,
                                items: const [
                                    DropdownMenuItem(value: 1, child: Text("1秒 (推奨)")),
                                    DropdownMenuItem(value: 2, child: Text("2秒")),
                                    DropdownMenuItem(value: 3, child: Text("3秒")),
                                    DropdownMenuItem(value: 5, child: Text("5秒")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.foregroundIntervalSeconds = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("バックグラウンド更新間隔"),
                            trailing: DropdownButton<int>(
                                value: _settings.backgroundIntervalSeconds,
                                items: const [
                                    DropdownMenuItem(value: 1, child: Text("1秒")),
                                    DropdownMenuItem(value: 2, child: Text("2秒")),
                                    DropdownMenuItem(value: 3, child: Text("3秒")),
                                    DropdownMenuItem(value: 5, child: Text("5秒")),
                                    DropdownMenuItem(value: 10, child: Text("10秒")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.backgroundIntervalSeconds = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                    ]),

                    const SizedBox(height: 16),
                    _buildSectionHeader("3. 常駐通知設定", Icons.notifications_active),
                    _buildCard([
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("常駐通知の有効化"),
                            subtitle: const Text("ステータスバーに 6 種の電波アイコンと詳細を表示"),
                            value: _settings.foregroundNotificationEnabled,
                            onChanged: (val) {
                                setState(() => _settings.foregroundNotificationEnabled = val);
                                _save();
                            },
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("通知スタイル"),
                            trailing: DropdownButton<NotificationDetailStyle>(
                                value: _settings.notificationStyle,
                                items: const [
                                    DropdownMenuItem(
                                        value: NotificationDetailStyle.detailed,
                                        child: Text("詳細 2行スタイル"),
                                    ),
                                    DropdownMenuItem(
                                        value: NotificationDetailStyle.compact,
                                        child: Text("コンパクト 1行"),
                                    ),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.notificationStyle = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                    ]),

                    const SizedBox(height: 16),
                    _buildSectionHeader("4. イベント通知・バイブレーション設定", Icons.vibration),
                    _buildCard([
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("⚡ 5G+ (sub6) 突入バイブ通知"),
                            subtitle: const Text("高速 sub6 エリア接続時に短い振動で通知"),
                            value: _settings.vibrateOn5gSub6,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOn5gSub6 = val);
                                _save();
                            },
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("📡 基地局ハンドオーバー時通知"),
                            subtitle: const Text("PCI 切り替わり時に極小振動 ＋ トースト"),
                            value: _settings.vibrateOnHandover,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOnHandover = val);
                                _save();
                            },
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("⚠️ 限界電波 (RSRP < -120dBm) 警告"),
                            subtitle: const Text("圏外寸前や微弱電波時に警告バイブ"),
                            value: _settings.vibrateOnCriticalSignal,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOnCriticalSignal = val);
                                _save();
                            },
                        ),
                    ]),

                    const SizedBox(height: 16),
                    _buildSectionHeader("5. UI・ナビゲーション・テーマ設定", Icons.palette),
                    _buildCard([
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("ナビゲーション形式"),
                            trailing: DropdownButton<AppNavigationStyle>(
                                value: _settings.navigationStyle,
                                items: const [
                                    DropdownMenuItem(
                                        value: AppNavigationStyle.bottomNav,
                                        child: Text("ボトムナビ (初期値)"),
                                    ),
                                    DropdownMenuItem(
                                        value: AppNavigationStyle.cardButtons,
                                        child: Text("ボタン画面遷移"),
                                    ),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.navigationStyle = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("画面の常時点灯 (スリープ防止)"),
                            value: _settings.keepScreenOn,
                            onChanged: (val) {
                                setState(() => _settings.keepScreenOn = val);
                                _save();
                            },
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("グラフ初期表示スパン"),
                            trailing: DropdownButton<int>(
                                value: _settings.graphSpanMinutes,
                                items: const [
                                    DropdownMenuItem(value: 1, child: Text("1分")),
                                    DropdownMenuItem(value: 3, child: Text("3分 (推奨)")),
                                    DropdownMenuItem(value: 5, child: Text("5分")),
                                    DropdownMenuItem(value: 10, child: Text("10分")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.graphSpanMinutes = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("アプリテーマ"),
                            trailing: DropdownButton<AppThemeMode>(
                                value: _settings.appTheme,
                                items: const [
                                    DropdownMenuItem(value: AppThemeMode.oled, child: Text("OLED 漆黒ダーク")),
                                    DropdownMenuItem(value: AppThemeMode.dark, child: Text("マテリアルダーク")),
                                    DropdownMenuItem(value: AppThemeMode.light, child: Text("ライトモード")),
                                    DropdownMenuItem(value: AppThemeMode.system, child: Text("システム追従")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.appTheme = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                    ]),

                    const SizedBox(height: 16),
                    _buildSectionHeader("6. 将来拡張 (Phase 2)", Icons.extension),
                    _buildCard([
                        const ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text("フローティング小窓表示 (Overlay)"),
                            subtitle: Text("他アプリ起動中も画面上に常時電波表示 (Phase 2)"),
                            trailing: Chip(label: Text("予定", style: TextStyle(fontSize: 11))),
                        ),
                        const ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text("ログ記録 & CSVエクスポート"),
                            subtitle: Text("受信ログのファイル保存・共有 (Phase 2)"),
                            trailing: Chip(label: Text("予定", style: TextStyle(fontSize: 11))),
                        ),
                    ]),
                    const SizedBox(height: 24),
                ],
            ),
        );
    }

    Widget _buildSectionHeader(String title, IconData icon) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Row(
                children: [
                    Icon(icon, size: 18, color: Colors.cyanAccent),
                    const SizedBox(width: 8),
                    Text(
                        title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildCard(List<Widget> children) {
        return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white12),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                    children: children,
                ),
            ),
        );
    }
}
