/// Surface treatments available for a fused perler-bead product.
enum PerlerProductFinish {
  holeless('无孔烫', isSupported: true),
  bathTowel('澡巾烫', isSupported: true),
  linen('麻布烫', isSupported: true);
  // towel('毛巾烫'),
  // fineGlitter('细闪'),
  // coarseGlitter('粗闪');

  final String label;
  final bool isSupported;

  const PerlerProductFinish(this.label, {this.isSupported = false});
}
