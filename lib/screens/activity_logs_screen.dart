import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../constants.dart';
import '../widgets/app_drawer.dart';

/// Owner-only list of who created / edited / deleted what, when, and from which IP.
class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _logs = [];
  String? _nextUrl;
  int _total = 0;
  bool _loading = false;
  String? _error;

  String _action = '';      // '' = all
  String _entityType = '';  // '' = all

  static const _actions = {
    '': 'All',
    'CREATE': 'Created',
    'UPDATE': 'Edited',
    'DELETE': 'Deleted',
    'PAYMENT': 'Payments',
  };

  static const _entityTypes = {
    '': 'Everything',
    'Invoice': 'Bills',
    'Customer': 'Customers',
    'Product': 'Products',
    'Category': 'Categories',
    'Settings': 'Settings',
    'Dashboard PIN': 'Dashboard PIN',
    'User': 'Users',
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = reset
          ? await _api.get(ApiConstants.auditLogsUrl, queryParams: {
              if (_action.isNotEmpty) 'action': _action,
              if (_entityType.isNotEmpty) 'entity_type': _entityType,
              if (_searchController.text.trim().isNotEmpty) 'search': _searchController.text.trim(),
            })
          : await _api.get(_nextUrl!);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          if (reset) _logs.clear();
          _logs.addAll((data['results'] as List).cast<Map<String, dynamic>>());
          _nextUrl = data['next'];
          _total = data['count'] ?? _logs.length;
        });
      } else if (response.statusCode == 403) {
        setState(() => _error = 'Only the owner can view activity logs.');
      } else {
        setState(() => _error = 'Could not load activity logs (${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Activity logs error: $e');
      if (mounted) setState(() => _error = 'Connection error');
    }

    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Activity Logs',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search bill no., customer, product, user…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _entityType,
                    items: _entityTypes.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _entityType = v ?? '');
                      _load(reset: true);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _actions.entries.map((e) {
              return ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: _action == e.key,
                onSelected: (_) {
                  setState(() => _action = e.key);
                  _load(reset: true);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    if (_loading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_logs.isEmpty) {
      return const Center(
        child: Text('No activity found.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _logs.length + 1,
        itemBuilder: (context, index) {
          if (index == _logs.length) return _buildFooter();
          return _LogTile(log: _logs[index]);
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _nextUrl == null
            ? Text('Showing all $_total entries', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
            : _loading
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: () => _load(),
                    child: Text('Load more (${_logs.length} of $_total)'),
                  ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogTile({required this.log});

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  ({IconData icon, Color color}) _style(String action) {
    switch (action) {
      case 'CREATE':
        return (icon: Icons.add_circle_outline, color: const Color(0xFF16A34A));
      case 'UPDATE':
        return (icon: Icons.edit_outlined, color: const Color(0xFF2563EB));
      case 'DELETE':
        return (icon: Icons.delete_outline, color: const Color(0xFFEF4444));
      case 'PAYMENT':
        return (icon: Icons.payments_outlined, color: const Color(0xFFD97706));
      default:
        return (icon: Icons.info_outline, color: const Color(0xFF64748B));
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : _dateFormat.format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(log['action'] ?? '');
    final user = (log['user_label'] as String?)?.isNotEmpty == true ? log['user_label'] : 'System';
    final ip = log['ip_address'] ?? '-';
    final reason = (log['reason'] as String?) ?? '';
    final details = log['details'] is Map ? Map<String, dynamic>.from(log['details']) : <String, dynamic>{};
    final detailRows = _detailRows(details);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(style.icon, color: style.color),
          title: Text(
            log['summary'] ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$user  •  ${_formatTime(log['timestamp'])}  •  IP $ip',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason.isNotEmpty) _row('Reason', reason),
            ...detailRows,
            if (reason.isEmpty && detailRows.isEmpty)
              const Text('No extra details.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  /// Turns the details JSON into short readable lines.
  List<Widget> _detailRows(Map<String, dynamic> details) {
    final rows = <Widget>[];

    final changes = details['changes'];
    if (changes is Map) {
      changes.forEach((field, change) {
        if (change is Map) {
          rows.add(_row(_label(field), '${_short(change['from'])}  →  ${_short(change['to'])}'));
        }
      });
    }

    // Created / deleted record (customers, products, …) or deleted bill.
    final data = details['data'] ?? details['before'];
    if (data is Map) {
      data.forEach((field, value) {
        if (field == 'items' && value is List) {
          rows.add(_row('Items', value.map((i) => i is Map ? '${i['product']} × ${i['quantity']}' : '$i').join(', ')));
        } else if (field == 'payments' && value is List) {
          if (value.isNotEmpty) {
            rows.add(_row('Payments', value.map((p) => p is Map ? '${p['amount']} ${p['mode']}' : '$p').join(', ')));
          }
        } else if (value != null) {
          rows.add(_row(_label(field), _short(value)));
        }
      });
    }

    // Anything else (payments, bill summary, bulk upload counts…).
    details.forEach((key, value) {
      if (key == 'changes' || key == 'data' || key == 'before' || value == null) return;
      if (value is List) {
        if (value.isEmpty) return;
        rows.add(_row(_label(key), value.map((v) => v is Map ? v.values.join(' ') : '$v').join(', ')));
      } else if (value is! Map) {
        rows.add(_row(_label(key), '$value'));
      }
    });

    return rows;
  }

  String _label(Object key) {
    final s = key.toString().replaceAll('_', ' ');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  String _short(Object? value) {
    if (value == null) return '—';
    final s = value is String ? value : jsonEncode(value);
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
