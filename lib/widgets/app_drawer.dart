import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../dashboard_provider.dart';
import '../dashboard_pin_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildSectionHeader('MAIN MENU'),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  label: 'Billing',
                  route: '/billing',
                  isActive: currentRoute == '/billing',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  route: '/inventory',
                  isActive: currentRoute == '/inventory',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.account_balance_outlined,
                  label: 'Ledgers',
                  route: '/ledger',
                  isActive: currentRoute == '/ledger',
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('SYSTEM'),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  route: '/settings',
                  isActive: currentRoute == '/settings',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  onTap: () {
                    Provider.of<DashboardPinProvider>(context, listen: false).clearAll();
                    Provider.of<DashboardProvider>(context, listen: false).clearDashboardData();
                    Provider.of<AuthProvider>(context, listen: false).logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute != '/dashboard') {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vighnaharta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Fataka Manager',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? route,
    VoidCallback? onTap,
    bool isActive = false,
    bool isDestructive = false,
  }) {
    final activeColor = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF2563EB);
    final inactiveColor = const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap ?? () {
          if (route != null) {
            // If we are leaving the dashboard, revoke access to ensure it locks
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute == '/dashboard' && route != '/dashboard') {
              Provider.of<DashboardPinProvider>(context, listen: false).revokeAccess();
            }
            Navigator.pushReplacementNamed(context, route);
          }
        },
        leading: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : (isDestructive ? const Color(0xFFEF4444).withOpacity(0.8) : const Color(0xFF1E293B)),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close drawer
          // If leaving dashboard, revoke access
          if (currentRoute == '/dashboard') {
            Provider.of<DashboardPinProvider>(context, listen: false).revokeAccess();
          }
          Navigator.pushNamed(context, '/settings');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admin User',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.settings_outlined, size: 18, color: const Color(0xFF64748B).withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
