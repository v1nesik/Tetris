import 'dart:async';
import 'dart:io';

import 'blocks.dart';
import '../ansi_cli_helper.dart' as ansi;

const int heightBoard = 17; // высота игровой доски
const int widthBoard = 11; // ширина игровой доски

// тип заполнения ячеек игровой доски
const int posFree = 0; // свободное место
const int posFilled = 1; // заполненное место
const int posBoarder = 2; // граница
int record = 0; // рекорд
late List<List<int>> mainBoard; // основная доска
late List<List<int>> mainCpy; // копия основной доски
late List<List<int>> mblock; // блок c фигурой
late List<List<int>> nextBlock; // следующий блок с фигурой
late int x; // координата x
late int y; // координата y
bool _isGameOver = false; // игра окончена
int scoreGame = 0; // набранные очки

// подписка на получение нажатия клавиш
StreamSubscription? _subscription;

bool get isGameOver => _isGameOver;

int _delay =
    500; // начальная задержка между шагами игрового цикла (в миллисекундах)
int levelspeed = 1; // начальный уровень скорости

// lib/src/board.dart
// Функция отрисовки основной доски
void drawBoard() {
  ansi.gotoxy(0, 0); // устанавливаем курсор в начало
  for (int i = 0; i < heightBoard - 2; i++) {
    for (int j = 0; j < widthBoard - 1; j++) {
      switch (mainBoard[i][j]) {
        case posFree:
          stdout.write('⬛');
        case posFilled:
          stdout.write('⬜');
        case posBoarder:
          stdout.write('🟥');
      }
    }
    stdout.write('\n');
  }
// отрисовываем нижнюю границу (полная ширина)
  stdout.write('🟥' * (widthBoard - 1)); // автоматически подстроится под ширину
  stdout.write('\n');
}

void drawBoardNextBlock() {
  // Рисуем следующий блок на уровне нижней части поля
  for (int i = 0; i < 4; i++) {
    ansi.gotoxy(widthBoard * 2 + 2, (heightBoard - 2) - 4 + i);
    for (int j = 0; j < 4; j++) {
      if (nextBlock[i][j] == 1) {
        stdout.write('⬜');
      } else {
        stdout.write('⬛');
      }
    }
    stdout.write('    ');
  }
}

// Функция очистки заполненных строк
void clearLine() {
  for (int j = 0; j <= heightBoard - 3; j++) {
    // проверка заполненности строки
    int i = 1;
    while (i <= widthBoard - 3) {
      if (mainBoard[j][i] == posFree) {
        break;
      }
      i++;
    }

    if (i == widthBoard - 2) {
      // если строка заполнена
      // очистка строки и сдвиг строк игровой доски вниз
      for (int k = j; k > 0; k--) {
        for (int idx = 1; idx <= widthBoard - 3; idx++) {
          mainBoard[k][idx] = mainBoard[k - 1][idx];
        }
      }

      // Обнуляем верхнюю строку (кроме границ)
      for (int idx = 1; idx <= widthBoard - 3; idx++) {
        mainBoard[0][idx] = posFree;
      }

      // увеличение очков
      scoreGame += 10;
      updateSpeed();
      displayScore();
      recordScore();

      j--; // проверяем эту же строку снова, так как она теперь содержит строки сверху
    }
  }
}

// Функция генерации нового блока и добавления его на основную доску
void newBlock() {
  x = (widthBoard ~/ 2) - 2; // динамический центр, а не фиксированный 4
  y = 0;

  mblock = nextBlock;
  nextBlock = getNewBlock();
  drawBoardNextBlock();

  // добавляем новый блок на основную доску
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      mainBoard[y + i][x + j] = mainCpy[y + i][x + j] + mblock[i][j];

      // проверка на пересечение
      if (mainBoard[y + i][x + j] > 1) {
        _isGameOver = true; // игра окончена
      }
    }
  }
}

