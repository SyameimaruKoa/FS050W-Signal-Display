import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'views/widgets/event_lamp_overlay.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Pip, Foreground, and Notification Services
    PipService.initialize();
    BackgroundService.initService();
    await NotificationService.initialize();

    // 2. Load Persisted Settings
    final settings = await StorageService.loadSettings();

    // Synchronize auto PiP setting with native layer
    PipService.setAutoEnterPip(settings.autoPipOnHome, settings.pipAspectRatio);

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
    static const MethodChannel _lifecycleChannel = MethodChannel('com.syameimarukoa.fs050w_monitor/lifecycle');

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addObserver(this);

        _lifecycleChannel.setMethodCallHandler((call) async {
            if (call.method == 'onScreenStateChanged') {
                final bool isScreenOn = call.arguments as bool? ?? true;
                if (mounted) {
                    context.read<ApiService>().setScreenState(isScreenOn);
                }
            }
        });
    }

    @override
    void dispose() {
        WidgetsBinding.instance.removeObserver(this);
        super.dispose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
        super.didChangeAppLifecycleState(state);
        final apiService = context.read<ApiService>();
        if (state == AppLifecycleState.paused) {
            // App paused (or screen off): allow battery-saving state
            apiService.setScreenState(false);
        } else if (state == AppLifecycleState.resumed) {
            // App resumed: wake up polling
            apiService.setScreenState(true);
        }
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final settings = apiService.settings;

        // Manage Wakelock (Screen Always On)
        if (settings.keepScreenOn) {
            WakelockPlus.enable();
        } else {
            WakelockPlus.disable();
        }

        // Determine Theme
        final ThemeData themeData = _buildThemeData(settings.appTheme, context);

        return ValueListenableBuilder<bool>(
            valueListenable: PipService.isPipModeNotifier,
            builder: (context, isInPipMode, _) {
                return MaterialApp(
                    title: 'FS050W Monitor',
                    debugShowCheckedModeBanner: false,
                    theme: themeData,
                    home: isInPipMode
                        ? const PipScreen()
                        : EventLampOverlay(
                            child: settings.isSetupCompleted
                                ? const MainNavigationShell()
                                : SetupWizardScreen(
                                    onComplete: () {},
                                ),
                        ),
                );
            },
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
                    textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.dark().textTheme),
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
                    textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.dark().textTheme),
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
                    textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.light().textTheme),
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

            // Initial overlay sync if enabled
            if (apiService.settings.overlayEnabled) {
                OverlayService.startOverlay(apiService.settings);
            }
        });
    }

    @override
    void dispose() {
        _subscribedService?.removeListener(_onSignalUpdated);
        super.dispose();
    }

    void _onSignalUpdated() {
        final apiService = _subscribedService;
        if (apiService == null) return;

        final signal = apiService.currentSignal;
        if (signal != null) {
            NotificationService.handleSignalEvents(signal, apiService.settings);
            OverlayService.updateOverlayData(
                signal,
                apiService.settings,
                isConnecting: apiService.isConnecting,
            );
        }
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

        if (!isBottomNav) {
            return pages[_currentIndex];
        }

        return Scaffold(
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
        );
    }
}
