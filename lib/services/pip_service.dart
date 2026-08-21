import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
    static const MethodChannel _channel = MethodChannel('com.syameimarukoa.fs050w_monitor/pip');

    static final ValueNotifier<bool> isPipModeNotifier = ValueNotifier<bool>(false);

    static void initialize() {
        _channel.setMethodCallHandler((call) async {
            if (call.method == 'onPipModeChanged') {
                final bool isInPip = call.arguments as bool? ?? false;
                isPipModeNotifier.value = isInPip;
            }
        });
    }

    static Future<bool> isPipSupported() async {
        try {
            final bool? result = await _channel.invokeMethod<bool>('isPipSupported');
            return result ?? false;
        } catch (_) {
            return false;
        }
    }

    static Future<bool> enterPipMode(String aspectRatio) async {
        try {
            final rational = parseAspectRatio(aspectRatio);
            final bool? success = await _channel.invokeMethod<bool>('enterPipMode', {
                'numerator': rational.$1,
                'denominator': rational.$2,
            });
            return success ?? false;
        } catch (_) {
            return false;
        }
    }

    static Future<void> setAutoEnterPip(bool enabled, String aspectRatio) async {
        try {
            final rational = parseAspectRatio(aspectRatio);
            await _channel.invokeMethod('setAutoEnterPip', {
                'enabled': enabled,
                'numerator': rational.$1,
                'denominator': rational.$2,
            });
        } catch (_) {}
    }

    static (int, int) parseAspectRatio(String ratioStr) {
        switch (ratioStr) {
            case '16:9':
                return (16, 9);
            case '9:16':
                return (9, 16);
            case '1:1':
                return (1, 1);
            case '4:3':
                return (4, 3);
            case '3:4':
                return (3, 4);
            case '21:9':
                return (21, 9);
            case '9:21':
                return (9, 21);
            default:
                final parts = ratioStr.split(':');
                if (parts.length == 2) {
                    final n = int.tryParse(parts[0]);
                    final d = int.tryParse(parts[1]);
                    if (n != null && d != null && d > 0) {
                        return (n, d);
                    }
                }
                return (16, 9);
        }
    }

    static double getAspectRatioValue(String ratioStr) {
        final (num, den) = parseAspectRatio(ratioStr);
        return num / den;
    }
}
