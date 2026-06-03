class AdminWriteResult<T> {
  const AdminWriteResult({required this.data, required this.traceId});

  final T data;
  final String traceId;
}
