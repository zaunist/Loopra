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
                    _WordListView(controller: controller),
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

class _MobileTypingScaffold extends StatelessWidget {
  const _MobileTypingScaffold({required this.controller});

  final TypingController controller;

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
                child: _MobileWordArea(controller: controller),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: _MobileKeyboard(controller: controller),
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
    final TextStyle titleStyle = (appBarTheme.titleTextStyle ??
            textTheme.titleLarge ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
        .copyWith(
      color: appBarTheme.titleTextStyle?.color ??
          appBarTheme.foregroundColor ??
          theme.colorScheme.onSurface,
    );
    final Color baseSubtitleColor = appBarTheme.titleTextStyle?.color ??
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
  const _MobileWordArea({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _WordPanel(
            controller: controller,
            startPrompt: '点击键盘开始',
            resumePrompt: '点击键盘继续',
          ),
        ),
        const SizedBox(height: 16),
        _StatsBar(controller: controller),
        const SizedBox(height: 16),
        _MobileActionButtons(controller: controller),
      ],
    );
  }
}

class _MobileActionButtons extends StatelessWidget {
  const _MobileActionButtons({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        FilledButton.icon(
          onPressed: controller.isLoading || !controller.isSessionReady
              ? null
              : () {
                  controller.toggleTyping();
                },
          icon: Icon(controller.isTyping ? Icons.pause : Icons.play_arrow),
          label: Text(controller.isTyping ? '暂停' : '开始'),
        ),
        OutlinedButton(
          onPressed: controller.isLoading || !controller.isSessionReady
              ? null
              : () {
                  unawaited(controller.restartChapter());
                },
          child: const Text('重新开始'),
        ),
        if (controller.canSkipCurrentWord)
          OutlinedButton(
            onPressed: controller.skipCurrentWord,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('跳过'),
          ),
      ],
    );
  }
}

class _MobileKeyboard extends StatelessWidget {
  const _MobileKeyboard({required this.controller});

  final TypingController controller;

  static const List<List<String>> _rows = <List<String>>[
    <String>['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    <String>['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    <String>['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const List<int> _offsetFlex = <int>[0, 1, 2];

  @override
  Widget build(BuildContext context) {
    final bool disabled =
        controller.isLoading ||
        !controller.isSessionReady ||
        controller.isFinished;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(_rows.length, (int rowIndex) {
        final List<String> rowKeys = _rows[rowIndex];
        final int offset = _offsetFlex[rowIndex];
        return Padding(
          padding: EdgeInsets.only(
            bottom: rowIndex == _rows.length - 1 ? 0 : 12,
          ),
          child: Row(
            children: <Widget>[
              if (offset > 0) Spacer(flex: offset),
              ...rowKeys.map(
                (String letter) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _KeyboardKey(
                      label: letter,
                      onPressed: disabled
                          ? null
                          : () => controller.handleCharacterInput(
                              letter.toLowerCase(),
                            ),
                    ),
                  ),
                ),
              ),
              if (offset > 0) Spacer(flex: offset),
            ],
          ),
        );
      }),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
        ),
      ),
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
    final String? selectedDescription =
        selected != null && selected.description.isNotEmpty
        ? selected.description
        : null;
    final String? selectedCategory =
        selected != null &&
            selected.category != null &&
            selected.category!.isNotEmpty
        ? selected.category
        : null;

