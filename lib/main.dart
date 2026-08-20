import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/app_settings.dart';
import 'models/signal_data.dart';
import 'services/api_service.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'views/dashboard_screen.dart';
import 'views/graph_screen.dart';
import 'views/settings_screen.dart';
import 'views/setup_wizard_screen.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Foreground and Notification Services
    BackgroundService.initService();
    await NotificationService.initialize();

    // 2. Load Persisted Settings
    final settings = await StorageService.loadSettings();

    runApp(
        MultiProvider(
            providers: [
                ChangeNotifierProvider(create: (_) => ApiService(settings)),
            ],
            child: const Fs050wApp(),
        ),
    );
}

class Fs050wApp extends StatelessWidget {
    const Fs050wApp({super.key});

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

        return MaterialApp(
            title: 'FS050W Monitor',
            debugShowCheckedModeBanner: false,
            theme: themeData,
            home: settings.isSetupCompleted
                ? const MainNavigationShell()
                : SetupWizardScreen(
                    onComplete: () {
                        // After wizard completion, state updates automatically via notifyListeners()
                    },
                ),
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
            if (apiService.settings.foregroundNotificationEnabled) {
                BackgroundService.startService();
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
            BackgroundService.updateNotification(signal, apiService.settings);
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
            body: IndexedStack(
                index: _currentIndex,
                children: pages,
            ),
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
