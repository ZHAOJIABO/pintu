enum DenoiseStrength {
  mild('轻度'),
  standard('标准'),
  strong('强力');

  final String label;

  const DenoiseStrength(this.label);

  static DenoiseStrength fromName(String? name) {
    return DenoiseStrength.values.firstWhere(
      (strength) => strength.name == name,
      orElse: () => DenoiseStrength.standard,
    );
  }
}
