// ignore_for_file: constant_identifier_names

import 'dart:developer' as developer;

enum LogLevel { DEBUG, INFO, WARN, ERROR, NONE }

class Logger {
  Logger({LogLevel level = LogLevel.ERROR}) : _level = level;

  LogLevel _level;

  void setLevel(LogLevel level) {
    _level = level;
  }

  LogLevel getLevel() => _level;

  void debug(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index <= LogLevel.DEBUG.index) {
      developer.log(
        '$message',
        name: 'rgb_sdk_flutter.debug',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void info(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index <= LogLevel.INFO.index) {
      developer.log(
        '$message',
        name: 'rgb_sdk_flutter.info',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void warn(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index <= LogLevel.WARN.index) {
      developer.log(
        '$message',
        name: 'rgb_sdk_flutter.warn',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void error(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index <= LogLevel.ERROR.index) {
      developer.log(
        '$message',
        name: 'rgb_sdk_flutter.error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final Logger logger = Logger();

void configureLogging(LogLevel level) {
  logger.setLevel(level);
}
