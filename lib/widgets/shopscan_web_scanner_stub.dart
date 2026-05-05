import 'package:flutter/widgets.dart';

class ShopScanWebScannerController {
  final ValueNotifier<bool> hasTorch = ValueNotifier<bool>(false);
  final ValueNotifier<bool> torchEnabled = ValueNotifier<bool>(false);

  Future<void> stop() async {}

  Future<bool> toggleTorch() async => false;

  void dispose() {
    hasTorch.dispose();
    torchEnabled.dispose();
  }
}

class ShopScanWebScanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}