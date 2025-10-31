# Loopra

把练习变成本能。

## 自定义词典

应用现在支持导入与删除自定义词典。入口位于「设置 → 词库」，在该区域可以使用：

- `导入词库`：从本地选择一个符合规范的 JSON 文件并立即启用。
- `删除词库`：仅对自定义词典可用，删除后词典文件会从本地存储中移除。

> **提示**：Web 端会将自定义词典存储在浏览器本地存储中，清除站点数据会同时删除已导入词典。

### 词典文件格式

词典文件需要是一个 JSON 对象，包含 `meta` 与 `entries` 两个字段，可以参考示例文件 [`custom_en_dictionary.json`](custom_en_dictionary.json)：

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

导入时应用会校验基本结构，并将内容保存到本地数据目录（`Application Support/Loopra/dictionaries` 等平台对应位置）。要更新词典，可重新导入同一个文件；若名称重复，系统会为词典分配新的 ID 以确保不同版本可以共存。
