import 'package:dio/dio.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/e2ee.dart';

/// Exception thrown when a tags request fails
class TagsRequestFailure implements Exception {}

/// Exception thrown when the created tag payload is empty
class TagsNotFoundFailure implements Exception {}

/// Exception thrown when the tag name is reserved for the date tags (E2EE
/// mode mirror of the backend masterdata blacklist).
class TagsBlacklistedFailure implements Exception {}

class TagsRepository {
  final apiInstance = Api();

  /// Returns the id of the created tag. Pass [idParentTag] to create the tag
  /// as a synonym of an existing main tag of the same category. In E2EE mode
  /// the name is encrypted and its blind index sent alongside; [isDateTag]
  /// lifts the blacklist for the client-managed month/year tags.
  Future<int> createTag(String text, int idCategory,
      {int? idParentTag, bool isDateTag = false}) async {
    late Response<Map<String, dynamic>> response;
    try {
      response =
          await apiInstance.api.post<Map<String, dynamic>>('/tags', data: {
        ...await _outgoingTag(text, isDateTag: isDateTag),
        'idCategory': idCategory,
        if (idParentTag != null) 'idParentTag': idParentTag,
      });

      if (response.data == null) {
        throw TagsNotFoundFailure();
      }
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }

    return response.data!['id'] as int;
  }

  /// Full-state update: omitting [idParentTag] detaches the tag from its
  /// parent (it becomes a main tag again).
  Future<void> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    try {
      await apiInstance.api.patch<void>('/tags/$id', data: {
        ...await _outgoingTag(text),
        'idCategory': idCategory,
        if (idParentTag != null) 'idParentTag': idParentTag,
      });
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }
  }

  /// Builds the tag fields of a write payload. Plaintext name as-is for
  /// regular users; encrypted name + blind index for E2EE users, with the
  /// blacklist enforced client-side (the server cannot read the name).
  Future<Map<String, dynamic>> _outgoingTag(String text,
      {bool isDateTag = false}) async {
    final e2ee = E2ee();
    if (!e2ee.enabled) return {'tag': text};

    if (!isDateTag && e2ee.isBlacklistedTag(text)) {
      throw TagsBlacklistedFailure();
    }

    return {
      'tag': await e2ee.encrypt(text),
      'tagIndex': await e2ee.tagIndex(text),
    };
  }

  /// Deleting a synonym repoints its events to the main tag. Deleting a main
  /// tag deletes its whole synonym group; [deleteEvents] also deletes the
  /// events whose only non-date tags belonged to the group.
  Future<void> deleteTag(int id, {bool deleteEvents = false}) async {
    try {
      await apiInstance.api.delete<void>('/tags/$id', data: {
        'deleteEvents': deleteEvents,
      });
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }
  }

  /// Event counts for the tag's synonym group, for the delete dialog.
  Future<TagUsage> getTagUsage(int id) async {
    try {
      final response =
          await apiInstance.api.get<Map<String, dynamic>>('/tags/$id/usage');
      if (response.data == null) {
        throw TagsNotFoundFailure();
      }
      return TagUsage.fromJson(response.data!);
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }
  }
}
