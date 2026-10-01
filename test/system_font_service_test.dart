import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs050w_signal_display/services/system_font_service.dart';

void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('Standalone fonts retain their data', () {
        final bytes = Uint8List(12);
        ByteData.sublistView(bytes).setUint32(0, 0x00010000);
        expect(SystemFontService.extractFont(bytes, 0), same(bytes));
    });

    test('Selects the requested TTC face and relocates its tables', () {
        final bytes = Uint8List(104);
        final data = ByteData.sublistView(bytes);
        data.setUint32(0, 0x74746366);
        data.setUint32(4, 0x00010000);
        data.setUint32(8, 2);
        data.setUint32(12, 20);
        data.setUint32(16, 48);
        for (final offset in [20, 48]) {
            data.setUint32(offset, 0x00010000);
            data.setUint16(offset + 4, 1);
            data.setUint16(offset + 6, 16);
            data.setUint32(offset + 12, 0x68656164);
            data.setUint32(offset + 20, offset == 20 ? 76 : 88);
            data.setUint32(offset + 24, 12);
        }
        data.setUint32(76, 111);
        data.setUint32(88, 222);
        final result = SystemFontService.extractFont(bytes, 1);
        final output = ByteData.sublistView(result);
        expect(output.getUint32(20), 28);
        expect(output.getUint32(28), 222);
        var sum = 0;
        for (var offset = 0; offset < result.length; offset += 4) {
            sum = (sum + output.getUint32(offset)) & 0xffffffff;
        }
        expect(sum, 0xb1b0afba);
        expect(data.getUint32(96), 0);
        expect(() => SystemFontService.extractFont(bytes, 2), throwsFormatException);
        data.setUint32(68, 1000);
        expect(() => SystemFontService.extractFont(bytes, 1), throwsFormatException);
    });

    test('Unsupported devices and channel failures retain generic system font', () async {
        const channel = MethodChannel('com.syameimarukoa.fs050w_signal_display/system_font');
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = SystemFontService();
        var calls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'getSystemFonts');
            expect(call.arguments['signature'], isNull);
            return null;
        });
        await Future.wait([service.refresh(), service.refresh()]);
        expect(calls, 1);
        expect(service.fontFamily, 'sans-serif');
        messenger.setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'SYSTEM_FONT_UNAVAILABLE');
        });
        await service.refresh();
        expect(service.fontFamily, 'sans-serif');
        messenger.setMockMethodCallHandler(channel, null);
        await service.refresh();
        expect(service.fontFamily, 'sans-serif');
        service.dispose();
    });
}
