import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
              if (controller.canManageDictionaries) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: controller.isLoading ? null : () async => _importDictionary(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('导入词库'),
                    ),
                    if (selected?.isCustom == true)
                      OutlinedButton.icon(
                        onPressed:
                            controller.isLoading ? null : () async => _confirmDeleteDictionary(context, selected!),
                        icon: const Icon(Icons.delete),
                        label: const Text('删除词库'),
                      ),
                  ],
                ),
              ],
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
                title: const Text('默写模式'),
                value: controller.dictationMode,
                onChanged: controller.isLoading
                    ? null
                    : (bool value) {
                        controller.toggleDictationMode(value);
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

  Future<void> _importDictionary(BuildContext context) async {
    final TypingController controller = context.read<TypingController>();
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final PlatformFile file = result.files.single;
      DictionaryMeta imported;
      if (file.bytes != null) {
        final String content = utf8.decode(file.bytes!);
        imported = await controller.importDictionaryFromContent(content);
      } else if (file.path != null) {
        imported = await controller.importDictionaryFromPath(file.path!);
      } else {
        throw const FormatException('无法读取词典文件内容。');
      }

      if (!context.mounted) {
        return;
      }
      _showSnack(context, '已导入词库：${imported.name}');
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, error.message);
    } on UnsupportedError catch (error) {
      if (!context.mounted) {
        return;
      }
      final String message = error.message?.toString() ?? '当前平台暂不支持导入词库。';
      _showSnack(context, message);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, '导入失败：$error');
    }
  }

  Future<void> _confirmDeleteDictionary(BuildContext context, DictionaryMeta meta) async {
    final TypingController controller = context.read<TypingController>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('删除词库'),
        content: Text('确定要删除词库「${meta.name}」吗？此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await controller.deleteDictionary(meta.id);
      if (!context.mounted) {
        return;
      }
      _showSnack(context, '已删除词库：${meta.name}');
    } on UnsupportedError catch (error) {
      if (!context.mounted) {
        return;
      }
      final String message = error.message?.toString() ?? '当前平台暂不支持删除词库。';
      _showSnack(context, message);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, '删除失败：$error');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
