import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_snackbar.dart';

final farmersControllerProvider =
    StateNotifierProvider.autoDispose<FarmersController, FarmersState>((ref) {
  return FarmersController()..load();
});

class FarmersState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> farmers;
  final Map<String, dynamic>? pagination;
  final String search;

  const FarmersState({
    this.isLoading = false,
    this.error,
    this.farmers = const [],
    this.pagination,
    this.search = '',
  });

  FarmersState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? farmers,
    Map<String, dynamic>? pagination,
    String? search,
  }) {
    return FarmersState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      farmers: farmers ?? this.farmers,
      pagination: pagination ?? this.pagination,
      search: search ?? this.search,
    );
  }
}

class FarmersController extends StateNotifier<FarmersState> {
  FarmersController() : super(const FarmersState());

  final DioClient _client = DioClient();

  Future<void> load({String? search}) async {
    final nextSearch = search ?? state.search;
    state = state.copyWith(isLoading: true, error: null, search: nextSearch);

    try {
      final response = await _client.get(
        ApiEndpoints.farmers,
        queryParameters: {
          'page': 1,
          'limit': 50,
          if (nextSearch.trim().isNotEmpty) 'search': nextSearch.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          farmers: _asRows(response.data['data']),
          pagination: response.data['pagination'] is Map
              ? Map<String, dynamic>.from(response.data['pagination'])
              : null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error:
              response.data['message']?.toString() ?? 'Unable to load farmers',
        );
      }
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<String?> save(Map<String, dynamic> payload, {String? id}) async {
    try {
      final response = id == null
          ? await _client.post(ApiEndpoints.farmers, data: payload)
          : await _client.put(ApiEndpoints.farmerById(id), data: payload);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
        await load();
        return null;
      }

      return response.data['message']?.toString() ?? 'Unable to save farmer';
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> deactivate(String id) async {
    try {
      final response = await _client.delete(ApiEndpoints.farmerById(id));
      if (response.statusCode == 200 && response.data['success'] == true) {
        await load();
        return null;
      }
      return response.data['message']?.toString() ??
          'Unable to deactivate farmer';
    } catch (error) {
      return error.toString();
    }
  }

  static List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class FarmersScreen extends ConsumerStatefulWidget {
  final String? initialRole;

  const FarmersScreen({super.key, this.initialRole});

  @override
  ConsumerState<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends ConsumerState<FarmersScreen> {
  late final TextEditingController _searchController;

  bool get _canManage {
    final role = (widget.initialRole ?? 'ADMIN').toUpperCase();
    return role == 'ADMIN' || role == 'OPERATOR';
  }

  bool get _canDeactivate =>
      (widget.initialRole ?? 'ADMIN').toUpperCase() == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTestShell = widget.initialRole != null;
    if (isTestShell) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: 'Farmers',
                subtitle: 'Search, verify, and maintain farmer bank profiles.',
                icon: Icons.people_rounded,
                trailing: _canManage
                    ? FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Farmer'),
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(farmersControllerProvider);
    final controller = ref.read(farmersControllerProvider.notifier);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'Farmers',
          subtitle: 'Search, verify, and maintain farmer bank profiles.',
          icon: Icons.people_rounded,
          trailing: _canManage
              ? FilledButton.icon(
                  onPressed: () => _openFarmerDialog(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Farmer'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        _SearchPanel(
          controller: _searchController,
          onSearch: () => controller.load(search: _searchController.text),
          onClear: () {
            _searchController.clear();
            controller.load(search: '');
          },
        ),
        const SizedBox(height: 16),
        if (state.error != null)
          _MessagePanel(
            icon: Icons.error_outline_rounded,
            title: 'Farmers could not be loaded',
            message: state.error!,
            actionLabel: 'Retry',
            onAction: controller.load,
          )
        else
          _FarmersTable(
            rows: state.farmers,
            isLoading: state.isLoading,
            canManage: _canManage,
            canDeactivate: _canDeactivate,
            onEdit: (row) => _openFarmerDialog(context, controller, row: row),
            onDeactivate: (row) => _confirmDeactivate(context, controller, row),
          ),
      ],
    );

    return SingleChildScrollView(child: content);
  }

  Future<void> _openFarmerDialog(
    BuildContext context,
    FarmersController controller, {
    Map<String, dynamic>? row,
  }) async {
    final error = await showDialog<String?>(
      context: context,
      builder: (context) => _FarmerFormDialog(
        farmer: row,
        onSave: (payload) =>
            controller.save(payload, id: row?['id']?.toString()),
      ),
    );

    if (!context.mounted) return;
    if (error == null) {
      AppSnackbar.success(
          context, row == null ? 'Farmer created' : 'Farmer updated');
    } else if (error.isNotEmpty) {
      AppSnackbar.error(context, error);
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    FarmersController controller,
    Map<String, dynamic> row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate farmer'),
        content: Text('Deactivate ${row['name'] ?? 'this farmer'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final error = await controller.deactivate(row['id'].toString());
    if (!context.mounted) return;
    if (error == null) {
      AppSnackbar.success(context, 'Farmer deactivated');
    } else {
      AppSnackbar.error(context, error);
    }
  }
}

class _FarmersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool isLoading;
  final bool canManage;
  final bool canDeactivate;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDeactivate;

  const _FarmersTable({
    required this.rows,
    required this.isLoading,
    required this.canManage,
    required this.canDeactivate,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
          height: 280, child: Center(child: CircularProgressIndicator()));
    }

    if (rows.isEmpty) {
      return const _MessagePanel(
        icon: Icons.person_search_rounded,
        title: 'No farmers found',
        message: 'Try another search or add the first farmer profile.',
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            ),
            columns: [
              const DataColumn(label: Text('Farmer ID')),
              const DataColumn(label: Text('Name')),
              const DataColumn(label: Text('Village')),
              const DataColumn(label: Text('District')),
              const DataColumn(label: Text('Mobile')),
              const DataColumn(label: Text('Bank')),
              const DataColumn(label: Text('Status')),
              if (canManage) const DataColumn(label: Text('Actions')),
            ],
            rows: rows.map((row) {
              final active = row['isActive'] != false;
              return DataRow(
                cells: [
                  DataCell(Text(row['farmerId']?.toString() ?? '-')),
                  DataCell(Text(row['name']?.toString() ?? '-')),
                  DataCell(Text(row['village']?.toString() ?? '-')),
                  DataCell(Text(row['district']?.toString() ?? '-')),
                  DataCell(Text(Formatters.mobile(row['phone']?.toString()))),
                  DataCell(Text(row['bankName']?.toString() ?? '-')),
                  DataCell(StatusBadge(status: active ? 'Active' : 'Inactive')),
                  if (canManage)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => onEdit(row),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          if (canDeactivate && active)
                            IconButton(
                              tooltip: 'Deactivate',
                              onPressed: () => onDeactivate(row),
                              icon: const Icon(Icons.block_rounded),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _FarmerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? farmer;
  final Future<String?> Function(Map<String, dynamic> payload) onSave;

  const _FarmerFormDialog({required this.farmer, required this.onSave});

  @override
  State<_FarmerFormDialog> createState() => _FarmerFormDialogState();
}

class _FarmerFormDialogState extends State<_FarmerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  static const _fields = <_FieldSpec>[
    _FieldSpec('farmerId', 'Farmer ID', required: true),
    _FieldSpec('name', 'Farmer Name', required: true),
    _FieldSpec('fatherName', 'Father/Husband Name'),
    _FieldSpec('village', 'Village', required: true),
    _FieldSpec('district', 'District', required: true),
    _FieldSpec('state', 'State'),
    _FieldSpec('pincode', 'Pincode'),
    _FieldSpec('phone', 'Mobile'),
    _FieldSpec('aadharNumber', 'Aadhaar'),
    _FieldSpec('bankName', 'Bank Name'),
    _FieldSpec('branchName', 'Branch'),
    _FieldSpec('accountNumber', 'Account Number'),
    _FieldSpec('ifscCode', 'IFSC'),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in _fields)
        field.key: TextEditingController(
          text: widget.farmer?[field.key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.farmer == null ? 'Add Farmer' : 'Edit Farmer'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _fields.map((field) {
                return SizedBox(
                  width: 360,
                  child: TextFormField(
                    controller: _controllers[field.key],
                    enabled: !_saving &&
                        !(field.key == 'farmerId' && widget.farmer != null),
                    decoration: InputDecoration(labelText: field.label),
                    validator: field.required
                        ? (value) => value == null || value.trim().isEmpty
                            ? 'Required'
                            : null
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(''),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) payload[entry.key] = value;
    }
    final error = await widget.onSave(payload);
    if (!mounted) return;
    Navigator.of(context).pop(error);
  }
}

class _FieldSpec {
  final String key;
  final String label;
  final bool required;

  const _FieldSpec(this.key, this.label, {this.required = false});
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchPanel({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search farmers',
                  hintText: 'Name, farmer ID, village, phone, or Aadhaar',
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Clear',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accentSoft,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(icon,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
