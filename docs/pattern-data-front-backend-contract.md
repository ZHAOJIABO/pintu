# PatternData 图纸前后端对接规范

`PatternData` 是 Bobobeads 图纸在客户端、服务端、外部内容提供方之间交换的标准数据结构。它描述的是可编辑、可重绘的拼豆格子和颜色表，而不是一张预览图片。

本文面向 Flutter、后端、内容运营工具及外部图纸提供方。接口路径、鉴权和通用响应头约定以 [Flutter 客户端后端接口对接文档](flutter-client-api-integration.md) 为准。

## 1. 结论与边界

- 跨端传输和业务存档的逻辑契约统一使用 `PatternData`。
- Flutter 内部的 `GeneratedPattern` 不是接口契约，不能作为服务端存储格式直接暴露。
- `patternImageUrl` 仅是预览图；不能替代 `PatternData`，否则图纸无法可靠重绘、统计或编辑。
- 后端必须校验并重新计算图纸统计值，不能信任客户端传入的 `beadCount`、`colorCount`。
- 目前客户端没有“从本地选择 JSON 文件导入图纸”的独立 UI。外部图纸应由后端作为模板或作品保存，并通过既有详情接口返回。

## 2. 核心概念

| 名称 | 作用 | 是否跨端传输 |
|---|---|---|
| `GeneratedPattern` | Flutter 本地生成、渲染和导出的内部模型。像素为 RGBA 字节。 | 否 |
| `PatternData` | 图纸的接口和存储逻辑模型。像素为调色板索引。 | 是 |
| `colorPalette` | 当前图纸使用的颜色快照。 | 是 |
| `patternImageUrl` | 图纸 PNG 等预览资源地址。 | 是，但仅用于展示 |
| `DraftProject` | 本地生成来源，如原图、裁剪、尺寸和颜色限制。 | 否，除非业务另行保存草稿 |

Flutter 的本地生成结果会由 `PatternData.fromGeneratedPattern` 转换为接口格式；收到接口详情时，会由 `PatternData.toGeneratedPattern` 转换回渲染所需的内部格式。

## 3. PatternData JSON 契约

```json
{
  "width": 3,
  "height": 3,
  "boardSpec": "29x29",
  "pixels": [1, 1, 0, 1, 2, 1, 0, 1, 1],
  "colorPalette": [
    {
      "index": 1,
      "hex": "#FF0000",
      "brand": "mard",
      "code": "A01",
      "name": "红色"
    },
    {
      "index": 2,
      "hex": "#FFFFFF",
      "brand": "mard",
      "code": "A02",
      "name": "白色"
    }
  ],
  "schemaVersion": 1
}
```

### 3.1 字段说明

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `width` | integer | 是 | 图纸横向格数。 |
| `height` | integer | 是 | 图纸纵向格数。 |
| `boardSpec` | string | 是 | 板型/规格标识，例如 `29x29`。用于业务归类和展示，实际渲染尺寸以 `width`、`height` 为准。 |
| `pixels` | integer[] | 是 | 按行优先顺序排列的颜色索引。长度必须等于 `width * height`。 |
| `colorPalette` | object[] | 是 | 图纸颜色快照。数组本身不代表像素颜色顺序，以元素的 `index` 为准。 |
| `schemaVersion` | integer | 建议是 | 数据结构版本。当前固定为 `1`；生产方应显式发送。 |

### 3.2 colorPalette 元素

| 字段 | 类型 | 必填 | 约束与用途 |
|---|---|---:|---|
| `index` | integer | 是 | 正整数，且在同一张图纸内唯一。由 `pixels` 引用。 |
| `hex` | string | 是 | `#RRGGBB`，例如 `#FF0000`。 |
| `brand` | string | 建议是 | 色板品牌标识，例如 `mard`。 |
| `code` | string | 建议是 | 色号，例如 `A01`。同一图纸内应唯一，材料统计以它作为键。 |
| `name` | string | 建议是 | 人类可读颜色名，例如 `红色`。 |

当 `brand`、`code` 或 `name` 缺失时，当前 Flutter 客户端可以使用降级显示；但外部生产方应提供完整颜色快照，保证材料表、历史图纸与不同端的显示一致。

