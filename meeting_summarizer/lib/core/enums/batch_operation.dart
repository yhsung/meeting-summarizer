/// Batch operation types for file management
enum BatchOperation {
  /// Rename multiple files with pattern support
  rename('rename', 'Rename Files', 'Bulk rename files using patterns'),

  /// Move files to different directories
  move('move', 'Move Files', 'Move files to different locations'),

  /// Delete multiple files
  delete('delete', 'Delete Files', 'Delete multiple files with confirmation'),

  /// Copy files to different locations
  copy('copy', 'Copy Files', 'Create copies of files in different locations'),

  /// Convert file formats
  convert(
    'convert',
    'Convert Format',
    'Convert files between different formats',
  ),

  /// Archive files into compressed packages
  archive('archive', 'Archive Files', 'Create compressed archives from files'),

  /// Extract files from archives
  extract('extract', 'Extract Files', 'Extract files from archive packages'),

  /// Update file metadata
  updateMetadata(
    'updateMetadata',
    'Update Metadata',
    'Update file metadata and tags',
  ),

  /// Tag multiple files
  tag('tag', 'Tag Files', 'Add or remove tags from multiple files'),

  /// Categorize files
  categorize(
    'categorize',
    'Categorize Files',
    'Change file categories for organization',
  );

  const BatchOperation(this.value, this.displayName, this.description);

  /// Internal operation identifier
  final String value;

  /// User-friendly display name
  final String displayName;

  /// Description of the operation
  final String description;

  /// Operations that modify file content
  static List<BatchOperation> get contentModifyingOperations => [
    convert,
    archive,
    extract,
  ];

  /// Operations that modify file location
  static List<BatchOperation> get locationModifyingOperations => [move, copy];

  /// Operations that modify file metadata
  static List<BatchOperation> get metadataModifyingOperations => [
    rename,
    updateMetadata,
    tag,
    categorize,
  ];

  /// Operations that are destructive and need confirmation
  static List<BatchOperation> get destructiveOperations => [delete];

  /// Operations that can be undone
  static List<BatchOperation> get undoableOperations => [
    rename,
    move,
    copy,
    updateMetadata,
    tag,
    categorize,
  ];

  /// Check if this operation is content-modifying
  bool get modifiesContent => contentModifyingOperations.contains(this);

  /// Check if this operation is location-modifying
  bool get modifiesLocation => locationModifyingOperations.contains(this);

  /// Check if this operation is metadata-modifying
  bool get modifiesMetadata => metadataModifyingOperations.contains(this);

  /// Check if this operation is destructive
  bool get isDestructive => destructiveOperations.contains(this);

  /// Check if this operation can be undone
  bool get isUndoable => undoableOperations.contains(this);

  /// Get operation from string value
  static BatchOperation fromString(String value) {
    return BatchOperation.values.firstWhere(
      (op) => op.value == value,
      orElse: () => throw ArgumentError('Unknown batch operation: $value'),
    );
  }
}
