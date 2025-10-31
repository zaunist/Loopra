import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dictionary.dart';
import '../models/word_entry.dart';
import '../services/audio_service.dart';
import '../state/typing_controller.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class TypingScreen extends StatefulWidget {
  const TypingScreen({super.key});

  @override
  State<TypingScreen> createState() => _TypingScreenState();
}

class _TypingScreenState extends State<TypingScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final TypingController controller = context.read<TypingController>();
      if (controller.selectedDictionary == null) {
        await controller.initialise();
      }
      if (!mounted) {
        return;
      }
      if (!_isMobileLayout(context)) {
        _ensureFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TypingController>(
      builder: (BuildContext context, TypingController controller, _) {
        final bool isMobile = _isMobileLayout(context);
        if (isMobile) {
          return _MobileTypingScaffold(controller: controller);
        }

        _ensureFocus();
        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            final bool handled = controller.handleKeyEvent(event);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          child: Scaffold(
            appBar: AppBar(
              title: const _AppBarBranding(),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.insights),
                  tooltip: '查看统计',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const StatisticsDialog(),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                width: double.infinity,
                child: Column(
                  children: <Widget>[
                    _HeaderControls(controller: controller),
                    const SizedBox(height: 24),
                    Expanded(child: _WordPanel(controller: controller)),
                    const SizedBox(height: 16),
                    _StatsBar(controller: controller),
                    const SizedBox(height: 16),
                    if (controller.isFinished)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          key: const ValueKey<String>('desktop-finish-actions'),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _DesktopCompletionActions(
                            controller: controller,
                          ),
                        ),
                      ),
                    if (controller.isFinished) const SizedBox(height: 16),
                    const _SloganFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  bool _isMobileLayout(BuildContext context) {
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 600;
  }
}

class _MobileTypingScaffold extends StatefulWidget {
  const _MobileTypingScaffold({required this.controller});

  final TypingController controller;

  @override
  State<_MobileTypingScaffold> createState() => _MobileTypingScaffoldState();
}

class _MobileTypingScaffoldState extends State<_MobileTypingScaffold> {
  late final TextEditingController _textController;
  late final FocusNode _inputFocusNode;
  bool _suppressInputCallback = false;

  TypingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _inputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _requestKeyboard() {
    if (!_inputFocusNode.hasFocus) {
      _inputFocusNode.requestFocus();
    }
  }

  void _hideKeyboard() {
    if (_inputFocusNode.hasFocus) {
      _inputFocusNode.unfocus();
    }
    FocusScope.of(context).unfocus();
  }

  void _handleToggleTyping() {
    if (_controller.isLoading || !_controller.isSessionReady) {
      return;
    }
    final bool wasTyping = _controller.isTyping;
    _controller.toggleTyping();
    if (!wasTyping) {
      _requestKeyboard();
    } else {
      _hideKeyboard();
    }
  }

  void _handleRestart() {
    if (_controller.isLoading || !_controller.isSessionReady) {
      return;
    }
    _hideKeyboard();
    unawaited(_controller.restartChapter());
  }

  void _handleSkip() {
    if (_controller.isLoading ||
        !_controller.isSessionReady ||
        !_controller.canSkipCurrentWord) {
      return;
    }
    _controller.skipCurrentWord();
    _requestKeyboard();
  }

  void _handleNextChapter() {
    if (_controller.isLoading || !_controller.hasNextChapter) {
      return;
    }
    _hideKeyboard();
    unawaited(_controller.goToNextChapter());
  }

  void _handleWordAreaTap() {
    if (_controller.isLoading || !_controller.isSessionReady) {
      return;
    }
    if (!_controller.isTyping && !_controller.isFinished) {
      _controller.toggleTyping();
    }
    _requestKeyboard();
  }

  void _handleInputChanged(String value) {
    if (_suppressInputCallback || value.isEmpty) {
      return;
    }
    _suppressInputCallback = true;
    for (final int codePoint in value.runes) {
      final String character = String.fromCharCode(codePoint);
      if (character == '\n' || character == '\r') {
        continue;
      }
      _controller.handleCharacterInput(character);
    }
    _textController.clear();
    _suppressInputCallback = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _AppBarBranding(),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _MobileWordArea(
                  controller: _controller,
                  onWordAreaTap: _handleWordAreaTap,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: _MobileActionButtons(
                controller: _controller,
                onToggleTyping: _handleToggleTyping,
                onRestart: _handleRestart,
                onSkip: _controller.canSkipCurrentWord ? _handleSkip : null,
                onGoToNextChapter:
                    _controller.isFinished && _controller.hasNextChapter
                    ? _handleNextChapter
                    : null,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 1,
                width: double.infinity,
                child: TextField(
                  focusNode: _inputFocusNode,
                  controller: _textController,
                  onChanged: _handleInputChanged,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  autofillHints: const <String>[],
                  cursorColor: Colors.transparent,
                  style: const TextStyle(color: Colors.transparent, height: 1),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onEditingComplete: _hideKeyboard,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarBranding extends StatelessWidget {
  const _AppBarBranding();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final TextTheme textTheme = theme.textTheme;
    final TextStyle titleStyle =
        (appBarTheme.titleTextStyle ??
                textTheme.titleLarge ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
            .copyWith(
              color:
                  appBarTheme.titleTextStyle?.color ??
                  appBarTheme.foregroundColor ??
                  theme.colorScheme.onSurface,
            );
    final Color baseSubtitleColor =
        appBarTheme.titleTextStyle?.color ??
        appBarTheme.foregroundColor ??
        theme.colorScheme.onSurfaceVariant;
    final Color subtitleColor = baseSubtitleColor.withValues(alpha: 0.72);
    final TextStyle subtitleStyle =
        (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          color: subtitleColor,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Loopra', style: titleStyle),
        Text('把练习变成本能', style: subtitleStyle),
      ],
    );
  }
}

class _MobileWordArea extends StatelessWidget {
  const _MobileWordArea({
    required this.controller,
    required this.onWordAreaTap,
  });

  final TypingController controller;
  final VoidCallback onWordAreaTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onWordAreaTap,
            child: _WordPanel(
              controller: controller,
              startPrompt: '点击任意位置开始练习',
              resumePrompt: '点击任意位置开始练习',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatsBar(controller: controller),
      ],
    );
  }
}

class _MobileActionButtons extends StatelessWidget {
  const _MobileActionButtons({
    required this.controller,
    required this.onToggleTyping,
    required this.onRestart,
    this.onSkip,
    this.onGoToNextChapter,
  });

  final TypingController controller;
  final VoidCallback onToggleTyping;
  final VoidCallback onRestart;
  final VoidCallback? onSkip;
  final VoidCallback? onGoToNextChapter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        if (controller.isFinished && controller.hasNextChapter)
          FilledButton.icon(
            onPressed: controller.isLoading ? null : onGoToNextChapter,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('进入下一章'),
          ),
        FilledButton.icon(
          onPressed:
              controller.isLoading ||
                  !controller.isSessionReady ||
                  controller.isFinished
              ? null
              : onToggleTyping,
          icon: Icon(controller.isTyping ? Icons.pause : Icons.play_arrow),
          label: Text(controller.isTyping ? '暂停' : '开始'),
        ),
        OutlinedButton(
          onPressed: controller.isLoading || !controller.isSessionReady
              ? null
              : onRestart,
          child: const Text('重新开始'),
        ),
        if (controller.canSkipCurrentWord)
          OutlinedButton(
            onPressed: controller.isLoading || !controller.isSessionReady
                ? null
                : onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('跳过'),
          ),
      ],
    );
  }
}

class _DesktopCompletionActions extends StatelessWidget {
  const _DesktopCompletionActions({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    final bool hasNext = controller.hasNextChapter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        FilledButton.icon(
          onPressed: (!hasNext || controller.isLoading)
              ? null
              : () {
                  unawaited(controller.goToNextChapter());
                },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('进入下一章'),
        ),
        if (!hasNext)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('已经是最后一章', textAlign: TextAlign.center),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: controller.isLoading
              ? null
              : () {
                  unawaited(controller.restartChapter());
                },
          child: const Text('重新练习本章'),
        ),
      ],
    );
  }
}

