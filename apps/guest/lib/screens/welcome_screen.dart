import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.bed,
      iconColor: Color(0xFF4CAF50),
      title: 'Book & Stay',
      subtitle:
          'Browse available rooms, check availability on a live calendar, and reserve in seconds.',
      highlight: 'No front desk queues.',
    ),
    _Slide(
      icon: Icons.restaurant,
      iconColor: Color(0xFF2196F3),
      title: 'Order Anything',
      subtitle:
          'Scan your table QR, browse the menu, add items to cart and track your order live.',
      highlight: 'Food & drinks, delivered.',
    ),
    _Slide(
      icon: Icons.account_balance_wallet,
      iconColor: Color(0xFFFF9800),
      title: 'Earn & Pay',
      subtitle:
          'Top up your wallet with MTN, Airtel, or M-Pesa. Earn loyalty points on every spend.',
      highlight: 'One tap checkout.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1E2A3A),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 20),
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Primary button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sign-in link
            TextButton(
              onPressed: () {
                _finish(); // mark done, then home will show login sheet
              },
              child: const Text(
                'Already have an account?  Sign In',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String highlight;

  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.highlight,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: slide.iconColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(slide.icon, size: 64, color: slide.iconColor),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            slide.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // Highlight pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: slide.iconColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              slide.highlight,
              style: TextStyle(
                color: slide.iconColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
