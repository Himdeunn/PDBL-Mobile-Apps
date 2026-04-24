import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for all network images in the app.
/// Limits: 100 objects, 7-day TTL — keeps disk usage under ~50MB in typical use.
class WudiCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'wudi_image_cache';

  static final WudiCacheManager _instance = WudiCacheManager._();
  factory WudiCacheManager() => _instance;

  WudiCacheManager._()
      : super(Config(
          _key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
        ));
}
