import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../settings_provider.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _receiptMessageController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _shopNameController.text = settings.shopName;
    _shopAddressController.text = settings.shopAddress;
    _shopPhoneController.text = settings.shopPhone;
    _gstNumberController.text = settings.gstNumber;
    _receiptMessageController.text = settings.receiptMessage;
    _lowStockThresholdController.text = settings.lowStockThreshold.toString();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _gstNumberController.dispose();
    _receiptMessageController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

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
              title: 'BUSINESS PROFILE',
              icon: Icons.store_outlined,
              children: [
                _buildTextField('Shop Name', _shopNameController),
                _buildTextField('Address', _shopAddressController, maxLines: 2),
                _buildTextField('Contact Numbers', _shopPhoneController),
                _buildTextField('GST Number', _gstNumberController),
                _buildTextField('Receipt Message (Footer)', _receiptMessageController),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        settings.updateBusinessProfile(
                          shopName: _shopNameController.text,
                          shopAddress: _shopAddressController.text,
                          shopPhone: _shopPhoneController.text,
                          gstNumber: _gstNumberController.text,
                          receiptMessage: _receiptMessageController.text,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            backgroundColor: Color(0xFF16A34A),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                      label: const Text('Save Profile', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'PRINT & HARDWARE',
              icon: Icons.print_outlined,
              children: [
                _buildSwitchTile(
                  'Auto-Print Dialog',
                  'Automatically open print dialog after saving invoice',
                  settings.autoPrint,
                  (val) => settings.setAutoPrint(val),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Printer Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRadioTile('A4 Size (Standard)', 'A4', settings.printerType, (val) => settings.setPrinterType(val!)),
                      ),
                      Expanded(
                        child: _buildRadioTile('Thermal (POS)', 'Thermal', settings.printerType, (val) => settings.setPrinterType(val!)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'INVENTORY & STOCK',
              icon: Icons.inventory_2_outlined,
              children: [
                _buildTextField(
                  'Low Stock Threshold',
                  _lowStockThresholdController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final intVal = int.tryParse(val);
                    if (intVal != null) settings.setLowStockThreshold(intVal);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'USER & SECURITY',
              icon: Icons.security_outlined,
              children: [
                ListTile(
                  title: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Update your login credentials'),
                  leading: const Icon(Icons.lock_outline, color: Color(0xFFEF4444)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password change feature coming soon')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildSwitchTile(
                  'Auto-Logout',
                  'Lock app when idle for 10 minutes',
                  false,
                  (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Auto-logout timer updated')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'SYSTEM & DATA',
              icon: Icons.settings_applications_outlined,
              children: [
                ListTile(
                  title: const Text('Export Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export Inventory and Sales to Excel'),
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF2563EB)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting to Excel...')),
                          );
                        },
                        child: const Text('EXCEL', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting to CSV...')),
                          );
                        },
                        child: const Text('CSV', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
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
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF2563EB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildRadioTile(String title, String value, String groupValue, Function(String?) onChanged) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontSize: 13)),
      value: value,groupValue: groupValue,
      onChanged: onChanged,
      activeColor: const Color(0xFF2563EB),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
