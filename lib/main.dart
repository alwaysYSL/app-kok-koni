import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/auth/data/secure_key_val_store.dart';
import 'core/composition/app_composition.dart';
import 'core/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final profile = DeploymentProfile.fromEnvironment();
  final preferences = await SharedPreferences.getInstance();
  const secureStore = FlutterSecureKeyValStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  final composition = AppComposition.fromProfile(
    profile,
    preferences: preferences,
    secureStore: secureStore,
  );

  runApp(
    ProviderScope(
      overrides: [
        appCompositionProvider.overrideWithValue(composition),
        preferencesProvider.overrideWithValue(preferences),
      ],
      child: const KokApp(),
    ),
  );
}
