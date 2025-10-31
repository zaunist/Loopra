import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dictionary.dart';
import '../services/audio_service.dart';
import '../state/typing_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<TypingController>(
        builder: (BuildContext context, TypingController controller, _) {
          final DictionaryMeta? selected = controller.selectedDictionary;
          final List<DictionaryMeta> dictionaries = controller.dictionaries;
          final bool hasChapters = controller.chapterCount > 0;
          final List<DropdownMenuItem<int>> chapterItems = hasChapters
              ? List<DropdownMenuItem<int>>.generate(
                  controller.chapterCount,
                  (int index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text('第 ${index + 1} 章'),
                  ),
                )
              : const <DropdownMenuItem<int>>[];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: <Widget>[
              const _SectionHeader(label: '词库'),
              InputDecorator(
                decoration: const InputDecoration(labelText: '选择词库'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selected?.id,
                    items: dictionaries
                        .map(
                          (DictionaryMeta meta) => DropdownMenuItem<String>(
                            value: meta.id,
                            child: Text(meta.name),
                          ),
                        )
                        .toList(),
                    onChanged: controller.isLoading || dictionaries.isEmpty
                        ? null
                        : (String? id) {
                            if (id != null) {
                              unawaited(controller.selectDictionary(id));
                            }
                          },
                  ),
                ),
              ),
              if (selected != null && selected.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    selected.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (selected != null && (selected.category ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    label: Text(selected.category!),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              const SizedBox(height: 24),
              const _SectionHeader(label: '章节'),
              InputDecorator(
                decoration: const InputDecoration(labelText: '选择章节'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: hasChapters
                        ? (controller.selectedChapter < controller.chapterCount
                            ? controller.selectedChapter
                            : 0)
                        : null,
                    items: chapterItems,
                    onChanged: controller.isLoading || !hasChapters
                        ? null
                        : (int? chapter) {
                            if (chapter != null) {
                              unawaited(controller.selectChapter(chapter));
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(label: '练习偏好'),
              SwitchListTile(
                title: const Text('显示释义'),
                value: controller.showTranslation,
                onChanged: controller.isLoading
                    ? null
                    : (bool value) {
                        controller.toggleTranslationVisibility(value);
                      },
              ),
              SwitchListTile(
                title: const Text('忽略大小写'),
                value: controller.ignoreCase,
                onChanged: controller.isLoading
                    ? null
                    : (bool value) {
                        controller.toggleIgnoreCase(value);
                      },
              ),
              SwitchListTile(
                title: const Text('按键音'),
                value: controller.keySoundEnabled,
                onChanged: controller.isLoading
                    ? null
                    : (bool value) {
                        controller.toggleKeySound(value);
                      },
              ),
              SwitchListTile(
                title: const Text('提示音'),
                value: controller.feedbackSoundEnabled,
                onChanged: controller.isLoading
                    ? null
                    : (bool value) {
                        controller.toggleFeedbackSound(value);
                      },
              ),
              if (controller.supportsPronunciation) ...<Widget>[
                SwitchListTile(
                  title: const Text('自动发音'),
                  value: controller.autoPronunciationEnabled,
                  onChanged: controller.isLoading
                      ? null
                      : (bool value) {
                          controller.toggleAutoPronunciation(value);
                        },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                  child: Text(
                    '发音偏好',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<PronunciationVariant>(
                  segments: const <ButtonSegment<PronunciationVariant>>[
                    ButtonSegment<PronunciationVariant>(
                      value: PronunciationVariant.us,
                      label: Text('美音'),
                    ),
                    ButtonSegment<PronunciationVariant>(
                      value: PronunciationVariant.uk,
                      label: Text('英音'),
                    ),
                  ],
                  selected: <PronunciationVariant>{controller.pronunciationVariant},
                  onSelectionChanged: controller.isLoading
                      ? null
                      : (Set<PronunciationVariant> selection) {
                          if (selection.isNotEmpty) {
                            controller.setPronunciationVariant(selection.first);
                          }
                        },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
