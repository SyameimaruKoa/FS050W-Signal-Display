import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SetupWizardScreen extends StatefulWidget {
    final VoidCallback? onComplete;

    const SetupWizardScreen({super.key, this.onComplete});

    @override
    State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
    final TextEditingController _ipController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

    bool _isScanning = false;
    bool _isTesting = false;
    bool _isDetected = false;
    bool _isPasswordVisible = false;
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

            if (gateway != null && gateway.isNotEmpty) {
                _detectedGateway = gateway;
                _ipController.text = gateway;
            }

            final apiService = context.read<ApiService>();
            final targetIp = _detectedGateway ?? "192.168.100.1";
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
        TextInput.finishAutofillContext(shouldSave: true);
        apiService.updateSettings(settings);
        apiService.startPolling();
        widget.onComplete?.call();
        if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
        }
    }

    @override
    Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
            body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Icon(
                                Icons.router,
                                size: 64,
                                color: isDark ? Colors.cyanAccent : const Color(0xFF00ADB5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                                "+F FS050W Signal Display",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                                "ルーターに接続し、電波強度の監視を開始します",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                            ),
                            const SizedBox(height: 24),

                            if (_isScanning)
                                Card(
                                    color: Theme.of(context).cardColor,
                                    child: const Padding(
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
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                ),
                                            ),
                                        ],
                                    ),
                                ),

                            const SizedBox(height: 24),

                            Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text(
                                                "接続設定",
                                                style: TextStyle(
                                                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                ),
                                            ),
                                            const SizedBox(height: 16),
                                            AutofillGroup(
                                                child: Column(
                                                    children: [
                                                        TextField(
                                                            controller: _ipController,
                                                            decoration: const InputDecoration(
                                                                labelText: "ルーター IP アドレス",
                                                                hintText: "192.168.100.1",
                                                                prefixIcon: Icon(Icons.wifi),
                                                            ),
                                                            keyboardType: TextInputType.url,
                                                            autofillHints: const [AutofillHints.url, AutofillHints.username],
                                                        ),
                                                        const SizedBox(height: 12),
                                                        TextField(
                                                            controller: _passwordController,
                                                            decoration: InputDecoration(
                                                                labelText: "Web管理パスワード (初期: admin)",
                                                                hintText: "未設定の場合は admin が使用されます",
                                                                prefixIcon: const Icon(Icons.lock_outline),
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
                                                            keyboardType: TextInputType.visiblePassword,
                                                            autofillHints: const [AutofillHints.password],
                                                            onEditingComplete: () {
                                                                TextInput.finishAutofillContext(shouldSave: true);
                                                            },
                                                        ),
                                                    ],
                                                ),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100,
                                                    foregroundColor: isDark ? Colors.white : Colors.black87,
                                                    elevation: 0,
                                                ),
                                                onPressed: _isTesting ? null : _testConnection,
                                                icon: _isTesting
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                    : const Icon(Icons.network_check),
                                                label: const Text("接続テスト"),
                                            ),
                                        ],
                                    ),
                                ),
                            ),

                            if (_testResult != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                    _testResult!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _isTestSuccess
                                            ? (isDark ? Colors.greenAccent : const Color(0xFF2E7D32))
                                            : (isDark ? Colors.orangeAccent : Colors.orange.shade800),
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
                                child: Text(
                                    "設定をスキップして手動で開始 (強制進行)",
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}