// Функция перемещения фигуры по основной доске
void moveBlock(int x2, int y2) {
  // убираем фигуру с текущей позиции
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      if (y + i >= 0 &&
          y + i < heightBoard &&
          x + j >= 0 &&
          x + j < widthBoard) {
        mainBoard[y + i][x + j] -= mblock[i][j];
      }
    }
  }

  // устанавливаем новую позицию
  x = x2;
  y = y2;

  // добавляем фигуру на новую позицию
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      if (y + i >= 0 &&
          y + i < heightBoard &&
          x + j >= 0 &&
          x + j < widthBoard) {
        mainBoard[y + i][x + j] += mblock[i][j];
      }
    }
  }

  drawBoard();
}

// Функция проверки возможности сдвига блока в заданном направлении
bool isFilledBlock(int x2, int y2) {
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      if (mblock[i][j] != 0) {
        int newX = x2 + j;
        int newY = y2 + i;

        // Проверка выхода за границы
        if (newX < 0 || newX >= widthBoard || newY < 0 || newY >= heightBoard) {
          return true; // столкновение с границей
        }

        if (mainCpy[newY][newX] != 0) {
          return true; // столкновение с другим блоком
        }
      }
    }
  }
  return false;
}

// Функция обработки поворота блока
void rotateBlock() {
  // Временный блок с текущей фигурой
  List<List<int>> tmp = List.generate(4, (_) => List.filled(4, 0));

  // Заполняем временный блок
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      tmp[i][j] = mblock[i][j];
    }
  }

  // Поворачиваем фигуру
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      mblock[i][j] = tmp[3 - j][i];
    }
  }

  // Проверка на то, что фигура не пересекается с границей
  // или другими блоками ранее помещенных на доску фигур
  if (isFilledBlock(x, y)) {
    // если есть пересечения, то возвращаем старую фигуру
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        mblock[i][j] = tmp[i][j];
      }
    }
  }

  // Обновляем основную доску
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      // убираем старую фигуру
      mainBoard[y + i][x + j] -= tmp[i][j];

      // добавляем новую фигуру
      mainBoard[y + i][x + j] += mblock[i][j];
    }
  }

  drawBoard();
}

void savePresentBoardToCpy() {
  for (int i = 0; i < heightBoard - 1; i++) {
    for (int j = 0; j < widthBoard; j++) {
      mainCpy[i][j] = mainBoard[i][j];
    }
  }
}

// Функция для обработки нажатия клавиш
// Функция для обработки нажатия клавиш
void controlUserInput() {
  // Если подписка уже есть - не создаём новую
  if (_subscription != null) return;

  stdin.echoMode = false;
  stdin.lineMode = false;
  _subscription = stdin.listen((data) {
    int key = data.first;
    switch (key) {
      case 119:
        rotateBlock();
        break;
      case 97:
        if (!isFilledBlock(x - 1, y)) {
          moveBlock(x - 1, y);
        }
        break;
      case 115:
        if (!isFilledBlock(x, y + 1)) {
          moveBlock(x, y + 1);
        }
        break;
      case 100:
        if (!isFilledBlock(x + 1, y)) {
          moveBlock(x + 1, y);
        }
        break;
      case 112:
        pauseGame();
        break;
      case 113:
        _isGameOver = true;
        break;
      default:
        break;
    }
  });
}

// Функция для инициализации игры
initGame() {
  record = loadRecordfromFile();
  controlUserInput(); // ← ТОЛЬКО ОДИН РАЗ ПРИ СТАРТЕ
}

// Функция обработки шага игрового цикла
void nextStep() {
  // можно сдвинуть фигуру?
  if (!isFilledBlock(x, y + 1)) {
    // да
    moveBlock(x, y + 1);
  } else {
    // нет
    clearLine();
    savePresentBoardToCpy();
    newBlock();
  }
}
// Функция увеличения скорости каждые 50 очков

