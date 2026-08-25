import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/app_settings.dart';
import 'services/api_service.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'services/pip_service.dart';
import 'services/overlay_service.dart';
import 'services/storage_service.dart';
import 'views/dashboard_screen.dart';
import 'views/graph_screen.dart';
import 'views/settings_screen.dart';
import 'views/setup_wizard_screen.dart';
import 'views/pip_screen.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait Up
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // 1. Initialize Pip, Foreground, and Notification Services
    PipService.initialize();
    BackgroundService.initService();
    await NotificationService.initialize();

    // 2. Load Persisted Settings
    final settings = await StorageService.loadSettings();

    // Synchronize auto PiP and overlay setting with native layer
    PipService.setAutoEnterPip(settings.autoPipOnHome, settings.pipAspectRatio);
    if (settings.overlayEnabled) {
        final hasPermission = await OverlayService.checkPermission();
        if (hasPermission) {
            await OverlayService.startOverlay(settings);
        }
    }

    runApp(
        MultiProvider(
            providers: [
                ChangeNotifierProvider(create: (_) => ApiService(settings)),
            ],
            child: const Fs050wApp(),
        ),
    );
}

class Fs050wApp extends StatefulWidget {
    const Fs050wApp({super.key});

    @override
    State<Fs050wApp> createState() => _Fs050wAppState();
}

class _Fs050wAppState extends State<Fs050wApp> with WidgetsBindingObserver {
    static const MethodChannel _lifecycleChannel = MethodChannel('com.syameimarukoa.fs050w_signal_display/lifecycle');

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addObserver(this);
        _lifecycleChannel.setMethodCallHandler(_handleLifecycleCall);
    }

    @override
    void dispose() {
        WidgetsBinding.instance.removeObserver(this);
        super.dispose();
    }

    Future<dynamic> _handleLifecycleCall(MethodCall call) async {
        if (call.method == 'onScreenStateChanged') {
            final isScreenOn = call.arguments as bool? ?? true;
            if (mounted) {
                final api = context.read<ApiService>();
                if (isScreenOn) {
                    api.startPolling();
                } else {
                    api.stopPolling();
                }
            }
        }
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
        final api = context.read<ApiService>();
        if (state == AppLifecycleState.resumed) {
            api.startPolling();
            PipService.setAutoEnterPip(api.settings.autoPipOnHome, api.settings.pipAspectRatio);
        } else if (state == AppLifecycleState.paused) {
            // Background handling
        }
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final settings = apiService.settings;

        // Keep Screen On
        if (settings.keepScreenOn) {
            WakelockPlus.enable();
        } else {
            WakelockPlus.disable();
        }

        return MaterialApp(
            title: 'FS050W Signal Display',
            debugShowCheckedModeBanner: false,
            theme: _buildThemeData(settings.appTheme, context),
            builder: (context, child) {
                return PiPDetectorShell(child: child!);
            },
            home: const MainNavigationShell(),
        );
    }

    ThemeData _buildThemeData(AppThemeMode mode, BuildContext context) {
        switch (mode) {
            case AppThemeMode.oled:
                return ThemeData(
                    brightness: Brightness.dark,
                    scaffoldBackgroundColor: Colors.black,
                    cardColor: const Color(0xFF111111),
                    appBarTheme: const AppBarTheme(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                    ),
                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                    colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00ADB5),
                        secondary: Color(0xFF00E5FF),
                        surface: Color(0xFF111111),
                    ),
                );
            case AppThemeMode.dark:
                return ThemeData(
                    brightness: Brightness.dark,
                    scaffoldBackgroundColor: const Color(0xFF121212),
                    cardColor: const Color(0xFF1E1E1E),
                    appBarTheme: const AppBarTheme(
                        backgroundColor: Color(0xFF1E1E1E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                    ),
                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                    colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00ADB5),
                        secondary: Color(0xFF00E5FF),
                        surface: Color(0xFF1E1E1E),
                    ),
                );
            case AppThemeMode.light:
                return ThemeData(
                    brightness: Brightness.light,
                    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
                    cardColor: Colors.white,
                    appBarTheme: const AppBarTheme(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 1,
                    ),
                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFF00ADB5),
                        secondary: Color(0xFF007A78),
                        surface: Colors.white,
                    ),
                );
            case AppThemeMode.system:
                final isPlatformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
                return _buildThemeData(isPlatformDark ? AppThemeMode.dark : AppThemeMode.light, context);
        }
    }
}

class PiPDetectorShell extends StatefulWidget {
    final Widget child;
    const PiPDetectorShell({super.key, required this.child});

    @override
    State<PiPDetectorShell> createState() => _PiPDetectorShellState();
}

class _PiPDetectorShellState extends State<PiPDetectorShell> {
    bool _isPipMode = false;

    @override
    void initState() {
        super.initState();
        PipService.isPipModeNotifier.addListener(_onPipChanged);
    }

    @override
    void dispose() {
        PipService.isPipModeNotifier.removeListener(_onPipChanged);
        super.dispose();
    }

    void _onPipChanged() {
        if (mounted) {
            setState(() {
                _isPipMode = PipService.isPipModeNotifier.value;
            });
        }
    }

    @override
    Widget build(BuildContext context) {
        if (_isPipMode) {
            return const PipScreen();
        }
        return widget.child;
    }
}

class MainNavigationShell extends StatefulWidget {
    const MainNavigationShell({super.key});

    @override
    State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
    int _currentIndex = 0;
    ApiService? _subscribedService;

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            final apiService = context.read<ApiService>();
            _subscribedService = apiService;
            apiService.addListener(_onSignalUpdated);
            apiService.startPolling();

            if (apiService.settings.routerIp.isEmpty) {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
                );
            }
        });
    }

    @override
    void dispose() {
        _subscribedService?.removeListener(_onSignalUpdated);
        super.dispose();
    }

    void _onSignalUpdated() {
        final apiService = context.read<ApiService>();
        final signal = apiService.currentSignal;
        final settings = apiService.settings;
        final isConnecting = apiService.isConnecting;

        OverlayService.updateOverlayData(signal, settings, isConnecting: isConnecting);
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final isBottomNav = apiService.settings.navigationStyle == AppNavigationStyle.bottomNav;

        final List<Widget> pages = [
            DashboardScreen(
                onNavigateToGraph: () => setState(() => _currentIndex = 1),
                onNavigateToSettings: () => setState(() => _currentIndex = 2),
            ),
            const GraphScreen(),
            const SettingsScreen(),
        ];

        final mainContent = isBottomNav
            ? Scaffold(
                body: pages[_currentIndex],
                bottomNavigationBar: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                        setState(() {
                            _currentIndex = index;
                        });
                    },
                    destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: 'ダッシュボード',
                        ),
                        NavigationDestination(
                            icon: Icon(Icons.show_chart_outlined),
                            selectedIcon: Icon(Icons.show_chart),
                            label: '同期グラフ',
                        ),
                        NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: '設定',
                        ),
                    ],
                ),
            )
            : pages[_currentIndex];

        return mainContent;
    }
}
