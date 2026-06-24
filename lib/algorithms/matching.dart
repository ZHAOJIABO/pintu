import 'dart:math';
import '../models/color.dart';

abstract class Matching {
  String get name;
  double delta(BeadColor c1, BeadColor c2);
  double deltaLab(Lab l1, Lab l2) =>
      delta(BeadColor(0, 0, 0, 0), BeadColor(0, 0, 0, 0));
  bool get usesLab => false;
}

class EuclideanMatching implements Matching {
  @override
  String get name => 'Euclidean';

  @override
  bool get usesLab => false;

  @override
  double delta(BeadColor c1, BeadColor c2) {
    return sqrt(
      pow(c1.r - c2.r, 2) +
          pow(c1.g - c2.g, 2) +
          pow(c1.b - c2.b, 2) +
          pow(c1.a - c2.a, 2),
    );
  }

  @override
  double deltaLab(Lab l1, Lab l2) => 0;
}

class CIE94Matching implements Matching {
  @override
  String get name => 'DeltaE (CIE94)';

  @override
  bool get usesLab => true;

  @override
  double delta(BeadColor ca, BeadColor cb) {
    return deltaLab(colorToLab(ca), colorToLab(cb));
  }

  @override
  double deltaLab(Lab l1, Lab l2) {
    final deltaL = l1.l - l2.l;
    final deltaA = l1.a - l2.a;
    final deltaB = l1.b - l2.b;
    final c1 = sqrt(l1.a * l1.a + l1.b * l1.b);
    final c2 = sqrt(l2.a * l2.a + l2.b * l2.b);
    final deltaC = c1 - c2;
    double deltaH = deltaA * deltaA + deltaB * deltaB - deltaC * deltaC;
    deltaH = deltaH < 0 ? 0 : sqrt(deltaH);
    final sc = 1.0 + 0.045 * c1;
    final sh = 1.0 + 0.015 * c1;
    final deltaLKlsl = deltaL / 1.0;
    final deltaCkcsc = deltaC / sc;
    final deltaHkhsh = deltaH / sh;
    final i =
        deltaLKlsl * deltaLKlsl +
        deltaCkcsc * deltaCkcsc +
        deltaHkhsh * deltaHkhsh;
    return i < 0 ? 0 : sqrt(i);
  }
}

class CIE2000Matching implements Matching {
  @override
  String get name => 'DeltaE (CIE2000)';

  @override
  bool get usesLab => true;

  double _degree(double radian) => (360 * radian) / (2 * pi);
  double _radian(double degree) => (2 * pi * degree) / 360;

  @override
  double delta(BeadColor ca, BeadColor cb) {
    return deltaLab(colorToLab(ca), colorToLab(cb));
  }

  @override
  double deltaLab(Lab l1, Lab l2) {
    final c1Val = sqrt(pow(l1.a, 2) + pow(l1.b, 2));
    final c2Val = sqrt(pow(l2.a, 2) + pow(l2.b, 2));
    final cAve = (c1Val + c2Val) / 2;
    final g = 0.5 * (1 - sqrt(pow(cAve, 7) / (pow(cAve, 7) + pow(25, 7))));

    final l1p = l1.l;
    final a1p = (1 + g) * l1.a;
    final b1p = l1.b;
    final l2p = l2.l;
    final a2p = (1 + g) * l2.a;
    final b2p = l2.b;
    final c1p = sqrt(pow(a1p, 2) + pow(b1p, 2));
    final c2p = sqrt(pow(a2p, 2) + pow(b2p, 2));

    double h1p;
    if (a1p == 0 && b1p == 0) {
      h1p = 0;
    } else if (b1p >= 0) {
      h1p = _degree(atan2(b1p, a1p));
    } else {
      h1p = _degree(atan2(b1p, a1p)) + 360;
    }

    double h2p;
    if (a2p == 0 && b2p == 0) {
      h2p = 0;
    } else if (b2p >= 0) {
      h2p = _degree(atan2(b2p, a2p));
    } else {
      h2p = _degree(atan2(b2p, a2p)) + 360;
    }

    final dhCond = (h2p - h1p) > 180
        ? 1
        : (h2p - h1p) < -180
        ? 2
        : 0;
    double dhp;
    if (dhCond == 0) {
      dhp = h2p - h1p;
    } else if (dhCond == 1) {
      dhp = h2p - h1p - 360;
    } else {
      dhp = h2p + 360 - h1p;
    }

    final dLp = l2p - l1p;
    final dCp = c2p - c1p;
    final dHp = 2 * sqrt(c1p * c2p) * sin(_radian(dhp / 2));
    final lpAve = (l1p + l2p) / 2;
    final cpAve = (c1p + c2p) / 2;

    int hAveCond;
    if (c1p * c2p == 0) {
      hAveCond = 3;
    } else if ((h2p - h1p).abs() <= 180) {
      hAveCond = 0;
    } else if (h1p + h2p < 360) {
      hAveCond = 1;
    } else {
      hAveCond = 2;
    }

    double hpAve;
    if (hAveCond == 3) {
      hpAve = h1p + h2p;
    } else if (hAveCond == 0) {
      hpAve = (h1p + h2p) / 2;
    } else if (hAveCond == 1) {
      hpAve = 180 + (h1p + h2p) / 2;
    } else {
      hpAve = -180 + (h1p + h2p) / 2;
    }

    final sl = 1 + (0.015 * pow(lpAve - 50, 2)) / sqrt(20 + pow(lpAve - 50, 2));
    final sc = 1 + 0.045 * cpAve;
    final t =
        1 -
        0.17 * cos(_radian(hpAve - 30)) +
        0.24 * cos(_radian(2 * hpAve)) +
        0.32 * cos(_radian(3 * hpAve + 6)) -
        0.2 * cos(_radian(4 * hpAve - 63));
    final sh = 1 + 0.015 * cpAve * t;
    final dTheta = 30 * exp(-1 * pow((hpAve - 275) / 25, 2));
    final rc = 2 * sqrt(pow(cpAve, 7) / (pow(cpAve, 7) + pow(25, 7)));
    final rt = -1 * sin(_radian(2 * dTheta)) * rc;

    const kl = 1.0;
    const kc = 1.0;
    const kh = 1.0;

    final deltaE2000 = sqrt(
      pow(dLp / (sl * kl), 2) +
          pow(dCp / (sc * kc), 2) +
          pow(dHp / (sh * kh), 2) +
          rt * (dCp / (sc * kc)) * (dHp / (sh * kh)),
    );
    return deltaE2000;
  }
}
