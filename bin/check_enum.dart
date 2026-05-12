import 'package:flutter_gemma/pigeon.g.dart';

void main() {
  print('Available ModelTypes:');
  for (var value in ModelType.values) {
    print(' - $value');
  }
}
