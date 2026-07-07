enum ColorLimit {
  unlimited(null, '不限'),
  eight(8, '8'),
  sixteen(16, '16'),
  twentyFour(24, '24'),
  thirtyTwo(32, '32');

  final int? value;
  final String label;

  const ColorLimit(this.value, this.label);

  static ColorLimit fromName(String? name) {
    return ColorLimit.values.firstWhere(
      (limit) => limit.name == name,
      orElse: () => ColorLimit.unlimited,
    );
  }
}
