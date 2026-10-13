import 'package:homl/data/store/local_store.dart';
import 'package:homl/helpers/e2ee.dart';

/// What happened to a write.
enum WriteOutcome {
  /// The server has it.
  sent,

  /// Saved on this device, in the outbox: it is sent once the server is back
  /// (data/sync/sync_engine.dart).
  queued,
}

/// The state a queued write is encoded for: the account's encryption (its
/// E2EE key check, null for a plain account) and the server data generation.
/// The engine refuses to send an op whose stamps no longer match the server.
Future<({String? keyCheck, String? generation})> writeStamps() async {
  final e2ee = E2ee();
  final keyCheck = e2ee.enabled ? await e2ee.keyCheck() : null;
  final settings = await LocalStore.instance.load(StoreEntry.settings);
  final payload = settings?.payload;
  final generation =
      payload is Map ? payload['dataGeneration'] as String? : null;
  return (keyCheck: keyCheck, generation: generation);
}
