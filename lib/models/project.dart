import '../algorithms/matching.dart';

enum BoardType {
  midi(29, 'Midi'),
  mini(57, 'Mini');

  final int beadsPerSide;
  final String label;
  const BoardType(this.beadsPerSide, this.label);
}

enum MatchingAlgorithm {
  euclidean,
  cie94,
  cie2000;

  Matching get matcher {
    switch (this) {
      case MatchingAlgorithm.euclidean:
        return EuclideanMatching();
      case MatchingAlgorithm.cie94:
        return CIE94Matching();
      case MatchingAlgorithm.cie2000:
        return CIE2000Matching();
    }
  }
}

class Project {
  BoardType boardType;
  int boardsX;
  int boardsY;
  MatchingAlgorithm matchingAlgorithm;
  bool ditheringEnabled;
  int ditheringHardness;
  bool fitImage;
  bool centerImage;

  Project({
    this.boardType = BoardType.midi,
    this.boardsX = 1,
    this.boardsY = 1,
    this.matchingAlgorithm = MatchingAlgorithm.cie2000,
    this.ditheringEnabled = true,
    this.ditheringHardness = 50,
    this.fitImage = true,
    this.centerImage = true,
  });

  int get canvasWidth => boardType.beadsPerSide * boardsX;
  int get canvasHeight => boardType.beadsPerSide * boardsY;
}
