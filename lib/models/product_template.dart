enum CropAspectRatio {
  portrait916('9:16', 9 / 16),
  portrait34('3:4', 3 / 4),
  square('1:1', 1),
  landscape43('4:3', 4 / 3),
  landscape169('16:9', 16 / 9),
  freeform('Free', null);

  final String label;
  final double? value;

  const CropAspectRatio(this.label, this.value);
}

class ProductTemplate {
  final String id;
  final String name;
  final String subtitle;
  final double? physicalSizeCm;
  final int beadWidth;
  final int beadHeight;
  final CropAspectRatio defaultAspectRatio;
  final bool custom;

  const ProductTemplate({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.physicalSizeCm,
    required this.beadWidth,
    required this.beadHeight,
    required this.defaultAspectRatio,
    this.custom = false,
  });

  int get estimatedBeads => beadWidth * beadHeight;

  String get physicalSizeLabel => physicalSizeCm == null
      ? 'XX cm'
      : '${physicalSizeCm!.toStringAsFixed(1)}cm';

  ProductTemplate copyWith({
    String? id,
    String? name,
    String? subtitle,
    double? physicalSizeCm,
    int? beadWidth,
    int? beadHeight,
    CropAspectRatio? defaultAspectRatio,
    bool? custom,
  }) {
    return ProductTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      physicalSizeCm: physicalSizeCm ?? this.physicalSizeCm,
      beadWidth: beadWidth ?? this.beadWidth,
      beadHeight: beadHeight ?? this.beadHeight,
      defaultAspectRatio: defaultAspectRatio ?? this.defaultAspectRatio,
      custom: custom ?? this.custom,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'physicalSizeCm': physicalSizeCm,
    'beadWidth': beadWidth,
    'beadHeight': beadHeight,
    'defaultAspectRatio': defaultAspectRatio.name,
    'custom': custom,
  };

  factory ProductTemplate.fromJson(Map<String, Object?> json) {
    return ProductTemplate(
      id: json['id']! as String,
      name: json['name']! as String,
      subtitle: json['subtitle']! as String,
      physicalSizeCm: (json['physicalSizeCm'] as num?)?.toDouble(),
      beadWidth: json['beadWidth']! as int,
      beadHeight: json['beadHeight']! as int,
      defaultAspectRatio: CropAspectRatio.values.firstWhere(
        (ratio) => ratio.name == json['defaultAspectRatio'],
        orElse: () => CropAspectRatio.square,
      ),
      custom: json['custom'] as bool? ?? false,
    );
  }
}

class ProductTemplateCatalog {
  static const int minCustomBeads = 8;
  static const int maxCustomBeads = 150;

  // These are MVP placeholders. Product should tune the exact bead dimensions
  // once the commercial template sizes are final.
  static const templates = <ProductTemplate>[
    ProductTemplate(
      id: 'small_charm',
      name: '小鼻嘎',
      subtitle: '10',
      physicalSizeCm: 2.6,
      beadWidth: 16,
      beadHeight: 16,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'fridge_magnet',
      name: '冰箱贴',
      subtitle: '15',
      physicalSizeCm: 4.0,
      beadWidth: 24,
      beadHeight: 24,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'keychain',
      name: '钥匙扣',
      subtitle: '20',
      physicalSizeCm: 5.3,
      beadWidth: 32,
      beadHeight: 32,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'large_keychain',
      name: '大钥匙扣',
      subtitle: '25',
      physicalSizeCm: 7.0,
      beadWidth: 40,
      beadHeight: 40,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'coaster',
      name: '杯垫',
      subtitle: '30',
      physicalSizeCm: 8.2,
      beadWidth: 48,
      beadHeight: 48,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'decorative_picture',
      name: '装饰画',
      subtitle: '40',
      physicalSizeCm: 11.0,
      beadWidth: 64,
      beadHeight: 64,
      defaultAspectRatio: CropAspectRatio.square,
    ),
    ProductTemplate(
      id: 'luggage_tag',
      name: '行李牌',
      subtitle: '50',
      physicalSizeCm: 14.0,
      beadWidth: 64,
      beadHeight: 96,
      defaultAspectRatio: CropAspectRatio.portrait34,
    ),
    ProductTemplate(
      id: 'custom',
      name: '自定义',
      subtitle: 'X',
      physicalSizeCm: null,
      beadWidth: 64,
      beadHeight: 64,
      defaultAspectRatio: CropAspectRatio.freeform,
      custom: true,
    ),
  ];

  static ProductTemplate get defaultTemplate =>
      templates.firstWhere((template) => template.id == 'keychain');

  static ProductTemplate byId(String id) {
    return templates.firstWhere(
      (template) => template.id == id,
      orElse: () => defaultTemplate,
    );
  }

  static bool isValidCustomDimension(int value) {
    return value >= minCustomBeads && value <= maxCustomBeads;
  }
}
