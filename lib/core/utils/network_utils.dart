Map<String, String> getNetworkImageHeaders(String url) {
  final Map<String, String> headers = {
    'User-Agent': 'WUDI-Mobile-App',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Environment-specific adaptations
  if (url.contains('ngrok-free.app') || url.contains('ngrok.io')) {
    headers['ngrok-skip-browser-warning'] = 'true';
  } else if (!url.contains('localhost') && !url.contains('10.0.2.2')) {
    // Production (Google Cloud) specific headers for better CORS/CDN compatibility
    try {
      final uri = Uri.parse(url);
      headers['Origin'] = '${uri.scheme}://${uri.host}';
      headers['Referer'] = '${uri.scheme}://${uri.host}/';
    } catch (_) {}
  }

  return headers;
}
