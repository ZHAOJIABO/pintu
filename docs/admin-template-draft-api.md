# 管理后台图纸草稿接口契约（需求稿）

本文约定 Web 管理后台新增的「草稿」能力。鉴权与响应信封沿用 `docs/admin-template-management-api.md`：

```http
Authorization: Bearer <admin_access_token>
X-Platform: web
X-Device-Id: admin-web
```

## 0. 背景与目标

当前后台只有「发布」和「更新」两个动作，二者都立即对用户端生效：

- 生成图纸后唯一出口是 `POST /api/v1/admin/templates`，点了就上线，没有中间态。
- 编辑已发布模板走 `PUT /api/v1/admin/templates/{templateId}`，全量覆盖并立即生效，改一半保存就等于把半成品推给了用户。
- 编辑器状态纯内存，刷新或关闭浏览器即丢失，无法「先存着，下次继续改」。

需要达成的两个场景：

1. **新图纸暂存**：生成或画了一半，先存草稿，改天继续，满意了再发布。
2. **已发布模板的修订暂存**：在不影响线上版本的前提下修改已发布模板，满意了再一次性替换。

## 1. 核心模型

草稿是**独立资源**，有自己的 `draftId`，并可选关联一个已发布模板：

| 场景 | `templateId` | 发布后行为 |
| --- | --- | --- |
| 新图纸草稿 | 为空 | 新建一条已发布模板 |
| 已发布模板的修订草稿 | 指向该模板 | 覆盖该模板，草稿删除 |

关键约束：

- **草稿完全不影响线上**。已发布模板的 `patternData` 与预览资源在草稿保存期间保持原样，用户端读到的始终是已发布版本。只有「发布草稿」这一步才会替换线上内容。
- **一个模板同时最多挂一份草稿**。对同一 `templateId` 重复创建草稿应返回已存在的那份（含 `draftId`），而不是产生第二份。
- **草稿对全部管理员可见可编辑**，不做归属隔离。因此需要并发保护，见第 8 节。

## 2. 保存草稿（新建）

```http
POST /api/v1/admin/template-drafts
Content-Type: application/json

{
  "idempotencyKey": "admin-draft-1735900000000",
  "templateId": "",
  "title": "小狐狸",
  "description": "",
  "categoryId": 7,
  "tags": "动物,入门",
  "difficulty": 1,
  "previewFileKey": "",
  "patternData": {"width": 29, "height": 29, "boardSpec": "29x29", "pixels": [], "colorPalette": []}
}
```

响应：

```json
{
  "header": {"code": 0, "message": "success"},
  "draft": {"draftId": "draft-001", "templateId": "", "updatedAt": "2026-08-19T10:03:00Z"}
}
```

字段规则（**与发布接口的关键差异**）：

- **除 `patternData` 外所有业务字段都允许为空或缺省**。草稿的用途就是承载半成品：标题没想好、分类还没选、`difficulty` 未定都必须能存下来。发布接口现有的必填校验不可照搬到本接口，否则草稿功能失去意义。
- `patternData` 仍需通过结构校验（沿用 `docs/pattern-data-front-backend-contract.md`），结构非法返回可读错误。
- `previewFileKey` 可为空。草稿列表的缩略图不强制要求：为空时前端用 `patternData` 本地渲染兜底（该兜底渲染已在模板库列表使用）。这样自动保存不必每次重新上传 358×358 PNG。若前端提交了 `previewFileKey`，服务端照常存储并在列表返回可访问 URL。
- `templateId` 非空时表示这是某个已发布模板的修订草稿，服务端需校验该模板存在且处于已发布状态，否则返回 `404`。
- `idempotencyKey` 沿用发布接口的语义，防止重复点击产生多份草稿。

## 3. 更新草稿

```http
PUT /api/v1/admin/template-drafts/{draftId}
Content-Type: application/json

{
  "title": "小狐狸",
  "description": "适合入门",
  "categoryId": 7,
  "tags": "动物,入门",
  "difficulty": 1,
  "previewFileKey": "",
  "patternData": {"...": "..."},
  "baseUpdatedAt": "2026-08-19T10:03:00Z"
}
```

- 字段与创建接口一致，同样允许为空。
- `baseUpdatedAt` 是前端读到这份草稿时的 `updatedAt`，用于乐观锁，见第 8 节。
- 响应返回新的 `updatedAt`，前端据此更新本地基线。

## 4. 草稿箱列表

```http
GET /api/v1/admin/template-drafts?page.page=1&page.pageSize=50
```

```json
{
  "header": {"code": 0, "message": "success"},
  "drafts": [
    {
      "draftId": "draft-001",
      "templateId": "",
      "title": "小狐狸",
      "categoryId": 7,
      "categoryName": "动物",
      "thumbnailUrl": "",
      "difficulty": 1,
      "width": 29,
      "height": 29,
      "colorCount": 8,
      "updatedAt": "2026-08-19T10:03:00Z",
      "updatedByActor": "admin-zhao",
      "patternData": {"...": "..."}
    }
  ],
  "page": {"total": 1, "page": 1, "pageSize": 50, "hasMore": false}
}
```

