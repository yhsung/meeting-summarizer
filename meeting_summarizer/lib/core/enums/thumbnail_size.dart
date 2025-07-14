import 'dart:ui';

/// Thumbnail size definitions for different use cases
enum ThumbnailSize {
  /// Small thumbnails for list views (64x64)
  small(64, 'Small', 'Compact thumbnails for list views'),

  /// Medium thumbnails for grid views (128x128)
  medium(128, 'Medium', 'Standard thumbnails for grid views'),

  /// Large thumbnails for detailed views (256x256)
  large(256, 'Large', 'High-quality thumbnails for detailed views'),

  /// Extra large thumbnails for preview cards (512x512)
  extraLarge(
    512,
    'Extra Large',
    'Maximum quality thumbnails for preview cards',
  );

  const ThumbnailSize(this.size, this.displayName, this.description);

  /// Size in pixels (square)
  final int size;

  /// User-friendly display name
  final String displayName;

  /// Description of the thumbnail size
  final String description;

  /// Get the size as a Size object for easier use with Flutter widgets
  Size get sizeObject => Size(size.toDouble(), size.toDouble());

  /// Get thumbnail size from integer value
  static ThumbnailSize fromSize(int size) {
    if (size <= 64) return ThumbnailSize.small;
    if (size <= 128) return ThumbnailSize.medium;
    if (size <= 256) return ThumbnailSize.large;
    return ThumbnailSize.extraLarge;
  }

  /// Get appropriate thumbnail size for a given context
  static ThumbnailSize forContext(String context) {
    switch (context.toLowerCase()) {
      case 'list':
      case 'compact':
        return ThumbnailSize.small;
      case 'grid':
      case 'gallery':
        return ThumbnailSize.medium;
      case 'detail':
      case 'card':
        return ThumbnailSize.large;
      case 'preview':
      case 'modal':
        return ThumbnailSize.extraLarge;
      default:
        return ThumbnailSize.medium;
    }
  }

  /// Calculate file size multiplier based on thumbnail size
  /// Used for cache management and storage estimation
  double get sizeMultiplier {
    switch (this) {
      case ThumbnailSize.small:
        return 0.25;
      case ThumbnailSize.medium:
        return 1.0;
      case ThumbnailSize.large:
        return 4.0;
      case ThumbnailSize.extraLarge:
        return 16.0;
    }
  }
}
