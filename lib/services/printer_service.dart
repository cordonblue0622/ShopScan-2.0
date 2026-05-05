import '../models/transaction_model.dart';

class PrinterService {
  // Initialize printer connection
  Future<void> initializePrinter() async {
    try {
      // Implementation for printer initialization
      // This will vary based on the actual printer library used
    } catch (e) {
      throw Exception('Failed to initialize printer: $e');
    }
  }

  // Generate receipt text
  String generateReceiptText(TransactionModel transaction, String storeName) {
    StringBuffer receipt = StringBuffer();

    receipt.writeln('═══════════════════════════════════');
    receipt.writeln(storeName);
    receipt.writeln('═══════════════════════════════════');
    receipt.writeln('');

    receipt.writeln('Transaction ID: #${transaction.id}');
    receipt.writeln('Date: ${_formatDateTime(transaction.timestamp)}');
    receipt.writeln('');

    receipt.writeln('───────────────────────────────────');
    receipt.writeln('ITEMS');
    receipt.writeln('───────────────────────────────────');

    for (final item in transaction.items) {
      final itemTotal = item.price * item.quantity;
      receipt.writeln(item.productName);
      receipt.writeln(
          '  ${item.quantity} x \$${_formatPrice(item.price)} = \$${_formatPrice(itemTotal)}');
    }

    receipt.writeln('');
    receipt.writeln('───────────────────────────────────');

    receipt.writeln(
        'Subtotal:        \$${_formatPrice(transaction.subtotal)}');
    receipt.writeln('Tax (${_calculateTaxRate(transaction)}%):           \$${_formatPrice(transaction.tax)}');

    if (transaction.discount > 0) {
      receipt.writeln(
          'Discount:        -\$${_formatPrice(transaction.discount)}');
    }

    receipt.writeln('───────────────────────────────────');
    receipt.writeln('TOTAL:           \$${_formatPrice(transaction.total)}');
    receipt.writeln('───────────────────────────────────');
    receipt.writeln('');

    receipt.writeln('Thank you for shopping at $storeName!');
    receipt.writeln('═══════════════════════════════════');

    return receipt.toString();
  }

  // Print receipt
  Future<void> printReceipt(
    TransactionModel transaction,
    String storeName,
  ) async {
    try {
      final receiptText = generateReceiptText(transaction, storeName);
      // Implementation for actual printing
      // This will use the esc_pos_printer or similar library
    } catch (e) {
      throw Exception('Failed to print receipt: $e');
    }
  }

  // Format price
  String _formatPrice(double price) {
    return price.toStringAsFixed(2);
  }

  // Format datetime
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Calculate tax rate
  double _calculateTaxRate(TransactionModel transaction) {
    if (transaction.subtotal == 0) return 0;
    return (transaction.tax / transaction.subtotal) * 100;
  }
}
