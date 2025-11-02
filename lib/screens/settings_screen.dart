import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dictionary.dart';
import '../models/subscription.dart';
import '../services/audio_service.dart';
import '../state/auth_controller.dart';
import '../state/subscription_controller.dart';
import '../state/typing_controller.dart';
import 'account/account_dialog.dart';
import 'statistics_screen.dart';
import 'dictionary_picker_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
              const _SectionHeader(label: '账号与同步'),
              const _AccountSyncSection(),
              const SizedBox(height: 24),
              const _SectionHeader(label: '词库'),
              InputDecorator(
                decoration: const InputDecoration(labelText: '选择词库'),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: controller.isLoading || dictionaries.isEmpty
                        ? null
                        : () async {
                            final String? result =
                                await DictionaryPickerDialog.show(
                                  context,
                                  dictionaries: dictionaries,
                                  initialDictionaryId: selected?.id,
                                );
                            if (result != null &&
                                result.isNotEmpty &&
                                result != selected?.id) {
                              unawaited(controller.selectDictionary(result));
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  selected?.name ?? '暂无可用词库',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (selected != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      selected.languageLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.open_in_new_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
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
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Chip(
                        label: Text(selected.languageLabel),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      if ((selected.category ?? '').isNotEmpty)
                        Chip(
                          label: Text(selected.category!),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      if (selected.isCustom)
                        const Chip(
                          label: Text('自定义词库'),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                    ],
                  ),
                ),
              if (controller.canManageDictionaries) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: controller.isLoading
                          ? null
                          : () async => _importDictionary(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('导入词库'),
                    ),
                    if (selected?.isCustom == true)
                      OutlinedButton.icon(
                        onPressed: controller.isLoading
                            ? null
                            : () async =>
                                  _confirmDeleteDictionary(context, selected!),
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
                  selected: <PronunciationVariant>{
                    controller.pronunciationVariant,
                  },
                  onSelectionChanged: controller.isLoading
                      ? null
                      : (Set<PronunciationVariant> selection) {
                          if (selection.isNotEmpty) {
                            controller.setPronunciationVariant(selection.first);
                          }
                        },
                ),
              ],
              if (_isMobilePlatform()) ...<Widget>[
                const SizedBox(height: 24),
                const _SectionHeader(label: '统计'),
                ListTile(
                  leading: const Icon(Icons.insights),
                  title: const Text('查看练习统计'),
                  subtitle: const Text('查看历史练习次数、用时、准确率等详细数据。'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StatisticsScreen(),
                      ),
                    );
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

  Future<void> _confirmDeleteDictionary(
    BuildContext context,
    DictionaryMeta meta,
  ) async {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

bool _isMobilePlatform() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
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
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AccountSyncSection extends StatelessWidget {
  const _AccountSyncSection();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthController, SubscriptionController>(
      builder:
          (
            BuildContext context,
            AuthController auth,
            SubscriptionController subscription,
            _,
          ) {
            final bool isBusy =
                auth.isLoading ||
                subscription.isLoading ||
                subscription.isCreatingCheckout;
            if (!auth.isConfigured) {
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_off,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text(
                              '暂未启用云同步',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text('请提供 Supabase 配置后再启用登录与同步功能。'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!subscription.isConfigured) {
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text(
                              '订阅功能未配置',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text('请补充 Creem API 凭证后再启用订阅与云同步功能。'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (auth.isLoggedIn) {
              final String subscribeLabel = _subscribeButtonLabel(subscription);
              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.verified_user),
                      title: Text(auth.email ?? '已登录'),
                      subtitle: const Text('订阅用户可以在登录后同步练习进度。'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium),
                      title: const Text('订阅状态'),
                      subtitle: Text(subscription.status.describeState()),
                    ),
                    if (subscription.note != null &&
                        subscription.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          subscription.note!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    if (isBusy) const LinearProgressIndicator(minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 12,
                        children: <Widget>[
                          if (!subscription.status.isActive)
                            FilledButton(
                              onPressed:
                                  isBusy || subscription.availablePlans.isEmpty
                                  ? null
                                  : () => _startLifetimeSubscription(
                                      context,
                                      subscription,
                                    ),
                              child: Text(subscribeLabel),
                            ),
                          TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    final ScaffoldMessengerState messenger =
                                        ScaffoldMessenger.of(context);
                                    await auth.signOut();
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('已退出登录')),
                                    );
                                  },
                            child: const Text('退出登录'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Card(
              margin: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('未登录'),
                    subtitle: Text('登录并完成订阅后即可在多设备间同步练习进度。'),
                  ),
                  if (auth.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (subscription.note != null &&
                      subscription.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        subscription.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 12,
                      children: <Widget>[
                        FilledButton(
                          onPressed: isBusy
                              ? null
                              : () => AccountDialog.show(context),
                          child: const Text('登录 / 注册'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }

  Future<void> _startLifetimeSubscription(
    BuildContext context,
    SubscriptionController subscription,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SubscriptionPlan? plan = _selectLifetimePlan(
      subscription.availablePlans,
    );
    if (plan == null) {
      messenger.showSnackBar(const SnackBar(content: Text('暂无可用订阅计划，请稍后再试。')));
      return;
    }

    try {
      final Uri checkoutUrl = await subscription.createCheckoutSession(
        plan: plan,
      );
      final LaunchMode mode = kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication;
      final bool launched = await launchUrl(checkoutUrl, mode: mode);
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('无法打开订阅页面，请稍后重试。')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('订阅失败：$error')));
    }
  }

  String _subscribeButtonLabel(SubscriptionController subscription) {
    final SubscriptionPlan? plan = _selectLifetimePlan(
      subscription.availablePlans,
    );
    if (plan == null) {
      return '订阅永久会员';
    }
    final String priceLabel = _formatPlanPrice(plan);
    if (priceLabel.isEmpty) {
      return '订阅永久会员';
    }
    return '订阅永久会员';
  }

  SubscriptionPlan? _selectLifetimePlan(List<SubscriptionPlan> plans) {
    if (plans.isEmpty) {
      return null;
    }
    try {
      return plans.firstWhere(
        (SubscriptionPlan plan) => plan.type == SubscriptionPlanType.lifetime,
      );
    } on StateError {
      return plans.first;
    }
  }

  String _formatPlanPrice(SubscriptionPlan plan) {
    if (plan.price == null || plan.currency == null || plan.currency!.isEmpty) {
      return '';
    }
    final double value = plan.price!.toDouble();
    final bool isWhole = value == value.truncateToDouble();
    final String amount = isWhole
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$amount ${plan.currency}';
  }
}
