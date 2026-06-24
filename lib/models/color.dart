import 'dart:math';

class BeadColor {
  double r;
  double g;
  double b;
  double a;

  BeadColor(this.r, this.g, this.b, this.a);

  BeadColor.fromInt(int r, int g, int b, int a)
    : r = r.toDouble(),
      g = g.toDouble(),
      b = b.toDouble(),
      a = a.toDouble();

  BeadColor clone() => BeadColor(r, g, b, a);

  BeadColor add(BeadColor c) {
    r += c.r;
    g += c.g;
    b += c.b;
    return this;
  }

  BeadColor sub(BeadColor c) {
    r -= c.r;
    g -= c.g;
    b -= c.b;
    return this;
  }

  BeadColor mult(double s) {
    r *= s;
    g *= s;
    b *= s;
    return this;
  }

  int get rInt => r.round().clamp(0, 255);
  int get gInt => g.round().clamp(0, 255);
  int get bInt => b.round().clamp(0, 255);
  int get aInt => a.round().clamp(0, 255);

  String toHex() {
    return '#${((1 << 24) + (rInt << 16) + (gInt << 8) + bInt).toRadixString(16).substring(1)}';
  }

  @override
  bool operator ==(Object other) =>
      other is BeadColor &&
      rInt == other.rInt &&
      gInt == other.gInt &&
      bInt == other.bInt &&
      aInt == other.aInt;

  @override
  int get hashCode => Object.hash(rInt, gInt, bInt, aInt);
}

class Lab {
  final double l;
  final double a;
  final double b;

  Lab(this.l, this.a, this.b);
}

Lab colorToLab(BeadColor c) {
  double r = c.r / 255;
  double g = c.g / 255;
  double b = c.b / 255;

  r = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
  g = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
  b = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

  double x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  double y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.0;
  double z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

  x = x > 0.008856 ? pow(x, 1.0 / 3.0).toDouble() : 7.787 * x + 16.0 / 116.0;
  y = y > 0.008856 ? pow(y, 1.0 / 3.0).toDouble() : 7.787 * y + 16.0 / 116.0;
  z = z > 0.008856 ? pow(z, 1.0 / 3.0).toDouble() : 7.787 * z + 16.0 / 116.0;

  return Lab(116 * y - 16, 500 * (x - y), 200 * (y - z));
}

BeadColor foregroundColor(BeadColor color) {
  if (0.299 * color.r + 0.587 * color.g + 0.114 * color.b > 255 / 2) {
    return BeadColor.fromInt(0, 0, 0, 255);
  }
  return BeadColor.fromInt(255, 255, 255, 255);
}
