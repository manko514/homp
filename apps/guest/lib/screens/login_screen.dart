import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String tenantId;
  final String hotelName;
  final VoidCallback onSuccess;

  const LoginScreen({
    super.key,
    required this.tenantId,
    required this.hotelName,
    required this.onSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  // Login
  final _loginEmailCtrl    = TextEditingController();
  final _loginPhoneCtrl    = TextEditingController();
  final _loginPassCtrl     = TextEditingController();
  bool _loginWithPhone     = false;

  // Register
  final _regNameCtrl       = TextEditingController();
  final _regEmailCtrl      = TextEditingController();
  final _regPhoneCtrl      = TextEditingController();
  final _regPassCtrl       = TextEditingController();
  final _regConfirmCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmailCtrl.dispose(); _loginPhoneCtrl.dispose(); _loginPassCtrl.dispose();
    _regNameCtrl.dispose(); _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose(); _regPassCtrl.dispose(); _regConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _loginWithPhone ? null : _loginEmailCtrl.text.trim();
    final phone = _loginWithPhone ? _loginPhoneCtrl.text.trim() : null;
    final pass  = _loginPassCtrl.text;

    if ((email?.isEmpty ?? true) && (phone?.isEmpty ?? true)) {
      setState(() => _error = _loginWithPhone ? 'Phone number required' : 'Email required');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Password required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.login(widget.tenantId, email: email, phone: phone, password: pass);
      if (mounted) widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final name  = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final pass  = _regPassCtrl.text;
    final conf  = _regConfirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Name, email and password required');
      return;
    }
    if (pass != conf) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.register(widget.tenantId, name: name, email: email, password: pass, phone: phone);
      if (mounted) widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.hotelName, style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50))),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Sign In'), Tab(text: 'Create Account')],
          onTap: (_) => setState(() => _error = null),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_loginTab(), _registerTab()],
      ),
    );
  }

  Widget _loginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _card(children: [
            if (_error != null) _errorBox(_error!),

            // Email / Phone toggle
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() { _loginWithPhone = false; _error = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_loginWithPhone ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !_loginWithPhone ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : [],
                    ),
                    child: Center(child: Text('Email', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: !_loginWithPhone ? const Color(0xFF1E2A3A) : const Color(0xFF888EA8),
                    ))),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() { _loginWithPhone = true; _error = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _loginWithPhone ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _loginWithPhone ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : [],
                    ),
                    child: Center(child: Text('Phone', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: _loginWithPhone ? const Color(0xFF1E2A3A) : const Color(0xFF888EA8),
                    ))),
                  ),
                )),
              ]),
            ),

            // Email or Phone field
            if (!_loginWithPhone) ...[
              _label('Email'),
              _field(_loginEmailCtrl, 'you@example.com', keyboardType: TextInputType.emailAddress),
            ] else ...[
              _label('Phone Number'),
              _field(_loginPhoneCtrl, '+1 555 000 0000', keyboardType: TextInputType.phone),
            ],
            const SizedBox(height: 14),
            _label('Password'),
            _passField(_loginPassCtrl, 'Your password'),
            const SizedBox(height: 20),
            _btn('Sign In', _loading ? null : _login),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => _tabs.animateTo(1),
                child: const Text("Don't have an account? Create one",
                    style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
              ),
            ),
          ]),

          // Social login divider
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Divider(color: Colors.white24)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: Colors.white24)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _socialBtn(
              icon: 'G',
              label: 'Google',
              color: const Color(0xFFEA4335),
              onTap: _loading ? () {} : _googleSignIn,
            )),
            const SizedBox(width: 12),
            Expanded(child: _socialBtn(
              icon: '',
              label: 'Apple',
              color: Colors.white,
              textColor: const Color(0xFF1E2A3A),
              useAppleIcon: true,
              onTap: _loading ? () {} : _appleSignIn,
            )),
          ]),
          const SizedBox(height: 24),
          _guestNote(),
        ],
      ),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn(scopes: ['email', 'profile']).signIn();
      if (googleUser == null) { setState(() => _loading = false); return; }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Google did not return an ID token');
      await AuthService.socialLogin(widget.tenantId, provider: 'google', idToken: idToken);
      if (mounted) widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Apple did not return an identity token');
      await AuthService.socialLogin(widget.tenantId, provider: 'apple', idToken: idToken);
      if (mounted) widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _socialBtn({
    required String icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    bool useAppleIcon = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (useAppleIcon)
            const Icon(Icons.apple, size: 18, color: Color(0xFF1E2A3A))
          else
            Text(icon, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
        ]),
      ),
    );
  }

  Widget _registerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _card(children: [
            if (_error != null) _errorBox(_error!),
            _label('Full Name'),
            _field(_regNameCtrl, 'John Smith'),
            const SizedBox(height: 14),
            _label('Email'),
            _field(_regEmailCtrl, 'you@example.com',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _label('Phone (optional)'),
            _field(_regPhoneCtrl, '+1 555 000 0000',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _label('Password'),
            _passField(_regPassCtrl, 'At least 6 characters'),
            const SizedBox(height: 14),
            _label('Confirm Password'),
            _passField(_regConfirmCtrl, 'Repeat password'),
            const SizedBox(height: 20),
            _btn('Create Account', _loading ? null : _register),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => _tabs.animateTo(0),
                child: const Text('Already have an account? Sign in',
                    style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _guestNote(),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.grey),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: _loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _guestNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white54, size: 16),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Sign in to book rooms, check-in digitally, earn loyalty points, and view your bill.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
