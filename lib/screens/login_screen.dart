import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _forgotPasswordEmailController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberDevice = false;
  String _selectedRole = 'Owner';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _forgotPasswordEmailController.dispose();
    super.dispose();
  }

  void _handleSignIn(BuildContext context) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final selectedRole = _selectedRole == 'Owner' ? UserRole.owner : UserRole.cashier;
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      expectedRole: selectedRole,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      // Navigation will be handled by the provider listener in main.dart
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in successful!')),
      );
    } else {
      _showErrorSnackBar(authProvider.error ?? 'Sign in failed');
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

  bool _isValidEmail(String email) {
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailPattern.hasMatch(email);
  }

  Future<void> _showForgotPasswordDialog() async {
    _forgotPasswordEmailController.text = _emailController.text.trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSending = false;

        return StatefulBuilder(
          builder: (stateContext, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _forgotPasswordEmailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSending,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter your account email',
                    ),
                  ),
                  if (isSending) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Sending reset email...'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final email =
                              _forgotPasswordEmailController.text.trim();

                          if (email.isEmpty) {
                            _showErrorSnackBar(
                              'Enter your email address first',
                            );
                            return;
                          }

                          if (!_isValidEmail(email)) {
                            _showErrorSnackBar(
                              'Enter a valid email address',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                          });

                          final authProvider = context.read<AuthProvider>();
                          final dialogNavigator = Navigator.of(dialogContext);
                          final success = await authProvider.resetPassword(email);

                          if (!mounted) {
                            return;
                          }

                          if (dialogContext.mounted) {
                            dialogNavigator.pop();
                          }

                          if (success) {
                            await _showResetPasswordSentDialog(email);
                          } else {
                            _showErrorSnackBar(
                              authProvider.error ??
                                  'Failed to send password reset email',
                            );
                          }
                        },
                  child: const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showResetPasswordSentDialog(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Email Sent'),
          content: Text(
            'We sent a password reset link to $email. Open your inbox and follow the instructions to continue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildLogo(),
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildTitle(),
                const SizedBox(height: AppDimens.paddingXLarge * 1.5),
                _buildRoleTabs(),
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildEmailField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildPasswordField(),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildRememberAndForgot(),
                const SizedBox(height: AppDimens.paddingXLarge),
                _buildSignInButton(context),
                const SizedBox(height: AppDimens.paddingLarge),
                _buildDivider(),
                const SizedBox(height: AppDimens.paddingLarge),
                _buildSocialSignInButtons(context),
                const SizedBox(height: AppDimens.paddingLarge),
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(AppColors.primary),
        borderRadius: BorderRadius.circular(AppDimens.radiusXLarge),
      ),
      child: const Icon(
        Icons.qr_code_2,
        size: 50,
        color: Color(AppColors.white),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'ShopScan',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppDimens.paddingSmall),
        Text(
          'Precision POS for modern retail',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(AppColors.greyDark),
              ),
        ),
      ],
    );
  }

  Widget _buildRoleTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppColors.grey),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      padding: const EdgeInsets.all(AppDimens.paddingSmall),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRole = 'Owner';
                });
              },
              child: _buildRoleTab('Owner', _selectedRole == 'Owner'),
            ),
          ),
          const SizedBox(width: AppDimens.paddingSmall),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRole = 'Cashier';
                });
              },
              child: _buildRoleTab('Cashier', _selectedRole == 'Cashier'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMedium,
        vertical: AppDimens.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(AppColors.white) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: Color(
                isSelected ? AppColors.black : AppColors.greyDark,
              ),
            ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.email_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: AppStrings.email,
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
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.lock_outlined,
          color: Color(AppColors.greyDark),
        ),
        hintText: AppStrings.password,
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

  Widget _buildRememberAndForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: _rememberDevice,
              onChanged: (value) {
                setState(() {
                  _rememberDevice = value ?? false;
                });
              },
            ),
            Text(
              AppStrings.rememberDevice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            _showForgotPasswordDialog();
          },
          child: Text(
            AppStrings.forgotPassword,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.primary),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return ElevatedButton(
          onPressed: authProvider.isLoading
              ? null
              : () => _handleSignIn(context),
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
                  AppStrings.signIn,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
        );
      },
    );
  }

  Widget _buildRegisterLink() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/register-shop');
      },
      child: RichText(
        text: TextSpan(
          text: AppStrings.dontHaveAccount,
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: AppStrings.registerShop,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(AppColors.primary),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Color(AppColors.grey),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMedium),
          child: Text(
            'Or continue with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(AppColors.greyDark),
            ),
          ),
        ),
        const Expanded(
          child: Divider(
            color: Color(AppColors.grey),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialSignInButtons(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSocialButton(
                    icon: Icons.g_mobiledata,
                    label: 'Google',
                    color: 0xFFDB4437,
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _handleGoogleSignIn(context, authProvider),
                  ),
                ),
                const SizedBox(width: AppDimens.paddingMedium),
                Expanded(
                  child: _buildSocialButton(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    color: 0xFF1877F2,
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _handleFacebookSignIn(context, authProvider),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required int color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Color(color)),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Color(color),
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Color(color)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final success = await authProvider.signInWithGoogle(
      role: _selectedRole == 'Owner' ? UserRole.owner : UserRole.cashier,
    );

    if (mounted) {
      if (!success) {
        _showErrorSnackBar(authProvider.error ?? 'Google sign-in failed');
      }
    }
  }

  Future<void> _handleFacebookSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final success = await authProvider.signInWithFacebook(
      role: _selectedRole == 'Owner' ? UserRole.owner : UserRole.cashier,
    );

    if (mounted) {
      if (!success) {
        _showErrorSnackBar(authProvider.error ?? 'Facebook sign-in failed');
      }
    }
  }
}
