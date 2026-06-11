import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2563EB)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_fire_department_outlined, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text('Vighnaharta Fataka', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Manager Dashboard', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Billing'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/billing');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Inventory'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/inventory');
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Ledgers'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/ledger');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
