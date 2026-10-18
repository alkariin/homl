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

/// A deletion that also deletes the events cannot wait in the outbox as it
/// is: sent later, the server would delete the events added on another
/// device meanwhile, which this one never showed. The caller deletes the
/// events it knows one by one (each an ordinary deletion, so an event edited
/// elsewhere is kept), then the tag or category alone
/// (homl-web/docs/offline-sync.md).
class DeleteEventsOfflineFailure implements Exception {}

/// The categories as the server last sent them (the saved payload), or
/// empty.
Future<List<Map<String, dynamic>>> _savedCategories() async {
  final stored = await LocalStore.instance.load(StoreEntry.categories);
  final payload = stored?.payload;
  if (payload is! List) return const [];
  return [for (final category in payload) Map<String, dynamic>.from(category)];
}

/// Tag [id] as the server last sent it — name, category, main tag and blind
/// index — for the base of a queued change; null when the server never had
/// it.
Future<Map<String, dynamic>?> serverTag(int id) async {
  for (final category in await _savedCategories()) {
    for (final tag in (category['tags'] as List?) ?? const []) {
      if ((tag as Map)['id'] != id) continue;
      return {
        'tag': tag['tag'],
        'idCategory': category['id'],
        'idParentTag': tag['idParentTag'],
        if (tag['tagIndex'] != null) 'tagIndex': tag['tagIndex'],
      };
    }
  }
  return null;
}

/// Category [id] as the server last sent it: name, color, and the ids of
/// its tags (a tag added elsewhere since is an edit of the category).
Future<Map<String, dynamic>?> serverCategory(int id) async {
  for (final category in await _savedCategories()) {
    if (category['id'] != id) continue;
    return {
      'category': category['category'],
      'color': category['color'],
      'tags': [
        for (final tag in (category['tags'] as List?) ?? const [])
          (tag as Map)['id'],
      ],
    };
  }
  return null;
}

/// Tag group [id] as the server last sent it: name, members, category and
/// blind index.
Future<Map<String, dynamic>?> serverGroup(int id) async {
  for (final category in await _savedCategories()) {
    for (final group in (category['groups'] as List?) ?? const []) {
      if ((group as Map)['id'] != id) continue;
      return {
        'name': group['name'],
        'members': [...(group['members'] as List? ?? const [])],
        'idCategory': category['id'],
        if (group['nameIndex'] != null) 'nameIndex': group['nameIndex'],
      };
    }
  }
  return null;
}