- 按 `updatedAt` 倒序返回，最近改的排最前。
- `updatedByActor` 用于在多人协作时显示「最后由谁修改」。
- `title` 为空的草稿由前端显示为「未命名草稿」，服务端不必填充占位标题。
- 列表建议附带 `patternData` 以支持缩略图兜底渲染；若数据量过大担心响应体积，可改为不返回 `patternData` 而要求服务端为草稿生成缩略图，此时 `thumbnailUrl` 变为必填。**两种方案二选一，请后端确认走哪条**，前端据此实现。

## 5. 草稿详情

```http
GET /api/v1/admin/template-drafts/{draftId}
```

响应结构对齐 `GET /api/v1/admin/templates/{templateId}`，用于重新进入编辑页：

```json
{
  "header": {"code": 0, "message": "success"},
  "draft": {
    "draftId": "draft-001",
    "templateId": "",
    "title": "小狐狸",
    "description": "适合入门",
    "categoryId": 7,
    "tags": ["动物", "入门"],
    "difficulty": 1,
    "previewFileKey": "",
    "updatedAt": "2026-08-19T10:03:00Z",
    "updatedByActor": "admin-zhao"
  },
  "patternData": {"...": "..."}
}
```

## 6. 发布草稿

```http
POST /api/v1/admin/template-drafts/{draftId}/publish
Content-Type: application/json

{
  "idempotencyKey": "admin-publish-1735900000000",
  "previewFileKey": "oss-key-of-358x358-png",
  "baseUpdatedAt": "2026-08-19T10:03:00Z"
}
```

- **完整校验在此刻执行**，而非保存草稿时：`title` 非空、`categoryId` 有效、`patternData` 合法、`previewFileKey` 存在。任一不满足返回可读错误，前端把用户挡回编辑页补全。
- `previewFileKey` 由前端在发布前重新生成并上传 358×358 PNG（走现有 `POST /api/v1/admin/media/upload`），规范见 `docs/admin-template-management-api.md` 第 1 节。发布请求携带该 key，因为草稿期间可能一直没有缩略图。
- 服务端按 `templateId` 分支处理，**整个过程必须原子**：
  - `templateId` 为空 → 新建已发布模板，返回新 `templateId`。
  - `templateId` 非空 → 覆盖该模板的图纸、元信息、预览资源。
- 发布成功后删除该草稿。失败时草稿必须完整保留，且不得留下只更新了一半的模板或预览资源。

响应：

```json
{
  "header": {"code": 0, "message": "success"},
  "templateId": "template-001"
}
```

## 7. 丢弃草稿

```http
DELETE /api/v1/admin/template-drafts/{draftId}
```

- 操作幂等：删除不存在的草稿返回成功，或返回前端可识别的「已删除」业务码，不要报服务端错误。
- 丢弃草稿不影响其关联的已发布模板。

## 8. 并发保护

草稿全员可编辑，两名管理员同时改同一份草稿会互相覆盖。要求：

- 更新与发布接口都接受 `baseUpdatedAt`。若服务端当前 `updatedAt` 比它新，返回**专用业务码**表示冲突，不要静默覆盖。
- 前端收到冲突码后提示「这份草稿已被 {updatedByActor} 修改」，并提供重新加载的入口。
- 请后端明确该冲突码的具体数值，前端需要按码值分支，不能靠匹配 `message` 文案。

## 9. 已发布模板列表需补充的字段

`GET /api/v1/admin/templates` 的每条模板增加两个字段，用于在模板库标示「这张图有未发布的改动」：

```json
{"hasDraft": true, "draftId": "draft-002"}
```

没有草稿时 `hasDraft` 为 `false`、`draftId` 为空。前端据此在卡片上打「草稿」角标，并把编辑入口指向草稿而非模板本身，避免管理员绕过草稿直接覆盖线上。

## 10. 待后端确认的开放项

1. 草稿数量上限与保留期限。建议设上限（如全局 200 条）与过期清理策略（如 90 天未更新自动清理），并把上限写成可读错误返回，前端提示管理员先清理。达到上限时保存草稿应失败而非静默丢弃。
2. 第 4 节中草稿列表的缩略图方案二选一。
3. 第 8 节冲突业务码的具体数值，以及其余新增错误码（草稿不存在、超出上限、发布校验失败）的码值分配。
4. 是否需要保留已发布模板的历史版本以支持回滚。本文范围内不要求，但若后端表结构顺手能支持，值得一并考虑。

## 11. 权限与错误约定

沿用现有约定：无权限返回 HTTP `401/403`，草稿或模板不存在返回 HTTP `404`，其余业务错误通过 `header.code` 与 `header.message` 返回。所有新增接口只接受管理员 access token。
