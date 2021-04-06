import 'package:intl/intl.dart';

class RemoteLogger {
  static RemoteLogger _instance;
  Function remoteLogger;

  RemoteLogger._internal() {
    _instance = this;
  }

  factory RemoteLogger() => _instance ?? RemoteLogger._internal();

  String get _now => DateFormat("Hms").format(DateTime.now());

  void log(String message, [StackTrace stackTrace]) {
    if (remoteLogger != null)
      remoteLogger(message, stackTrace);
    else
      print('[$_now] $message');
  }
}