## 4. 像素编码规则

`pixels` 使用行优先（row-major）的一维数组：

```text
pixels[y * width + x]
```

对于 `width = 3`、`height = 3`、`pixels = [1, 1, 0, 1, 2, 1, 0, 1, 1]`：

| y \ x | 0 | 1 | 2 |
|---:|---:|---:|---:|
| 0 | 1 | 1 | 0 |
| 1 | 1 | 2 | 1 |
| 2 | 0 | 1 | 1 |

- `0` 表示透明/空格，不对应任何 `colorPalette` 元素。
- 正整数表示 `colorPalette` 中相同 `index` 的颜色。
- 像素索引不是数组下标。即使调色板元素顺序变化，只要 `index` 不变，图纸含义不变。

## 5. 校验规则

服务端接收图纸时应完整校验，随后再持久化。客户端校验用于尽早反馈，不能替代服务端校验。

| 项目 | 规则 |
|---|---|
| 尺寸 | `width > 0`、`height > 0`。当前接口默认最大 `200 x 200`。 |
| 总格数 | `width * height <= 40000`。计算时应防止整数溢出。 |
| 像素数量 | `pixels.length == width * height`。 |
| 调色板数量 | 当前接口默认最多 128 色。 |
| 调色板索引 | 每个 `index` 必须大于 0，且不可重复。 |
| 像素索引 | 必须为 `0`，或存在于 `colorPalette.index`。 |
| 颜色格式 | `hex` 必须匹配 `^#[0-9A-Fa-f]{6}$`。 |
| 色号 | 建议 `code` 在同一图纸中唯一；重复色号会导致材料统计合并。 |
| 统计值 | `beadCount` 必须由非零像素数计算；`colorCount` 必须由实际使用的非零颜色数计算。 |

建议在业务错误响应中沿用现有响应信封：HTTP 状态码表示传输层问题，业务校验失败通过 `header.code`、`header.message` 和 `traceId` 返回。不要只因为 HTTP 为 `200` 就视为写入成功。

## 6. Flutter 本地模型与转换

### 6.1 GeneratedPattern

Flutter 本地算法使用 `GeneratedPattern`：

```text
GeneratedPattern
  pixels: Uint8List  // RGBA，每个格子 4 字节，长度为 width * height * 4
  width: int
  height: int
  usage: Map<String, int>
  paletteEntries: List<PaletteEntry>
  draft: DraftProject
```

它包含 RGBA 像素、生成来源和界面所需对象，不适合作为服务端通用数据格式。

### 6.2 转换方向

```text
客户端图片/AI 输出图
  -> 本地颜色量化
  -> GeneratedPattern (RGBA)
  -> PatternData (索引像素 JSON)
  -> 服务端

服务端模板/作品详情
  -> PatternData (索引像素 JSON)
  -> GeneratedPattern (RGBA)
  -> 现有“图纸”页面渲染
```

本地生成的颜色匹配目前使用 CIEDE2000，平滑开关来自草稿配置，平滑强度固定为 50。这些是算法输入，不是外部图纸提供方必须传递的字段；外部图纸只需提供最终 `PatternData`。

## 7. 前后端交互形式

所有 REST JSON 使用 lowerCamelCase，并遵循统一响应信封：

```json
{
  "header": {
    "code": 0,
    "message": "success",
    "traceId": "optional-trace-id"
  }
}
```

### 7.1 官方图纸详情

图库列表只返回摘要；用户点击缩略图后，客户端请求详情并取得完整 `PatternData`。

```http
GET /api/v1/templates/{templateId}
```

```json
{
  "header": {"code": 0, "message": "success"},
  "template": {
    "templateId": "external-rabbit-001",
    "title": "外部小兔",
    "thumbnailUrl": "https://cdn.example.com/templates/rabbit-thumb.png",
    "previewUrl": "https://cdn.example.com/templates/rabbit-preview.png",
    "boardSpec": "29x29",
    "width": 29,
    "height": 29,
    "colorCount": 12
  },
  "patternData": {
    "width": 29,
    "height": 29,
    "boardSpec": "29x29",
    "pixels": [1, 1, 0],
    "colorPalette": [
      {"index": 1, "hex": "#FF0000", "brand": "mard", "code": "A01", "name": "红色"}
    ],
    "schemaVersion": 1
  }
}
```

