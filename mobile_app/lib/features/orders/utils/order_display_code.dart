String orderDisplayCode({required String orderId, String? orderCode}) {
  final normalizedOrderCode = orderCode?.trim();
  if (normalizedOrderCode != null && normalizedOrderCode.isNotEmpty) {
    return normalizedOrderCode;
  }

  final normalizedOrderId = orderId.trim();
  return normalizedOrderId.length >= 6
      ? normalizedOrderId.substring(0, 6).toUpperCase()
      : normalizedOrderId.toUpperCase();
}
