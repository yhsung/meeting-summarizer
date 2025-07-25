import 'package:flutter/material.dart';
import '../../../../core/services/advanced_search_service.dart';
import '../../../../core/models/storage/file_metadata.dart';

/// Widget to display search results with ranking and metadata
class SearchResultsWidget extends StatelessWidget {
  final SearchResult searchResult;
  final Function(FileMetadata)? onFileSelected;
  final Function(SearchQuery)? onSearchChanged;

  const SearchResultsWidget({
    super.key,
    required this.searchResult,
    this.onFileSelected,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!searchResult.hasResults) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Facets and filters
        if (searchResult.facets.categories.isNotEmpty ||
            searchResult.facets.tags.isNotEmpty)
          _buildFacets(context),

        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: searchResult.results.length,
            itemBuilder: (context, index) {
              final result = searchResult.results[index];
              return _buildResultItem(context, result);
            },
          ),
        ),

        // Pagination
        if (searchResult.totalPages > 1) _buildPagination(context),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No files found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria or filters',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFacets(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: const Text('Filter Results'),
        leading: const Icon(Icons.filter_list),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category facets
                if (searchResult.facets.categories.isNotEmpty)
                  _buildFacetSection(
                    'Categories',
                    searchResult.facets.categories,
                  ),

                // Tag facets
                if (searchResult.facets.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildFacetSection('Tags', searchResult.facets.tags),
                ],

                // Size facets
                if (searchResult.facets.sizes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildFacetSection('File Sizes', searchResult.facets.sizes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacetSection(String title, List<FacetItem> facets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: facets.take(10).map((facet) {
            return FilterChip(
              label: Text('${facet.label} (${facet.count})'),
              selected: false, // TODO: Track selected facets
              onSelected: (selected) {
                // TODO: Apply facet filter
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultItem(BuildContext context, RankedFileMetadata result) {
    final metadata = result.metadata;
    final relevancePercent = (result.score / 100 * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildFileIcon(metadata),
        title: Text(
          metadata.fileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata.description != null) ...[
              Text(metadata.description!),
              const SizedBox(height: 4),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      metadata.category.displayName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(metadata.createdAt),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatFileSize(metadata.fileSize),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            if (metadata.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: metadata.tags.take(5).map((tag) {
                  return Chip(
                    label: Text(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: relevancePercent / 100,
              backgroundColor: Colors.grey[300],
              strokeWidth: 3,
            ),
            const SizedBox(height: 4),
            Text(
              '$relevancePercent%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => onFileSelected?.call(metadata),
      ),
    );
  }

  Widget _buildFileIcon(FileMetadata metadata) {
    IconData iconData;
    Color iconColor;

    switch (metadata.extension.toLowerCase()) {
      case '.wav':
      case '.mp3':
      case '.aac':
      case '.m4a':
        iconData = Icons.audiotrack;
        iconColor = Colors.orange;
        break;
      case '.txt':
      case '.md':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.json':
      case '.xml':
        iconData = Icons.code;
        iconColor = Colors.green;
        break;
      case '.zip':
      case '.tar':
      case '.gz':
        iconData = Icons.archive;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  Widget _buildPagination(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
              onPressed: searchResult.hasPreviousPage
                  ? () => _changePage(searchResult.currentPage - 1)
                  : null,
            ),
            Text(
              'Page ${searchResult.currentPage} of ${searchResult.totalPages}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton.icon(
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
              onPressed: searchResult.hasNextPage
                  ? () => _changePage(searchResult.currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _changePage(int newPage) {
    if (onSearchChanged != null) {
      final newQuery = searchResult.query.copyWith(page: newPage);
      onSearchChanged!(newQuery);
    }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
