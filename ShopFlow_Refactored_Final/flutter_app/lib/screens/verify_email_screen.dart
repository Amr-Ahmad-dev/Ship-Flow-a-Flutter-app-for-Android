// lib/screens/verify_email_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  String? _userId;
  bool _init = false;

  // The didChangeDependencies function initializes the screen state by extracting navigation arguments.
  // It handles a 'devCode' argument for easier testing during development.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _userId = args?['userId'] as String?;
      final dev = args?['devCode'] as String?;
      // Pre-fill in dev mode
      if (dev != null && dev.length == 6) {
        for (int i = 0; i < 6; i++) _ctrls[i].text = dev[i];
      }
      _init = true;
    }
  }

  // The dispose function cleans up controllers and focus nodes to prevent memory leaks.
  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  // Getter that joins the individual digits from the 6 controllers into a single string.
  String get _code => _ctrls.map((c) => c.text).join();

  // The _verify function communicates with the ApiService to validate the 6-digit email code.
  // It manages the loading state and error messaging for the UI.
  // PURPOSE: To confirm the user's email address in System A.
  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context
          .read<ApiService>()
          .verifyEmail(userId: _userId!, code: _code);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // The _resend function triggers a request to send a new verification code.
  // PURPOSE: To allow users to retry if they didn't receive the original email.
  // This part needs to be fixed because it currently pre-fills the 'mock' code from the server, 
  // which defeats the purpose of actual security verification.
  Future<void> _resend() async {
    if (_userId == null) return;
    try {
      final result = await context
          .read<ApiService>()
          .resendCode(userId: _userId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New code sent!')));
      final c = result['verificationCode'] as String?;
      if (c != null && c.length == 6) {
        for (int i = 0; i < 6; i++) _ctrls[i].text = c[i];
        setState(() {});
      }
    } catch (_) {}
  }

  // The build method renders the 6-digit input UI and action buttons.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.mark_email_unread_outlined,
                  size: 64, color: AppConstants.kPrimary),
              const SizedBox(height: 20),
              const Text('Check Your Email',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('We sent a 6-digit code to your email address.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),
              // 6-box digit input
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 46, height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextFormField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        _nodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _nodes[i - 1].requestFocus();
                      }
                      setState(() {});
                    },
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Email'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resend,
                child: const Text("Didn't receive it? Resend"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