class _HeaderControls extends StatelessWidget {
  const _HeaderControls({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    final List<DictionaryMeta> dictionaries = controller.dictionaries;
    final DictionaryMeta? selected = controller.selectedDictionary;
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints _) {
        final bool enableToggles = !controller.isLoading;
        final bool enableSessionActions = !controller.isLoading && controller.isSessionReady;

        final List<Widget> headerItems = <Widget>[];
        void addHeaderItem(Widget widget) {
          if (headerItems.isNotEmpty) {
            headerItems.add(const SizedBox(width: 8));
          }
          headerItems.add(widget);
        }

        addHeaderItem(
          _IconMenuButton<String>(
            icon: Icons.menu_book_rounded,
            tooltip: selected?.name ?? '选择词库',
            enabled: dictionaries.isNotEmpty && !controller.isLoading,
            selectedValue: selected?.id,
            options: dictionaries
                .map(
                  (DictionaryMeta dict) => _MenuOption<String>(
                    value: dict.id,
                    label: dict.name,
                  ),
                )
                .toList(),
            onSelected: (String value) {
              unawaited(controller.selectDictionary(value));
            },
          ),
        );

        final String chapterTooltip = controller.chapterCount == 0
            ? '章节'
            : '第 ${controller.selectedChapter + 1} 章';
        addHeaderItem(
          _IconMenuButton<int>(
            icon: Icons.layers_rounded,
            tooltip: chapterTooltip,
            enabled: controller.chapterCount > 0 && !controller.isLoading,
            selectedValue: controller.chapterCount == 0
                ? null
                : (controller.selectedChapter < controller.chapterCount
                      ? controller.selectedChapter
                      : 0),
            options: controller.chapterCount == 0
                ? const <_MenuOption<int>>[]
                : List<_MenuOption<int>>.generate(
                    controller.chapterCount,
                    (int index) => _MenuOption<int>(
                      value: index,
                      label: '第 ${index + 1} 章',
                    ),
                  ),
            onSelected: (int value) {
              unawaited(controller.selectChapter(value));
            },
          ),
        );

        if (controller.supportsPronunciation) {
          final String pronunciationTooltip = controller.pronunciationVariant == PronunciationVariant.us
              ? '美音'
              : '英音';
          addHeaderItem(
            _IconMenuButton<PronunciationVariant>(
              icon: Icons.graphic_eq_rounded,
              tooltip: pronunciationTooltip,
              enabled: !controller.isLoading,
              selectedValue: controller.pronunciationVariant,
              options: const <_MenuOption<PronunciationVariant>>[
                _MenuOption<PronunciationVariant>(
                  value: PronunciationVariant.us,
                  label: '美音',
                ),
                _MenuOption<PronunciationVariant>(
                  value: PronunciationVariant.uk,
                  label: '英音',
                ),
              ],
              onSelected: (PronunciationVariant variant) {
                controller.setPronunciationVariant(variant);
              },
            ),
          );
        }

        final List<_ToggleAction> toggleActions = <_ToggleAction>[
          _ToggleAction(
            label: '显示释义',
            icon: Icons.menu_book_outlined,
            selected: controller.showTranslation,
            enabled: enableToggles,
            onChanged: controller.toggleTranslationVisibility,
          ),
          _ToggleAction(
            label: '忽略大小写',
            icon: Icons.text_fields,
            selected: controller.ignoreCase,
            enabled: enableToggles,
            onChanged: controller.toggleIgnoreCase,
          ),
          _ToggleAction(
            label: '按键音',
            icon: Icons.keyboard,
            selected: controller.keySoundEnabled,
            enabled: enableToggles,
            onChanged: controller.toggleKeySound,
          ),
          _ToggleAction(
            label: '提示音',
            icon: Icons.volume_up,
            selected: controller.feedbackSoundEnabled,
            enabled: enableToggles,
            onChanged: controller.toggleFeedbackSound,
          ),
          _ToggleAction(
            label: '默写模式',
            icon: Icons.spellcheck,
            selected: controller.dictationMode,
            enabled: enableToggles,
            onChanged: controller.toggleDictationMode,
          ),
        ];

        if (controller.supportsPronunciation) {
          toggleActions.add(
            _ToggleAction(
              label: '自动发音',
              icon: Icons.record_voice_over,
              selected: controller.autoPronunciationEnabled,
              enabled: enableToggles,
              onChanged: controller.toggleAutoPronunciation,
            ),
          );
        }

        for (final _ToggleAction action in toggleActions) {
          addHeaderItem(_IconToggleChip(action: action));
        }

        addHeaderItem(
          Tooltip(
            message: controller.isTyping ? '暂停' : '开始',
            waitDuration: const Duration(milliseconds: 200),
            child: IconButton.filled(
              style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
              onPressed: enableSessionActions
                  ? () {
                      controller.toggleTyping();
                    }
                  : null,
              icon: Icon(controller.isTyping ? Icons.pause : Icons.play_arrow),
            ),
          ),
        );

        addHeaderItem(
          Tooltip(
            message: '重新开始',
            waitDuration: const Duration(milliseconds: 200),
            child: IconButton.outlined(
              style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
              onPressed: enableSessionActions
                  ? () {
                      unawaited(controller.restartChapter());
                    }
                  : null,
              icon: const Icon(Icons.refresh),
            ),
          ),
        );

        addHeaderItem(
          Tooltip(
            message: '跳过',
            waitDuration: const Duration(milliseconds: 200),
            child: IconButton.outlined(
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(10),
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: controller.canSkipCurrentWord
                  ? () {
                      controller.skipCurrentWord();
                    }
                  : null,
              icon: const Icon(Icons.skip_next),
            ),
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: headerItems,
            ),
          ),
        );
      },
    );
  }
}

