import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
    static const String kDefaultKey = "0123456789";
    static const String kPrefix = "4cc68e3626e5b94602c325f7c4ca5dee:example.com:";
    static const String kUsername = "4cc68e3626e5b94602c325f7c4ca5dee";

    static String computeLoginPasswordHash(String password, String prikey) {
        final keyBytes = utf8.encode(kDefaultKey);
        final passBytes = utf8.encode(password);

        final hmac1 = Hmac(md5, keyBytes);
        final h1Digest = hmac1.convert(passBytes);
        final h1 = h1Digest.toString();

        final p1Input = utf8.encode(kPrefix + h1);
        final p1Digest = md5.convert(p1Input);
        final p1 = p1Digest.toString();

        final hmac2 = Hmac(md5, keyBytes);
        final p2Input = utf8.encode(p1 + prikey);
        final p2Digest = hmac2.convert(p2Input);
        return p2Digest.toString();
    }
}
