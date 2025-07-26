import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/services/offline_queue_service.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_operation.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';

void main() {
  group('OfflineQueueService', () {
    late OfflineQueueService service;
    late Directory temporaryDirectory;

    setUpAll(() async {
      // Initialize FFI for SQLite in tests
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Mock PathProvider for tests
      TestWidgetsFlutterBinding.ensureInitialized();
      temporaryDirectory = await Directory.systemTemp.createTemp();

      const MethodChannel channel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return temporaryDirectory.path;
        }
        return null;
      });
    });

    tearDownAll(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    setUp(() async {
      service = OfflineQueueService.instance;
      await service.initialize();
    });

    tearDown(() async {
      await service.clearQueue();
      await service.dispose();
      await OfflineQueueService.resetInstance();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Service should be initialized in setUp
        expect(service, isNotNull);
      });

      test('should handle multiple initializations', () async {
        // Should not throw when initialized multiple times
        await service.initialize();
        await service.initialize();
      });
    });

    group('Queue Operations', () {
      late SyncOperation testOperation;

      setUp(() {
        testOperation = SyncOperation(
          id: 'test_op_1',
          type: SyncOperationType.upload,
          localFilePath: '/test/file.txt',
          remoteFilePath: '/remote/file.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
          priority: 1,
        );
      });

      test('should enqueue operation successfully', () async {
        final result = await service.enqueueOperation(
          operation: testOperation,
          priority: 2,
        );

        expect(result, isTrue);

        final pendingOps = await service.getPendingOperations();
        expect(pendingOps.length, equals(1));
        expect(pendingOps.first.id, equals('test_op_1'));
        expect(pendingOps.first.priority, equals(2));
      });

      test('should dequeue operation successfully', () async {
        await service.enqueueOperation(operation: testOperation);

        final result = await service.dequeueOperation('test_op_1');
        expect(result, isTrue);

        final pendingOps = await service.getPendingOperations();
        expect(pendingOps.length, equals(0));
      });

      test(
        'should return false when dequeuing non-existent operation',
        () async {
          final result = await service.dequeueOperation('non_existent_id');
          expect(result, isFalse);
        },
      );

      test('should get operations by status', () async {
        await service.enqueueOperation(operation: testOperation);

        // Update status to processing
        await service.updateOperationStatus(
          operationId: 'test_op_1',
          status: QueueOperationStatus.processing,
        );

        final processingOps = await service.getOperationsByStatus(
          QueueOperationStatus.processing,
        );
        expect(processingOps.length, equals(1));
        expect(
          processingOps.first.status,
          equals(QueueOperationStatus.processing),
        );

        final pendingOps = await service.getOperationsByStatus(
          QueueOperationStatus.pending,
        );
        expect(pendingOps.length, equals(0));
      });

      test('should update operation status and retry count', () async {
        await service.enqueueOperation(operation: testOperation);

        await service.updateOperationStatus(
          operationId: 'test_op_1',
          status: QueueOperationStatus.failed,
          errorMessage: 'Test error',
          incrementRetry: true,
        );

        final operations = await service.getOperationsByStatus(
          QueueOperationStatus.failed,
        );
        expect(operations.length, equals(1));
        expect(operations.first.retryCount, equals(1));
        expect(operations.first.errorMessage, equals('Test error'));
      });
    });

    group('Priority Management', () {
      test('should order operations by priority', () async {
        // Create operations with different priorities
        final lowPriorityOp = SyncOperation(
          id: 'low_priority',
          type: SyncOperationType.upload,
          localFilePath: '/test/low.txt',
          remoteFilePath: '/remote/low.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        final highPriorityOp = SyncOperation(
          id: 'high_priority',
          type: SyncOperationType.upload,
          localFilePath: '/test/high.txt',
          remoteFilePath: '/remote/high.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        // Enqueue in reverse priority order
        await service.enqueueOperation(operation: lowPriorityOp, priority: 0);
        await service.enqueueOperation(operation: highPriorityOp, priority: 3);

        final operations = await service.getPendingOperationsByPriorityOrder();
        expect(operations.length, equals(2));

        // High priority should come first
        expect(operations.first.id, equals('high_priority'));
        expect(operations.first.priority, equals(3));
        expect(operations.last.id, equals('low_priority'));
        expect(operations.last.priority, equals(0));
      });

      test('should get operations by priority level', () async {
        final op1 = SyncOperation(
          id: 'op1',
          type: SyncOperationType.upload,
          localFilePath: '/test/1.txt',
          remoteFilePath: '/remote/1.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        final op2 = SyncOperation(
          id: 'op2',
          type: SyncOperationType.upload,
          localFilePath: '/test/2.txt',
          remoteFilePath: '/remote/2.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        await service.enqueueOperation(operation: op1, priority: 2);
        await service.enqueueOperation(operation: op2, priority: 1);

        final highPriorityOps = await service.getOperationsByPriority(2);
        expect(highPriorityOps.length, equals(1));
        expect(highPriorityOps.first.id, equals('op1'));

        final normalPriorityOps = await service.getOperationsByPriority(1);
        expect(normalPriorityOps.length, equals(1));
        expect(normalPriorityOps.first.id, equals('op2'));
      });

      test('should get high priority operations', () async {
        final operations = [
          ('low_op', 0),
          ('normal_op', 1),
          ('high_op', 2),
          ('critical_op', 3),
        ];

        for (final (id, priority) in operations) {
          final op = SyncOperation(
            id: id,
            type: SyncOperationType.upload,
            localFilePath: '/test/$id.txt',
            remoteFilePath: '/remote/$id.txt',
            provider: CloudProvider.googleDrive,
            status: SyncOperationStatus.queued,
            createdAt: DateTime.now(),
          );
          await service.enqueueOperation(operation: op, priority: priority);
        }

        final highPriorityOps = await service.getHighPriorityOperations();
        expect(highPriorityOps.length, equals(2)); // Priority >= 2
        expect(
          highPriorityOps.map((op) => op.id),
          containsAll(['high_op', 'critical_op']),
        );
      });

      test('should update operation priority', () async {
        final op = SyncOperation(
          id: 'test_op',
          type: SyncOperationType.upload,
          localFilePath: '/test/file.txt',
          remoteFilePath: '/remote/file.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        await service.enqueueOperation(operation: op, priority: 1);

        final updated = await service.updateOperationPriority(
          operationId: 'test_op',
          newPriority: 3,
        );
        expect(updated, isTrue);

        final operations = await service.getOperationsByPriority(3);
        expect(operations.length, equals(1));
        expect(operations.first.id, equals('test_op'));
      });

      test('should promote and demote operations', () async {
        final op = SyncOperation(
          id: 'test_op',
          type: SyncOperationType.upload,
          localFilePath: '/test/file.txt',
          remoteFilePath: '/remote/file.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        await service.enqueueOperation(operation: op, priority: 1);

        // Promote to high priority
        final promoted = await service.promoteToHighPriority('test_op');
        expect(promoted, isTrue);

        var operations = await service.getOperationsByPriority(3);
        expect(operations.length, equals(1));

        // Demote to low priority
        final demoted = await service.demoteToLowPriority('test_op');
        expect(demoted, isTrue);

        operations = await service.getOperationsByPriority(0);
        expect(operations.length, equals(1));
      });
    });

    group('Statistics', () {
      test('should provide queue statistics', () async {
        // Add operations with different statuses
        final op1 = SyncOperation(
          id: 'op1',
          type: SyncOperationType.upload,
          localFilePath: '/test/1.txt',
          remoteFilePath: '/remote/1.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        final op2 = SyncOperation(
          id: 'op2',
          type: SyncOperationType.download,
          localFilePath: '/test/2.txt',
          remoteFilePath: '/remote/2.txt',
          provider: CloudProvider.icloud,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        await service.enqueueOperation(operation: op1);
        await service.enqueueOperation(operation: op2);

        await service.updateOperationStatus(
          operationId: 'op2',
          status: QueueOperationStatus.processing,
        );

        final stats = await service.getQueueStatistics();
        expect(stats.totalOperations, equals(2));
        expect(stats.pendingOperations, equals(1));
        expect(stats.processingOperations, equals(1));
        expect(stats.pendingPercentage, equals(50.0));
      });

      test('should provide priority statistics', () async {
        final operations = [
          ('critical1', 3),
          ('critical2', 3),
          ('high1', 2),
          ('normal1', 1),
          ('low1', 0),
          ('low2', 0),
        ];

        for (final (id, priority) in operations) {
          final op = SyncOperation(
            id: id,
            type: SyncOperationType.upload,
            localFilePath: '/test/$id.txt',
            remoteFilePath: '/remote/$id.txt',
            provider: CloudProvider.googleDrive,
            status: SyncOperationStatus.queued,
            createdAt: DateTime.now(),
          );
          await service.enqueueOperation(operation: op, priority: priority);
        }

        final priorityStats = await service.getPriorityStatistics();
        expect(priorityStats.criticalCount, equals(2));
        expect(priorityStats.highCount, equals(1));
        expect(priorityStats.normalCount, equals(1));
        expect(priorityStats.lowCount, equals(2));
        expect(priorityStats.totalOperations, equals(6));
        expect(
          priorityStats.highPriorityPercentage,
          equals(50.0),
        ); // (2+1)/6 * 100
      });
    });

    group('Queue Management', () {
      test('should clear queue', () async {
        final operations = List.generate(
          5,
          (index) => SyncOperation(
            id: 'op_$index',
            type: SyncOperationType.upload,
            localFilePath: '/test/$index.txt',
            remoteFilePath: '/remote/$index.txt',
            provider: CloudProvider.googleDrive,
            status: SyncOperationStatus.queued,
            createdAt: DateTime.now(),
          ),
        );

        for (final op in operations) {
          await service.enqueueOperation(operation: op);
        }

        var stats = await service.getQueueStatistics();
        expect(stats.totalOperations, equals(5));

        await service.clearQueue();

        stats = await service.getQueueStatistics();
        expect(stats.totalOperations, equals(0));
      });

      test('should handle scheduled operations', () async {
        final futureTime = DateTime.now().add(const Duration(hours: 1));

        final op = SyncOperation(
          id: 'scheduled_op',
          type: SyncOperationType.upload,
          localFilePath: '/test/scheduled.txt',
          remoteFilePath: '/remote/scheduled.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
          scheduledAt: futureTime,
        );

        await service.enqueueOperation(
          operation: op,
          delay: const Duration(hours: 1),
        );

        // Should not appear in pending operations yet
        final pendingOps = await service.getPendingOperations();
        expect(pendingOps.length, equals(0));

        // But should appear in all operations by status
        final queuedOps = await service.getOperationsByStatus(
          QueueOperationStatus.pending,
        );
        expect(queuedOps.length, equals(1));
      });
    });

    group('Error Handling', () {
      test('should handle database errors gracefully', () async {
        // Dispose the service to simulate database unavailability
        await service.dispose();

        // Operations should return default values or empty lists
        final stats = await service.getQueueStatistics();
        expect(stats.totalOperations, equals(0));

        final operations = await service.getPendingOperations();
        expect(operations, isEmpty);
      });

      test('should handle invalid operation IDs', () async {
        await service.updateOperationStatus(
          operationId: 'non_existent',
          status: QueueOperationStatus.completed,
        );

        // Should not throw, just handle gracefully
        // If we reach this point, the method completed without throwing
      });
    });

    group('Stream Updates', () {
      test('should emit status updates', () async {
        final statusUpdates = <QueueStatusUpdate>[];
        final subscription = service.statusStream.listen(statusUpdates.add);

        final op = SyncOperation(
          id: 'stream_test',
          type: SyncOperationType.upload,
          localFilePath: '/test/stream.txt',
          remoteFilePath: '/remote/stream.txt',
          provider: CloudProvider.googleDrive,
          status: SyncOperationStatus.queued,
          createdAt: DateTime.now(),
        );

        await service.enqueueOperation(operation: op);

        await service.updateOperationStatus(
          operationId: 'stream_test',
          status: QueueOperationStatus.processing,
        );

        await service.updateOperationStatus(
          operationId: 'stream_test',
          status: QueueOperationStatus.completed,
        );

        // Wait a bit for stream updates
        await Future.delayed(const Duration(milliseconds: 100));

        expect(statusUpdates.length, greaterThanOrEqualTo(3));
        expect(
          statusUpdates.map((u) => u.operationId),
          everyElement(equals('stream_test')),
        );

        await subscription.cancel();
      });
    });
  });
}
