# Database Migration System

This document describes the database migration system implemented for the Meeting Summarizer application.

## Overview

The migration system provides a robust, data-preserving way to upgrade database schemas while maintaining backward compatibility and data integrity.

## Key Components

### DatabaseMigrations Class
- **Purpose**: Manages schema migrations between database versions
- **Features**: 
  - Sequential migration execution
  - Data preservation during upgrades
  - Validation and rollback capabilities
  - Backup creation before migrations

### DatabaseHelper Integration
- **Enhanced _onUpgrade**: Uses migration system instead of drop-and-recreate
- **Version Management**: Tracks database versions and compatibility
- **Utility Methods**: Migration status checking and database recreation

## Migration Process

### 1. Version Compatibility Check
```dart
if (oldVersion < DatabaseSchema.minSupportedVersion) {
  throw Exception('Database version too old');
}
```

### 2. Backup Creation
```dart
final backupPath = await DatabaseMigrations.createBackup(db);
```

### 3. Sequential Migration Execution
```dart
for (int version = oldVersion + 1; version <= newVersion; version++) {
  await _executeVersionMigration(db, version);
}
```

### 4. Migration Validation
```dart
final isValid = await DatabaseMigrations.validateMigration(db, newVersion);
```

### 5. Rollback on Failure
```dart
if (!isValid) {
  await DatabaseMigrations.restoreFromBackup(db.path, backupPath);
}
```

## Supported Migrations

### Version 2: Encryption Support
- Adds encryption fields to recordings and transcriptions tables
- Introduces encryption settings
- Creates indexes for encrypted data lookups

### Version 3: Collaboration Features
- Adds sharing capabilities to recordings
- Creates shares table for managing access tokens
- Introduces collaboration fields for summaries

### Version 4: Advanced Analytics
- Adds usage tracking to all major entities
- Creates analytics events and user sessions tables
- Introduces performance monitoring fields

## Database Schema Versioning

### Version Constants
```dart
static const int databaseVersion = 1;        // Current version
static const int minSupportedVersion = 1;    // Minimum supported
static const int maxSupportedVersion = 4;    // Maximum supported
```

### Version Progression
1. **Version 1**: Base schema (recordings, transcriptions, summaries, settings)
2. **Version 2**: Encryption support
3. **Version 3**: Collaboration features  
4. **Version 4**: Advanced analytics

## Migration Safety Features

### Data Preservation
- All migrations use `ALTER TABLE` statements where possible
- Existing data is preserved during schema changes
- Foreign key relationships are maintained

### Validation System
- Table structure validation
- Data integrity checks
- Foreign key constraint verification
- Settings data validation

### Error Handling
- Automatic backup creation before migrations
- Rollback capability on failure
- Comprehensive error logging
- Graceful degradation strategies

## Usage Examples

### Check Migration Status
```dart
final dbHelper = DatabaseHelper();
final migrationInfo = await dbHelper.getMigrationInfo();

if (migrationInfo['needsMigration']) {
  // Handle migration requirement
}
```

### Force Database Recreation
```dart
// Emergency fallback for corrupted databases
await dbHelper.recreateDatabase();
```

### Manual Migration Validation
```dart
final isValid = await DatabaseMigrations.validateMigration(db, targetVersion);
```

## Testing

### Migration Tests
- Sequential migration testing (1→2→3→4)
- Data preservation validation
- Rollback scenario testing
- Error condition handling

### Integration Tests
- DatabaseHelper migration integration
- Version compatibility testing
- Concurrent operation safety
- Performance impact assessment

## Best Practices

### Adding New Migrations
1. Increment `maxSupportedVersion` in DatabaseSchema
2. Add migration case in `_executeVersionMigration`
3. Create comprehensive tests for the new migration
4. Update documentation

### Migration Script Guidelines
- Use transactions for atomic operations
- Preserve existing data whenever possible
- Add proper indexes for new columns
- Include rollback strategy documentation

### Error Recovery
- Always create backups before migrations
- Implement validation checks after migrations
- Provide clear error messages for failures
- Consider graceful degradation for non-critical features

## Performance Considerations

### Migration Timing
- Migrations run during app startup
- Large datasets may require progress indicators
- Consider background migration strategies for heavy operations

### Index Management
- Create indexes after data migration
- Drop unused indexes during cleanup
- Monitor query performance post-migration

### Storage Optimization
- Run VACUUM after major migrations
- Consider data archival for large datasets
- Monitor storage usage growth

## Security Considerations

### Sensitive Data
- Encryption migrations handle existing plaintext data
- Secure key management during transitions
- Audit trail for sensitive operations

### Access Control
- Share token migrations preserve security
- Permission validation during collaboration migrations
- Authentication state preservation

## Troubleshooting

### Common Issues
1. **Migration Timeout**: Large datasets may need extended timeouts
2. **Constraint Violations**: Check foreign key relationships
3. **Storage Space**: Ensure adequate space for backups
4. **Version Conflicts**: Validate version compatibility before migration

### Recovery Procedures
1. Check backup availability
2. Validate database integrity
3. Consider incremental recovery
4. Fallback to database recreation if necessary

## Future Enhancements

### Planned Features
- Incremental backup strategies
- Background migration processing
- Migration progress tracking
- Advanced rollback capabilities

### Performance Optimizations
- Parallel migration execution for independent operations
- Streaming migration for large datasets
- Compression for backup storage
- Delta migration strategies