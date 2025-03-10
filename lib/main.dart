import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:simple_chess_board/models/board_arrow.dart';
import 'package:chess/chess.dart' as chesslib;
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stockfish API',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Stockfish 17 Chess Engine using REST chess-api'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final _chess = chesslib.Chess.fromFEN(chesslib.Chess.DEFAULT_POSITION);
  var _blackAtBottom = false;
  BoardArrow? _lastMoveArrowCoordinates;
  late ChessBoardColors _boardColors;
  final _highlightCells = <String, Color>{};

  @override
  void initState() {
    _boardColors = ChessBoardColors()
      ..lightSquaresColor = Colors.blue.shade200
      ..darkSquaresColor = Colors.blue.shade600
      ..coordinatesZoneColor = Colors.redAccent.shade200
      ..lastMoveArrowColor = Colors.cyan
      ..startSquareColor = Colors.orange
      ..endSquareColor = Colors.green
      ..circularProgressBarColor = Colors.red
      ..coordinatesColor = Colors.green;

    super.initState();
  }

  Future<void> tryMakingMove({required ShortMove move}) async {
    // print(move.from);
    // print(move.to);
    final success = _chess.move(<String, String?>{
      'from': move.from,
      'to': move.to,
      'promotion': move.promotion?.name,
    });
    if (success) {
      setState(() {
        _lastMoveArrowCoordinates = BoardArrow(from: move.from, to: move.to);
      });
      var client = http.Client();
      try {
        var response = await client.post(Uri.https('chess-api.com', 'v1'),
            body: {'input': jsonEncode(_chess.pgn())});

        var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        _chess.move(decodedResponse['san']);
        print('Black Move: '+decodedResponse['san']);
        setState(() {
          String from = decodedResponse['from'];
          String to = decodedResponse['to'];
          _lastMoveArrowCoordinates = BoardArrow(from: from, to: to);
        });
      } finally {
        client.close();
      }

    }
  }

  Future<PieceType?> handlePromotion(BuildContext context) {
    final navigator = Navigator.of(context);
    return showDialog<PieceType>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Promotion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Queen"),
                onTap: () => navigator.pop(PieceType.queen),
              ),
              ListTile(
                title: const Text("Rook"),
                onTap: () => navigator.pop(PieceType.rook),
              ),
              ListTile(
                title: const Text("Bishop"),
                onTap: () => navigator.pop(PieceType.bishop),
              ),
              ListTile(
                title: const Text("Knight"),
                onTap: () => navigator.pop(PieceType.knight),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _blackAtBottom = !_blackAtBottom;
              });
            },
            icon: const Icon(Icons.swap_vert),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SimpleChessBoard(
                chessBoardColors: _boardColors,
                engineThinking: false,
                fen: _chess.fen,
                onMove: tryMakingMove,
                blackSideAtBottom: _blackAtBottom,
                whitePlayerType: PlayerType.human,
                blackPlayerType: PlayerType.human,
                lastMoveToHighlight: _lastMoveArrowCoordinates,
                cellHighlights: _highlightCells,
                onPromote: () => handlePromotion(context),
                onPromotionCommited: ({
                  required ShortMove moveDone,
                  required PieceType pieceType,
                }) {
                  moveDone.promotion = pieceType;
                  tryMakingMove(move: moveDone);
                },
                onTap: ({required String cellCoordinate}) {

                  // print(_chess.pgn());
                  if (_highlightCells[cellCoordinate] == null) {
                    _highlightCells[cellCoordinate] = Colors.red;
                    setState(() {});
                  } else {_highlightCells.remove(cellCoordinate);
                    setState(() {});
                  }
                },
              ),
            ),
            Text("Click on a cell in order to (un)highlight it."
                " You can also drag and drop pieces")
          ],
        ),
      ),
    );
  }
}