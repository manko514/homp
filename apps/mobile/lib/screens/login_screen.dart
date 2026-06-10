import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hotelCode = TextEditingController(text: 'demo');
  final _email = TextEditingController(text: 'admin@homp.demo');
  final _password = TextEditingController(text: 'admin123');
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tenant = await ApiService.lookupTenant(_hotelCode.text.trim());
      final tenantId = tenant['id']?.toString();
      if (tenantId == null) throw Exception('Invalid tenant response');
      final result = await ApiService.login(
        _email.text.trim(),
        _password.text,
        tenantId,
      );
      final token = (result['access_token'] ?? result['accessToken'])?.toString();
      if (token == null) throw Exception('No token in response');
      await ApiService.saveToken(token);
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.hotel, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('HOMP',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 6),
                Text('Hospitality Operations Platform',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                const SizedBox(height: 40),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sign In',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 4),
                      const Text('Enter your credentials to continue',
                          style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                      const SizedBox(height: 24),

                      // Hotel code
                      _buildLabel('Hotel Code'),
                      const SizedBox(height: 6),
                      _buildField(
                        controller: _hotelCode,
                        hint: 'demo',
                        icon: Icons.domain,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      _buildField(
                        controller: _email,
                        hint: 'admin@homp.demo',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      _buildField(
                        controller: _password,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                            color: AppTheme.textLight,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppTheme.red, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Sign In',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textLight, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textLight),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.navy, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hotelCode.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
