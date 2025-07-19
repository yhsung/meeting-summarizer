import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'network_connectivity_service.dart';

/// Service for managing retry logic with multiple retry policies
class RetryManager {
  static RetryManager? _instance;
  static RetryManager get instance => _instance ??= RetryManager._();
  RetryManager._();

  final Map<String, RetryContext> _activeRetries = {};
  final StreamController<RetryStatusUpdate> _statusController =
      StreamController<RetryStatusUpdate>.broadcast();

  /// Stream of retry status updates
  Stream<RetryStatusUpdate> get statusStream => _statusController.stream;

  /// Execute an operation with retry logic
  Future<T> executeWithRetry<T>({
    required String operationId,
    required Future<T> Function() operation,
    RetryPolicy policy = const ExponentialBackoffPolicy(),
    bool requiresConnectivity = true,
    Function(Exception error, int attemptNumber)? onRetry,
  }) async {
    final context = RetryContext(
      operationId: operationId,
      policy: policy,
      requiresConnectivity: requiresConnectivity,
    );

    _activeRetries[operationId] = context;

    try {
      return await _executeWithRetryInternal(
        context: context,
        operation: operation,
        onRetry: onRetry,
      );
    } finally {
      _activeRetries.remove(operationId);
    }
  }

  /// Internal retry execution logic
  Future<T> _executeWithRetryInternal<T>({
    required RetryContext context,
    required Future<T> Function() operation,
    Function(Exception error, int attemptNumber)? onRetry,
  }) async {
    Exception? lastException;

    for (int attempt = 0; attempt <= context.policy.maxRetries; attempt++) {
      context.currentAttempt = attempt;

      try {
        // Check connectivity requirement
        if (context.requiresConnectivity) {
          final connectivityService = NetworkConnectivityService.instance;
          if (!await connectivityService.isConnected) {
            throw ConnectivityException('No internet connectivity available');
          }
        }

        // Log attempt
        if (attempt > 0) {
          dev.log(
            'RetryManager: Retry attempt $attempt for operation ${context.operationId}',
          );
          _statusController.add(
            RetryStatusUpdate(
              operationId: context.operationId,
              attemptNumber: attempt,
              isRetrying: true,
              nextRetryDelay: null,
            ),
          );
        }

        // Execute the operation
        final result = await operation();

        // Success - log and return
        if (attempt > 0) {
          dev.log(
            'RetryManager: Operation ${context.operationId} succeeded after $attempt retries',
          );
          _statusController.add(
            RetryStatusUpdate(
              operationId: context.operationId,
              attemptNumber: attempt,
              isRetrying: false,
              succeeded: true,
            ),
          );
        }

        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        context.lastError = lastException;

        // Check if we should retry
        if (attempt >= context.policy.maxRetries) {
          break; // No more retries
        }

        if (!context.policy.shouldRetry(lastException, attempt)) {
          dev.log(
            'RetryManager: Operation ${context.operationId} failed with non-retryable error: $e',
          );
          break; // Non-retryable error
        }

        // Calculate delay for next retry
        final delay = context.policy.calculateDelay(attempt);
        context.nextRetryAt = DateTime.now().add(delay);

        dev.log(
          'RetryManager: Operation ${context.operationId} failed (attempt ${attempt + 1}), '
          'retrying in ${delay.inMilliseconds}ms: $e',
        );

        // Notify retry callback
        onRetry?.call(lastException, attempt + 1);

        // Notify status update
        _statusController.add(
          RetryStatusUpdate(
            operationId: context.operationId,
            attemptNumber: attempt,
            isRetrying: true,
            nextRetryDelay: delay,
            error: lastException.toString(),
          ),
        );

        // Wait for the calculated delay
        await Future.delayed(delay);

        // Check if connectivity is required and wait for it if needed
        if (context.requiresConnectivity) {
          await _waitForConnectivity(context.operationId);
        }
      }
    }

    // All retries exhausted
    dev.log(
      'RetryManager: Operation ${context.operationId} failed after ${context.policy.maxRetries} retries',
    );
    _statusController.add(
      RetryStatusUpdate(
        operationId: context.operationId,
        attemptNumber: context.currentAttempt,
        isRetrying: false,
        succeeded: false,
        error: lastException?.toString(),
      ),
    );

    throw RetryExhaustedException(
      operationId: context.operationId,
      attemptCount: context.policy.maxRetries + 1,
      lastError: lastException!,
    );
  }

