//
// Notes:
//  ply = half move (ie black or white's half of the move)

import std.stdio;
import std.ascii;
import std.traits;
import std.range;

enum Side {
    White, Black
}

enum Name {
    King, Queen, Rook, Bishop, Knight, Pawn
}

struct Piece {
    Side side;
    Name name;
}

string toString(Piece piece) {
    return
        [
        [ "\u2654", "\u2655", "\u2656", "\u2657", "\u2658", "\u2659" ],
        [ "\u265A", "\u265B", "\u265C", "\u265D", "\u265E", "\u265F" ]
        ]
        [piece.side][piece.name];
}

//
//
//

enum File {
    _A, _B, _C, _D, _E, _F, _G, _H
}

char toChar(File f) {
    return "abcdefgh"[f];
}

enum Rank {
    _1, _2, _3, _4, _5, _6, _7, _8
}

char toChar(Rank r) {
    return "12345678"[r];
}

struct Coord {
    File file;
    Rank rank;
}

string toString(in Coord coord) {
    return toChar(coord.file) ~ "+" ~ toChar(coord.rank);
}

//
//
//

struct Board {
    struct Square {
        this(in Side side, in Name name) {
            occupied = true;
            piece = Piece(side, name);
        }

        bool  occupied = false;
        Piece piece;        // valid if occupied
    }

    this(in Square[8][8] squares_) {
        squares = squares_;
    }

    Square square(Coord coord) const {
        return squares[coord.file][coord.rank];
    }

private:
    Square * at(Coord coord) {
        return &squares[coord.file][coord.rank];
    }

    void add(Piece piece, Coord coord) {
        auto square = at(coord);
        if (square.occupied) {
            // error
        }
        else {
            square.occupied = true;
            square.piece    = piece;
        }
    }

    void remove(Coord coord) {
        auto square = at(coord);
        if (square.occupied) {
            square.occupied = false;
        }
        else {
            // error
        }
    }

    void move(Coord source, Coord dest) {
        auto source_sq = at(source);
        auto dest_sq = at(dest);

        if (source_sq.occupied && !dest_sq.occupied) {
            source_sq.occupied = false;
            dest_sq.occupied = true;
            dest_sq.piece = source_sq.piece;
        }
        else {
            // error
        }
    }

    Square[8][8] squares =
        [
        [ Square(Side.White, Name.Rook),   Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Rook)   ],
        [ Square(Side.White, Name.Knight), Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Knight) ],
        [ Square(Side.White, Name.Bishop), Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Bishop) ],
        [ Square(Side.White, Name.Queen),  Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Queen)  ],
        [ Square(Side.White, Name.King),   Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.King)   ],
        [ Square(Side.White, Name.Bishop), Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Bishop) ],
        [ Square(Side.White, Name.Knight), Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Knight) ],
        [ Square(Side.White, Name.Rook),   Square(Side.White, Name.Pawn), Square(), Square(), Square(), Square(), Square(Side.Black, Name.Pawn), Square(Side.Black, Name.Rook)   ]
        ];
}

void dump(in Board board) {
    bool light_square = true;

    foreach_reverse(r; EnumMembers!Rank) {
        write(toChar(r));
        foreach(f; EnumMembers!File) {

            if (light_square) {
                write("\033[47m");
            }
            else {
                write("\033[40m");
            }

            Board.Square square = board.square(Coord(f, r));
            if (square.occupied) {
                write(toString(square.piece));
            }
            else {
                write(" ");
            }

            light_square = !light_square;
        }
        writeln("\033[0m");

        light_square = !light_square;
    }

    write(" ");
    foreach(f; EnumMembers!File) {
        writef("%s", toChar(f));
    }
    writeln("");
}

//
//
//

enum KingState {
    Safe,
    Check,
    CheckMate
}

class Game {
    struct SideState {
        KingState kingState;
        bool      kingMoved;
        bool      queenRookMoved;
        bool      kingRookMoved;
    }

    struct Ply {
        this(Coord source_, Coord dest_) {
            source = source_;
            dest = dest_;
        }

        Coord source;
        Coord dest;
    }

    @property Board board() { return _board; }

    struct Flags {
        bool check;
        bool mate;
    }

    // Default initial pieces, white to play
    this () {
    }

    // Restore a previous game
    this (Board board, Flags whiteFlags, Flags blackFlags, Side nextPly) {
        _board   = board;
        _nextPly = nextPly;
    }

    enum Acceptance {
        Normal,
        Check,
        Mate,
        Illegal
    }

    Acceptance apply(in Ply ply) {
        auto source = _board.square(ply.source);
        auto dest   = _board.square(ply.dest);

        /+
        auto sq1 = square(update.source);
        auto sq2 = square(update.dest);

        if (sq1.piece == Piece.Pawn && update.dest.file != update.source.file) {
            // en-passant
        }
        else if (sq1.piece == Piece.King && update.dest.file - update.source.file > 1) {
            // castle
        }
        +/

        return Acceptance.Normal;
    }

    private {
        struct PieceState {
            bool  uncaptured;
            Coord coord;        // valid if uncaptured
        }

        Board         _board;
        Side          _nextPly;
        SideState     _whiteSideState;
        PieceState[8] _whitePieceState;
        SideState     _blackSideState;
        PieceState[8] _blackPieceState;
    }
}

void main(string[] args) {
    Board board;
    dump(board);

    /+
    Game game;
    +/
}
