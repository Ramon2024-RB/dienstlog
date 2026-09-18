import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _extendedAnalyticsKey = 'extended_analytics_enabled';

  @override
  Future<AppSettings> build() async {
    final preferences = await SharedPreferences.getInstance();

    return AppSettings(
      extendedAnalyticsEnabled:
          preferences.getBool(_extendedAnalyticsKey) ?? false,
    );
  }

  Future<void> setExtendedAnalyticsEnabled(bool enabled) async {
    final previous = state.value ?? const AppSettings();

    state = AsyncData(
      previous.copyWith(
        extendedAnalyticsEnabled: enabled,
      ),
    );

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_extendedAnalyticsKey, enabled);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
