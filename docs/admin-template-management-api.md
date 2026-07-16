# 管理后台模板库接口契约

本文约定 Web 管理后台的“模板库”和“下架模板”接口。所有接口均使用现有 JSON 响应信封，且只接受管理员 access token。

```http
Authorization: Bearer <admin_access_token>
X-Platform: web
X-Device-Id: admin-web
```

## 1. 查询已发布模板

```http
GET /api/v1/admin/templates?page.page=1&page.pageSize=100
```

用于后台模板库。前端从第一页开始持续请求，直到 `page.hasMore=false`，所以服务端必须返回当前所有处于已发布状态的模板，包含没有出现在客户端首页场景中的模板。

响应：

```json
{
  "header": {"code": 0, "message": "success"},
  "templates": [
    {
      "templateId": "template-001",
      "title": "小狐狸",
      "categoryId": 7,
      "categoryName": "动物",
      "previewUrl": "https://cdn.example.com/templates/fox-preview.png",
      "thumbnailUrl": "https://cdn.example.com/templates/fox-thumb.png",
      "description": "适合入门的狐狸图案",
      "tags": ["动物", "入门"],
      "difficulty": 1,
      "width": 29,
      "height": 29,
      "colorCount": 8
    }
  ],
  "page": {"total": 1, "page": 1, "pageSize": 100, "hasMore": false}
}
```

字段规则：

- `categoryId` 必填，后台以它和 `GET /api/v1/admin/template-categories` 的结果分组。
- `tags` 推荐返回字符串数组；当前前端也兼容历史逗号分隔字符串。
- `thumbnailUrl` 优先用于列表卡片，缺失时前端使用 `previewUrl`。服务端必须至少返回一个可被浏览器访问的 URL；仅返回对象存储 `previewFileKey` 会导致卡片无法显示图片。
- 模板图库缩略图统一存储为 **358×358px PNG**，对应 iOS “兔子的图库”中 119.33×119.33pt 卡片的 3× Retina 资源。`thumbnailUrl` 必须指向该方形缩略图；当客户端可能回退到 `previewUrl` 时，`previewUrl` 也必须是同一资源或符合相同规范的方图。
- 缩略图只渲染 `PatternData` 的彩色像素块与白色空白背景，保留图案的像素位置；不得包含最终图纸的标题、坐标轴、边框、网格、色号文字或配色图例。最终图纸仍按独立的导出链路生成，不能作为模板图库图片上传。
- 为平滑迁移，前端也兼容 `previewFileUrl`、`patternImageUrl` 与 `imageUrl`。这些字段的值同样必须是完整 URL 或以 `/` 开头的可访问路径。
- 列表也可附带完整 `patternData`，前端会将其渲染为预览兜底；但不应以此替代缩略图 URL。
- OSS/CDN 响应必须使用 `Content-Type: image/png`（或对应图片类型）和 `Content-Disposition: inline`；不要返回 `attachment` 或 `x-oss-force-download: true`。若图片 URL 使用 OSS 默认 Bucket 域名，OSS 可能自动追加这两个下载响应头；此时必须绑定自定义域名（或 CDN 域名）并让接口返回该域名的 URL，不能只靠修改对象元数据消除 `x-oss-force-download`。
- OSS/CDN 必须为后台 Web 域名配置 CORS：至少允许 `GET`、`HEAD`，并返回 `Access-Control-Allow-Origin: <后台 Web 的实际 Origin>`（本地开发时为本地后台地址）。不能确定域名时可暂时使用 `*`，再收紧为正式域名。否则 Flutter Web 默认的图片解码会被浏览器拦截。

当前后台对 OSS 图片使用原生 HTML `<img>` 作为兼容渲染策略，以便在旧对象尚未修复 CORS 时仍可展示；新上传对象和长期部署仍应遵守上述响应头约定。

前端状态：首次打开和手动刷新时显示加载态；空列表显示空状态；请求失败保留上一轮数据并显示可读错误，可通过刷新重试。

## 2. 下架模板

```http
POST /api/v1/admin/templates/{templateId}/unpublish
Content-Type: application/json

{"reason": "内容需要修订"}
```

- `reason` 可选，最大 200 字符，供运营审计使用。
- 下架成功后，模板不可再通过客户端模板列表和详情接口被普通用户获取；后台查询接口也不再返回它。
- 该操作应幂等：重复下架同一模板应返回成功，或返回前端可识别的“已下架”业务状态，而非造成服务端错误。
- 无权限返回 HTTP `401/403`；不存在的模板返回 HTTP `404`；其他业务错误通过 `header.code` 和 `header.message` 返回。

前端状态：点击下架先要求确认，可填写原因；提交期间仅禁用当前模板的下架按钮；成功后立即从当前分类移除，失败时保留卡片并显示错误。

## 3. 创建模板分类

```http
POST /api/v1/admin/template-categories
Content-Type: application/json

{"name": "节日"}
```

`name` 必填，去除首尾空白后长度为 1–30 字符，且管理员可见范围内不能重名。成功响应：

```json
{
  "header": {"code": 0, "message": "success"},
  "category": {"categoryId": 9, "name": "节日", "templateCount": 0}
}
```

前端创建成功后立即把分类放入发布表单并设为当前选择，无需刷新页面。

## 4. 获取管理员模板详情

```http
GET /api/v1/admin/templates/{templateId}
```

用于进入模板编辑页。响应包含完整元信息和可编辑的 `patternData`：

```json
{
  "header": {"code": 0, "message": "success"},
  "template": {
    "templateId": "template-001",
    "title": "小狐狸",
    "categoryId": 7,
    "description": "适合入门",
    "tags": ["动物", "入门"],
    "difficulty": 1,
    "previewUrl": "https://cdn.example.com/templates/fox-preview.png"
  },
  "patternData": {"width": 29, "height": 29, "boardSpec": "29x29", "pixels": [], "colorPalette": []}
}
```

## 5. 更新官方模板

```http
PUT /api/v1/admin/templates/{templateId}
Content-Type: application/json
```

请求体沿用发布接口字段：`title`、`description`、`categoryId`、`tags`、`difficulty`、`previewFileKey`、`patternData`。`previewFileKey` 是历史字段名，实际承载上述 358×358px 的图库缩略图；后台会先把重新生成的缩略图 PNG 上传到 `POST /api/v1/admin/media/upload`，再发送更新请求。

服务端必须校验 `PatternData`，原子地更新图纸、分类、元信息和预览资源，并在模板列表中返回新的可访问 `previewUrl` / `thumbnailUrl`。更新失败时不得留下只更新了一半的图纸或预览资源。

## 6. 存量模板迁移

已存储为“完整图纸”的历史图片不会在客户端读取时自动变成图库缩略图。应由服务端依据每条模板的 `PatternData` 批量重建 358×358px PNG 并更新对应文件键；没有批处理能力时，管理员在编辑页点击“保存修改”也会重新上传符合本规范的缩略图。
