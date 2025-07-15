import 'package:flutter/material.dart';
import 'package:file_icon/file_icon.dart';

import '../models/storage/file_metadata.dart';
import '../models/preview/preview_result.dart';
import '../models/preview/preview_config.dart';
import '../enums/preview_type.dart';
import '../enums/thumbnail_size.dart';
import '../services/preview_service.dart';

/// Widget for displaying file thumbnails with loading states and fallbacks
class ThumbnailWidget extends StatefulWidget {
  final FileMetadata fileMetadata;
  final ThumbnailSize size;
  final PreviewService? previewService;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showOverlay;
  final Widget? overlayWidget;

  const ThumbnailWidget({
    super.key,
    required this.fileMetadata,
    this.size = ThumbnailSize.medium,
    this.previewService,
    this.onTap,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showOverlay = false,
    this.overlayWidget,
  });

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  PreviewResult? _previewResult;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileMetadata.id != widget.fileMetadata.id ||
        oldWidget.size != widget.size) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (widget.previewService == null) {
      setState(() {
        _errorMessage = 'Preview service not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _previewResult = null;
    });

    try {
      // Check cache first
      final cached = await widget.previewService!.getCachedPreview(
        widget.fileMetadata.id,
        widget.size,
      );

      if (cached != null && cached.success) {
        setState(() {
          _previewResult = cached;
          _isLoading = false;
        });
        return;
      }

      // Generate new thumbnail if not cached
      final previewType = widget.previewService!.getPreviewType(
        widget.fileMetadata,
      );
      if (previewType == PreviewType.unsupported) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unsupported file type';
        });
        return;
      }

      final config = PreviewConfig(
        type: previewType,
        thumbnailSize: widget.size,
        enableCache: true,
      );

      final result = await widget.previewService!.generatePreview(
        widget.fileMetadata,
        config,
      );

      setState(() {
        _previewResult = result;
        _isLoading = false;
        if (!result.success) {
          _errorMessage = result.errorMessage;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load thumbnail: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimension = widget.size.size.toDouble();
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnailContent(context),
              if (widget.showOverlay || widget.overlayWidget != null)
                _buildOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null || _previewResult?.success == false) {
      return _buildErrorState(context);
    }

    if (_previewResult != null && _previewResult!.success) {
      return _buildThumbnailImage(context);
    }

    return _buildFallbackIcon(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
      child: Center(
        child: SizedBox(
          width: widget.size.size * 0.3,
          height: widget.size.size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.errorContainer.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: widget.size.size * 0.3,
            color: theme.colorScheme.error,
          ),
          if (widget.size.size >= 128) ...[
            const SizedBox(height: 4),
            Text(
              'Error',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(BuildContext context) {
    if (_previewResult!.thumbnailData != null) {
      return Image.memory(
        _previewResult!.thumbnailData!,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorState(context),
      );
    }

    if (_previewResult!.thumbnailPath != null) {
      return Image.asset(
        _previewResult!.thumbnailPath!,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorState(context),
      );
    }

    return _buildFallbackIcon(context);
  }

  Widget _buildFallbackIcon(BuildContext context) {
    final theme = Theme.of(context);
    final extension = widget.fileMetadata.fileName
        .split('.')
        .last
        .toLowerCase();

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FileIcon(extension, size: widget.size.size * 0.5),
          if (widget.size.size >= 128) ...[
            const SizedBox(height: 8),
            Text(
              extension.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.overlayWidget != null) {
      return widget.overlayWidget!;
    }

    if (!widget.showOverlay) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          stops: const [0.6, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.size.size >= 128) ...[
                Text(
                  widget.fileMetadata.fileName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                _formatFileSize(widget.fileMetadata.fileSize),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Grid widget for displaying multiple thumbnails
class ThumbnailGrid extends StatelessWidget {
  final List<FileMetadata> files;
  final ThumbnailSize thumbnailSize;
  final PreviewService? previewService;
  final Function(FileMetadata)? onThumbnailTap;
  final int crossAxisCount;
  final double spacing;
  final bool showOverlay;

  const ThumbnailGrid({
    super.key,
    required this.files,
    this.thumbnailSize = ThumbnailSize.medium,
    this.previewService,
    this.onThumbnailTap,
    this.crossAxisCount = 3,
    this.spacing = 8.0,
    this.showOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ThumbnailWidget(
          fileMetadata: file,
          size: thumbnailSize,
          previewService: previewService,
          showOverlay: showOverlay,
          onTap: () => onThumbnailTap?.call(file),
        );
      },
    );
  }
}

/// List widget for displaying thumbnails in a list format
class ThumbnailList extends StatelessWidget {
  final List<FileMetadata> files;
  final ThumbnailSize thumbnailSize;
  final PreviewService? previewService;
  final Function(FileMetadata)? onThumbnailTap;
  final double spacing;

  const ThumbnailList({
    super.key,
    required this.files,
    this.thumbnailSize = ThumbnailSize.small,
    this.previewService,
    this.onThumbnailTap,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          leading: ThumbnailWidget(
            fileMetadata: file,
            size: thumbnailSize,
            previewService: previewService,
            onTap: () => onThumbnailTap?.call(file),
          ),
          title: Text(file.fileName, style: theme.textTheme.bodyMedium),
          subtitle: Text(
            '${_formatFileSize(file.fileSize)} • ${_formatDate(file.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => onThumbnailTap?.call(file),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