  /// Wait for connectivity to be available
  Future<void> _waitForConnectivity(String operationId) async {
    final connectivityService = NetworkConnectivityService.instance;

    if (await connectivityService.isConnected) {
      return; // Already connected
    }

    dev.log(
      'RetryManager: Waiting for connectivity for operation $operationId',
    );

    try {
      await connectivityService.waitForConnectivity(
        timeout: const Duration(minutes: 5),
      );
      dev.log('RetryManager: Connectivity restored for operation $operationId');
    } catch (e) {
      dev.log(
        'RetryManager: Timeout waiting for connectivity for operation $operationId',
      );
      throw ConnectivityException('Timeout waiting for connectivity: $e');
    }
  }

  /// Cancel an active retry operation
  void cancelRetry(String operationId) {
    final context = _activeRetries.remove(operationId);
    if (context != null) {
      dev.log('RetryManager: Cancelled retry for operation $operationId');
      _statusController.add(
        RetryStatusUpdate(
          operationId: operationId,
          attemptNumber: context.currentAttempt,
          isRetrying: false,
          cancelled: true,
        ),
      );
    }
  }

  /// Get retry context for an operation
  RetryContext? getRetryContext(String operationId) {
    return _activeRetries[operationId];
  }

  /// Get all active retry operations
  Map<String, RetryContext> get activeRetries =>
      Map.unmodifiable(_activeRetries);

  /// Get retry statistics
  RetryStatistics getStatistics() {
    final contexts = _activeRetries.values.toList();

    return RetryStatistics(
      activeRetries: contexts.length,
      totalAttempts: contexts.fold(0, (sum, ctx) => sum + ctx.currentAttempt),
      averageAttempts: contexts.isNotEmpty
          ? contexts.fold(0, (sum, ctx) => sum + ctx.currentAttempt) /
                contexts.length
          : 0.0,
      retryPolicies: contexts
          .map((ctx) => ctx.policy.runtimeType.toString())
          .toSet(),
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    _activeRetries.clear();
    await _statusController.close();
  }
}

/// Context for tracking retry operations
class RetryContext {
  final String operationId;
  final RetryPolicy policy;
  final bool requiresConnectivity;
  final DateTime createdAt;

  int currentAttempt = 0;
  DateTime? nextRetryAt;
  Exception? lastError;

  RetryContext({
    required this.operationId,
    required this.policy,
    required this.requiresConnectivity,
  }) : createdAt = DateTime.now();

  /// Get time until next retry
  Duration? get timeUntilNextRetry {
    if (nextRetryAt == null) return null;
    final now = DateTime.now();
    if (nextRetryAt!.isBefore(now)) return Duration.zero;
    return nextRetryAt!.difference(now);
  }

  /// Check if retry is due
  bool get isRetryDue {
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  @override
  String toString() {
    return 'RetryContext(id: $operationId, attempt: $currentAttempt, '
        'policy: ${policy.runtimeType}, nextRetry: $nextRetryAt)';
  }
}

/// Abstract base class for retry policies
abstract class RetryPolicy {
  const RetryPolicy();

  /// Maximum number of retry attempts
  int get maxRetries;

  /// Calculate delay before next retry attempt
  Duration calculateDelay(int attemptNumber);

  /// Determine if an error should trigger a retry
  bool shouldRetry(Exception error, int attemptNumber);
}

/// Exponential backoff retry policy
class ExponentialBackoffPolicy extends RetryPolicy {
  final int _maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final double jitter;

  const ExponentialBackoffPolicy({
    int maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.multiplier = 2.0,
    this.jitter = 0.1,
  }) : _maxRetries = maxRetries;

  @override
  int get maxRetries => _maxRetries;

  @override
  Duration calculateDelay(int attemptNumber) {
    // Calculate exponential backoff: initial * (multiplier ^ attempt)
    double delayMs =
        initialDelay.inMilliseconds.toDouble() * pow(multiplier, attemptNumber);

    // Apply jitter to avoid thundering herd
    final random = Random();
    final jitterMs = delayMs * jitter * (random.nextDouble() - 0.5) * 2;
    delayMs += jitterMs;

    // Cap at maximum delay
    delayMs = min(delayMs, maxDelay.inMilliseconds.toDouble());

    return Duration(milliseconds: delayMs.round());
  }

  @override
  bool shouldRetry(Exception error, int attemptNumber) {
    // Don't retry certain types of errors
    if (error is AuthenticationException ||
        error is AuthorizationException ||
        error is InvalidArgumentException) {
      return false;
    }

    // Don't retry if we've hit the max attempts
    if (attemptNumber >= maxRetries) {
      return false;
    }

    return true;
  }
}

/// Linear backoff retry policy
class LinearBackoffPolicy extends RetryPolicy {
  final int _maxRetries;
  final Duration increment;
  final Duration maxDelay;

  const LinearBackoffPolicy({
    int maxRetries = 3,
    this.increment = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 2),
  }) : _maxRetries = maxRetries;

