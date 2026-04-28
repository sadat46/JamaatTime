class NoticeException implements Exception {
  const NoticeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoticeNotFound extends NoticeException {
  const NoticeNotFound() : super('Notice not found.');
}

class NoticeHidden extends NoticeException {
  const NoticeHidden() : super('Notice is hidden or expired.');
}

class NoticeNetwork extends NoticeException {
  const NoticeNetwork(super.message);
}

class NoticePermissionDenied extends NoticeException {
  const NoticePermissionDenied() : super('Permission denied.');
}
