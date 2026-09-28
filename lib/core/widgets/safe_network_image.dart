import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SafeNetworkImage extends StatelessWidget {
  static const int _minCacheDimension = 64;
  static const int _defaultMaxCacheDimension = 3072;

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool gaplessPlayback;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder errorBuilder;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final FilterQuality filterQuality;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.gaplessPlayback = true,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.filterQuality = FilterQuality.medium,
  });

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        (uri.isScheme('http') || uri.isScheme('https'));
  }

  int _maxWidthLimit() {
    return maxWidthDiskCache ?? _defaultMaxCacheDimension;
  }

  int _maxHeightLimit() {
    return maxHeightDiskCache ?? _defaultMaxCacheDimension;
  }

  int? _cacheWidthFromLayout(BuildContext context, double? logicalWidth) {
    if (memCacheWidth != null) return memCacheWidth;

    if (logicalWidth == null || logicalWidth <= 0 || logicalWidth.isInfinite) {
      return _maxWidthLimit();
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final physicalWidth = (logicalWidth * devicePixelRatio).ceil();

    return physicalWidth.clamp(_minCacheDimension, _maxWidthLimit()).toInt();
  }

  int? _cacheHeightFromLayout(BuildContext context, double? logicalHeight) {
    if (memCacheHeight != null) return memCacheHeight;

    if (logicalHeight == null ||
        logicalHeight <= 0 ||
        logicalHeight.isInfinite) {
      return maxHeightDiskCache;
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final physicalHeight = (logicalHeight * devicePixelRatio).ceil();

    return physicalHeight.clamp(_minCacheDimension, _maxHeightLimit()).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();

    if (!_isValidHttpUrl(imageUrl)) {
      return errorBuilder(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth =
            width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);

        final layoutHeight =
            height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : null);

        return CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: imageUrl,
          width: width,
          height: height,
          fit: fit,
          useOldImageOnUrlChange: gaplessPlayback,

          // Memory cache is now calculated using devicePixelRatio.
          // This prevents blurry images on high-density screens.
          memCacheWidth: _cacheWidthFromLayout(context, layoutWidth),
          memCacheHeight: _cacheHeightFromLayout(context, layoutHeight),

          // Disk cache now matches the image upload max size.
          // Previously 1600 was too aggressive for images uploaded up to 3072.
          maxWidthDiskCache: maxWidthDiskCache ?? _defaultMaxCacheDimension,
          maxHeightDiskCache: maxHeightDiskCache,

          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          filterQuality: filterQuality,
          placeholder: (context, _) => placeholderBuilder(context),
          errorWidget: (context, _, _) => errorBuilder(context),
        );
      },
    );
  }
}