  @override
  int get maxRetries => _maxRetries;

  @override
  Duration calculateDelay(int attemptNumber) {
    final delayMs = increment.inMilliseconds.toDouble() * (attemptNumber + 1);
    final cappedDelayMs = min(delayMs, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: cappedDelayMs.round());
  }

  @override
  bool shouldRetry(Exception error, int attemptNumber) {
    // Same logic as exponential backoff
    if (error is AuthenticationException ||
        error is AuthorizationException ||
        error is InvalidArgumentException) {
      return false;
    }

    return attemptNumber < maxRetries;
  }
}

/// Fixed interval retry policy
class FixedIntervalPolicy extends RetryPolicy {
  final int _maxRetries;
  final Duration interval;

  const FixedIntervalPolicy({
    int maxRetries = 3,
    this.interval = const Duration(seconds: 5),
  }) : _maxRetries = maxRetries;

  @override
  int get maxRetries => _maxRetries;

  @override
  Duration calculateDelay(int attemptNumber) => interval;

  @override
  bool shouldRetry(Exception error, int attemptNumber) {
    if (error is AuthenticationException ||
        error is AuthorizationException ||
        error is InvalidArgumentException) {
      return false;
    }

    return attemptNumber < maxRetries;
  }
}

/// Immediate retry policy (no delay)
class ImmediateRetryPolicy extends RetryPolicy {
  final int _maxRetries;

  const ImmediateRetryPolicy({int maxRetries = 2}) : _maxRetries = maxRetries;

  @override
  int get maxRetries => _maxRetries;

  @override
  Duration calculateDelay(int attemptNumber) => Duration.zero;

  @override
  bool shouldRetry(Exception error, int attemptNumber) {
    // Only retry network-related errors immediately
    if (error is ConnectivityException || error is NetworkException) {
      return attemptNumber < maxRetries;
    }
    return false;
  }
}

/// Update about retry operation status
class RetryStatusUpdate {
  final String operationId;
  final int attemptNumber;
  final bool isRetrying;
  final Duration? nextRetryDelay;
  final String? error;
  final bool succeeded;
  final bool cancelled;
  final DateTime timestamp;

  RetryStatusUpdate({
    required this.operationId,
    required this.attemptNumber,
    required this.isRetrying,
    this.nextRetryDelay,
    this.error,
    this.succeeded = false,
    this.cancelled = false,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    if (cancelled) {
      return 'RetryStatusUpdate(id: $operationId, cancelled)';
    }
    if (succeeded) {
      return 'RetryStatusUpdate(id: $operationId, succeeded after $attemptNumber attempts)';
    }
    if (isRetrying) {
      return 'RetryStatusUpdate(id: $operationId, retrying attempt $attemptNumber, '
          'next retry in: ${nextRetryDelay?.inMilliseconds}ms)';
    }
    return 'RetryStatusUpdate(id: $operationId, failed after $attemptNumber attempts)';
  }
}

/// Statistics about retry operations
class RetryStatistics {
  final int activeRetries;
  final int totalAttempts;
  final double averageAttempts;
  final Set<String> retryPolicies;

  const RetryStatistics({
    required this.activeRetries,
    required this.totalAttempts,
    required this.averageAttempts,
    required this.retryPolicies,
  });

  @override
  String toString() {
    return 'RetryStatistics(active: $activeRetries, totalAttempts: $totalAttempts, '
        'avgAttempts: ${averageAttempts.toStringAsFixed(1)}, '
        'policies: ${retryPolicies.join(", ")})';
  }
}

/// Exception thrown when all retry attempts are exhausted
class RetryExhaustedException implements Exception {
  final String operationId;
  final int attemptCount;
  final Exception lastError;

  const RetryExhaustedException({
    required this.operationId,
    required this.attemptCount,
    required this.lastError,
  });

  @override
  String toString() {
    return 'RetryExhaustedException: Operation $operationId failed after $attemptCount attempts. '
        'Last error: $lastError';
  }
}

/// Exception for connectivity-related issues
class ConnectivityException implements Exception {
  final String message;

  const ConnectivityException(this.message);

  @override
  String toString() => 'ConnectivityException: $message';
}

/// Exception for network-related issues
class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception for authentication issues
class AuthenticationException implements Exception {
  final String message;

  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Exception for authorization issues
class AuthorizationException implements Exception {
  final String message;

  const AuthorizationException(this.message);

  @override
  String toString() => 'AuthorizationException: $message';
}

/// Exception for invalid arguments
class InvalidArgumentException implements Exception {
  final String message;

  const InvalidArgumentException(this.message);

  @override
  String toString() => 'InvalidArgumentException: $message';
}
