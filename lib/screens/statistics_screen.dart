import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice_statistics.dart';
import '../state/statistics_controller.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习统计'),
      ),
      body: const _StatisticsContent(),
    );
  }
}

class StatisticsDialog extends StatelessWidget {
  const StatisticsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: const _StatisticsContent(isDialog: true),
      ),
    );
  }
}

class _StatisticsContent extends StatefulWidget {
  const _StatisticsContent({this.isDialog = false});

  final bool isDialog;

  @override
  State<_StatisticsContent> createState() => _StatisticsContentState();
}

class _StatisticsContentState extends State<_StatisticsContent> {
  String? _selectedDictionaryId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Consumer<StatisticsController>(
      builder: (BuildContext context, StatisticsController controller, _) {
        if (!controller.isReady) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final List<PracticeDictionaryRef> dictionaries = controller.dictionaries;
        if (dictionaries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _EmptyPlaceholder(
                message: '暂无练习记录，完成一次练习后即可查看统计数据。',
              ),
            ),
          );
        }

        final String fallbackId = dictionaries.first.id;
        final String selectedId = (() {
          final String? stored = _selectedDictionaryId;
          if (stored == null) {
            return fallbackId;
          }
          final bool exists =
              dictionaries.any((PracticeDictionaryRef item) => item.id == stored);
          return exists ? stored : fallbackId;
        })();
        final PracticeTotals totals = controller.totalsForDictionary(selectedId);
        final List<ChapterStatisticsSummary> chapters =
            controller.chapterSummariesForDictionary(selectedId);
        final PracticeDictionaryRef selectedDictionary = dictionaries.firstWhere(
          (PracticeDictionaryRef item) => item.id == selectedId,
          orElse: () => dictionaries.first,
        );

        return Scrollbar(
          thumbVisibility: widget.isDialog,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DictionaryPicker(
                  dictionaries: dictionaries,
                  selectedId: selectedId,
                  onChanged: (String value) {
                    setState(() {
                      _selectedDictionaryId = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Text('总览', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _SummaryGrid(totals: totals),
                const SizedBox(height: 28),
                Text('章节表现 - ${selectedDictionary.name}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (chapters.isEmpty)
                  const _EmptyPlaceholder(message: '该词库暂无章节练习记录。')
                else
                  Column(
                    children: chapters
                        .map(
                          (ChapterStatisticsSummary summary) => _ChapterCard(
                            summary: summary,
                            showDictionaryName: false,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DictionaryPicker extends StatelessWidget {
  const _DictionaryPicker({
    required this.dictionaries,
    required this.selectedId,
    required this.onChanged,
  });

  final List<PracticeDictionaryRef> dictionaries;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '选择词库',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          items: dictionaries
              .map(
                (PracticeDictionaryRef item) => DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.totals});

  final PracticeTotals totals;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_SummaryItem> items = <_SummaryItem>[
      _SummaryItem(
        label: '总练习次数',
        value: totals.totalSessions.toString(),
        icon: Icons.repeat,
        color: theme.colorScheme.primary,
      ),
      _SummaryItem(
        label: '累计时长',
        value: _formatDuration(totals.totalElapsedSeconds),
        icon: Icons.timer,
        color: theme.colorScheme.secondary,
      ),
      _SummaryItem(
        label: '完成单词',
        value: totals.totalCompletedWords.toString(),
        icon: Icons.abc,
        color: theme.colorScheme.tertiary,
      ),
      _SummaryItem(
        label: '平均准确率',
        value: _formatPercent(totals.accuracy),
        icon: Icons.check_circle,
        color: theme.colorScheme.primaryContainer,
      ),
      _SummaryItem(
        label: '平均每分钟单词数',
        value: totals.averageWordsPerMinute.toStringAsFixed(1),
        icon: Icons.speed,
        color: theme.colorScheme.secondaryContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth > 640;
        final int columns = wide ? 3 : 1;
        final double spacing = 12;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (_SummaryItem item) => SizedBox(
                  width: wide ? (constraints.maxWidth - spacing * (columns - 1)) / columns : double.infinity,
                  child: _SummaryCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: item.color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: item.color.withValues(alpha: 0.2),
              foregroundColor: item.color,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.value,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.summary, this.showDictionaryName = true});

  final ChapterStatisticsSummary summary;
  final bool showDictionaryName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String chapterLabel = '第 ${summary.chapterIndex + 1} 章';
    final DateTime localTime = summary.lastPracticed.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              showDictionaryName ? '${summary.dictionaryName} · $chapterLabel' : chapterLabel,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                _MetricChip(
                  label: '完成率',
                  value: _formatPercent(summary.averageCompletionRate),
                  icon: Icons.task_alt,
                ),
                _MetricChip(
                  label: '准确率',
                  value: _formatPercent(summary.averageAccuracy),
                  icon: Icons.check,
                ),
                _MetricChip(
                  label: '平均每分钟单词数',
                  value: summary.averageWordsPerMinute.toStringAsFixed(1),
                  icon: Icons.speed,
                ),
                _MetricChip(
                  label: '平均用时',
                  value: _formatDuration(summary.averageElapsedSeconds.round()),
                  icon: Icons.timer,
                ),
                _MetricChip(
                  label: '练习次数',
                  value: summary.sessionCount.toString(),
                  icon: Icons.repeat,
                ),
                _MetricChip(
                  label: '累计完成词数',
                  value: summary.totalCompletedWords.toString(),
                  icon: Icons.abc,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '最近练习：${_formatDateTime(localTime)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label：$value'),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _formatDuration(num seconds) {
  final int totalSeconds = seconds.round();
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int secs = totalSeconds % 60;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(secs)}';
}

String _formatPercent(double value) {
  final double clamped = value.isNaN ? 0 : value;
  return '${(clamped * 100).clamp(0, 100).toStringAsFixed(1)}%';
}

String _formatDateTime(DateTime timestamp) {
  final DateTime time = timestamp;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)} '
      '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
}
