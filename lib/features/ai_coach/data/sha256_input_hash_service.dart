import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/features/ai_coach/domain/input_hash_service.dart';

final class Sha256InputHashService implements InputHashService {
  const Sha256InputHashService();

  @override
  String hashCanonicalJson(String canonicalJson) {
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }
}
