import '../network/api_client.dart';

class ImageUtils {
  static String getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return '';
    
    // If it's already a full URL
    if (avatarPath.startsWith('http')) {
      // Force HTTPS for security and potential server-side blocks
      return avatarPath.replaceAll('http://', 'https://');
    }
    
    // Construct storage URL from API base URL
    // API_URL = https://.../api -> Storage URL = https://.../storage
    final baseStorageUrl = ApiClient.baseUrl.replaceAll('/api', '/storage');
    
    // Ensure clean path concatenation
    final cleanBase = baseStorageUrl.endsWith('/') 
        ? baseStorageUrl.substring(0, baseStorageUrl.length - 1) 
        : baseStorageUrl;
    final cleanPath = avatarPath.startsWith('/') ? avatarPath : '/$avatarPath';
    
    return '$cleanBase$cleanPath';
  }
}
