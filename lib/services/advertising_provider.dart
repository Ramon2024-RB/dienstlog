import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/advertising.dart';
import 'app_database.dart';

final advertisingProvider =
    AsyncNotifierProvider<AdvertisingNotifier, List<Advertising>>(
  AdvertisingNotifier.new,
);

class AdvertisingNotifier extends AsyncNotifier<List<Advertising>> {
  @override
  Future<List<Advertising>> build() {
    return AppDatabase.instance.getAdvertisings();
  }

  Future<void> addAdvertising(Advertising advertising) async {
    await AppDatabase.instance.insertAdvertising(advertising);
    state = AsyncData(await AppDatabase.instance.getAdvertisings());
  }

  Future<void> updateAdvertising(Advertising advertising) async {
    await AppDatabase.instance.updateAdvertising(advertising);
    state = AsyncData(await AppDatabase.instance.getAdvertisings());
  }

  Future<void> deleteAdvertising(String id) async {
    await AppDatabase.instance.deleteAdvertising(id);
    state = AsyncData(await AppDatabase.instance.getAdvertisings());
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      AppDatabase.instance.getAdvertisings,
    );
  }
}
