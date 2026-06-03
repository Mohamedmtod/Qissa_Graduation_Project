class AdminWorkerTransitionResult {
  const AdminWorkerTransitionResult({
    required this.orderId,
    required this.fromStatus,
    required this.toStatus,
    required this.restocked,
  });

  final String orderId;
  final String fromStatus;
  final String toStatus;
  final bool restocked;

  factory AdminWorkerTransitionResult.fromJson(Map<String, dynamic> json) {
    final transition = json['transition'] as Map<String, dynamic>? ?? {};
    return AdminWorkerTransitionResult(
      orderId: json['orderId']?.toString() ?? '',
      fromStatus: transition['from']?.toString() ?? '',
      toStatus: transition['to']?.toString() ?? '',
      restocked: json['restocked'] == true,
    );
  }
}
