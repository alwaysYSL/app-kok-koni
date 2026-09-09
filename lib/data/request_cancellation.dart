import 'dart:async';

final class RequestCancellation {
  RequestCancellation._(this._whenCancelled);

  final Future<Object?> _whenCancelled;
  bool _isCancelled = false;
  Object? _reason;

  bool get isCancelled => _isCancelled;
  Object? get reason => _reason;
  Future<Object?> get whenCancelled => _whenCancelled;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw RequestCancelledException(_reason);
    }
  }
}

final class RequestCancellationController {
  RequestCancellationController() : _completer = Completer<Object?>() {
    token = RequestCancellation._(_completer.future);
  }

  final Completer<Object?> _completer;
  late final RequestCancellation token;

  void cancel([Object? reason]) {
    if (token._isCancelled) return;
    token._isCancelled = true;
    token._reason = reason;
    if (!_completer.isCompleted) {
      _completer.complete(reason);
    }
  }
}

final class RequestCancelledException implements Exception {
  const RequestCancelledException([this.reason]);
  final Object? reason;

  @override
  String toString() => reason != null
      ? 'RequestCancelledException: $reason'
      : 'RequestCancelledException';
}