void updateSpeed() {
  if (scoreGame % 50 == 0 && scoreGame != 0) {
    _delay = (_delay * 0.9).toInt(); // уменьшаем задержку на 10%
    if (_delay < 100) {
      _delay = 100; // устанавливаем минимальную задержку
    }
    levelspeed = (500 / _delay).round();
    if (levelspeed < 1) levelspeed = 1;
    if (levelspeed > 10) levelspeed = 10;
    displaySpeed();
  }
}

// Функция запуска игрового цикла
Future<void> start() async {
  await runGame();
}

// Кнопка паузы
void pauseGame() {
  _subscription?.pause();

  int pauseLine = heightBoard + 3; // строка для паузы

  ansi.gotoxy(0, pauseLine);
  stdout.write('Game paused. Press G to continue...');

  // Ждем именно клавишу g для продолжения
  while (true) {
    int key = stdin.readByteSync();
    if (key == 103) {
      // g - продолжить
      break;
    }
  }

  // Стираем строку
  ansi.gotoxy(0, pauseLine);
  stdout.write(' ' * 50);

  ansi.gotoxy(0, 0);
  _subscription?.resume();
}

// вывод очков в реальном времени
void displayScore() {
  ansi.gotoxy(widthBoard * 2 + 2, heightBoard - 2);
  stdout.write('Score: $scoreGame  ');
}

void recordScore() {
  if (scoreGame > record) {
    record = scoreGame;
    saveRecord();
  }
}

void saveRecord() {
  try {
    File('record.txt').writeAsStringSync(record.toString());
  } catch (e) {
    // Игнорируем ошибки при сохранении рекорда
  }
}

int loadRecordfromFile() {
  try {
    String content = File('record.txt').readAsStringSync();
    return int.parse(content);
  } catch (e) {
    // Если файл не найден или содержимое некорректно, возвращаем 0
    return 0;
  }
}

Future<void> runGame() async {
  _isGameOver = false;
  scoreGame = 0;
  _delay = 500;
  levelspeed = 1;
  mainBoard = List.generate(
    heightBoard,
    (_) => List.filled(widthBoard, posFree),
  );
  mainCpy = List.generate(
    heightBoard,
    (_) => List.filled(widthBoard, posFree),
  );
  mblock = List.generate(
    4,
    (_) => List.filled(4, posFree),
  );

  for (int i = 0; i <= heightBoard - 2; i++) {
    for (int j = 0; j <= widthBoard - 2; j++) {
      if (j == 0 || j == widthBoard - 2 || i == heightBoard - 2) {
        mainBoard[i][j] = posBoarder;
        mainCpy[i][j] = posBoarder;
      }
    }
  }

  nextBlock = getNewBlock();
  newBlock();
  drawBoardNextBlock();
  drawBoard();
  displayScore();
  displaySpeed();

  // НЕ ВЫЗЫВАЕМ controlUserInput() здесь!

  while (!_isGameOver) {
    nextStep();
    await Future.delayed(Duration(milliseconds: _delay));
  }

  ansi.gotoxy(0, heightBoard + 5);
  ansi.setTextColor(ansi.yellowTColor);
  stdout.write('===============\n'
      '~~~Game Over~~~\n'
      '===============\n');
  stdout.writeln('Score: $scoreGame ');
  stdout.writeln('Record: $record ');

  await Future.delayed(const Duration(seconds: 2));

  _subscription?.pause();

  stdout.write('\nPlay again? (y/n): ');
  int key = stdin.readByteSync();

  if (key == 121 || key == 89) {
    ansi.clearScreen();
    _subscription?.resume();
    await runGame();
  } else {
    _subscription?.cancel();
    ansi.reset();
    exit(0);
  }
}

void displaySpeed() {
  ansi.gotoxy(widthBoard * 2 + 2, heightBoard - 1); // на строку рекорда
  stdout.write('Record: $record  Speed: $levelspeed  ');
}
