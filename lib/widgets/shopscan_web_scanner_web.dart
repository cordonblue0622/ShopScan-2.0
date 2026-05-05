// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as dart_js;
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

dynamic _scannerRuntime() {
  return dart_js.context['shopScanScanner'];
}

dynamic _callScannerMethod(String method, List<dynamic> args) {
  final runtime = _scannerRuntime();
  if (runtime == null) {
    throw StateError('ShopScan web scanner runtime is not available.');
  }

  return (runtime as dart_js.JsObject).callMethod(method, args);
}

class ShopScanWebScannerController {
  final ValueNotifier<bool> hasTorch = ValueNotifier<bool>(false);
  final ValueNotifier<bool> torchEnabled = ValueNotifier<bool>(false);

  String? _scannerId;

  void _attach(String scannerId) {
    _scannerId = scannerId;
  }

  void _detach(String scannerId) {
    if (_scannerId == scannerId) {
      _scannerId = null;
      hasTorch.value = false;
      torchEnabled.value = false;
    }
  }

  void _setHasTorch(bool value) {
    hasTorch.value = value;
    if (!value) {
      torchEnabled.value = false;
    }
  }

  void _setTorchEnabled({required bool value}) {
    torchEnabled.value = value;
  }

  Future<void> stop() async {
    final scannerId = _scannerId;
    if (scannerId == null) {
      return;
    }

    try {
      _callScannerMethod('stop', <dynamic>[scannerId]);
    } finally {
      _detach(scannerId);
    }
  }

  Future<bool> toggleTorch() async {
    final scannerId = _scannerId;
    if (scannerId == null) {
      throw StateError('Scanner is not ready yet.');
    }

    final nextState = _callScannerMethod(
      'toggleTorch',
      <dynamic>[scannerId],
    );

    final isEnabled = nextState == true;
    _setTorchEnabled(value: isEnabled);
    return isEnabled;
  }

  void dispose() {
    unawaited(stop());
    hasTorch.dispose();
    torchEnabled.dispose();
  }
}

class ShopScanWebScanner extends StatefulWidget {
  const ShopScanWebScanner({
    required this.controller,
    required this.onDetected,
    this.onStarted,
    this.onError,
    super.key,
  });

  final ShopScanWebScannerController controller;
  final ValueChanged<String> onDetected;
  final ValueChanged<String>? onError;
  final VoidCallback? onStarted;

  @override
  State<ShopScanWebScanner> createState() => _ShopScanWebScannerState();
}

class _ShopScanWebScannerState extends State<ShopScanWebScanner> {
  late final String _viewType =
      'shopscan-web-scanner-view-${DateTime.now().microsecondsSinceEpoch}';
  late final String _scannerId =
      'shopscan-web-scanner-${DateTime.now().microsecondsSinceEpoch}';
  Timer? _pollTimer;
  bool _didNotifyStarted = false;
  bool _didRequestStart = false;
  int _lastDetectionVersion = 0;
  int _lastErrorVersion = 0;
  late final html.DivElement _hostElement = html.DivElement()
    ..id = _viewType
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = 'black'
    ..style.overflow = 'hidden';

  void _onDetectedJs(String value) {
    if (!mounted) {
      return;
    }

    widget.onDetected(value);
  }

  void _onErrorJs(String message) {
    if (!mounted) {
      return;
    }

    widget.onError?.call(message);
  }

  void _onStartedJs() {
    if (!mounted) {
      return;
    }

    widget.onStarted?.call();
  }

  @override
  void initState() {
    super.initState();
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _hostElement,
    );
    widget.controller._attach(_scannerId);
  }

  void _handlePlatformViewCreated(int _) {
    if (!mounted || _didRequestStart) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestStart) {
        return;
      }

      _didRequestStart = true;
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        () {
          if (!mounted) {
            return;
          }

          unawaited(_startScanner());
        },
      );
    });
  }

  Future<void> _startScanner() async {
    try {
      _didNotifyStarted = false;
      _lastDetectionVersion = 0;
      _lastErrorVersion = 0;

      _callScannerMethod(
        'start',
        <dynamic>[_scannerId, _viewType],
      );

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _pollScannerState(),
      );

      Future<void>.delayed(const Duration(seconds: 8), () {
        if (!mounted || _didNotifyStarted) {
          return;
        }

        widget.onError?.call(
          'Scanner startup is taking longer than expected. Tap Retry Camera.',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      widget.onError?.call(error.toString());
    }
  }

  void _pollScannerState() {
    if (!mounted) {
      return;
    }

    try {
      final state = _callScannerMethod('snapshot', <dynamic>[_scannerId]);
      if (state is! dart_js.JsObject) {
        return;
      }

      final torchAvailable = state['torchAvailable'] == true;
      final torchEnabled = state['torchEnabled'] == true;
      widget.controller._setHasTorch(torchAvailable);
      widget.controller._setTorchEnabled(value: torchEnabled);

      final started = state['started'] == true;
      if (started && !_didNotifyStarted) {
        _didNotifyStarted = true;
        _onStartedJs();
      }

      final detectionVersion =
          (state['detectionVersion'] as num?)?.toInt() ?? 0;
      if (detectionVersion > _lastDetectionVersion) {
        _lastDetectionVersion = detectionVersion;
        final detectedValue = state['detectedValue']?.toString().trim();
        if (detectedValue != null && detectedValue.isNotEmpty) {
          _onDetectedJs(detectedValue);
        }
      }

      final errorVersion = (state['errorVersion'] as num?)?.toInt() ?? 0;
      if (errorVersion > _lastErrorVersion) {
        _lastErrorVersion = errorVersion;
        final errorMessage = state['errorMessage']?.toString().trim();
        if (errorMessage != null && errorMessage.isNotEmpty) {
          _onErrorJs(errorMessage);
        }
      }
    } catch (error) {
      widget.onError?.call(error.toString());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    widget.controller._detach(_scannerId);

    try {
      _callScannerMethod('stop', <dynamic>[_scannerId]);
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: _handlePlatformViewCreated,
    );
  }
}