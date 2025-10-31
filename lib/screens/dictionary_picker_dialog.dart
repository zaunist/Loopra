import 'package:flutter/material.dart';

import '../models/dictionary.dart';

class DictionaryPickerDialog extends StatefulWidget {
  const DictionaryPickerDialog({
    super.key,
    required this.dictionaries,
    this.initialDictionaryId,
  });

  final List<DictionaryMeta> dictionaries;
  final String? initialDictionaryId;

  static Future<String?> show(
    BuildContext context, {
    required List<DictionaryMeta> dictionaries,
    String? initialDictionaryId,
  }) {
    if (dictionaries.isEmpty) {
      return Future<String?>.value(null);
    }
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => DictionaryPickerDialog(
        dictionaries: dictionaries,
        initialDictionaryId: initialDictionaryId,
      ),
    );
  }

  @override
  State<DictionaryPickerDialog> createState() => _DictionaryPickerDialogState();
}

class _DictionaryPickerDialogState extends State<DictionaryPickerDialog> {
  late final List<_LanguageOption> _languages;
  late String _activeLanguage;

  @override
  void initState() {
    super.initState();
    _languages = _buildLanguageOptions(widget.dictionaries);
    _activeLanguage = _resolveInitialLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<DictionaryMeta> filtered = _filterDictionaries();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '选择词库',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '根据语言浏览不同的词库，点击卡片即可切换。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _LanguageSelector(
                options: _languages,
                activeCode: _activeLanguage,
                onChanged: (String code) {
                  setState(() {
                    _activeLanguage = code;
                  });
                },
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyPlaceholder()
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final DictionaryMeta meta = filtered[index];
                          final bool isCurrent = widget.initialDictionaryId == meta.id;
                          return _DictionaryCard(
                            meta: meta,
                            isCurrent: isCurrent,
                            onSelected: () => Navigator.of(context).pop(meta.id),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<DictionaryMeta> _filterDictionaries() {
    final List<DictionaryMeta> sorted = List<DictionaryMeta>.from(widget.dictionaries)
      ..sort((DictionaryMeta a, DictionaryMeta b) => a.name.compareTo(b.name));
    if (_activeLanguage.isEmpty) {
      return sorted;
    }
    return sorted
        .where((DictionaryMeta meta) => meta.normalizedLanguageCode == _activeLanguage)
        .toList(growable: false);
  }

  String _resolveInitialLanguage() {
    DictionaryMeta? selected;
    if (widget.initialDictionaryId != null) {
      for (final DictionaryMeta meta in widget.dictionaries) {
        if (meta.id == widget.initialDictionaryId) {
          selected = meta;
          break;
        }
      }
    }
    final String code = selected?.normalizedLanguageCode ?? '';
    final bool exists = _languages.any(( _LanguageOption option) => option.code == code);
    return exists ? code : '';
  }

  List<_LanguageOption> _buildLanguageOptions(List<DictionaryMeta> dictionaries) {
    final Map<String, String> labels = <String, String>{};
    for (final DictionaryMeta meta in dictionaries) {
      final String code = meta.normalizedLanguageCode;
      labels.putIfAbsent(code, () => meta.languageLabel);
    }

    final List<_LanguageOption> options = labels.entries
        .map(
          (MapEntry<String, String> entry) => _LanguageOption(
            code: entry.key,
            label: entry.value,
          ),
        )
        .toList()
      ..sort(
        ( _LanguageOption a,  _LanguageOption b) => a.label.compareTo(b.label),
      );

    return <_LanguageOption>[
      const _LanguageOption(code: '', label: '全部'),
      ...options,
    ];
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.options,
    required this.activeCode,
    required this.onChanged,
  });

  final List<_LanguageOption> options;
  final String activeCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (_LanguageOption option) => ChoiceChip(
              label: Text(option.label),
              selected: option.code == activeCode,
              onSelected: option.code == activeCode
                  ? null
                  : (bool _) {
                      onChanged(option.code);
                    },
            ),
          )
          .toList(),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  const _DictionaryCard({
    required this.meta,
    required this.isCurrent,
    required this.onSelected,
  });

  final DictionaryMeta meta;
  final bool isCurrent;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderSide border = BorderSide(
      color: isCurrent ? colorScheme.primary : colorScheme.outlineVariant,
      width: isCurrent ? 1.6 : 1,
    );
    final Color? background =
        isCurrent ? colorScheme.primary.withValues(alpha: 0.08) : null;

    final List<Widget> chips = <Widget>[
      Chip(
        label: Text(meta.languageLabel),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    ];
    if ((meta.category ?? '').isNotEmpty) {
      chips.add(
        Chip(
          label: Text(meta.category!),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }
    if (meta.isCustom) {
      chips.add(
        const Chip(
          label: Text('自定义'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: border,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      meta.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isCurrent)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '当前使用',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (meta.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    meta.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.tonal(
                    onPressed: onSelected,
                    child: const Text('使用这个词库'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              '该语言暂时没有词库。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({required this.code, required this.label});

  final String code;
  final String label;
}