class _IconToggleChip extends StatelessWidget {
  const _IconToggleChip({required this.action});

  final _ToggleAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool enabled = action.enabled;
    final bool selected = action.selected;

    final Color iconColor;
    if (!enabled) {
      iconColor = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (selected) {
      iconColor = colorScheme.primary;
    } else {
      iconColor = colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: action.label,
      waitDuration: const Duration(milliseconds: 200),
      child: FilterChip(
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        label: Icon(action.icon, size: 18, color: iconColor),
        selected: selected,
        onSelected: enabled
            ? (_) {
                action.onChanged(!selected);
              }
            : null,
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary.withValues(alpha: 0.16),
        disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
        ),
      ),
    );
  }
}

class _IconMenuButton<T> extends StatelessWidget {
  const _IconMenuButton({
    required this.icon,
    required this.tooltip,
    required this.options,
    required this.onSelected,
    required this.enabled,
    this.selectedValue,
  });

  final IconData icon;
  final String tooltip;
  final List<_MenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color iconColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 200),
      child: PopupMenuButton<T>(
        enabled: enabled,
        tooltip: tooltip,
        splashRadius: 24,
        offset: const Offset(0, 40),
        onSelected: onSelected,
        itemBuilder: (BuildContext context) {
          if (options.isEmpty) {
            return <PopupMenuEntry<T>>[
              PopupMenuItem<T>(
                enabled: false,
                height: 36,
                child: Text(
                  '暂无选项',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ];
          }
          return options.map(( _MenuOption<T> option) => _buildItem(context, option)).toList();
        },
        child: Container(
          height: 40,
          width: 44,
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? colorScheme.outlineVariant
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 20),
              Positioned(
                bottom: 6,
                right: 6,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: enabled
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<T> _buildItem(BuildContext context, _MenuOption<T> option) {
    final ThemeData theme = Theme.of(context);
    final bool isSelected = selectedValue != null && selectedValue == option.value;
    final ColorScheme colorScheme = theme.colorScheme;

    return PopupMenuItem<T>(
      value: option.value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 20,
            child: isSelected
                ? Icon(Icons.check, size: 18, color: colorScheme.primary)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _MenuOption<T> {
  const _MenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _ToggleAction {
  const _ToggleAction({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;
}

class _WordPanel extends StatelessWidget {
  const _WordPanel({
    required this.controller,
    this.startPrompt = '按任意键开始',
    this.resumePrompt = '按任意键继续',
  });

  final TypingController controller;
  final String startPrompt;
  final String resumePrompt;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && !controller.isSessionReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final WordEntry? word = controller.currentWord;

    if (word == null) {
      return const Center(child: Text('当前章节没有可用的单词'));
    }

    final ThemeData theme = Theme.of(context);

    final Widget wordBody = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _WordDisplay(
          word: word,
          states: controller.letterStates,
          dictationMode: controller.dictationMode,
        ),
        const SizedBox(height: 12),
        if (word.usPhonetic != null || word.ukPhonetic != null)
          Text(
            _buildPhoneticLine(word),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        if (word.notation != null && word.notation!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              word.notation!,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
          ),
        if (controller.supportsPronunciation)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              onPressed: controller.isLoading
                  ? null
                  : controller.playCurrentPronunciation,
              icon: const Icon(Icons.volume_up),
              label: const Text('播放发音'),
            ),
          ),
        if (controller.showTranslation)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              word.translationText.isEmpty ? '（无释义）' : word.translationText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );

    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: wordBody,
            ),
          ),
        ),
        if (!controller.isTyping && !controller.isFinished)
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.55,
                          ),
                          child: Text(
                            controller.elapsedSeconds == 0
                                ? startPrompt
                                : resumePrompt,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        if (controller.isFinished)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              color: Colors.black.withValues(alpha: 0.4),
              child: _FinishCard(controller: controller),
            ),
          ),
      ],
    );
  }

  String _buildPhoneticLine(WordEntry word) {
    final List<String> result = <String>[];
    if (word.usPhonetic != null && word.usPhonetic!.isNotEmpty) {
      result.add('美 /${word.usPhonetic}/');
    }
    if (word.ukPhonetic != null && word.ukPhonetic!.isNotEmpty) {
      result.add('英 /${word.ukPhonetic}/');
    }
    return result.join('   ');
  }
}

