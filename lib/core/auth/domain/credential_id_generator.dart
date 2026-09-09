import 'dart:math';

abstract interface class CredentialIdGenerator {
  String generate();
}

class UuidCredentialIdGenerator implements CredentialIdGenerator {
  final Random _random;

  UuidCredentialIdGenerator([Random? random])
    : _random = random ?? Random.secure();

  @override
  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    final b = bytes.map(hex).toList();
    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }
}

class DeterministicCredentialIdGenerator implements CredentialIdGenerator {
  final String prefix;
  int _counter;

  DeterministicCredentialIdGenerator([
    this.prefix = 'cred',
    int initialCounter = 1,
  ]) : _counter = initialCounter;

  @override
  String generate() {
    final id = '$prefix-$_counter';
    _counter++;
    return id;
  }
}
