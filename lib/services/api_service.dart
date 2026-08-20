import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/signal_data.dart';
import '../models/app_settings.dart';
import '../utils/crypto_utils.dart';

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

    ApiService(this._settings);

    ConnectionStatus get status => _status;
    String? get errorMessage => _errorMessage;
    SignalData? get currentSignal => _currentSignal;
    List<SignalData> get signalHistory => List.unmodifiable(_signalHistory);
    bool get isLoggedIn => _isLoggedIn;
    AppSettings get settings => _settings;

    void updateSettings(AppSettings newSettings) {
        final bool ipChanged = _settings.routerIp != newSettings.routerIp;
        final bool passChanged = _settings.webPassword != newSettings.webPassword;
        final bool intervalChanged = _settings.foregroundIntervalSeconds != newSettings.foregroundIntervalSeconds;

        _settings = newSettings;
        if (ipChanged || passChanged) {
            _csrfToken = null;
            _sessionCookie = null;
            _prikey = null;
            _isLoggedIn = false;
            if (_isPolling) {
                restartPolling();
            }
        } else if (intervalChanged && _isPolling) {
            _restartTimer();
        }
        notifyListeners();
    }

    void startPolling() {
        if (_isPolling) return;
        _isPolling = true;
        _pollOnce();
        _restartTimer();
    }

    void stopPolling() {
        _isPolling = false;
        _pollingTimer?.cancel();
        _pollingTimer = null;
    }

    void restartPolling() {
        stopPolling();
        startPolling();
    }

    void _restartTimer() {
        _pollingTimer?.cancel();
        final interval = Duration(seconds: _settings.foregroundIntervalSeconds.clamp(1, 10));
        _pollingTimer = Timer.periodic(interval, (_) => _pollOnce());
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
        } catch (e) {
            // failed
        }
        return false;
    }

    Future<void> _pollOnce() async {
        try {
            if (_csrfToken == null || _sessionCookie == null) {
                _status = ConnectionStatus.connecting;
                notifyListeners();
                final bool initSuccess = await _fetchCsrfToken();
                if (!initSuccess) {
                    _status = ConnectionStatus.error;
                    _errorMessage = "ルーター (${_settings.routerIp}) に接続できません";
                    notifyListeners();
                    return;
                }
            }

            if (!_isLoggedIn && _settings.webPassword.isNotEmpty) {
                final bool loginSuccess = await _performLogin();
                if (loginSuccess) {
                    _isLoggedIn = true;
                    _status = ConnectionStatus.authenticated;
                } else {
                    // Fallback to passwordless mode if enabled or if locked
                    if (_settings.autoPasswordless) {
                        _isLoggedIn = false;
                        _status = ConnectionStatus.unauthenticatedMode;
                    } else {
                        _status = ConnectionStatus.error;
                        _errorMessage = "ログイン認証に失敗しました (パスワードを確認してください)";
                        notifyListeners();
                        return;
                    }
                }
            } else if (!_isLoggedIn) {
                _status = ConnectionStatus.unauthenticatedMode;
            }

            final Map<String, dynamic>? params = await _fetchParams();
            if (params != null) {
                bool hasCa = false;
                List<String> caBands = [];
                if (_isLoggedIn) {
                    final caData = await _fetchCaList();
                    if (caData != null) {
                        hasCa = caData['hasCa'] == true;
                        caBands = (caData['bands'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                    }
                }

                final signal = SignalData.fromApiResponse(
                    params,
                    hasCa: hasCa,
                    caBands: caBands,
                    previousData: _currentSignal,
                );

                _currentSignal = signal;
                _signalHistory.add(signal);

                // Keep maximum 600 history points (10 mins at 1s)
                if (_signalHistory.length > 600) {
                    _signalHistory.removeRange(0, _signalHistory.length - 600);
                }

                _status = _isLoggedIn ? ConnectionStatus.authenticated : ConnectionStatus.unauthenticatedMode;
                _errorMessage = null;
                notifyListeners();
            } else {
                // If fetching params failed, attempt quick CSRF recovery once
                _csrfToken = null;
                _sessionCookie = null;
                final bool reInit = await _fetchCsrfToken();
                if (reInit) {
                    final retryParams = await _fetchParams();
                    if (retryParams != null) {
                        final signal = SignalData.fromApiResponse(
                            retryParams,
                            previousData: _currentSignal,
                        );
                        _currentSignal = signal;
                        _signalHistory.add(signal);
                        _status = _isLoggedIn ? ConnectionStatus.authenticated : ConnectionStatus.unauthenticatedMode;
                        _errorMessage = null;
                        notifyListeners();
                        return;
                    }
                }
                _handleFetchFailure();
            }
        } catch (e) {
            _handleFetchFailure(e.toString());
        }
    }

    Future<bool> _fetchCsrfToken() async {
        try {
            final uri = Uri.parse("http://${_settings.routerIp}/goform/x_csrf_token");
            final response = await _client.get(uri).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
                _updateHeadersFromResponse(response);
                return _csrfToken != null;
            }
        } catch (e) {
            // connection failed
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
            ).timeout(const Duration(seconds: 3));

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
            ).timeout(const Duration(seconds: 3));

            if (loginResp.statusCode == 200) {
                _updateHeadersFromResponse(loginResp);
                final loginJson = jsonDecode(loginResp.body);
                if (loginJson['retcode'] == 0) {
                    return true;
                }
            }
        } catch (e) {
            // login failed
        }
        return false;
    }

    Future<Map<String, dynamic>?> _fetchParams() async {
        final keysPayload = jsonEncode({
            'keys': [
                'mnet_sysmode',
                'mnet_operator_name',
                'mnet_rsrp',
                'mnet_rssi',
                'mnet_rsrq',
                'mnet_sinr',
                'mnet_wnw_band',
                'mnet_wnw_pci',
                'mnet_wnw_earfcn',
                'mnet_endc_rsrp',
                'mnet_endc_rsrq',
                'mnet_endc_snr',
                'mnet_wnw_psband',
                'mnet_wnw_pspci',
                'mnet_wnw_psnrarfcn',
                'battery_percent',
                'battery_charging',
            ]
        });

        // Try authenticated endpoint first if logged in
        if (_isLoggedIn) {
            final authUri = Uri.parse("http://${_settings.routerIp}/action/get_mgdb_params");
            final authHeaders = {
                'Content-Type': 'application/json',
                if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
                if (_sessionCookie != null) 'Cookie': _sessionCookie!,
            };

            try {
                final response = await _client.post(authUri, headers: authHeaders, body: keysPayload).timeout(const Duration(seconds: 3));
                _updateHeadersFromResponse(response);
                if (response.statusCode == 200 && !response.body.startsWith('<!DOCTYPE')) {
                    final dynamic data = jsonDecode(response.body);
                    if (data is Map<String, dynamic> && data['retcode'] == 0) {
                        return (data['data'] is Map<String, dynamic>) ? (data['data'] as Map<String, dynamic>) : data;
                    }
                } else if (response.statusCode == 401 || response.statusCode == 403 || response.body.startsWith('<!DOCTYPE')) {
                    _isLoggedIn = false;
                }
            } catch (e) {
                // fall through to unauthenticated
            }
        }

        // Unauthenticated mode (/goform/get_mgdb_params)
        final uri = Uri.parse("http://${_settings.routerIp}/goform/get_mgdb_params");
        final headers = {
            'Content-Type': 'application/json',
            if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        };

        try {
            final response = await _client.post(uri, headers: headers, body: keysPayload).timeout(const Duration(seconds: 3));
            _updateHeadersFromResponse(response);
            if (response.statusCode == 200) {
                final dynamic data = jsonDecode(response.body);
                if (data is Map<String, dynamic> && data['retcode'] == 0) {
                    return (data['data'] is Map<String, dynamic>) ? (data['data'] as Map<String, dynamic>) : data;
                }
            }
        } catch (e) {
            // failed
        }
        return null;
    }

    Future<Map<String, dynamic>?> _fetchCaList() async {
        if (!_isLoggedIn) return null;
        final uri = Uri.parse("http://${_settings.routerIp}/action/mnet_get_ca_list");
        final Map<String, String> headers = {
            'Content-Type': 'application/json',
            if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        };

        try {
            final response = await _client.post(uri, headers: headers, body: '{}').timeout(const Duration(seconds: 2));
            _updateHeadersFromResponse(response);
            if (response.statusCode == 200) {
                final dynamic data = jsonDecode(response.body);
                if (data is Map<String, dynamic>) {
                    final caList = data['ca_list'] as List<dynamic>?;
                    if (caList != null && caList.isNotEmpty) {
                        final bands = caList.map((e) => "B${e['band'] ?? e}").toList();
                        return {'hasCa': true, 'bands': bands};
                    }
                }
            }
        } catch (e) {
            // ignore
        }
        return {'hasCa': false, 'bands': <String>[]};
    }

    void _handleFetchFailure([String? message]) {
        _csrfToken = null;
        _sessionCookie = null;
        _status = ConnectionStatus.error;
        _errorMessage = message ?? "ルーターからのデータ取得に失敗しました";
        notifyListeners();
    }
}
