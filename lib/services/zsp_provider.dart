import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/zsp_location.dart';
import 'app_database.dart';

final zspProvider =
    AsyncNotifierProvider<ZspNotifier, List<ZspLocation>>(
  ZspNotifier.new,
);

class ZspNotifier extends AsyncNotifier<List<ZspLocation>> {
  final AppDatabase _database = AppDatabase.instance;

  @override
  Future<List<ZspLocation>> build() {
    return _database.getZspLocations();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_database.getZspLocations);
  }

  Future<void> addLocation(ZspLocation location) async {
    await _database.insertZspLocation(location);
    state = AsyncData(await _database.getZspLocations());
  }

  Future<void> updateLocation(ZspLocation location) async {
    await _database.updateZspLocation(location);
    state = AsyncData(await _database.getZspLocations());
  }

  Future<void> setDefault(String id) async {
    await _database.setDefaultZsp(id);
    state = AsyncData(await _database.getZspLocations());
  }

  Future<void> setActive(ZspLocation location, bool isActive) async {
    await _database.updateZspLocation(
      location.copyWith(isActive: isActive),
    );
    state = AsyncData(await _database.getZspLocations());
  }
}
