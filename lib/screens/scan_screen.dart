import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/auth_provider.dart';
import '../core/utils/cart_provider.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import 'cart_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────────
  final _firestoreService = FirestoreService();

  // ── Scanner ──────────────────────────────────────────────────────────────────
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  String? _lastScanned;

  // ── Cart bounce animation ────────────────────────────────────────────────────
  late final AnimationController _cartBounce;
  late final Animation<double> _cartScale;

  // ── Manual input ─────────────────────────────────────────────────────────────
  final _manualController = TextEditingController();
  bool _showManualInput = false;

  // ── Status label ─────────────────────────────────────────────────────────────
  String? _statusLabel;

  @override
  void initState() {
    super.initState();

    _scannerController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.qrCode,
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scannerController.start();
    });

    _cartBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _cartBounce, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cartBounce.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // ── Barcode detection callback ───────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
      if (value.isEmpty) continue;

      debugPrint('SCANNER DETECTED');
      debugPrint('BARCODE VALUE: $value');

      if (value == _lastScanned) return;
      _lastScanned = value;

      _processBarcode(value);
      return;
    }
  }

  // ── Core barcode processing ───────────────────────────────────────────────────
  Future<void> _processBarcode(String barcode) async {
    if (!mounted || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Check cashier shift
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;

      if (auth.isCashier && user != null) {
        final shift =
            await _firestoreService.getActiveShiftForCashier(user.id);

        if (shift == null) {
          if (!mounted) return;
          _setStatus('Start your shift first before scanning items.');
          await _showWarning(
            'Not On Duty',
            'You need to start your shift before scanning items.',
          );
          return;
        }
      }

      // 2. Resolve shop
      final shopId = context.read<AuthProvider>().currentUser?.shopId;
      debugPrint('CURRENT SHOP ID: $shopId');

      if (shopId == null || shopId.isEmpty) {
        _setStatus('No shop assigned to this account.');
        await _showWarning(
          'No Shop Assigned',
          'No shop is assigned to this account. Contact your administrator.',
        );
        return;
      }

      // 3. Look up product
      final product = await _firestoreService.getProductByBarcode(
        barcode,
        shopId: shopId,
      );

      if (!mounted) return;

      if (product == null) {
        debugPrint('PRODUCT NOT FOUND: $barcode');
        _setStatus('Barcode not found in inventory.');
        await _showWarning(
          'Product Not Found',
          'Barcode "$barcode" was not found in your inventory.',
        );
        return;
      }

      debugPrint('PRODUCT FOUND: ${product.name}');

      if (product.stock <= 0) {
        _setStatus('${product.name} is out of stock.');
        await _showWarning(
          'Out of Stock',
          '${product.name} is currently out of stock.',
        );
        return;
      }

      // 4. Choose quantity
      if (!mounted) return;
      final qty = await _showQuantityPicker(product);
      if (qty == null || !mounted) return;

      // 5. Add to cart
      context.read<CartProvider>().addItem(TransactionItemModel(
            productId: product.id,
            productName: product.name,
            price: product.price,
            quantity: qty,
            sku: product.barcode,
            imageUrl: product.imageUrl,
          ));

      _cartBounce.forward(from: 0);
      _setStatus('Last: ${product.name} × $qty');

      await _showSuccess('Added to Cart!',
          '${product.name} × $qty added to your cart.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastScanned = null;
        });
      }
    }
  }

  // ── Status label helper ──────────────────────────────────────────────────────
  void _setStatus(String msg) {
    if (mounted) setState(() => _statusLabel = msg);
  }

  // ── Torch toggle ─────────────────────────────────────────────────────────────
  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────
  Future<void> _showWarning(String title, String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: Color(AppColors.warning), size: 52),
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primary),
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccess(String title, String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle_rounded,
            color: Color(AppColors.success), size: 52),
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primary),
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Quantity picker ──────────────────────────────────────────────────────────
  Future<int?> _showQuantityPicker(ProductModel product) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        int qty = 1;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                // product row
                Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          const Color(AppColors.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: Color(AppColors.primary)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            '₱${product.price.toStringAsFixed(2)}  •  Stock: ${product.stock}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600),
                          ),
                        ]),
                  ),
                ]),
                const SizedBox(height: 24),
                Text('Quantity',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _qtyBtn(
                        icon: Icons.remove,
                        enabled: qty > 1,
                        onTap: () => setSheet(() => qty--)),
                    const SizedBox(width: 28),
                    Text('$qty',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 28),
                    _qtyBtn(
                        icon: Icons.add,
                        enabled: qty < product.stock,
                        onTap: () => setSheet(() => qty++)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, qty),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                        'Add to Cart  •  ₱${(product.price * qty).toStringAsFixed(2)}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _qtyBtn({
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
        child: Icon(icon,
            color: enabled
                ? const Color(AppColors.primary)
                : Colors.grey.shade400),
      ),
    );
  }

  // ── Find Product bottom sheet ────────────────────────────────────────────────
  void _showFindProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (ctx, scroll) => _ProductSearchSheet(
            scrollController: scroll,
            firestoreService: _firestoreService,
            onProductSelected: (product) {
              Navigator.pop(ctx);
              _lastScanned = null;
              _processBarcode(product.barcode);
            },
          ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Camera view (takes remaining space) ──────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Camera feed
                  MobileScanner(
                    controller: _scannerController,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) =>
                        _buildErrorView(error),
                    placeholderBuilder: (context, child) => const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                  // Torch button (top-left)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: ValueListenableBuilder<TorchState>(
                      valueListenable: _scannerController.torchState,
                      builder: (_, state, __) => GestureDetector(
                        onTap: _toggleTorch,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: state == TorchState.on
                                ? const Color(AppColors.primary)
                                    .withOpacity(0.9)
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            state == TorchState.on
                                ? Icons.flashlight_off_rounded
                                : Icons.flashlight_on_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // "Align barcode" hint (top-centre)
                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Align barcode with frame',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),

                  // Scan frame (centre)
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(AppColors.primary).withOpacity(0.6),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),

                  // Cart FAB (bottom-right)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Consumer<CartProvider>(
                      builder: (_, cart, __) => ScaleTransition(
                        scale: _cartScale,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()),
                          ),
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
                                  child: Icon(Icons.shopping_cart_rounded,
                                      color: Colors.white, size: 26),
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
                                          minWidth: 20, minHeight: 20),
                                      child: Text(
                                        '${cart.itemCount}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Processing indicator
                  if (_isProcessing)
                    const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),

            // ── Bottom panel ─────────────────────────────────────────────────
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Manual input row
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showManualInput = !_showManualInput),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEDED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(Icons.keyboard_rounded,
                            size: 22, color: Color(0xFF5A5A5A)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Manual Input',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333))),
                        ),
                        Icon(
                          _showManualInput
                              ? Icons.keyboard_arrow_down
                              : Icons.chevron_right,
                          color: const Color(0xFF999999),
                        ),
                      ]),
                    ),
                  ),

                  if (_showManualInput) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualController,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Enter barcode or SKU',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(AppColors.borderColor)),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            final code = _manualController.text.trim();
                            if (code.isNotEmpty) {
                              _lastScanned = null;
                              _processBarcode(code);
                              _manualController.clear();
                            }
                          },
                        ),
                      ),
                      onSubmitted: (code) {
                        final c = code.trim();
                        if (c.isNotEmpty) {
                          _lastScanned = null;
                          _processBarcode(c);
                          _manualController.clear();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Find Product button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showFindProduct,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Find Product',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status label
                  if (_statusLabel != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 18, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera error view ────────────────────────────────────────────────────────
  Widget _buildErrorView(MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('Camera Unavailable',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'Check camera permissions, then tap Retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  await _scannerController.stop();
                  await _scannerController.start();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Product search bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet({
    required this.scrollController,
    required this.firestoreService,
    required this.onProductSelected,
  });

  final ScrollController scrollController;
  final FirestoreService firestoreService;
  final void Function(ProductModel product) onProductSelected;

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

  Future<void> _search(String query) async {
    _query = query.trim().toLowerCase();
    if (_query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final shopId = context.read<AuthProvider>().currentUser?.shopId;
      final results = await widget.firestoreService
          .searchProducts(_query, shopId: shopId);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Find Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          // Search field
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
                  borderSide: BorderSide.none),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 10),
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
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2,
                              color: Color(AppColors.primary), size: 20),
                        ),
                        title: Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '₱${p.price.toStringAsFixed(2)}  •  Stock: ${p.stock}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: Color(AppColors.primary)),
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
