import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../staff_provider.dart';
import '../auth_provider.dart';
import 'products_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  _StaffScreenState createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StaffProvider>(context, listen: false).fetchStaffList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = Provider.of<StaffProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.role?.toUpperCase() != 'OWNER') {
      return const Scaffold(
        body: Center(child: Text('Unauthorized access. Owner only.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'OWNER'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateStaffDialog(context),
        backgroundColor: const Color(0xFFFF5722),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: staffProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : staffProvider.staffList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No staff found', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => staffProvider.fetchStaffList(),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => staffProvider.fetchStaffList(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: staffProvider.staffList.length,
                    itemBuilder: (context, index) {
                      final staff = staffProvider.staffList[index];
                      final initials = staff.username.isNotEmpty ? staff.username[0].toUpperCase() : '?';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Color(staff.isActive ? 0xFFFF5722 : 0xFF424242),
                            child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(staff.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(staff.email, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: staff.role == 'STAFF' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  staff.role,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: staff.role == 'STAFF' ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (staff.isActive)
                                IconButton(
                                  onPressed: () => _confirmDeactivate(context, staff),
                                  icon: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
                                  tooltip: 'Deactivate',
                                )
                              else
                                const Icon(Icons.block, color: Colors.white24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _confirmDeactivate(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Staff'),
        content: Text('Are you sure you want to deactivate ${staff.username}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<StaffProvider>(context, listen: false).deactivateStaff(staff.userId);
              Navigator.pop(context);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateStaffDialog(BuildContext context) {
    final _usernameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    String _role = 'STAFF';
    final _formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create Staff', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('VIEWER')),
                ],
                onChanged: (v) => _role = v!,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
                      final success = await staffProvider.createStaff({
                        'username': _usernameController.text,
                        'email': _emailController.text,
                        'password': _passwordController.text,
                        'role': _role,
                      });
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff created successfully')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(staffProvider.errorMessage ?? 'Staff creation failed. Check input.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create Staff'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
