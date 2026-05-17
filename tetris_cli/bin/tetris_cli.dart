import 'dart:io';
import 'package:tetris_cli/src/board.dart' as game;
import 'package:tetris_cli/ansi_cli_helper.dart' as ansi;

void main(List<String> arguments) async {
  // Фиксируем размер окна терминала под игру
  // Высота = 27 строк, Ширина = 42 символа
  stdout.write('\u001b[8;27;42t');
  await Future.delayed(Duration(milliseconds: 100));
  ansi.reset();
  ansi.hideCursor();

  game.initGame();
  await game.start();

  ansi.reset();
  ansi.showCursor();
}
