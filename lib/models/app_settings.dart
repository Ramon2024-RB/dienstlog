class AppSettings {
  const AppSettings({
    this.extendedAnalyticsEnabled = false,
  });

  final bool extendedAnalyticsEnabled;

  AppSettings copyWith({
    bool? extendedAnalyticsEnabled,
  }) {
    return AppSettings(
      extendedAnalyticsEnabled:
          extendedAnalyticsEnabled ?? this.extendedAnalyticsEnabled,
    );
  }
}
