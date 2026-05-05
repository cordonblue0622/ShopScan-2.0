import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeService {
  late final MobileScannerController controller;

  BarcodeService() {
    controller = MobileScannerController();
  }

  // Initialize barcode scanner
  Future<void> initialize() async {
    try {
      await controller.start();
    } catch (e) {
      throw Exception('Failed to initialize barcode scanner: $e');
    }
  }

  // Dispose barcode scanner
  Future<void> dispose() async {
    try {
      await controller.stop();
    } catch (e) {
      throw Exception('Failed to stop scanner: $e');
    }
  }

  // Toggle flash
  Future<void> toggleFlash() async {
    try {
      await controller.toggleTorch();
    } catch (e) {
      throw Exception('Failed to toggle flash: $e');
    }
  }

  // Switch camera
  Future<void> switchCamera() async {
    try {
      await controller.switchCamera();
    } catch (e) {
      throw Exception('Failed to switch camera: $e');
    }
  }

  // Extract barcode from scan result
  String? extractBarcode(BarcodeCapture barcodeCapture) {
    try {
      for (final barcode in barcodeCapture.barcodes) {
        final rawValue = barcode.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          return rawValue;
        }
      }
    } catch (e) {
      throw Exception('Failed to extract barcode: $e');
    }
    return null;
  }
}
