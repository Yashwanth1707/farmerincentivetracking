import 'package:flutter/material.dart';

/// Reusable search bar widget
class SearchBarWidget extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autoFocus;
  final double? width;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search...',
    required this.onChanged,
    this.onClear,
    this.controller,
    this.autoFocus = false,
    this.width,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(() {
      if (_hasText != _controller.text.isNotEmpty) {
        setState(() => _hasText = _controller.text.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: widget.width ?? 320,
      child: TextField(
        controller: _controller,
        autofocus: widget.autoFocus,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chips row for filtering data
class FilterChips extends StatelessWidget {
  final List<FilterChipOption> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final String? label;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // "All" option
            ChoiceChip(
              label: Text(
                'All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selectedValue == null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              selected: selectedValue == null,
              onSelected: (_) => onChanged(null),
              visualDensity: VisualDensity.compact,
              selectedColor: colorScheme.primaryContainer,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              labelStyle: TextStyle(
                color: selectedValue == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            // Option chips
            for (final option in options)
              ChoiceChip(
                label: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedValue == option.value
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                selected: selectedValue == option.value,
                onSelected: (_) {
                  onChanged(
                      selectedValue == option.value ? null : option.value);
                },
                visualDensity: VisualDensity.compact,
                avatar:
                    option.icon != null ? Icon(option.icon, size: 16) : null,
                selectedColor: colorScheme.primaryContainer,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: selectedValue == option.value
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Filter chip option model
class FilterChipOption {
  final String value;
  final String label;
  final IconData? icon;

  const FilterChipOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Date range filter widget
class DateRangeFilter extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTimeRange?> onChanged;

  const DateRangeFilter({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        _DateField(
          label: 'From',
          date: startDate,
          onTap: () => _pickDate(context, isStart: true),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        _DateField(
          label: 'To',
          date: endDate,
          onTap: () => _pickDate(context, isStart: false),
        ),
        if (startDate != null || endDate != null)
          IconButton(
            icon: const Icon(Icons.clear_rounded, size: 18),
            onPressed: () => onChanged(null),
            visualDensity: VisualDensity.compact,
            tooltip: 'Clear dates',
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (startDate ?? now.subtract(const Duration(days: 30)))
          : (endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      helpText: isStart ? 'Select start date' : 'Select end date',
    );

    if (picked != null) {
      if (isStart) {
        onChanged(DateTimeRange(
          start: picked,
          end: endDate ?? now,
        ));
      } else {
        onChanged(DateTimeRange(
          start: startDate ?? now.subtract(const Duration(days: 30)),
          end: picked,
        ));
      }
    }
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: date != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
