/// App color constants
class AppColors {
  // Primary colors
  static const primary = 0xFF0052CC;
  static const primaryDark = 0xFF003B99;
  static const primaryLight = 0xFF4D9FFF;

  // Neutral colors
  static const white = 0xFFFFFFFF;
  static const black = 0xFF000000;
  static const grey = 0xFFF5F5F5;
  static const greyDark = 0xFF666666;
  static const greyLight = 0xFFE0E0E0;

  // Status colors
  static const success = 0xFF10B981;
  static const error = 0xFFEF4444;
  static const warning = 0xFFFB923C;
  static const info = 0xFF3B82F6;

  // Special colors
  static const orange = 0xFFC85A17;
  static const lightBg = 0xFFF8FAFC;
  static const borderColor = 0xFFE2E8F0;
}

/// App string constants
class AppStrings {
  // Auth
  static const String signIn = 'Sign In';
  static const String email = 'Business Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot?';
  static const String rememberDevice = 'Remember device';
  static const String dontHaveAccount = 'Don\'t have an account? ';
  static const String registerShop = 'Register Shop';

  // Navigation
  static const String home = 'Home';
  static const String scan = 'Scan';
  static const String sales = 'Sales';
  static const String stocks = 'Stocks';
  static const String profile = 'Profile';
  static const String dashboard = 'Dashboard';
  static const String products = 'Products';
  static const String reports = 'Reports';
  static const String cashiers = 'Cashiers';

  // Cashier
  static const String startShift = 'Start Shift';
  static const String endShift = 'End Shift';
  static const String scanProduct = 'Scan Product';
  static const String newSale = 'New Sale';
  static const String todaysSales = 'Today\'s Sales';

  // Transactions
  static const String checkout = 'Checkout';
  static const String cancel = 'Cancel';
  static const String total = 'Total';
  static const String subtotal = 'Subtotal';
  static const String tax = 'Tax';
  static const String discount = 'Discount';
  static const String paymentSuccessful = 'Payment Successful';

  // Receipt
  static const String printReceipt = 'Print Receipt';
  static const String shareExport = 'Share/Export';
  static const String receipt = 'RECEIPT';
  static const String done = 'Done';

  // Products
  static const String addProduct = 'Add Product';
  static const String manageInventory = 'Manage your inventory and stock levels';
  static const String searchByName = 'Search by name, category or barcode';
  static const String totalItems = 'TOTAL ITEMS';
  static const String outOfStock = 'OUT OF STOCK';
  static const String lowStock = 'LOW STOCK';
  static const String inventoryValue = 'INVENTORY VALUE';

  // Error messages
  static const String errorEmptyEmail = 'Email cannot be empty';
  static const String errorInvalidEmail = 'Please enter a valid email';
  static const String errorEmptyPassword = 'Password cannot be empty';
  static const String errorWeakPassword = 'Password is too weak';
  static const String errorAuthFailed = 'Authentication failed';
  static const String errorNetworkError = 'Network error occurred';
}

/// App dimension constants
class AppDimens {
  // Padding and margins
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Button sizes
  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 44.0;

  // Card sizes
  static const double cardElevation = 2.0;
}
