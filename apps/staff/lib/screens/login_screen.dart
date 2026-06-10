import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/staff_api_service.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _subdomainCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _tenantVerified = false;
  String? _tenantId;
  String? _tenantName;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSubdomain();
  }

  Future<void> _loadSavedSubdomain() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('staff_subdomain');
    if (saved != null) {
      _subdomainCtrl.text = saved;
      // Auto-verify saved subdomain
      await _verifyTenant(autoVerify: true);
    }
  }

  Future<void> _verifyTenant({bool autoVerify = false}) async {
    final subdomain = _subdomainCtrl.text.trim().toLowerCase();
    if (subdomain.isEmpty) {
      setState(() => _error = 'Enter your hotel subdomain');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final tenant = await StaffApiService.lookupTenant(subdomain);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('staff_subdomain', subdomain);
      setState(() {
        _tenantId = tenant['id'] as String;
        _tenantName = tenant['name'] as String?;
        _tenantVerified = true;
      });
    } catch (e) {
      if (!autoVerify) {
        setState(() => _error = 'Hotel not found. Check subdomain.');
      }
      setState(() => _tenantVerified = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    if (_tenantId == null) {
      setState(() => _error = 'Hotel not verified');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final data = await StaffApiService.login(email, password, _tenantId!);
      final token = data['accessToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token == null || user == null) throw Exception('Invalid server response');

      await StaffApiService.saveToken(token);
      await StaffApiService.saveUser(user);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ShellScreen(user: user)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _subdomainCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.hotel, size: 52, color: Color(0xFF1565C0)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'HOMP Staff',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text('Staff Portal', style: TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 36),

                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Hotel subdomain
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _subdomainCtrl,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _verifyTenant(),
                                enabled: !_tenantVerified,
                                decoration: InputDecoration(
                                  labelText: 'Hotel Subdomain',
                                  hintText: 'e.g. grandhotel',
                                  prefixIcon: const Icon(Icons.hotel),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _tenantVerified
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : null,
                                ),
                              ),
                            ),
                            if (!_tenantVerified) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _loading ? null : _verifyTenant,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Find'),
                              ),
                            ],
                          ],
                        ),

                        // Hotel name confirmed
                        if (_tenantVerified && _tenantName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(_tenantName!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(() { _tenantVerified = false; _tenantId = null; _tenantName = null; }),
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        ],

                        if (_tenantVerified) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
