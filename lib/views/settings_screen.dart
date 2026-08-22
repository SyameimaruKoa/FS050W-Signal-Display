import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../services/pip_service.dart';
import '../services/overlay_service.dart';
import '../services/storage_service.dart';
import 'widgets/log_viewer_dialog.dart';

class SettingsScreen extends StatefulWidget {
    const SettingsScreen({super.key});

    @override
    State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
    late AppSettings _settings;
    late TextEditingController _ipController;
    late TextEditingController _passController;
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

        final apiService = context.read<ApiService>();
        apiService.updateSettings(_settings);
        await StorageService.saveSettings(_settings);

        if (mounted) {
            PipService.setAutoEnterPip(_settings.autoPipOnHome, _settings.pipAspectRatio);
            if (apiService.currentSignal != null) {
                OverlayService.updateOverlayData(apiService.currentSignal, _settings);
            }
        }
    }

    Future<void> _toggleOverlay(bool enabled) async {
        if (enabled) {
            final hasPermission = await OverlayService.checkPermission();
            if (!hasPermission) {
                if (!mounted) return;
                final shouldOpenSettings = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                        title: const Text("権限の許可が必要です"),
                        content: const Text("フローティングオーバーレイを表示するには、「他のアプリの上に重ねて表示」の権限を許可してください。"),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text("キャンセル"),
                            ),
                            ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text("設定を開く"),
                            ),
                        ],
                    ),
                );

                if (shouldOpenSettings == true) {
                    await OverlayService.requestPermission();
                }
                return;
            }
        }

        setState(() {
            _settings.overlayEnabled = enabled;
        });
        await _save();
    }

    @override
    Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
            appBar: AppBar(
                title: const Text(
                    "⚙ 設定",
                    style: TextStyle(fontFamilyFallback: ['Noto Sans JP', 'sans-serif'], fontWeight: FontWeight.bold, fontSize: 18),
                ),
            ),
            body: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                    // 1. 【監視 & フローティング表示】
                    _buildSectionHeader("1. 監視 & フローティング表示", Icons.picture_in_picture_alt),
                    _buildCard([
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("フローティングオーバーレイ"),
                            subtitle: const Text("他アプリ使用中も最前面に電波ウィジェットを常時表示"),
                            value: _settings.overlayEnabled,
                            onChanged: (val) => _toggleOverlay(val),
                        ),
                        if (_settings.overlayEnabled) ...[
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("オーバーレイ表示スタイル"),
                                trailing: DropdownButton<String>(
                                    value: _settings.overlayStyle,
                                    items: const [
                                        DropdownMenuItem(value: "card", child: Text("PiP共通カード型 (スタイルA)")),
                                        DropdownMenuItem(value: "compact", child: Text("コンパクト行型 (スタイルB)")),
                                    ],
                                    onChanged: (val) {
                                        if (val != null) {
                                            setState(() => _settings.overlayStyle = val);
                                            _save();
                                        }
                                    },
                                ),
                            ),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("背景透過度: ${(_settings.overlayOpacity * 100).toInt()}%"),
                                subtitle: Slider(
                                    value: _settings.overlayOpacity,
                                    min: 0.2,
                                    max: 1.0,
                                    divisions: 16,
                                    label: "${(_settings.overlayOpacity * 100).toInt()}%",
                                    onChanged: (val) {
                                        setState(() => _settings.overlayOpacity = val);
                                        _save();
                                    },
                                ),
                            ),
                        ],
                        const Divider(height: 16),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("ホーム画面に戻った時に自動でPiP起動"),
                            subtitle: const Text("アプリ使用中にホーム操作を行うと自動で小窓化"),
                            value: _settings.autoPipOnHome,
                            onChanged: (val) {
                                setState(() => _settings.autoPipOnHome = val);
                                _save();
                            },
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("PiP アスペクト比 (全7種)"),
                            subtitle: Text("現在: ${_settings.pipAspectRatio}"),
                            trailing: DropdownButton<String>(
                                value: _settings.pipAspectRatio,
                                items: const [
                                    DropdownMenuItem(value: "16:9", child: Text("16:9 (横長標準)")),
                                    DropdownMenuItem(value: "9:16", child: Text("9:16 (縦長標準)")),
                                    DropdownMenuItem(value: "1:1", child: Text("1:1 (正方形)")),
                                    DropdownMenuItem(value: "4:3", child: Text("4:3 (横長クラシック)")),
                                    DropdownMenuItem(value: "3:4", child: Text("3:4 (縦長クラシック)")),
                                    DropdownMenuItem(value: "21:9", child: Text("21:9 (ウルトラワイド)")),
                                    DropdownMenuItem(value: "9:21", child: Text("9:21 (ウルトラトール)")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.pipAspectRatio = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("PiP 拡大時グラフ種類"),
                            subtitle: const Text("PiP拡大時に表示する電波履歴グラフ"),
                            trailing: DropdownButton<String>(
                                value: _settings.pipGraphType,
                                items: const [
                                    DropdownMenuItem(value: "rsrp", child: Text("RSRP 履歴")),
                                    DropdownMenuItem(value: "snr", child: Text("SNR / SINR 履歴")),
                                    DropdownMenuItem(value: "rsrq", child: Text("RSRQ 履歴")),
                                    DropdownMenuItem(value: "none", child: Text("非表示")),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.pipGraphType = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                    ]),

                    const SizedBox(height: 16),

                    // 2. 【イベント検知 & LEDランプ】
                    _buildSectionHeader("2. イベント検知 & LEDランプ", Icons.lightbulb_outline),
                    _buildCard([
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("イベント画面上部LEDランプ"),
                            subtitle: const Text("イベント発生時に画面最上部にパルスランプを3秒点灯"),
                            value: _settings.eventLampEnabled,
                            onChanged: (val) {
                                setState(() => _settings.eventLampEnabled = val);
                                _save();
                            },
                        ),
                        if (_settings.eventLampEnabled) ...[
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("ランプ形状"),
                                trailing: DropdownButton<String>(
                                    value: _settings.eventLampShape,
                                    items: const [
                                        DropdownMenuItem(value: "bar", child: Text("スリムバー型 (画面幅半分/1px)")),
                                        DropdownMenuItem(value: "dot", child: Text("ドット型 (6dp)")),
                                    ],
                                    onChanged: (val) {
                                        if (val != null) {
                                            setState(() => _settings.eventLampShape = val);
                                            _save();
                                        }
                                    },
                                ),
                            ),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("ランプ配置位置"),
                                trailing: DropdownButton<String>(
                                    value: _settings.eventLampPosition,
                                    items: const [
                                        DropdownMenuItem(value: "topCenter", child: Text("画面上部 中央")),
                                        DropdownMenuItem(value: "topLeft", child: Text("画面上部 左角")),
                                        DropdownMenuItem(value: "topRight", child: Text("画面上部 右角")),
                                    ],
                                    onChanged: (val) {
                                        if (val != null) {
                                            setState(() => _settings.eventLampPosition = val);
                                            _save();
                                        }
                                    },
                                ),
                            ),
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: OutlinedButton.icon(
                                    icon: const Icon(Icons.flash_on, size: 16, color: Color(0xFF00E5FF)),
                                    label: const Text("LEDランプ点灯テスト"),
                                    onPressed: () {
                                        OverlayService.triggerLamp("5g", _settings);
                                    },
                                ),
                            ),
                        ],
                        const Divider(height: 16),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("⚡ 5G+ (Sub6) 接続検知バイブ"),
                            subtitle: const Text("超高速 Sub6 エリア突入時に二重振動"),
                            value: _settings.vibrateOn5gSub6,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOn5gSub6 = val);
                                _save();
                            },
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("📡 ハンドオーバー検知バイブ"),
                            subtitle: const Text("基地局 (PCI) 切り替わり時に振動"),
                            value: _settings.vibrateOnHandover,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOnHandover = val);
                                _save();
                            },
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("⚠️ 電波微弱警告 (RSRP <= -115dBm)"),
                            subtitle: const Text("圏外寸前突入時に警告バイブ & 赤点滅"),
                            value: _settings.vibrateOnCriticalSignal,
                            onChanged: (val) {
                                setState(() => _settings.vibrateOnCriticalSignal = val);
                                _save();
                            },
                        ),
                    ]),

                    const SizedBox(height: 16),

                    // 3. 【通信 & ルーター接続】
                    _buildSectionHeader("3. 通信 & ルーター接続", Icons.router),
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
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("ポーリング間隔"),
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
                    ]),

                    const SizedBox(height: 16),

                    // 4. 【UI・テーマ & 表示設定】
                    _buildSectionHeader("4. UI・テーマ & 表示設定", Icons.palette),
                    _buildCard([
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("通信規格の表記方式"),
                            subtitle: const Text("アプリ全体およびPiP・オーバーレイの名称を統一"),
                            trailing: DropdownButton<String>(
                                value: _settings.generationNotation,
                                items: const [
                                    DropdownMenuItem(
                                        value: "4g_5g",
                                        child: Text("4G / 5G / e4G"),
                                    ),
                                    DropdownMenuItem(
                                        value: "lte_nr",
                                        child: Text("LTE / NR / eLTE"),
                                    ),
                                ],
                                onChanged: (val) {
                                    if (val != null) {
                                        setState(() => _settings.generationNotation = val);
                                        _save();
                                    }
                                },
                            ),
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("5G SNR 値の補正 (-23dB)"),
                            subtitle: const Text("FS050Wファームウェアのオフセットを自動補正"),
                            value: _settings.adjust5gSnr,
                            onChanged: (val) {
                                setState(() => _settings.adjust5gSnr = val);
                                _save();
                            },
                        ),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("シームレスゲージカラー"),
                            subtitle: const Text("電波バーの色をグラデーションで滑らかに変化"),
                            value: _settings.smoothGaugeColor,
                            onChanged: (val) {
                                setState(() => _settings.smoothGaugeColor = val);
                                _save();
                            },
                        ),
                        if (_settings.smoothGaugeColor)
                            Padding(
                                padding: const EdgeInsets.only(left: 12.0, right: 0.0, top: 4.0, bottom: 8.0),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        const Text(
                                            "グラデーション曲線 (イージング)",
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                            "電波バーと色の変化カーブを調整",
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Theme.of(context).dividerColor,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                    isExpanded: true,
                                                    value: _settings.smoothGaugeCurve,
                                                    items: const [
                                                        DropdownMenuItem(
                                                            value: "easeOut",
                                                            child: Text("Ease Out (推奨: 弱電界の変化を強調)"),
                                                        ),
                                                        DropdownMenuItem(
                                                            value: "easeIn",
                                                            child: Text("Ease In (強電界の変化を強調)"),
                                                        ),
                                                        DropdownMenuItem(
                                                            value: "easeInOut",
                                                            child: Text("Ease In-Out (S字曲線)"),
                                                        ),
                                                        DropdownMenuItem(
                                                            value: "linear",
                                                            child: Text("Linear (リニア / 線形)"),
                                                        ),
                                                    ],
                                                    onChanged: (val) {
                                                        if (val != null) {
                                                            setState(() => _settings.smoothGaugeCurve = val);
                                                            _save();
                                                        }
                                                    },
                                                ),
                                            ),
                                        ),
                                    ],
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
                        const Divider(height: 16),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("アプリ診断ログを表示 / コピー"),
                            subtitle: const Text("API通信履歴、エラー詳細、ハンドオーバー記録を確認"),
                            trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent.shade700,
                                    foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text("ログ表示"),
                                onPressed: () => LogViewerDialog.show(context),
                            ),
                        ),
                    ]),
                    const SizedBox(height: 24),
                ],
            ),
        );
    }

    Widget _buildSectionHeader(String title, IconData icon) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final headerColor = isDark ? Colors.cyanAccent : const Color(0xFF007A78);
        return Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Row(
                children: [
                    Icon(icon, size: 18, color: headerColor),
                    const SizedBox(width: 8),
                    Text(
                        title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: headerColor,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildCard(List<Widget> children) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Card(
            elevation: isDark ? 1 : 0.5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
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