列表接口 `GET /api/v1/templates` 至少应为每个可展示项提供 `templateId` 和 `thumbnailUrl` 或 `previewUrl`。图库图片统一为 358×358px PNG：只含 `PatternData` 对应的彩色像素块和白色背景，不含最终图纸的色号、坐标、网格、标题或图例。详情中的 `template.width`、`template.height`、`template.colorCount` 应与 `patternData` 重新计算出的结果一致。

### 7.2 保存客户端生成的图纸

图纸保存的完整业务流程如下：

```text
客户端生成 GeneratedPattern
  -> 转为 PatternData
  -> 创建 generation 凭证
  -> 上传原图和图纸预览图到对象存储
  -> POST generation/{generationId}/complete
  -> 服务端校验并保存 PatternData
```

完成请求的核心 body：

```json
{
  "title": "我的水彩图纸",
  "originalImageUrl": "https://cdn.example.com/original.png",
  "patternImageUrl": "https://cdn.example.com/pattern-preview.png",
  "patternData": {
    "width": 29,
    "height": 29,
    "boardSpec": "29x29",
    "pixels": [1, 1, 0],
    "colorPalette": [
      {"index": 1, "hex": "#FF0000", "brand": "mard", "code": "A01", "name": "红色"}
    ],
    "schemaVersion": 1
  },
  "beadCount": 2,
  "colorCount": 1
}
```

相关接口：

| 场景 | 接口 | PatternData 位置 |
|---|---|---|
| 官方模板详情 | `GET /api/v1/templates/{templateId}` | 响应的 `patternData` |
| 完成生成 | `POST /api/v1/generation/{generationId}/complete` | 请求的 `patternData` |
| 直接保存作品 | `POST /api/v1/works` | 请求的 `patternData` |
| 查询作品详情 | `GET /api/v1/works/{workId}` | 响应的 `patternData` |
| 保存草稿 | `POST /api/v1/works/drafts` | 请求的 `patternData` |

### 7.3 外部图纸接入

外部系统提供的是“已完成图纸”时，不需要提供原图、CIEDE2000 参数或平滑参数。它应提供完整的 `PatternData`，并配合以下任一业务身份：

1. **官方/运营模板**：保存为模板，向列表接口提供缩略图，向模板详情接口返回 `template + patternData`。
2. **用户作品**：保存为作品，向作品详情接口返回 `work + patternData`。
3. **客户端本地导入功能**：未来若增加 JSON 文件导入，文件内容应是本规范的 `PatternData`；导入后复用同一校验和渲染链路。

## 8. 后端存储建议

### 8.1 逻辑格式与物理格式

`PatternData` 是唯一的逻辑数据源，但数据库不一定要原样存储 JSON 数组。不要把 JSONB 和二进制像素同时当作两个可编辑的事实来源。

| 阶段 | 推荐物理存储 | 适用场景 |
|---|---|---|
| MVP | 一个完整的 `pattern_data JSONB` | 实现快、量级较小、便于排障和人工查看。 |
| 规模化 | `pixels` 保存为二进制，`colorPalette` 保存为 JSON，元数据列化 | 图纸量大、详情读取频繁、需要控制存储和网络成本。 |

当前契约最多 128 色，因此规模化存储时每个像素可使用 1 个无符号字节：字节值与 `colorPalette.index` 完全一致，`0` 仍表示透明。`200 x 200` 图纸的原始像素数据最多约 40 KB；可以按需要压缩，并记录编码方式。

### 8.2 推荐表结构

以下以 PostgreSQL 为例。模板和作品可以各自拥有一条图纸记录，或共用 `pattern_payloads` 表。

