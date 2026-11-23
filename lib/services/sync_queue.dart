import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_tr.dart';
import 'api_client.dart';

/// Global messenger so background tasks can show a snackbar even after the
/// screen that started them has been closed.
class AppMessenger {
  AppMessenger._();
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void showError(String message) {
    final state = key.currentState;
    if (state == null) return;
    state
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Serial background queue for write operations (optimistic UI).
///
/// * The UI applies a change locally and returns immediately.
/// * The network write runs here, strictly in order (so "create order" always
///   reaches the server before "add payment to that order").
/// * Transient network failures are retried with backoff (handles Render
///   cold starts); on a final failure the caller's rollback runs and the user
///   sees a message.
/// * GET requests wait for [idle] so a refresh never overwrites a local change
///   with stale server data.
class SyncQueue {
  SyncQueue._();

  static const _zoneKey = #bizflowSyncQueue;
  static Future<void> _tail = Future<void>.value();
  static int _pending = 0;

  static bool get hasPending => _pending > 0;
  static bool get isInsideQueue => Zone.current[_zoneKey] == true;

  /// Completes when all queued writes have finished (successfully or not).
  static Future<void> get idle => _tail;

  static Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _pending++;
    _tail = _tail.then((_) async {
      try {
        final result = await runZoned(
          () => _withRetry(task),
          zoneValues: {_zoneKey: true},
        );
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        _pending--;
      }
    });
    return completer.future;
  }

  /// Fire-and-forget write. [onError] should roll back the optimistic change.
  static void background(
    Future<void> Function() task, {
    void Function(Object error)? onError,
    Future<void> Function()? onSuccess,
  }) {
    unawaited(run(task).then((_) async {
      if (onSuccess != null) await onSuccess();
    }).catchError((Object e) {
      onError?.call(e);
      final msg = e is ApiException
          ? e.message
          : AppTr.tr(
              'Не удалось сохранить — нет связи с сервером',
              'Could not save — no connection to server',
            );
      AppMessenger.showError(msg);
    }));
  }

  static Future<T> _withRetry<T>(Future<T> Function() task) async {
    const delays = [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 6)];
    var attempt = 0;
    while (true) {
      try {
        return await task();
      } on ApiException catch (e) {
        // 4xx are real errors (validation etc.) — do not retry.
        final code = e.statusCode ?? 0;
        if (code >= 400 && code < 500) rethrow;
        if (attempt >= delays.length) rethrow;
      } catch (_) {
        if (attempt >= delays.length) rethrow;
      }
      await Future<void>.delayed(delays[attempt]);
      attempt++;
    }
  }
}
