class RemoteLogger {
  static RemoteLogger? _instance;
  Function remoteLogger = dummy;

  static dummy(String msg, [StackTrace? stackTrace]) {
    // String _now = DateFormat("Hms").format(DateTime.now());
    // print('[$_now] $msg');
  }

  RemoteLogger._internal() {
    _instance = this;
  }

  factory RemoteLogger() => _instance ?? RemoteLogger._internal();

  // String get _now => DateFormat("Hms").format(DateTime.now());

  void log(String message, [StackTrace? stackTrace]) {
    remoteLogger('[iex] ' + message, stackTrace);
  }
}
