import 'package:dio/dio.dart';

import 'package:homl/data/store/local_store.dart';

/// Reads [path] — a list the server fingerprints, `GET /events` or
/// `GET /categories` — and saves it as [entry] with its `ETag`. When this
/// device saved it with an `ETag`, the request carries it in
/// `If-None-Match`: a `304` means the saved copy is still exactly what the
/// server has, and it is returned instead, with nothing but the answer over
/// the network (homl-web/docs/api.md, "Conditional reads").
///
/// Throws the [DioException] of a failed request, or a bad response one
/// when the body is not a list, for the caller's usual fallback.
Future<List<dynamic>> fetchSaved(Dio dio, String path, StoreEntry entry) async {
  final saved = await LocalStore.instance.load(entry);
  final etag = saved?.payload is List ? saved!.etag : null;

  final response = await dio.get<dynamic>(path,
      options: Options(
        headers: {if (etag != null) 'If-None-Match': etag},
        validateStatus: (status) =>
            status != null &&
            ((status >= 200 && status < 300) || status == 304),
      ));

  if (response.statusCode == 304 && etag != null) {
    return saved!.payload as List<dynamic>;
  }
  final data = response.data;
  if (data is! List) {
    throw DioException.badResponse(
        statusCode: response.statusCode ?? 0,
        requestOptions: response.requestOptions,
        response: response);
  }
  await LocalStore.instance
      .save(entry, data, etag: response.headers.value('etag'));
  return data;
}
