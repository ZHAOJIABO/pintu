# bobobeads

一个跨平台 Flutter 应用，将图片转换为拼豆（Perler Bead）图案。支持 iOS 和 Android。

---

## 功能

- **图片导入** — 从相册选择或拍照，自动转换为拼豆图案
- **多品牌色板** — 支持 15 种色板（Hama Midi/Mini/Maxi、Nabbi、Mard、Artkal、Perler、Yant、Diamond Dotz）
- **板型配置** — Midi（29 珠/行）、Mini（57 珠/行），可设置横竖板数
- **3 种颜色匹配算法** — Euclidean、CIE94、CIE2000（ΔE00）
- **Floyd-Steinberg 抖动** — 可开关，支持 0-100% 强度调节
- **实时预览** — CustomPainter 渲染拼豆圆形效果，支持手势缩放/平移
- **网格叠加** — 显示板边界辅助对齐
- **用量统计** — 按颜色统计珠子数量
- **导出 PNG** — 生成图案图片并分享

---

## 项目结构

```
lib/
├── main.dart                        # 应用入口
├── models/
│   ├── color.dart                   # BeadColor 类 (RGBA) + RGB→Lab 色彩空间转换
│   ├── palette.dart                 # Palette / PaletteEntry 数据模型
│   └── project.dart                 # 项目配置 (板型、算法、抖动参数)
├── algorithms/
│   ├── matching.dart                # 颜色匹配算法 (Euclidean / CIE94 / CIE2000)
│   └── color_reducer.dart           # 主处理管线: 颜色量化 + Floyd-Steinberg 误差扩散
├── services/
│   ├── palette_service.dart         # HTTP 加载远程 CSV 色板数据
│   └── image_service.dart           # 图片选取、缩放、像素读写
├── rendering/
│   └── bead_painter.dart            # CustomPainter 绘制珠子圆形 + 网格
└── screens/
    ├── home_screen.dart             # 首页: 选图 + 参数配置
    ├── preview_screen.dart          # 预览: 缩放查看 + 用量统计
    └── export_screen.dart           # 导出: PNG 分享 + 详细库存列表
```

---

## 核心算法

### 颜色匹配

| 算法 | 原理 | 适用场景 |
|------|------|----------|
| Euclidean | RGB 空间欧氏距离 `√(Δr² + Δg² + Δb² + Δa²)` | 速度最快，精度一般 |
| CIE94 | Lab 色彩空间感知距离，加权亮度/色度/色相 | 平衡速度与精度 |
| CIE2000 (ΔE00) | 最先进的感知色差公式，处理蓝色/灰色区域更准确 | 精度最高，速度稍慢 |

### Floyd-Steinberg 抖动

对每个像素计算量化误差并扩散到相邻像素：

```
         [当前]   7/16 →
  3/16 ↙  5/16 ↓  1/16 ↘
```

通过 `hardness` 参数（0-100%）控制误差扩散强度，值越大抖动效果越明显。

### RGB → Lab 转换

```
RGB → sRGB 线性化（去 gamma）→ XYZ（矩阵变换，D65 光源）→ Lab（非线性映射）
```

Lab 色彩空间中的距离更符合人眼对颜色差异的感知。

---

## 图像处理流程

```
1. 用户选择图片（相册/相机）
       ↓
2. 按目标尺寸缩放（板数 × 每板珠数）
       ↓
3. 获取像素数据 (Uint8List RGBA)
       ↓
4. 颜色量化（每个像素匹配最近色板颜色）
   + Floyd-Steinberg 抖动（误差扩散）
   [在 Isolate 中运行，不阻塞 UI]
       ↓
5. 统计用量（每种颜色的珠子数）
       ↓
6. CustomPainter 渲染预览
       ↓
7. 导出分享
```

---

## 色板数据

色板从远程 CSV 服务加载：`https://beadcolors.eremes.xyz/gen/v3/{name}.csv`

CSV 格式：`ref,name,symbol,r,g,b`

内置 B&W（黑白）兜底色板，离线时可用。

---

## 开始使用

### 环境要求

- Flutter SDK >= 3.11
- Dart >= 3.11
- iOS 12+ / Android API 21+

### 运行

```bash
cd bobobeads
flutter pub get
flutter run
```

### 构建发布版

```bash
# iOS
flutter build ios

# Android
flutter build apk
```

---

## 依赖

| 包 | 用途 |
|----|------|
| `http` | 网络请求（加载色板 CSV） |
| `image` | 图片解码与像素操作 |
| `image_picker` | 相册/相机选图 |
| `pdf` | PDF 生成（待实现） |
| `path_provider` | 临时文件路径 |
| `share_plus` | 文件分享 |

---

## 后续规划

- [ ] PDF 导出（含分板映射 + 用量表）
- [ ] XLSX 导出
- [ ] SVG 导出
- [ ] 色板本地持久化缓存
- [ ] 颜色过滤（移除占比过低的颜色）
- [ ] 图片裁剪/旋转预处理
- [ ] 深色模式
