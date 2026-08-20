import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/app_settings.dart';

class SetupWizardScreen extends StatefulWidget {
    final VoidCallback onComplete;

    const SetupWizardScreen({super.key, required this.onComplete});

    @override
    State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
    final TextEditingController _ipController = TextEditingController(text: "192.168.155.1");
    final TextEditingController _passwordController = TextEditingController();

    bool _isScanning = false;
    bool _isTesting = false;
    bool _isDetected = false;
    String? _detectedGateway;
    String? _testResult;
    bool _isTestSuccess = false;

    @override
    void initState() {
        super.initState();
        _scanWifiNetwork();
    }

    @override
    void dispose() {
        _ipController.dispose();
        _passwordController.dispose();
        super.dispose();
    }

    Future<void> _scanWifiNetwork() async {
        setState(() {
            _isScanning = true;
            _isDetected = false;
        });

        try {
            final info = NetworkInfo();
            final gateway = await info.getWifiGatewayIP();
            final ip = await info.getWifiIP();

            if (gateway != null && gateway.isNotEmpty) {
                _detectedGateway = gateway;
                _ipController.text = gateway;
            }

            final apiService = context.read<ApiService>();
            final targetIp = _detectedGateway ?? "192.168.155.1";
            final canConnect = await apiService.testConnection(targetIp, "");

            setState(() {
                _isDetected = canConnect;
                _isScanning = false;
            });
        } catch (e) {
            setState(() {
                _isScanning = false;
            });
        }
    }

    Future<void> _testConnection() async {
        setState(() {
            _isTesting = true;
            _testResult = null;
        });

        final ip = _ipController.text.trim();
        final pass = _passwordController.text;
        final apiService = context.read<ApiService>();

        final success = await apiService.testConnection(ip, pass);

        setState(() {
            _isTesting = false;
            _isTestSuccess = success;
            _testResult = success
                ? "✅ +F FS050W との通信に成功しました！"
                : "❌ 接続に失敗しました。ルーターのWi-Fiに接続されているか確認してください。";
        });
    }

    Future<void> _finishSetup() async {
        final apiService = context.read<ApiService>();
        final settings = apiService.settings;
        settings.routerIp = _ipController.text.trim();
        settings.webPassword = _passwordController.text;
        settings.isSetupCompleted = true;

        await StorageService.saveSettings(settings);
        apiService.updateSettings(settings);
        apiService.startPolling();
        widget.onComplete();
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(
                    "🚀 初期セットアップ",
                    style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
                ),
            ),
            body: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            const Icon(
                                Icons.router,
                                size: 64,
                                color: Colors.cyanAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                                "+F FS050W 電波監視アプリ",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.notoSansJp(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                "ルーターに接続し、電波強度の監視を開始します",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 24),

                            // Detection Banner
                            if (_isScanning)
                                const Card(
                                    color: Color(0xFF1E1E1E),
                                    child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                                SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                SizedBox(width: 12),
                                                Text("Wi-Fi ネットワークをスキャン中..."),
                                            ],
                                        ),
                                    ),
                                )
                            else if (_isDetected)
                                Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.greenAccent, width: 1),
                                    ),
                                    child: Row(
                                        children: [
                                            const Icon(Icons.check_circle, color: Colors.greenAccent),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Text(
                                                    "🎉 +F FS050W (${_ipController.text}) を検出しました！",
                                                    style: const TextStyle(
                                                        color: Colors.greenAccent,
                                                        fontWeight: FontWeight.bold,
                                                    ),
                                                ),
                                            ),
                                        ],
                                    ),
                                ),

                            const SizedBox(height: 20),
                            TextField(
                                controller: _ipController,
                                decoration: const InputDecoration(
                                    labelText: "ルーター IP アドレス",
                                    hintText: "192.168.155.1",
                                    prefixIcon: Icon(Icons.dns),
                                    border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                    labelText: "Web管理パスワード (省略可)",
                                    hintText: "未設定の場合は未認証モードで動作",
                                    prefixIcon: Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(),
                                ),
                                obscureText: true,
                            ),
                            const SizedBox(height: 16),

                            ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.blueGrey.shade800,
                                ),
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                    : const Icon(Icons.network_check, color: Colors.cyanAccent),
                                label: const Text("接続テスト", style: TextStyle(color: Colors.white)),
                                onPressed: _isTesting ? null : _testConnection,
                            ),

                            if (_testResult != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                    _testResult!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _isTestSuccess ? Colors.greenAccent : Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                    ),
                                ),
                            ],

                            const SizedBox(height: 24),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: const Color(0xFF00ADB5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _finishSetup,
                                child: const Text(
                                    "監視を開始する",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _finishSetup,
                                child: const Text(
                                    "設定をスキップして手動で開始 (強制進行)",
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}
