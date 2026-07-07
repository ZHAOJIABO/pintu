import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/models/product_template.dart';

void main() {
  test('catalog exposes MVP templates with unique ids', () {
    final ids = ProductTemplateCatalog.templates.map((template) => template.id);

    expect(ProductTemplateCatalog.templates, hasLength(8));
    expect(ids.toSet(), hasLength(ProductTemplateCatalog.templates.length));
    expect(ProductTemplateCatalog.defaultTemplate.id, 'keychain');
  });

  test('custom dimension validation enforces bounds', () {
    expect(ProductTemplateCatalog.isValidCustomDimension(8), isTrue);
    expect(ProductTemplateCatalog.isValidCustomDimension(128), isTrue);
    expect(ProductTemplateCatalog.isValidCustomDimension(150), isTrue);
    expect(ProductTemplateCatalog.isValidCustomDimension(7), isFalse);
    expect(ProductTemplateCatalog.isValidCustomDimension(151), isFalse);
    expect(ProductTemplateCatalog.isValidCustomDimension(0), isFalse);
  });
}
