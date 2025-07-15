import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../models/storage/file_metadata.dart';
import '../models/preview/preview_result.dart';
import '../models/preview/preview_config.dart';
import '../enums/preview_type.dart';
import '../enums/thumbnail_size.dart';
import '../services/preview_service.dart';

/// Modal dialog for previewing files with zoom and navigation capabilities
class FilePreviewModal extends StatefulWidget {
  final FileMetadata fileMetadata;
  final List<FileMetadata>? additionalFiles;
  final PreviewService? previewService;
  final int initialIndex;

  const FilePreviewModal({
    super.key,
    required this.fileMetadata,
    this.additionalFiles,
    this.previewService,
    this.initialIndex = 0,
  });

  @override
  State<FilePreviewModal> createState() => _FilePreviewModalState();
}

class _FilePreviewModalState extends State<FilePreviewModal> {
  late PageController _pageController;
  late int _currentIndex;
  List<FileMetadata> _allFiles = [];
  final Map<String, PreviewResult> _previewCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _allFiles = [widget.fileMetadata];
    if (widget.additionalFiles != null) {
      _allFiles.addAll(widget.additionalFiles!);
    }
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrentPreview();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPreview() async {
    if (widget.previewService == null) return;

    final currentFile = _allFiles[_currentIndex];
    if (_previewCache.containsKey(currentFile.id)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final previewType = widget.previewService!.getPreviewType(currentFile);
      final config = PreviewConfig(
        type: previewType,
        thumbnailSize: ThumbnailSize.extraLarge,
        enableCache: true,
      );

      final result = await widget.previewService!.generatePreview(
        currentFile,
        config,
      );

      setState(() {
        _previewCache[currentFile.id] = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadCurrentPreview();
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = _allFiles[_currentIndex];

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentFile.fileName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              if (_allFiles.length > 1)
                Text(
                  '${_currentIndex + 1} of ${_allFiles.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showFileInfo(context, currentFile),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_allFiles.length == 1)
              _buildSingleFilePreview(currentFile)
            else
              _buildGalleryPreview(),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
        bottomNavigationBar: _allFiles.length > 1
            ? _buildNavigationBar()
            : null,
      ),
    );
  }

  Widget _buildSingleFilePreview(FileMetadata file) {
    final previewType =
        widget.previewService?.getPreviewType(file) ?? PreviewType.unsupported;

    switch (previewType) {
      case PreviewType.image:
        return _buildImagePreview(file);
      case PreviewType.video:
        return _buildVideoPreview(file);
      case PreviewType.pdf:
        return _buildPdfPreview(file);
      case PreviewType.text:
        return _buildTextPreview(file);
      case PreviewType.audio:
        return _buildAudioPreview(file);
      default:
        return _buildUnsupportedPreview(file);
    }
  }

  Widget _buildGalleryPreview() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: _allFiles.length,
      onPageChanged: _onPageChanged,
      builder: (context, index) {
        final file = _allFiles[index];
        return PhotoViewGalleryPageOptions.customChild(
          child: _buildSingleFilePreview(file),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained * 0.5,
          maxScale: PhotoViewComputedScale.covered * 2.0,
        );
      },
    );
  }

  Widget _buildImagePreview(FileMetadata file) {
    final previewResult = _previewCache[file.id];

    if (previewResult?.success == true &&
        previewResult?.thumbnailData != null) {
      return PhotoView(
        imageProvider: MemoryImage(previewResult!.thumbnailData!),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 0.5,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        heroAttributes: PhotoViewHeroAttributes(tag: file.id),
      );
    }

    // Fallback to original file if preview not available
    return PhotoView.customChild(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Image Preview',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              file.fileName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview(FileMetadata file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Video Preview',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement video playback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video playback not yet implemented'),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Video'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(FileMetadata file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'PDF Document',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement PDF viewer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF viewer not yet implemented')),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(FileMetadata file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Text File',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement text viewer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Text viewer not yet implemented'),
                ),
              );
            },
            icon: const Icon(Icons.text_snippet),
            label: const Text('View Text'),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview(FileMetadata file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audiotrack_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Audio File',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement audio player
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audio player not yet implemented'),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Audio'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedPreview(FileMetadata file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.help_outline,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Unsupported Format',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This file type cannot be previewed',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.navigate_before, color: Colors.white),
          ),
          Text(
            '${_currentIndex + 1} / ${_allFiles.length}',
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            onPressed: _currentIndex < _allFiles.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.navigate_next, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showFileInfo(BuildContext context, FileMetadata file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', file.fileName),
            _buildInfoRow('Size', _formatFileSize(file.fileSize)),
            _buildInfoRow('Created', _formatDate(file.createdAt)),
            _buildInfoRow('Modified', _formatDate(file.modifiedAt)),
            _buildInfoRow('Category', file.category.displayName),
            if (file.description?.isNotEmpty == true)
              _buildInfoRow('Description', file.description!),
            if (file.tags.isNotEmpty)
              _buildInfoRow('Tags', file.tags.join(', ')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Convenience function to show file preview modal
void showFilePreview(
  BuildContext context,
  FileMetadata fileMetadata, {
  List<FileMetadata>? additionalFiles,
  PreviewService? previewService,
  int initialIndex = 0,
}) {
  showDialog(
    context: context,
    useSafeArea: false,
    builder: (context) => FilePreviewModal(
      fileMetadata: fileMetadata,
      additionalFiles: additionalFiles,
      previewService: previewService,
      initialIndex: initialIndex,
    ),
  );
}
