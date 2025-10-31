# Loopra

把练习变成本能。

Loopra 是一个由 Flutter 构建的跨平台词汇/短语打字训练应用，目标是在沉浸式的练习循环中让肌肉记忆快速建立。项目同时覆盖桌面、移动端与 Web，让你在任意设备上都能保持节奏。

## 功能亮点

- 多平台支持：同一套代码即可在 Android、iOS、Windows、macOS、Linux 与 Web 上运行。
- 词库驱动训练：内置多套章节式词库，可按章节推进，也可自由导入自定义词典。
- 实时反馈：展示用时、完成度、每分钟单词数（WPM）与准确率，练习表现一目了然。
- 沉浸式体验：桌面端自动聚焦输入区域；支持暂停/继续、章节重练与跳过卡住的单词。
- 声音与发音：提供按键音、正确/错误提示音，以及美式/英式发音（词库支持时）。

## 快速开始

### 在线体验

https://loopra.vercel.app/

### 全平台客户端下载

> 由于没有苹果开发者账号及设备，所以 ios 版本能否使用犹未可知

https://github.com/zaunist/Loopra/releases

### 环境准备

- Flutter stable（建议 3.22 及以上）与 Dart 3.9+。
- 已安装对应平台的构建依赖（如 Android SDK、Xcode、桌面端工具链等）。

### 启动开发环境

```bash
flutter pub get
flutter run -d chrome     # Web
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux
flutter run -d ios        # iOS（需配置签名）
flutter run -d android    # Android
```

### 构建发行包

```bash
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build macos --release
flutter build windows --release
flutter build linux --release
flutter build ios --release --no-codesign
```

GitHub Actions 中的 `.github/workflows/build.yml` 已配置上述目标的自动构建与打包。

## 使用技巧

- **章节管理**：在「设置」或桌面端顶部控件中选择词库与章节，完成后可一键进入下一章。
- **练习节奏**：首次按键自动开始计时；暂停后任意键继续，保持注意力集中。
- **过滤开关**：通过 FilterChip/开关切换「显示释义」「忽略大小写」「按键音」「提示音」等偏好。
- **发音辅助**：支持的词库可切换美音/英音，或直接播放当前单词的发音，辅助听写练习。
- **卡词应对**：错误尝试超过 4 次会出现「跳过」按钮，帮助快速进入下一个单词。
- **统计复盘**：底部状态栏实时刷新 WPM、准确率等指标，方便记录每日练习质量。

## 自带与自定义词库

- 内置资源位于 `assets/dicts/`，覆盖常见考试词库与示例数据。
- 自定义词典入口位于「设置 → 词库」，可导入 JSON 文件并随时删除。
- Web 端在浏览器本地存储中保存自定义词库，清除站点数据会同步清空。

### 词典文件格式

词典文件需要是一个 JSON 对象，包含 `meta` 与 `entries` 两个字段，可参考示例文件 [`custom_en_dictionary.json`](custom_en_dictionary.json)：

```json
{
  "meta": {
    "id": "custom_en",
    "name": "我的英语词库",
    "description": "示例词库描述",
    "language": "en",
    "category": "自定义"
  },
  "entries": [
    {
      "name": "apple",
      "trans": ["苹果", "苹果树"],
      "usphone": "ˈæpəl",
      "ukphone": "ˈæpl",
      "notation": "n."
    }
  ]
}
```

- `meta.id`（可选）：词典唯一标识符，未提供时会根据名称自动生成。
- `meta.name`（必填）：词典在界面中的展示名称。
- `meta.description`（可选）：词典简介。
- `meta.language`（可选）：语言代码，支持的值为 `en`（英语）、`code`（编程）、`other`。
- `meta.category`（可选）：分类标签。
- `entries`（必填）：词条数组。
  - `name`（必填）：词条原文。
  - `trans`（可选）：释义，可以是字符串或字符串数组。
  - `usphone` / `ukphone`（可选）：美式 / 英式音标。
  - `notation`（可选）：额外备注（如词性）。

导入时应用会校验基本结构，并将内容保存到本地数据目录（例如 `Application Support/Loopra/dictionaries`）。要更新词典，可重新导入同一个文件；若名称重复，系统会为词典分配新的 ID 以确保不同版本共存。

## 贡献指南

欢迎提交 Issue 或 Pull Request，与社区一起打磨更高效的练习体验。

## 感谢

[qwerty-learner](https://github.com/RealKai42/qwerty-learner)
