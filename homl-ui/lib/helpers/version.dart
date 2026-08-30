/// Where the backend's `/healthz` lives, derived from the API base URL.
///
/// The Go router mounts `/healthz` at the server root and the API under
/// `HOML_API_URL` (`/api` by default), so `https://host/api` → `https://host/healthz`
/// and a proxy sub-path is kept: `https://host/homl/api` → `https://host/homl/healthz`.
/// A base URL without the `/api` suffix just gets `/healthz` appended.
String healthzUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.endsWith('/api')) {
    path = path.substring(0, path.length - '/api'.length);
  }
  return uri
      .replace(path: '$path/healthz', query: null, fragment: null)
      .toString();
}
