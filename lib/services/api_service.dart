import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/signal_data.dart';
import '../models/app_settings.dart';
import '../models/connection_state.dart';
import '../utils/crypto_utils.dart';
import 'app_logger.dart';
import 'overlay_service.dart';
import 'notification_service.dart';

enum ConnectionStatus {
    disconnected,
    connecting,
    authenticated,
    unauthenticatedMode,
    error,
}

class ApiService extends ChangeNotifier {
    final http.Client _client = http.Client();

    AppSettings _settings;
    ConnectionStatus _status = ConnectionStatus.disconnected;
    String? _errorMessage;
    SignalData? _currentSignal;
    final List<SignalData> _signalHistory = [];

    String? _csrfToken;
    String? _sessionCookie;
    String? _prikey;
    bool _isLoggedIn = false;

    Timer? _pollingTimer;
    bool _isPolling = false;
    bool _isScreenOn = true;
    bool _isFetching = false;
    int _consecutiveErrorCount = 0;
    DateTime? _lastLoginAttempt;
    DateTime? _lockoutUntil;
    int _lockoutRemainSeconds = 0;
    int _consecutiveLoginFailures = 0;

    ApiService(this._settings);

    ConnectionStatus get status => _status;
    String? get errorMessage => _errorMessage;
    SignalData? get currentSignal => _currentSignal;
    List<SignalData> get signalHistory => List.unmodifiable(_signalHistory);
    bool get isLoggedIn => _isLoggedIn;
    AppSettings get settings => _settings;
    bool get isConnecting => _status == ConnectionStatus.connecting;
    bool get isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
    int get lockoutRemainSeconds => _lockoutUntil != null ? _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999) : 0;

    void updateSettings(AppSettings newSettings) {
        final bool ipChanged = _settings.routerIp != newSettings.routerIp;
        final bool passChanged = _settings.webPassword != newSettings.webPassword;

        _settings = newSettings;
        if (ipChanged || passChanged) {
            _resetSession();
            _isLoggedIn = false;
            _lastLoginAttempt = null;
            _lockoutUntil = null;
            _consecutiveErrorCount = 0;
            if (_isPolling) {
                restartPolling();
            }
        } else if (_isPolling) {
            _restartTimer();
        }
        notifyListeners();
    }

    void setScreenState(bool isScreenOn) {
        _isScreenOn = isScreenOn;
        if (!isScreenOn) {
            AppLogger.info("Screen OFF detected: Pausing polling loop");
            _pollingTimer?.cancel();
            _pollingTimer = null;
        } else {
            AppLogger.info("Screen ON detected: Resuming polling loop immediately");
            if (_isPolling) {
                _pollOnce();
                _restartTimer();
            }
        }
    }

    void startPolling() {
        if (_isPolling) return;
        _isPolling = true;
        if (_isScreenOn) {
            _pollOnce();
            _restartTimer();
        }
    }

    void stopPolling() {
        _isPolling = false;
        _pollingTimer?.cancel();
        _pollingTimer = null;
    }

    void restartPolling() {
        stopPolling();
        _resetSession();
        startPolling();
    }

    void _restartTimer() {
        _pollingTimer?.cancel();
        final interval = Duration(seconds: _settings.foregroundIntervalSeconds.clamp(1, 10));
        _pollingTimer = Timer.periodic(interval, (_) {
            if (_isScreenOn) {
                _pollOnce();
            }
        });
    }

    void _resetSession() {
        _csrfToken = null;
        _sessionCookie = null;
        _prikey = null;
        _isLoggedIn = false;
        _lastLoginAttempt = null;
    }

    void _updateHeadersFromResponse(http.Response response) {
        final csrf = response.headers['x-csrf-token'];
        if (csrf != null && csrf.isNotEmpty) {
            _csrfToken = csrf;
        }
        final cookie = response.headers['set-cookie'];
        if (cookie != null && cookie.isNotEmpty) {
            final match = RegExp(r'-webs-session-=[^;]+').firstMatch(cookie);
            if (match != null) {
                _sessionCookie = match.group(0);
            } else {
                _sessionCookie = cookie.split(';').first;
            }
        }
    }

    Future<bool> testConnection(String ip, String password) async {
        try {
            final testUri = Uri.parse("http://$ip/goform/x_csrf_token");
            final resp = await _client.get(testUri).timeout(const Duration(seconds: 3));
            if (resp.statusCode == 200) {
                final csrf = resp.headers['x-csrf-token'];
                final cookie = resp.headers['set-cookie'];
                final cookieHeader = cookie?.split(';').first ?? '';

                final testParamsUri = Uri.parse("http://$ip/goform/get_mgdb_params");
                final testHeaders = {
                    'Content-Type': 'application/json',
                    if (csrf != null) 'X-Csrf-Token': csrf,
                    if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
                };
                final payload = jsonEncode({
                    'keys': ['mnet_sysmode', 'mnet_rsrp']
                });
                final paramResp = await _client.post(testParamsUri, headers: testHeaders, body: payload).timeout(const Duration(seconds: 3));
                if (paramResp.statusCode == 200) {
                    final json = jsonDecode(paramResp.body);
                    return json['retcode'] == 0;
                }
                return true;
            }
        } catch (_) {}
        return false;
    }

    Future<void> _pollOnce() async {
        if (_isFetching) return;
        _isFetching = true;

        try {
            final hasPassword = _settings.webPassword.isNotEmpty;

            // 1. Validate router IP is configured
            if (_settings.routerIp.isEmpty) {
                _status = ConnectionStatus.disconnected;
                _errorMessage = "ルーターIPが未設定です (設定画面で入力してください)";
                notifyListeners();
                return;
            }

            // 2. Check or establish session tokens
            if (_csrfToken == null || _sessionCookie == null) {
                if (_consecutiveErrorCount >= 2) {
                    _status = ConnectionStatus.connecting;
                    notifyListeners();
                }
                final bool initSuccess = await _fetchCsrfToken();
                if (!initSuccess) {
                    _handleFetchFailure("ルーター (${_settings.routerIp}) に接続できません");
                    return;
                }
            }

            // 3. Perform login if password is configured and not yet authenticated
            //    When password is empty, NEVER attempt login (explicit unauthenticated mode)
            if (hasPassword && !_isLoggedIn) {
                final now = DateTime.now();
                if (_lockoutUntil != null && now.isBefore(_lockoutUntil!)) {
                    final remaining = _lockoutUntil!.difference(now).inSeconds;
                    _isLoggedIn = false;
                    _status = ConnectionStatus.unauthenticatedMode;
                    _errorMessage = "ルーター一時ロック中 (残り ${remaining} 秒)";
                } else {
                    if (_lockoutUntil != null) {
                        // Lockout just expired - get fresh CSRF before retrying
                        _lockoutUntil = null;
                        _csrfToken = null;
                        _sessionCookie = null;
                        final reinit = await _fetchCsrfToken();
                        if (!reinit) {
                            _handleFetchFailure("ルーター (${_settings.routerIp}) に接続できません");
                            return;
                        }
                    }
                    final canAttempt = _lastLoginAttempt == null || now.difference(_lastLoginAttempt!).inSeconds >= 5;
                    if (canAttempt) {
                        _lastLoginAttempt = now;
                        AppLogger.info("Attempting authentication with router (${_settings.routerIp})...");
                        final bool loginSuccess = await _performLogin();
                        if (loginSuccess) {
                            _isLoggedIn = true;
                            _status = ConnectionStatus.authenticated;
                            _errorMessage = null;
                            _consecutiveLoginFailures = 0;
                            AppLogger.info("Authentication succeeded: Full parameter mode active");
                        } else {
                            // Do NOT call _resetSession() here - preserve CSRF token
                            // so unauthenticated fetch can still work
                            _isLoggedIn = false;
                            _consecutiveLoginFailures++;
                            _status = ConnectionStatus.unauthenticatedMode;
                            if (_consecutiveLoginFailures >= 3 && !isLockedOut) {
                                _errorMessage = "ログイン認証に失敗しました (パスワードを確認してください)";
                            }
                            AppLogger.warn("Login failed (attempt #$_consecutiveLoginFailures). Falling back to unauthenticated mode.");
                        }
                    }
                }
            } else if (!hasPassword) {
                _isLoggedIn = false;
                _status = ConnectionStatus.unauthenticatedMode;
            }

            // 4. Fetch Parameters
            Map<String, dynamic>? params = await _fetchParams();

            // 5. Session recovery if authenticated fetch failed
            if (params == null && _isLoggedIn) {
                AppLogger.warn("Authenticated fetch failed. Resetting session and retrying login once...");
                _resetSession();
                final reInit = await _fetchCsrfToken();
                if (reInit) {
                    final loginSuccess = await _performLogin();
                    if (loginSuccess) {
                        _isLoggedIn = true;
                        params = await _fetchParams();
                    } else {
                        _isLoggedIn = false;
                        // Try unauthenticated fallback
                        params = await _fetchParams();
                    }
                }
            }

            // 6. If still no params and we have CSRF, try fresh unauthenticated fetch
            if (params == null && _csrfToken != null) {
                _isLoggedIn = false;
                params = await _fetchParams();
            }

            // 7. Process successful response
            if (params != null) {
                _consecutiveErrorCount = 0;
                if (_isLoggedIn) {
                    _errorMessage = null;
                }

                final signal = SignalData.fromApiResponse(
                    params,
                    previousData: _currentSignal,
                    adjust5gSnr: _settings.adjust5gSnr,
                );

                NotificationService.handleSignalEvents(signal, _settings);

                _currentSignal = signal;
                _signalHistory.add(signal);

                OverlayService.updateOverlayData(signal, _settings, isLoggedIn: _isLoggedIn);

                if (_signalHistory.length > 600) {
                    _signalHistory.removeRange(0, _signalHistory.length - 600);
                }

                _status = _isLoggedIn ? ConnectionStatus.authenticated : ConnectionStatus.unauthenticatedMode;
                notifyListeners();
            } else {
                _handleFetchFailure();
            }
        } catch (e) {
            _handleFetchFailure(e.toString());
        } finally {
            _isFetching = false;
        }
    }

    Future<bool> _fetchCsrfToken() async {
        try {
            final uri = Uri.parse("http://${_settings.routerIp}/goform/x_csrf_token");
            final response = await _client.get(uri).timeout(const Duration(seconds: 4));
            if (response.statusCode == 200) {
                _updateHeadersFromResponse(response);
                AppLogger.debug("CSRF token fetched successfully: ${_csrfToken != null}");
                return _csrfToken != null && _sessionCookie != null;
            }
        } catch (e) {
            AppLogger.warn("Failed to reach x_csrf_token: $e");
        }
        return false;
    }

    Future<bool> _performLogin() async {
        try {
            if (_csrfToken == null || _sessionCookie == null) return false;

            // 1. Get prikey
            final prikeyUri = Uri.parse("http://${_settings.routerIp}/goform/get_private_key");
            final prikeyResp = await _client.post(
                prikeyUri,
                headers: {
                    'X-Csrf-Token': _csrfToken!,
                    'Cookie': _sessionCookie!,
                    'Content-Type': 'application/json',
                },
                body: '{}',
            ).timeout(const Duration(seconds: 4));

            if (prikeyResp.statusCode != 200) return false;
            _updateHeadersFromResponse(prikeyResp);

            final prikeyJson = jsonDecode(prikeyResp.body);
            final prikey = prikeyJson['prikey']?.toString();
            if (prikey == null || prikey.isEmpty) return false;
            _prikey = prikey;

            // 2. Hash calculation
            final hashedPassword = CryptoUtils.computeLoginPasswordHash(_settings.webPassword, _prikey!);

            // 3. POST login2 with updated CSRF token
            final loginUri = Uri.parse("http://${_settings.routerIp}/goform/login2");
            final loginResp = await _client.post(
                loginUri,
                headers: {
                    'X-Csrf-Token': _csrfToken!,
                    'Cookie': _sessionCookie!,
                    'Content-Type': 'application/json',
                },
                body: jsonEncode({
                    'username': CryptoUtils.kUsername,
                    'password': hashedPassword,
                    'prikey': _prikey,
                }),
            ).timeout(const Duration(seconds: 4));

            if (loginResp.statusCode == 200) {
                _updateHeadersFromResponse(loginResp);
                final loginJson = jsonDecode(loginResp.body);
                final retcode = loginJson['retcode'];
                if (retcode == 0) {
                    _lockoutUntil = null;
                    _lockoutRemainSeconds = 0;
                    return true;
                }
                final remainSecs = int.tryParse(loginJson['remain_secs']?.toString() ?? '0') ?? 0;
                final remainTimes = int.tryParse(loginJson['remain_times']?.toString() ?? '0') ?? 0;
                if (remainSecs > 0) {
                    _lockoutUntil = DateTime.now().add(Duration(seconds: remainSecs + 1));
                    _lockoutRemainSeconds = remainSecs;
                    AppLogger.warn("FS050W router temporary lockout active (${remainSecs}s remaining, $remainTimes attempts left)");
                } else {
                    AppLogger.warn("Login rejected by router (retcode: $retcode, remain_times: $remainTimes)");
                }
            }
        } catch (e) {
            AppLogger.warn("Exception during _performLogin: $e");
        }
        return false;
    }

    static const List<String> kValidParamKeys = [
        'mnet_rsrp',
        'mnet_rssi',
        'mnet_rsrq',
        'mnet_sinr',
        'mnet_snr',
        'mnet_wnw_pci',
        'mnet_wnw_band',
        'mnet_wnw_pspci',
        'mnet_wnw_psband',
        'mnet_endc_rsrp',
        'mnet_endc_snr',
        'mnet_endc_rsrq',
        'mnet_sysmode',
        'battery_percent',
        'battery_charging',
        'mnet_operator_name',
    ];

    Future<Map<String, dynamic>?> _fetchParams() async {
        final keysPayload = jsonEncode({'keys': kValidParamKeys});

        // 1. Try authenticated endpoint if logged in
        if (_isLoggedIn) {
            final authUri = Uri.parse("http://${_settings.routerIp}/action/get_mgdb_params");
            final authHeaders = {
                'Content-Type': 'application/json',
                if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
                if (_sessionCookie != null) 'Cookie': _sessionCookie!,
            };

            try {
                final response = await _client.post(authUri, headers: authHeaders, body: keysPayload).timeout(const Duration(seconds: 4));
                _updateHeadersFromResponse(response);
                if (response.statusCode == 200 && !response.body.startsWith('<!DOCTYPE')) {
                    final dynamic data = jsonDecode(response.body);
                    if (data is Map<String, dynamic> && data['retcode'] == 0) {
                        return (data['data'] is Map<String, dynamic>) ? (data['data'] as Map<String, dynamic>) : data;
                    }
                } else if (response.statusCode == 401 || response.statusCode == 403 || response.body.startsWith('<!DOCTYPE')) {
                    AppLogger.warn("Authenticated session expired (status: ${response.statusCode})");
                    _isLoggedIn = false;
                    return null;
                }
            } catch (e) {
                AppLogger.warn("Network error on /action/get_mgdb_params: $e");
                return null;
            }
        }

        // 2. Unauthenticated mode (/goform/get_mgdb_params)
        final uri = Uri.parse("http://${_settings.routerIp}/goform/get_mgdb_params");
        final headers = {
            'Content-Type': 'application/json',
            if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        };

        try {
            final response = await _client.post(uri, headers: headers, body: keysPayload).timeout(const Duration(seconds: 4));
            _updateHeadersFromResponse(response);
            if (response.statusCode == 200 && !response.body.startsWith('<!DOCTYPE')) {
                final dynamic data = jsonDecode(response.body);
                if (data is Map<String, dynamic> && data['retcode'] == 0) {
                    return (data['data'] is Map<String, dynamic>) ? (data['data'] as Map<String, dynamic>) : data;
                }
            }
        } catch (e) {
            AppLogger.warn("Network error on /goform/get_mgdb_params: $e");
        }
        return null;
    }

    void _handleFetchFailure([String? message]) {
        _consecutiveErrorCount++;
        _errorMessage = message ?? "ルーターからのデータ取得に失敗しました (自動再試行中)";

        if (_consecutiveErrorCount >= 3) {
            _status = ConnectionStatus.connecting;
            OverlayService.updateOverlayData(_currentSignal, _settings, isConnecting: true);
            notifyListeners();
        }
    }
}
