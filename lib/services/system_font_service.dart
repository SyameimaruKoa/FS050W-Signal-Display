import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the fonts Android actually uses, without bundling or persisting them.
class SystemFontService extends ChangeNotifier {
    static const _channel = MethodChannel('com.syameimarukoa.fs050w_signal_display/system_font');
    static final instance = SystemFontService();
    String? _signature;
    List<String> _families = const ['sans-serif'];
    Future<void>? _pending;

    String get fontFamily => _families.first;
    List<String> get fontFamilyFallback => _families.skip(1).toList();

    Future<void> refresh() {
        return _pending ??= _refresh().whenComplete(() => _pending = null);
    }

    Future<void> _refresh() async {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
        try {
            final response = await _channel.invokeMapMethod<String, dynamic>(
                'getSystemFonts', {'signature': _signature});
            if (response == null) return;
            final signature = response['signature'] as String;
            final fonts = response['fonts'] as List<dynamic>;
            final families = <String>[];
            for (var i = 0; i < fonts.length; i++) {
                final font = fonts[i] as Map<dynamic, dynamic>;
                final bytes = extractFont(font['bytes'] as Uint8List, font['ttcIndex'] as int);
                final family = 'AndroidSystemFont-$signature-$i';
                final loader = FontLoader(family)..addFont(SynchronousFuture(ByteData.sublistView(bytes)));
                await loader.load();
                families.add(family);
            }
            if (families.isEmpty) return;
            _signature = signature;
            _families = [...families, 'sans-serif'];
            notifyListeners();
        } on MissingPluginException {
            // Old Android and non-Android hosts retain the system generic family.
        } on PlatformException catch (error) {
            debugPrint('System font unavailable: ${error.code}');
        } on FormatException catch (error) {
            debugPrint('System font unavailable: $error');
        }
    }

    /// Flutter's FontLoader has no TTC index argument. Rebuild the selected face
    /// as a standalone SFNT, preserving its tables and correcting the checksum.
    @visibleForTesting
    static Uint8List extractFont(Uint8List bytes, int index) {
        final source = ByteData.sublistView(bytes);
        if (bytes.length < 12) throw const FormatException('Truncated font');
        if (source.getUint32(0) != 0x74746366) return bytes;
        final count = source.getUint32(8);
        if (index < 0 || index >= count || 12 + count * 4 > bytes.length) {
            throw const FormatException('Invalid font collection index');
        }
        final offset = source.getUint32(12 + index * 4);
        if (offset + 12 > bytes.length) throw const FormatException('Invalid font offset');
        final tables = source.getUint16(offset + 4);
        final headerSize = 12 + tables * 16;
        if (offset + headerSize > bytes.length) throw const FormatException('Truncated font tables');
        var size = headerSize;
        for (var i = 0; i < tables; i++) {
            final entry = offset + 12 + i * 16;
            final start = source.getUint32(entry + 8);
            final length = source.getUint32(entry + 12);
            if (start + length > bytes.length) throw const FormatException('Invalid font table');
            size += (length + 3) & ~3;
        }
        final result = Uint8List(size);
        result.setRange(0, headerSize, bytes, offset);
        final target = ByteData.sublistView(result);
        var cursor = headerSize;
        int? headOffset;
        for (var i = 0; i < tables; i++) {
            final entry = 12 + i * 16;
            final start = target.getUint32(entry + 8);
            final length = target.getUint32(entry + 12);
            result.setRange(cursor, cursor + length, bytes, start);
            target.setUint32(entry + 8, cursor);
            if (target.getUint32(entry) == 0x68656164 && length >= 12) {
                headOffset = cursor;
                target.setUint32(cursor + 8, 0);
            }
            cursor += (length + 3) & ~3;
        }
        if (headOffset != null) {
            var checksum = 0;
            for (var i = 0; i < result.length; i += 4) {
                checksum = (checksum + target.getUint32(i)) & 0xffffffff;
            }
            target.setUint32(headOffset + 8, (0xb1b0afba - checksum) & 0xffffffff);
        }
        return result;
    }
}