    return Wrap(
      runSpacing: 12,
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 220,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '词库',
              helperText: selectedDescription,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selected?.id,
                items: dictionaries
                    .map(
                      (DictionaryMeta dict) => DropdownMenuItem<String>(
                        value: dict.id,
                        child: Text(dict.name),
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
        ),
        if (selectedCategory != null)
          Chip(
            label: Text(selectedCategory),
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
        SizedBox(
          width: 160,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: '章节'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: controller.chapterCount == 0
                    ? null
                    : (controller.selectedChapter < controller.chapterCount
                          ? controller.selectedChapter
                          : 0),
                items: controller.chapterCount == 0
                    ? const <DropdownMenuItem<int>>[]
                    : List<DropdownMenuItem<int>>.generate(
                        controller.chapterCount,
                        (int index) => DropdownMenuItem<int>(
                          value: index,
                          child: Text('第 ${index + 1} 章'),
                        ),
                      ),
                onChanged: controller.isLoading || controller.chapterCount == 0
                    ? null
                    : (int? chapter) {
                        if (chapter != null) {
                          unawaited(controller.selectChapter(chapter));
                        }
                      },
              ),
            ),
          ),
        ),
        FilterChip(
          label: const Text('显示释义'),
          selected: controller.showTranslation,
          onSelected: controller.toggleTranslationVisibility,
        ),
        FilterChip(
          label: const Text('忽略大小写'),
          selected: controller.ignoreCase,
          onSelected: controller.toggleIgnoreCase,
        ),
        FilterChip(
          label: const Text('按键音'),
          selected: controller.keySoundEnabled,
          onSelected: controller.toggleKeySound,
        ),
        FilterChip(
          label: const Text('提示音'),
          selected: controller.feedbackSoundEnabled,
          onSelected: controller.toggleFeedbackSound,
        ),
        if (controller.supportsPronunciation)
          FilterChip(
            label: const Text('自动发音'),
            selected: controller.autoPronunciationEnabled,
            onSelected: controller.toggleAutoPronunciation,
          ),
        if (controller.supportsPronunciation)
          SizedBox(
            width: 140,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '发音偏好'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PronunciationVariant>(
                  isExpanded: true,
                  value: controller.pronunciationVariant,
                  items: const <DropdownMenuItem<PronunciationVariant>>[
                    DropdownMenuItem<PronunciationVariant>(
                      value: PronunciationVariant.us,
                      child: Text('美音'),
                    ),
                    DropdownMenuItem<PronunciationVariant>(
                      value: PronunciationVariant.uk,
                      child: Text('英音'),
                    ),
                  ],
                  onChanged: controller.isLoading
                      ? null
                      : (PronunciationVariant? variant) {
                          if (variant != null) {
                            controller.setPronunciationVariant(variant);
                          }
                        },
                ),
              ),
            ),
          ),
        ElevatedButton.icon(
          onPressed: controller.isLoading || !controller.isSessionReady
              ? null
              : () {
                  controller.toggleTyping();
                },
          icon: Icon(controller.isTyping ? Icons.pause : Icons.play_arrow),
          label: Text(controller.isTyping ? '暂停' : '开始'),
        ),
        OutlinedButton(
          onPressed: controller.isLoading || !controller.isSessionReady
              ? null
              : () {
                  unawaited(controller.restartChapter());
                },
          child: const Text('重新开始'),
        ),
        if (controller.canSkipCurrentWord)
          OutlinedButton(
            onPressed: controller.skipCurrentWord,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('跳过'),
          ),
      ],
    );
  }
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
        _WordDisplay(word: word, states: controller.letterStates),
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
  const _WordDisplay({required this.word, required this.states});

  final WordEntry word;
  final List<LetterState> states;

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
      letters.add(_LetterTile(letter: letter, state: state, style: baseStyle));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: letters,
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
    final double accuracy = controller.accuracy * 100;

    return Wrap(
      spacing: 24,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _StatTile(
          label: '用时',
          value: _formatDuration(controller.elapsedSeconds),
          icon: Icons.timer,
        ),
        _StatTile(
          label: '完成',
          value: '${controller.completedWords}/${controller.totalWords}',
          icon: Icons.playlist_add_check,
        ),
        _StatTile(
          label: '每分钟单词数',
          value: controller.wordsPerMinute.toString(),
          icon: Icons.speed,
        ),
        _StatTile(
          label: '准确率',
          value: '${accuracy.toStringAsFixed(0)}%',
          icon: Icons.check_circle,
        ),
      ],
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
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: theme.textTheme.titleMedium),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WordListView extends StatelessWidget {
  const _WordListView({required this.controller});

  final TypingController controller;

  @override
  Widget build(BuildContext context) {
    final List<WordEntry> words = controller.words;
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: words.length,
        itemBuilder: (BuildContext context, int index) {
          final bool isCurrent =
              index == controller.currentIndex && !controller.isFinished;
          final bool isCompleted = index < controller.currentIndex;
          final WordEntry word = words[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : isCompleted
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  word.headword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  word.translations.isEmpty ? '' : word.translations.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
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
              onPressed: () {
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