```sql
CREATE TABLE pattern_payloads (
  pattern_id UUID PRIMARY KEY,
  schema_version SMALLINT NOT NULL DEFAULT 1,
  width SMALLINT NOT NULL,
  height SMALLINT NOT NULL,
  board_spec TEXT NOT NULL,
  palette_json JSONB NOT NULL,
  pixels BYTEA NOT NULL,
  pixels_encoding TEXT NOT NULL DEFAULT 'uint8',
  bead_count INTEGER NOT NULL,
  color_count SMALLINT NOT NULL,
  content_sha256 CHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK (width > 0 AND height > 0),
  CHECK (width <= 200 AND height <= 200)
);
```

说明：

- `pixels` 保存未压缩 `uint8` 或压缩后的字节序列；若压缩，`pixels_encoding` 例如为 `uint8-zstd`。
- `palette_json` 保存完整 `colorPalette` 快照，而不是只保存颜色库外键。
- `bead_count`、`color_count` 是服务端从像素重算后的冗余列，供列表和统计使用。
- `content_sha256` 应基于规范化后的 `schemaVersion`、尺寸、`boardSpec`、调色板和像素计算，可用于幂等、去重和数据校验。
- 原图、预览图和缩略图应保存于对象存储，数据库仅保存 URL 或对象 key。

如果先使用 JSONB，建议存储完整的接口对象：

```text
pattern_data JSONB NOT NULL  -- 完整 PatternData
```

后续迁移到二进制时，保持 REST API 继续收发本规范 JSON；由后端在持久化层编码、解码即可，客户端和外部生产方不需要改动。

### 8.3 存储流程

```text
接收 PatternData JSON
  -> 校验尺寸、调色板、像素索引和颜色格式
  -> 重算 beadCount、colorCount
  -> 写入 PatternData JSONB，或编码 pixels 为 uint8 并保存 palette 快照
  -> 保存内容哈希、图纸元数据和对象存储资源引用
  -> 读取详情时重建 PatternData JSON
```

禁止仅保存 `patternImageUrl`。预览图无法支持逐格渲染、材料表统计、颜色编辑或未来的导出格式。

## 9. 版本演进规则

1. 当前生产方发送 `schemaVersion: 1`。
2. 向后兼容的可选字段可以直接新增；不得改变已有字段的类型或既有索引语义。
3. 修改像素编码、支持超过 255 色或改变颜色格式时，必须升级 `schemaVersion`，并提供旧版本读取迁移。
4. 数据库存储的 `schema_version` 与接口中的 `schemaVersion` 必须一致。
5. 服务端读取旧图纸时应转换为当前接口可理解的 JSON；无法转换时返回明确业务错误和 `traceId`，不要静默返回错误图纸。

## 10. 联调清单

### 外部生产方

- [ ] 发送 `width`、`height`、`boardSpec`、`pixels`、`colorPalette`、`schemaVersion`。
- [ ] 确认 `pixels.length == width * height`。
- [ ] 确认所有非零像素索引都存在于调色板。
- [ ] 确认每个调色板 `index` 唯一且大于 0。
- [ ] 确认 `hex` 使用 `#RRGGBB`，并提供品牌、色号和颜色名。
- [ ] 确认 `code` 在单张图纸内唯一。

### 后端

- [ ] 在写入前完成完整校验和统计重算。
- [ ] 详情接口返回的 `width`、`height`、`boardSpec` 与保存数据一致。
- [ ] 保存后再读取一次，确认 `pixels` 与调色板逐项一致。
- [ ] 不以预览图代替结构化图纸数据。
- [ ] 对模板/作品归属、读写权限和对象存储 URL 实施鉴权。

### Flutter 客户端

- [ ] 收到 `header.code == 0` 后再解析 `patternData`。
- [ ] 使用 `PatternData.toGeneratedPattern` 渲染详情页。
- [ ] 在本地生成后使用 `PatternData.fromGeneratedPattern` 组装保存请求。
- [ ] 对异常图纸保持容错，不展示错误的材料统计或错误颜色。

## 11. 参考实现

- [PatternData Flutter 模型与双向转换](../lib/services/api/api_models.dart)
- [图纸接口仓库](../lib/services/api/api_repositories.dart)
- [图纸数据转换测试](../test/services/api_client_test.dart)
- [主接口对接文档](flutter-client-api-integration.md)
