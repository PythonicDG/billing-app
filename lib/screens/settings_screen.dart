import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dashboard_pin_provider.dart';
import '../auth_provider.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final pinProvider = Provider.of<DashboardPinProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSection(
              title: 'USER & SECURITY',
              icon: Icons.security_outlined,
              children: [
                ListTile(
                  title: const Text('Dashboard PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    pinProvider.hasPinSet
                        ? 'Dashboard is protected with a PIN'
                        : 'No PIN set – dashboard is accessible to all',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  leading: Icon(
                    pinProvider.hasPinSet
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    color: pinProvider.hasPinSet
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pinProvider.hasPinSet)
                        TextButton(
                          onPressed: () => _showRemoveDashboardPinDialog(pinProvider),
                          child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ),
                      TextButton(
                        onPressed: () => _showSetDashboardPinDialog(pinProvider),
                        child: Text(
                          pinProvider.hasPinSet
                              ? 'Change'
                              : 'Set PIN',
                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Update your login credentials'),
                  leading: const Icon(Icons.lock_outline, color: Color(0xFFEF4444)),
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'SYSTEM & DATA',
              icon: Icons.settings_applications_outlined,
              children: [
                const ListTile(
                  title: Text('App Version', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('v1.0.0'),
                  trailing: Badge(
                    label: Text('LATEST'),
                    backgroundColor: Color(0xFFDCFCE7),
                    textColor: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...children,
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showSetDashboardPinDialog(DashboardPinProvider pinProvider) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final isPinSet = pinProvider.hasPinSet;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isPinSet ? 'Change Dashboard PIN' : 'Set Dashboard PIN',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPinSet 
                  ? 'Enter current PIN and a new 4-6 digit PIN.'
                  : 'Users will need this 4-6 digit PIN to access the Dashboard.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (isPinSet) ...[
                TextField(
                  controller: currentPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Current PIN',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPinController,
                obscureText: true,
                autofocus: !isPinSet,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: isPinSet ? 'New PIN' : 'Enter PIN (4-6 digits)',
                  counterText: '',
                  prefixIcon: const Icon(Icons.dialpad_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPin = currentPinController.text.trim();
                final newPin = newPinController.text.trim();

                if (isPinSet && currentPin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter current PIN'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                if (newPin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New PIN cannot be empty'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }
                if (newPin.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be at least 4 digits'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }
                
                // Show loading indicator
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                if (isPinSet) {
                  final isVerified = await pinProvider.verifyPin(currentPin);
                  if (!isVerified) {
                    if (mounted) {
                      Navigator.pop(ctx); // pop loading
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(pinProvider.errorMessage ?? 'Incorrect current PIN'),
                        backgroundColor: const Color(0xFFEF4444),
                      ));
                    }
                    return;
                  }
                }
                
                final success = await pinProvider.setPin(newPin);
                
                if (mounted) {
                  Navigator.pop(ctx); // pop loading
                  Navigator.pop(ctx); // pop dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'Dashboard PIN updated' : (pinProvider.errorMessage ?? 'Failed to update PIN')),
                    backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Save PIN', overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveDashboardPinDialog(DashboardPinProvider pinProvider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Remove Dashboard PIN',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your current PIN to remove dashboard protection.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'Enter current PIN',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = controller.text.trim();
                if (pin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your PIN'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                // Show loading indicator
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                // 1. Verify PIN first
                final isVerified = await pinProvider.verifyPin(pin);
                
                if (!isVerified) {
                  if (mounted) {
                    Navigator.pop(ctx); // pop loading
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(pinProvider.errorMessage ?? 'Incorrect PIN'),
                      backgroundColor: const Color(0xFFEF4444),
                    ));
                  }
                  return;
                }

                // 2. If verified, remove PIN
                final success = await pinProvider.removePin();
                
                if (mounted) {
                  Navigator.pop(ctx); // pop loading
                  Navigator.pop(ctx); // pop dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'Dashboard PIN removed' : 'Failed to remove PIN'),
                    backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Remove', overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Change Password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Old Password',
                  prefixIcon: const Icon(Icons.lock_open),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final oldPass = oldPasswordController.text;
                final newPass = newPasswordController.text;
                final confirmPass = confirmPasswordController.text;

                if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                if (newPass.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New password must be at least 8 characters'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                // Show loading
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final success = await authProvider.changePassword(oldPass, newPass);

                if (mounted) {
                  Navigator.pop(ctx); // pop loading
                  
                  if (success) {
                    Navigator.pop(ctx); // pop dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully'), backgroundColor: Color(0xFF16A34A)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to change password'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Update', overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      },
    );
  }
}