class _WordDisplay extends StatelessWidget {
  const _WordDisplay({
    required this.word,
    required this.states,
    required this.dictationMode,
  });

  final WordEntry word;
  final List<LetterState> states;
  final bool dictationMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle baseStyle = theme.textTheme.displaySmall!.copyWith(
      letterSpacing: 1.2,
    );

    final List<Widget> letters = <Widget>[];
    final String display = word.displayWord;
    for (int i = 0; i < display.length; i += 1) {
      final String letter = display[i];
      final LetterState state = i < states.length
          ? states[i]
          : LetterState.idle;
      final bool shouldHideLetter = dictationMode && state != LetterState.correct;
      final String visibleLetter = shouldHideLetter ? '_' : letter;
      letters.add(
        _LetterTile(letter: visibleLetter, state: state, style: baseStyle),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> spacedLetters = <Widget>[];
        for (int i = 0; i < letters.length; i += 1) {
          if (i > 0) {
            spacedLetters.add(const SizedBox(width: 4));
          }
          spacedLetters.add(letters[i]);
        }

        final Widget wordRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: spacedLetters,
        );

        final Widget scaledWord = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: wordRow,
        );

        if (!constraints.hasBoundedWidth) {
          return scaledWord;
        }

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: scaledWord,
          ),
        );
      },
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.state,
    required this.style,
  });

  final String letter;
  final LetterState state;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Color? background;
    Color? foreground = style.color;
    final ThemeData theme = Theme.of(context);

    switch (state) {
      case LetterState.correct:
        background = theme.colorScheme.primary.withValues(alpha: 0.15);
        foreground = theme.colorScheme.primary;
        break;
      case LetterState.wrong:
        background = theme.colorScheme.error.withValues(alpha: 0.2);
        foreground = theme.colorScheme.error;
        break;
      case LetterState.idle:
        background = null;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(letter, style: style.copyWith(color: foreground)),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double accuracy = controller.accuracy * 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              label: '用时',
              value: _formatDuration(controller.elapsedSeconds),
              icon: Icons.timer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: '完成',
              value: '${controller.completedWords}/${controller.totalWords}',
              icon: Icons.playlist_add_check,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: '每分钟单词数',
              value: controller.wordsPerMinute.toString(),
              icon: Icons.speed,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: '准确率',
              value: '${accuracy.toStringAsFixed(0)}%',
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String secs = twoDigits(duration.inSeconds.remainder(60));
    final int hours = duration.inHours;
    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    final Color iconColor = theme.colorScheme.primary;
    final TextStyle valueStyle =
        (theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
          fontWeight: FontWeight.w600,
        );
    final TextStyle labelStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 4),
          Text.rich(
            TextSpan(
              text: value,
              style: valueStyle,
              children: <InlineSpan>[
                TextSpan(text: ' $label', style: labelStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

class _SloganFooter extends StatelessWidget {
  const _SloganFooter();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '坚持练习，进步就在眼前。',
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('本章节完成！', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              '总耗时 ${_formatDuration(controller.elapsedSeconds)}，准确率 ${(controller.accuracy * 100).toStringAsFixed(0)}%。',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (!controller.hasNextChapter || controller.isLoading)
                  ? null
                  : () {
                      unawaited(controller.goToNextChapter());
                    },
              child: const Text('进入下一章'),
            ),
            if (!controller.hasNextChapter)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('已经是最后一章', textAlign: TextAlign.center),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.isLoading
                  ? null
                  : () {
                      unawaited(controller.restartChapter());
                    },
              child: const Text('重新练习本章'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String secs = twoDigits(duration.inSeconds.remainder(60));
    final int hours = duration.inHours;
    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }
}
