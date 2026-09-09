// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MetadataStorageException implements Exception {
  const MetadataStorageException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class CorruptMetadataException extends MetadataStorageException {
  const CorruptMetadataException(super.message);
}

enum LocalCleanupStatus { clean, pending, failed }

final class SessionMetadata {
  static const currentVersion = 1;

  const SessionMetadata._({
    required this.schemaVersion,
    required this.restoreAllowed,
    required this.cleanupStatus,
    required this.expectedCredentialId,
  });

  const SessionMetadata.signedOutClean()
    : this._(
        schemaVersion: currentVersion,
        restoreAllowed: false,
        cleanupStatus: LocalCleanupStatus.clean,
        expectedCredentialId: null,
      );

  const SessionMetadata.cleanupPending()
    : this._(
        schemaVersion: currentVersion,
        restoreAllowed: false,
        cleanupStatus: LocalCleanupStatus.pending,
        expectedCredentialId: null,
      );

  const SessionMetadata.cleanupFailed()
    : this._(
        schemaVersion: currentVersion,
        restoreAllowed: false,
        cleanupStatus: LocalCleanupStatus.failed,
        expectedCredentialId: null,
      );

  factory SessionMetadata.restoreEnabled(String credentialId) {
    if (credentialId.trim().isEmpty || credentialId.length > 128) {
      throw const CorruptMetadataException('expectedCredentialId tidak valid');
    }
    return SessionMetadata._(
      schemaVersion: currentVersion,
      restoreAllowed: true,
      cleanupStatus: LocalCleanupStatus.clean,
      expectedCredentialId: credentialId,
    );
  }

  final int schemaVersion;
  final bool restoreAllowed;
  final LocalCleanupStatus cleanupStatus;
  final String? expectedCredentialId;

  factory SessionMetadata.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const CorruptMetadataException('Metadata harus berupa object');
    }
    final version = value['schemaVersion'];
    final restore = value['restoreAllowed'];
    final rawStatus = value['cleanupStatus'];
    final rawId = value['expectedCredentialId'];
    if (version is! int || version != currentVersion || restore is! bool) {
      throw const CorruptMetadataException('Schema metadata tidak valid');
    }
    final status = rawStatus is String
        ? LocalCleanupStatus.values.asNameMap()[rawStatus]
        : null;
    if (status == null) {
      throw const CorruptMetadataException('cleanupStatus tidak valid');
    }
    if (rawId != null && rawId is! String) {
      throw const CorruptMetadataException(
        'expectedCredentialId harus string atau null',
      );
    }
    final id = rawId as String?;
    if (restore) {
      if (status != LocalCleanupStatus.clean ||
          id == null ||
          id.trim().isEmpty ||
          id.length > 128) {
        throw const CorruptMetadataException('Restore metadata tidak valid');
      }
      return SessionMetadata.restoreEnabled(id);
    }
    if (id != null) {
      throw const CorruptMetadataException(
        'expectedCredentialId wajib null ketika restore tidak diizinkan',
      );
    }
    return switch (status) {
      LocalCleanupStatus.clean => const SessionMetadata.signedOutClean(),
      LocalCleanupStatus.pending => const SessionMetadata.cleanupPending(),
      LocalCleanupStatus.failed => const SessionMetadata.cleanupFailed(),
    };
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'restoreAllowed': restoreAllowed,
    'cleanupStatus': cleanupStatus.name,
    'expectedCredentialId': expectedCredentialId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMetadata &&
          runtimeType == other.runtimeType &&
          schemaVersion == other.schemaVersion &&
          restoreAllowed == other.restoreAllowed &&
          cleanupStatus == other.cleanupStatus &&
          expectedCredentialId == other.expectedCredentialId;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    restoreAllowed,
    cleanupStatus,
    expectedCredentialId,
  );
}

abstract interface class SessionMetadataStore {
  Future<SessionMetadata?> read();
  Future<void> write(SessionMetadata metadata);
  Future<void> clear();
}

final class SharedPrefsSessionMetadataStore implements SessionMetadataStore {
  SharedPrefsSessionMetadataStore({
    required SharedPreferences prefs,
    required String key,
  }) : _prefs = prefs,
       _key = key;

  final SharedPreferences _prefs;
  final String _key;

  @override
  Future<SessionMetadata?> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    if (raw.trim().isEmpty) {
      throw const CorruptMetadataException('Metadata string kosong');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CorruptMetadataException('Metadata bukan JSON valid');
    }
    return SessionMetadata.fromJson(decoded);
  }

  @override
  Future<void> write(SessionMetadata metadata) async {
    final jsonStr = jsonEncode(metadata.toJson());
    final ok = await _prefs.setString(_key, jsonStr);
    if (!ok) {
      throw const MetadataStorageException('Gagal menulis metadata sesi');
    }
  }

  @override
  Future<void> clear() async {
    final ok = await _prefs.remove(_key);
    if (!ok && _prefs.containsKey(_key)) {
      throw const MetadataStorageException('Gagal menghapus metadata sesi');
    }
  }
}
