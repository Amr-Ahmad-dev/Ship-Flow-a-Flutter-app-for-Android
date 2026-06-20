// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _deleting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // The _login function gathers user credentials from text controllers and calls the ApiService's login method.
  // It manages a local '_loading' state to provide visual feedback.
  // Upon successful login, it navigates the user to the Home screen.
  // If an error occurs, it displays the error message in a SnackBar.
  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await context.read<ApiService>().login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  // The _deleteAll function acts as a high-risk administrative trigger.
  // It first prompts the user with a confirmation dialog. 
  // If confirmed, it communicates with the ApiService to perform a global data wipe across both System A and System B.
  // PURPOSE: Primarily for development/testing to reset the environment.
  // EDGE CASE: If this button is accidentally made available to end-users in production, it would be catastrophic.
  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Everything?'),
        content: const Text('This will wipe ALL data from System A and System B simultaneously. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE ALL', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await context.read<ApiService>().deleteAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All System Data Wiped Successfully')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      } finally {
        if (mounted) setState(() => _deleting = false);
      }
    }
  }

  // The build method renders the login interface. 
  // It includes email/password input fields, a login button, and a link to the registration screen.
  // It also includes a specialized 'DELETE ALL SYSTEM DATA' button as per requirements.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 80, color: AppConstants.kPrimary),
              const SizedBox(height: 16),
              const Text('ShopFlow', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 16),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login'),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Sign up. "Seven up. "')),
              
              const Divider(height: 64),
              
              // REQUIREMENT: Delete All button
              OutlinedButton.icon(
                onPressed: _deleting ? null : _deleteAll,
                icon: _deleting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('DELETE ALL SYSTEM DATA', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
