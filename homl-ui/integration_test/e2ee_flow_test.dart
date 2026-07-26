// True end-to-end test of the E2EE lifecycle: the REAL client stack (E2ee
// manager on the native crypto plugin, repositories, secure storage) against
// a RUNNING backend. This is the automated version of the manual walkthrough
// that caught the native-HKDF and stale-codegen bugs unit tests cannot see.
//
// Not part of `flutter test` (integration_test/ is only run explicitly) and
// it needs a device plus a live stack:
//
//   cd homl-web && make db-up && make migrateup && make local   # or make dev
//   cd homl-ui && ./run-e2e-test.sh                             # see script
//
// The developer's local session and E2EE key are saved and restored around
// the run, so executing this on your daily dev phone is safe.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/e2ee.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart' show TagView;
import 'package:homl/pages/insert/bloc/insert_cubit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full E2EE lifecycle against a live backend', (tester) async {
    // ------------------------------------------------------------------
    // Preserve the developer's local state: the test shares the app's
    // secure storage, so whatever it touches is put back afterwards.
    // ------------------------------------------------------------------
    final savedRefreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    final savedMasterKey =
        await LocalStorageManager.getValue(LocalStorageKey.e2eeMasterKey);
    addTearDown(() async {
      E2ee().lock();
      await LocalStorageManager.clearDataCaches();
      if (savedRefreshToken != null) {
        await LocalStorageManager.setValue(
            LocalStorageKey.refreshToken, savedRefreshToken);
      } else {
        await LocalStorageManager.remove(LocalStorageKey.refreshToken);
      }
      if (savedMasterKey != null) {
        await LocalStorageManager.setValue(
            LocalStorageKey.e2eeMasterKey, savedMasterKey);
      } else {
        await LocalStorageManager.remove(LocalStorageKey.e2eeMasterKey);
      }
    });

    await LocalStorageManager.remove(LocalStorageKey.refreshToken);
    await LocalStorageManager.remove(LocalStorageKey.e2eeMasterKey);
    await LocalStorageManager.clearDataCaches();
    E2ee().lock();

    final api = Api();
    final users = UsersRepository();
    final categoriesRepo = CategoriesRepository();
    final eventsRepo = EventsRepository();
    final tagsRepo = TagsRepository();
    final settingsRepo = SettingsRepository();
    final e2eeRepo = E2eeRepository();
    final e2ee = E2ee();

    Category dateCategoryOf(List<Category> categories) =>
        categories.firstWhere((c) => c.kind == CategoryKind.date);

    // ------------------------------------------------------------------
    // Throwaway account with one plaintext event, like a pre-E2EE user.
    // ------------------------------------------------------------------
    final username =
        'e2ee-it-${DateTime.now().microsecondsSinceEpoch}@homl.local';
    await users.register(username, 'Secret123', Language.en);

    var categories = await categoriesRepo.getCategories();
    final otherId =
        categories.firstWhere((c) => c.kind == CategoryKind.other).id;
    final cinemaId = await tagsRepo.createTag('Cinema', otherId);
    await eventsRepo.createEvent(
        description: 'Watched a film',
        date: DateTime.utc(2026, 7, 19),
        tagsId: [cinemaId]);

    // ------------------------------------------------------------------
    // Enable E2EE: real key on the native crypto, real atomic migration.
    // ------------------------------------------------------------------
    final mnemonic = await e2ee.prepareEnable();
    expect(mnemonic.split(' ').length, 12);
    await e2eeRepo.enable();
    await e2ee.commitEnable();
    expect(e2ee.enabled, isTrue);

    final settings = await settingsRepo.getSettings();
    expect(settings!.isE2eeEnabled, isTrue);
    expect(settings.e2eeKeyCheck, await e2ee.keyCheck());

    // The server now stores opaque blobs...
    final rawEvents = await api.api.get<List<dynamic>>('/events');
    final rawDescription =
        (rawEvents.data!.single as Map<String, dynamic>)['description']
            as String;
    expect(rawDescription.startsWith(E2ee.prefix), isTrue,
        reason: 'the server must only ever see ciphertext');

    // ...while the repositories hand the app decrypted models.
    var events = await eventsRepo.getEvents();
    expect(events.single.description, 'Watched a film');
    expect(events.single.tags.map((t) => t.tag), contains('Cinema'));

    // The offline cache must hold the ciphertext, never the plaintext.
    final cachedRaw =
        await LocalStorageManager.getValue(LocalStorageKey.eventsCache);
    expect(cachedRaw, contains(E2ee.prefix));
    expect(cachedRaw, isNot(contains('Watched a film')));

    // ------------------------------------------------------------------
    // Writing under E2EE through the real form cubit: new tag encrypted
    // with its blind index, date tags built client-side.
    // ------------------------------------------------------------------
    categories = await categoriesRepo.getCategories();
    final insertCubit = InsertCubit(eventsRepo, tagsRepo);
    insertCubit.addTag('Sunset');
    insertCubit.updateDate(DateTime.utc(2026, 7, 19));
    insertCubit.updateDescription('Golden hour');
    await insertCubit.submitEvent(categories, <String, TagView>{});
    expect(insertCubit.state.status, InsertStatus.success);
    await insertCubit.close();

    // The month/year tags exist in the date category, readable by the client.
    categories = await categoriesRepo.getCategories();
    final dateTagNames = dateCategoryOf(categories).tags.map((t) => t.tag);
    expect(dateTagNames, containsAll(['July', '2026']));

    events = await eventsRepo.getEvents();
    final golden = events.firstWhere((e) => e.description == 'Golden hour');
    expect(golden.tags.map((t) => t.tag), containsAll(['Sunset', 'July', '2026']));

    // Server-side search by blind index matches exactly the tagged event.
    final searched = await api.api.get<List<dynamic>>('/events',
        queryParameters: {'tags': await e2ee.tagIndex('Sunset')});
    expect(searched.data!.length, 1);

    // ------------------------------------------------------------------
    // Lost device: no key -> blocked; the recovery phrase restores it.
    // ------------------------------------------------------------------
    final keyCheck = settings.e2eeKeyCheck;
    e2ee.lock();
    await LocalStorageManager.remove(LocalStorageKey.e2eeMasterKey);

    final relocked = await settingsRepo.getSettings();
    expect(await e2ee.unlock(relocked), isFalse,
        reason: 'an E2EE account without a key must be blocked');

    expect(await e2ee.restore(mnemonic, keyCheck), E2eeRestoreResult.ok);
    events = await eventsRepo.getEvents();
    expect(events.map((e) => e.description), contains('Golden hour'));

    // ------------------------------------------------------------------
    // Disable: plaintext round trip, server reads again, index cleared.
    // ------------------------------------------------------------------
    await e2eeRepo.disable();
    await e2ee.disable();
    expect(e2ee.enabled, isFalse);

    final finalSettings = await settingsRepo.getSettings();
    expect(finalSettings!.isE2eeEnabled, isFalse);

    final plainEvents = await api.api.get<List<dynamic>>('/events');
    final descriptions = plainEvents.data!
        .map((e) => (e as Map<String, dynamic>)['description'] as String);
    expect(descriptions, containsAll(['Watched a film', 'Golden hour']),
        reason: 'after disable the server serves readable plaintext again');

    await users.logout();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
