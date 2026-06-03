import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum AdminIssueSeverity { info, warning, error, critical }

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.traceId,
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.targetId,
    required this.occurredAt,
    required this.outcome,
    this.details,
  });

  final String traceId;
  final String action;
  final String actorId;
  final String actorRole;
  final String targetId;
  final DateTime occurredAt;
  final String outcome;
  final String? details;
}

class AdminProductionIssue {
  const AdminProductionIssue({
    required this.traceId,
    required this.title,
    required this.source,
    required this.occurredAt,
    required this.severity,
    required this.message,
  });

  final String traceId;
  final String title;
  final String source;
  final DateTime occurredAt;
  final AdminIssueSeverity severity;
  final String message;
}

class AdminObservabilityService extends ChangeNotifier {
  AdminObservabilityService({Random? random, FirebaseFirestore? firestore})
    : _random = random ?? Random(),
      _firestore = firestore;

  final Random _random;
  final FirebaseFirestore? _firestore;
  final List<AdminAuditEntry> _auditEntries = [];
  final List<AdminProductionIssue> _productionIssues = [];
  bool _disposed = false;

  UnmodifiableListView<AdminAuditEntry> get auditEntries =>
      UnmodifiableListView(_auditEntries);

  UnmodifiableListView<AdminProductionIssue> get productionIssues =>
      UnmodifiableListView(_productionIssues);

  int get warningOrHigherCount => _productionIssues
      .where(
        (issue) => issue.severity.index >= AdminIssueSeverity.warning.index,
      )
      .length;

  String createTraceId(String action) {
    final normalized = action
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final entropy = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${normalized.isEmpty ? 'admin' : normalized}-${DateTime.now().millisecondsSinceEpoch}-$entropy';
  }

  void recordAudit(AdminAuditEntry entry) {
    _auditEntries.insert(0, entry);
    if (_auditEntries.length > 60) {
      _auditEntries.removeLast();
    }
    unawaited(_persistAudit(entry));
    _notifySafely();
  }

  void recordIssue(AdminProductionIssue issue) {
    _productionIssues.insert(0, issue);
    if (_productionIssues.length > 30) {
      _productionIssues.removeLast();
    }
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifySafely() {
    if (_disposed || !hasListeners) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !hasListeners) {
        return;
      }
      notifyListeners();
    });
  }

  Future<void> _persistAudit(AdminAuditEntry entry) async {
    try {
      if (_firestore == null && Firebase.apps.isEmpty) {
        return;
      }
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await firestore.collection('admin_audit_logs').doc(entry.traceId).set({
        'traceId': entry.traceId,
        'action': entry.action,
        'actorId': entry.actorId,
        'actorRole': entry.actorRole,
        'targetId': entry.targetId,
        'occurredAt': Timestamp.fromDate(entry.occurredAt),
        'outcome': entry.outcome,
        if (entry.details != null && entry.details!.trim().isNotEmpty)
          'details': entry.details!.trim(),
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][audit][persist_failed] traceId=${entry.traceId} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
