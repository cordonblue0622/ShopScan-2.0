import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../models/user_model.dart';

class ShopRegistrationScreen extends StatefulWidget {
  const ShopRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<ShopRegistrationScreen> createState() => _ShopRegistrationScreenState();
}

class _ShopRegistrationScreenState extends State<ShopRegistrationScreen> {
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    super.dispose();
  }

  void _handleRegister(BuildContext context) async {
    // Validation
    if (_shopNameController.text.isEmpty ||
        _ownerNameController.text.isEmpty ||
        _ownerEmailController.text.isEmpty ||
        _ownerPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _shopPhoneController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    if (_ownerPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Passwords do not match');
      return;
    }

    if (_ownerPasswordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    // Register the owner and shop
    final success = await authProvider.signUpWithShop(
      email: _ownerEmailController.text.trim(),
      password: _ownerPasswordController.text,
      ownerName: _ownerNameController.text.trim(),
      shopName: _shopNameController.text.trim(),
      shopAddress: _shopAddressController.text.trim(),
      shopPhone: _shopPhoneController.text.trim(),
      role: UserRole.owner,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop registered successfully!')),
        );
        // Navigate back to login
        Navigator.of(context).pop();
      } else {
        _showErrorSnackBar(authProvider.error ?? 'Registration failed');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.white),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(AppColors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(AppColors.black)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Register Shop',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Shop Information'),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildShopNameField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildAddressField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildPhoneField(),
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildSectionHeader('Owner Information'),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildOwnerNameField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildEmailField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildPasswordField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildConfirmPasswordField(),
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildRegisterButton(context),
                const SizedBox(height: AppDimens.paddingLarge),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(AppColors.black),
          ),
    );
  }

  Widget _buildShopNameField() {
    return TextField(
      controller: _shopNameController,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.store,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Shop Name',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return TextField(
      controller: _shopAddressController,
      maxLines: 2,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.location_on_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Shop Address (Optional)',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _shopPhoneController,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.phone_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Shop Phone Number',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildOwnerNameField() {
    return TextField(
      controller: _ownerNameController,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.person_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Full Name',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _ownerEmailController,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.email_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Email Address',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _ownerPasswordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.lock_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Password',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(AppColors.greyDark),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.lock_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: 'Confirm Password',
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(AppColors.greyDark),
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingMedium,
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: authProvider.isLoading
                ? null
                : () => _handleRegister(context),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        Color(AppColors.white),
                      ),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Create Shop & Account',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          text: 'Already have an account? ',
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: 'Sign In',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(AppColors.primary),
                    fontWeight: FontWeight.bold,
                  ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).pop();
                },
            ),
          ],
        ),
      ),
    );
  }
}
