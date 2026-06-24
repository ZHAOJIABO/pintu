import 'package:flutter/material.dart';

import '../models/product_template.dart';

class ProductTemplateCard extends StatelessWidget {
  final ProductTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const ProductTemplateCard({
    super.key,
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFEDEFF6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                template.subtitle,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              template.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              template.physicalSizeLabel,
              style: TextStyle(
                color: selected ? Colors.white70 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
