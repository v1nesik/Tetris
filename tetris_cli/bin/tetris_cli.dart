// bin/main.dart
import 'package:tetris_cli/tetris_cli.dart';
import 'package:tetris_cli/ansi_cli_helper.dart' as ansi;

void main(List<String> arguments) async {
  ansi.reset();
  ansi.hideCursor();

  bool playAgain = true;
  while (playAgain) {
    initGame();
    await start();
    // start() обработает вопрос о повторной игре и вызовет exit(0) если нужно выйти
    playAgain = false; // На случай, если по какой-то причине это не выполнится
  }
}
