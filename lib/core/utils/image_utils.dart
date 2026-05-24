import '../network/api_client.dart';

class ImageUtils {
  static String getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return '';

    // If it's already a full URL, just ensure security
    if (avatarPath.startsWith('http')) {
      return avatarPath.replaceFirst('http://', 'https://');
    }

    // Construct storage URL intelligently
    String apiBase = ApiClient.baseUrl;

    // Remove trailing slash for consistent manipulation
    if (apiBase.endsWith('/')) {
      apiBase = apiBase.substring(0, apiBase.length - 1);
    }

    // Replace /api with /storage at the end of the URL
    final String storageBase = apiBase.endsWith('/api')
        ? apiBase.substring(0, apiBase.length - 4) + '/storage'
        : apiBase + '/storage';

    final String cleanPath = avatarPath.startsWith('/')
        ? avatarPath
        : '/$avatarPath';

    return '$storageBase$cleanPath';
  }
}
