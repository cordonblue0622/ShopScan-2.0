import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/shopscan_web_scanner.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../core/utils/cart_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../models/product_model.dart';
import 'cart_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  static const List<BarcodeFormat> _supportedBarcodeFormats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.codabar,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.itf,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.qrCode,
  ];

  final _firestoreService = FirestoreService();
  final _manualController = TextEditingController();

  MobileScannerController? _scannerController;
  ShopScanWebScannerController? _webScannerController;

  String? _lastBarcode;
  String? _lastProductLabel;
  bool _isProcessing = false;
  bool _showManualInput = false;
  bool _isStartingScanner = false;
  MobileScannerException? _scannerError;
  String? _webScannerErrorMessage;

  AnimationController? _cartBounceController;
  Animation<double>? _cartBounceAnimation;

  int _scannerSessionId = 0;

  MobileScannerController _createScannerController({bool autoStart = true}) {
    return MobileScannerController(
      autoStart: autoStart,
      detectionSpeed: DetectionSpeed.normal,
      formats: _supportedBarcodeFormats,
    );
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webScannerController = ShopScanWebScannerController();
      _isStartingScanner = true;
    } else {
      _scannerController = _createScannerController();
    }

    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cartBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _cartBounceController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _cartBounceController?.dispose();
    _manualController.dispose();
    _scannerController?.dispose();
    _webScannerController?.dispose();
    super.dispose();
  }

  Future<void> _rebuildScannerControllerForRetry() async {
    final currentController = _scannerController;

    try {
      await currentController?.stop();
    } catch (_) {}

    currentController?.dispose();

    if (!mounted) return;

    setState(() {
      _scannerController = _createScannerController(autoStart: false);
      _scannerSessionId++;
      _scannerError = null;
    });

    await WidgetsBinding.instance.endOfFrame;
    await _scannerController?.start();
  }

  Future<void> _rebuildWebScannerControllerForRetry() async {
    final currentController = _webScannerController;

    try {
      await currentController?.stop();
    } catch (_) {}

    currentController?.dispose();

    if (!mounted) return;

    setState(() {
      _webScannerController = ShopScanWebScannerController();
      _scannerSessionId++;
      _webScannerErrorMessage = null;
    });

    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _startScanner({bool forceRestart = false}) async {
    if (_isStartingScanner || !mounted) return;

    setState(() {
      _isStartingScanner = true;
      _scannerError = null;
      _webScannerErrorMessage = null;
    });

    try {
      if (kIsWeb) {
        if (forceRestart) {
          await _rebuildWebScannerControllerForRetry();
        }
        return;
      }

      final controller = _scannerController;
      if (controller == null) {
        return;
      }

      if (forceRestart) {
        await _rebuildScannerControllerForRetry();
      } else {
        await controller.start();
      }
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      setState(() => _scannerError = error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerError = const MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isStartingScanner = false);
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (kIsWeb) {
      final controller = _webScannerController;
      if (controller == null) return;

      if (!controller.hasTorch.value) {
        _showErrorSnack('Flashlight is not available on this device.');
        return;
      }

      try {
        await controller.toggleTorch();
        if (mounted) setState(() {});
      } catch (_) {
        _showErrorSnack('Unable to change flashlight right now.');
      }
      return;
    }

    final controller = _scannerController;
    if (controller == null) return;

    final hasTorch = controller.hasTorchState.value;

    if (hasTorch != true) {
      _showErrorSnack('Flashlight is not available on this device.');
      return;
    }

    try {
      await controller.toggleTorch();
      if (mounted) setState(() {});
    } catch (_) {
      _showErrorSnack('Unable to change flashlight right now.');
    }
  }

  void _handleWebScannerStarted() {
    if (!mounted) return;

    setState(() {
      _isStartingScanner = false;
      _webScannerErrorMessage = null;
    });
  }

  void _handleWebScannerError(String message) {
    if (!mounted) return;

    setState(() {
      _isStartingScanner = false;
      _webScannerErrorMessage = message;
    });
  }

  String? _extractDetectedBarcodeValue(BarcodeCapture barcodeCapture) {
    for (final detectedBarcode in barcodeCapture.barcodes) {
      final rawValue = detectedBarcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) return rawValue;

      final displayValue = detectedBarcode.displayValue?.trim();
      if (displayValue != null && displayValue.isNotEmpty) return displayValue;
    }

    return null;
  }

  void _handleBarcodeDetection(BarcodeCapture barcodeCapture) {
    debugPrint('DETECT EVENT TRIGGERED: ${barcodeCapture.barcodes.length}');

    if (_isProcessing) return;

    final barcode = _extractDetectedBarcodeValue(barcodeCapture);

    debugPrint('EXTRACTED BARCODE: $barcode');

    if (barcode == null) return;

    _handleDetectedBarcodeValue(barcode);
  }

  void _handleDetectedBarcodeValue(String barcode) {
    if (_isProcessing) return;

    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) return;
    if (normalizedBarcode == _lastBarcode) return;

    debugPrint('SCANNED BARCODE: $normalizedBarcode');

    if (mounted) {
      setState(() {
        _lastProductLabel = 'Detected barcode: $normalizedBarcode';
      });
    }

    _lastBarcode = normalizedBarcode;
    _processBarcode(normalizedBarcode);
  }

  Future<bool> _ensureCashierOnDuty() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (!authProvider.isCashier || currentUser == null) return true;

    try {
      final activeShift =
          await _firestoreService.getActiveShiftForCashier(currentUser.id);

      if (activeShift != null) return true;
    } catch (_) {
      if (!mounted) return false;

      setState(() {
        _lastProductLabel = 'Unable to confirm your shift right now';
      });

      _showErrorSnack('Unable to confirm your shift right now. Try again.');
      return false;
    }

    if (!mounted) return false;

    setState(() {
      _lastProductLabel = 'Start your shift before scanning items';
    });

    _showErrorSnack('Start your shift first before scanning items.');
    return false;
  }

  Future<void> _processBarcode(String barcode) async {
    if (!mounted) return;

    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      _lastBarcode = null;
      return;
    }

    if (!await _ensureCashierOnDuty()) {
      _resetLastBarcodeAfterDelay(
        normalizedBarcode,
        delay: const Duration(milliseconds: 500),
      );
      return;
    }

    final shopId = context.read<AuthProvider>().currentUser?.shopId;

    debugPrint('SHOP ID: $shopId');

    if (shopId == null || shopId.isEmpty) {
      setState(() {
        _isProcessing = false;
        _lastProductLabel = 'No shop assigned to this account';
      });

      _resetLastBarcodeAfterDelay(normalizedBarcode);
      _showErrorSnack('No shop assigned to this account.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final product = await _firestoreService.getProductByBarcode(
        normalizedBarcode,
        shopId: shopId,
      );

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _isProcessing = false;
          _lastProductLabel =
              'Product not added: $normalizedBarcode is not in your inventory';
        });

        _resetLastBarcodeAfterDelay(normalizedBarcode);
        _showErrorSnack('Product not added. Barcode not found in inventory.');
        return;
      }

      if (product.stock <= 0) {
        setState(() {
          _isProcessing = false;
          _lastProductLabel =
              'Product not added: ${product.name} is out of stock';
        });

        _resetLastBarcodeAfterDelay(normalizedBarcode);
        _showErrorSnack('${product.name} is out of stock');
        return;
      }

      setState(() => _isProcessing = false);

      final quantity = await _showQuantityPicker(product);

      if (quantity == null || !mounted) {
        _lastBarcode = null;
        return;
      }

      final item = TransactionItemModel(
        productId: product.id,
        productName: product.name,
        price: product.price,
        quantity: quantity,
        sku: product.barcode,
        imageUrl: product.imageUrl,
      );

      context.read<CartProvider>().addItem(item);

      _cartBounceController?.forward(from: 0);

      if (mounted) {
        _showAddedOverlay(product.name, quantity);

        setState(() {
          _lastProductLabel =
              'Last: ${product.name} (₱${product.price.toStringAsFixed(2)})';
        });
      }

      _lastBarcode = null;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastProductLabel =
              'Product not added: unable to check barcode right now';
        });

        _resetLastBarcodeAfterDelay(normalizedBarcode);
        _showErrorSnack('Error: ${e.toString()}');
      }
    }
  }

  void _resetLastBarcodeAfterDelay(
    String barcode, {
    Duration delay = const Duration(milliseconds: 1200),
  }) {
    Future<void>.delayed(delay, () {
      if (!mounted) return;

      if (_lastBarcode == barcode) {
        _lastBarcode = null;
      }
    });
  }

  void _showErrorSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(AppColors.error),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildScannerErrorView(MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                'Scanner Unavailable',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The scanner could not start. Check camera permission, then tap Retry Camera.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isStartingScanner
                    ? null
                    : () => _startScanner(forceRestart: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_isStartingScanner ? 'Starting...' : 'Retry Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primary),
                  foregroundColor: const Color(AppColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebScannerErrorView(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                'Scanner Unavailable',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isStartingScanner
                    ? null
                    : () => _startScanner(forceRestart: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_isStartingScanner ? 'Starting...' : 'Retry Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primary),
                  foregroundColor: const Color(AppColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _showQuantityPicker(ProductModel product) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        int qty = 1;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              const Color(AppColors.primary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Color(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${product.price.toStringAsFixed(2)} • Stock: ${product.stock}',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quantity',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          color: const Color(AppColors.greyDark),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _qtyButton(
                        icon: Icons.remove,
                        enabled: qty > 1,
                        onTap: () => setSheetState(() => qty--),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '$qty',
                        style: Theme.of(ctx)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 24),
                      _qtyButton(
                        icon: Icons.add,
                        enabled: qty < product.stock,
                        onTap: () => setSheetState(() => qty++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, qty),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        'Add to Cart • ₱${(product.price * qty).toStringAsFixed(2)}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(AppColors.primary).withOpacity(0.1)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color:
              enabled ? const Color(AppColors.primary) : Colors.grey.shade400,
        ),
      ),
    );
  }

  void _showAddedOverlay(String productName, int qty) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final fadeAnim = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    final slideAnim = Tween(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOut),
    );

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).size.height * 0.35,
        left: 0,
        right: 0,
        child: AnimatedBuilder(
          animation: animController,
          builder: (ctx, child) => Transform.translate(
            offset: Offset(0, slideAnim.value),
            child: Opacity(opacity: fadeAnim.value, child: child),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(AppColors.success),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '$productName x$qty added!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    animController.forward().then((_) {
      entry.remove();
      animController.dispose();
    });
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (ctx, scrollController) {
            return _ProductSearchSheet(
              scrollController: scrollController,
              firestoreService: _firestoreService,
              onProductSelected: (product) {
                Navigator.pop(ctx);
                _processBarcode(product.barcode);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (kIsWeb)
                    ShopScanWebScanner(
                      key: ValueKey(_scannerSessionId),
                      controller: _webScannerController!,
                      onDetected: _handleDetectedBarcodeValue,
                      onStarted: _handleWebScannerStarted,
                      onError: _handleWebScannerError,
                    )
                  else
                    MobileScanner(
                      key: ValueKey(_scannerSessionId),
                      controller: _scannerController,
                      fit: BoxFit.cover,
                      onDetect: _handleBarcodeDetection,
                      errorBuilder: (context, error, child) {
                        return _buildScannerErrorView(error);
                      },
                      placeholderBuilder: (context, child) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                  if (_webScannerErrorMessage != null && !_isStartingScanner)
                    Positioned.fill(
                      child: _buildWebScannerErrorView(_webScannerErrorMessage!),
                    ),

                  if (_scannerError != null && !_isStartingScanner)
                    Positioned.fill(
                      child: _buildScannerErrorView(_scannerError!),
                    ),

                  Positioned(
                    top: 14,
                    left: 14,
                    child: kIsWeb
                        ? ValueListenableBuilder<bool>(
                            valueListenable: _webScannerController!.torchEnabled,
                            builder: (context, torchEnabled, _) {
                              return GestureDetector(
                                onTap: _toggleTorch,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: torchEnabled
                                        ? const Color(AppColors.primary)
                                            .withOpacity(0.9)
                                        : Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    torchEnabled
                                        ? Icons.flashlight_off_rounded
                                        : Icons.flashlight_on_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          )
                        : ValueListenableBuilder<TorchState>(
                            valueListenable: _scannerController!.torchState,
                            builder: (context, torchState, _) {
                              final isTorchOn = torchState == TorchState.on;

                              return GestureDetector(
                                onTap: _toggleTorch,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isTorchOn
                                        ? const Color(AppColors.primary)
                                            .withOpacity(0.9)
                                        : Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isTorchOn
                                        ? Icons.flashlight_off_rounded
                                        : Icons.flashlight_on_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Align barcode with frame',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Center(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(AppColors.primary)
                                    .withOpacity(0.5),
                                width: 2.5,
                              ),
                            ),
                          ),
                          _ScanLineAnimation(),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        return ScaleTransition(
                          scale: _cartBounceAnimation!,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D2D2D),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Center(
                                    child: Icon(
                                      Icons.shopping_cart_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  if (cart.itemCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(AppColors.error),
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Text(
                                          '${cart.itemCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (_isProcessing || _isStartingScanner)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),

            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showManualInput = !_showManualInput;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEDED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.keyboard_rounded,
                            size: 22,
                            color: Color(0xFF5A5A5A),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Manual Input',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          Icon(
                            _showManualInput
                                ? Icons.keyboard_arrow_down
                                : Icons.chevron_right,
                            color: const Color(0xFF999999),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showManualInput) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter barcode or SKU',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(AppColors.borderColor),
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            final code = _manualController.text.trim();

                            if (code.isNotEmpty) {
                              _lastBarcode = null;
                              _processBarcode(code);
                              _manualController.clear();
                            }
                          },
                        ),
                      ),
                      onSubmitted: (code) {
                        final trimmedCode = code.trim();

                        if (trimmedCode.isNotEmpty) {
                          _lastBarcode = null;
                          _processBarcode(trimmedCode);
                          _manualController.clear();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showProductSearch,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text(
                        'Find Product',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_lastProductLabel != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _lastProductLabel!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLineAnimation extends StatefulWidget {
  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _controller.value * 240 + 10,
          left: 10,
          right: 10,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(AppColors.primary).withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final ScrollController scrollController;
  final FirestoreService firestoreService;
  final void Function(ProductModel product) onProductSelected;

  const _ProductSearchSheet({
    required this.scrollController,
    required this.firestoreService,
    required this.onProductSelected,
  });

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _searchController = TextEditingController();

  List<ProductModel> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) async {
    _query = query.trim().toLowerCase();

    if (_query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final shopId = context.read<AuthProvider>().currentUser?.shopId;

      final results = await widget.firestoreService.searchProducts(
        _query,
        shopId: shopId,
      );

      if (mounted) {
        setState(() => _results = results);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _results = []);
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Find Product',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or barcode',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Type to search products'
                          : 'No products found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = _results[i];

                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                const Color(AppColors.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2,
                            color: Color(AppColors.primary),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '₱${p.price.toStringAsFixed(2)} • Stock: ${p.stock}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: Color(AppColors.primary),
                        ),
                        onTap: () => widget.onProductSelected(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}