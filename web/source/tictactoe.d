import std.stdio;
import std.algorithm;
import std.range;
import std.conv;

enum Player { None = 0, X = 1, O = 2 }

struct Board {
    Player[9] cells;

    this(Player[9] initial) {
        cells = initial;
    }

    bool isFull() const {
        return !cells[].canFind(Player.None);
    }

    Player checkWinner() const {
        static immutable int[][] wins = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
            [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
            [0, 4, 8], [2, 4, 6]             // diags
        ];
        foreach (win; wins) {
            if (cells[win[0]] != Player.None && cells[win[0]] == cells[win[1]] && cells[win[0]] == cells[win[2]]) {
                return cells[win[0]];
            }
        }
        return Player.None;
    }

    bool makeMove(int index, Player p) {
        if (index < 0 || index >= 9 || cells[index] != Player.None) return false;
        cells[index] = p;
        return true;
    }

    double[] toInputs() const {
        double[] inputs = new double[9];
        foreach (i, cell; cells) {
            if (cell == Player.X) inputs[i] = 1.0;
            else if (cell == Player.O) inputs[i] = -1.0;
            else inputs[i] = 0.0;
        }
        return inputs;
    }

    void display() const {
        for (int i = 0; i < 9; i++) {
            char c = '.';
            if (cells[i] == Player.X) c = 'X';
            if (cells[i] == Player.O) c = 'O';
            write(c, " ");
            if (i % 3 == 2) writeln();
        }
        writeln("-----");
    }
}
