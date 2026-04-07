import std.stdio;
import std.algorithm;
import std.random;
import nn;
import tictactoe;
import std.string;
import std.conv;

// Simple heuristic player to generate some training data
int getHeuristicMove(Board board, Player p) {
    Player other = (p == Player.X) ? Player.O : Player.X;
    
    // 1. Can I win?
    for (int i = 0; i < 9; i++) {
        if (board.cells[i] == Player.None) {
            Board temp = board;
            temp.makeMove(i, p);
            if (temp.checkWinner() == p) return i;
        }
    }
    
    // 2. Can I block?
    for (int i = 0; i < 9; i++) {
        if (board.cells[i] == Player.None) {
            Board temp = board;
            temp.makeMove(i, other);
            if (temp.checkWinner() == other) return i;
        }
    }
    
    // 3. Take center
    if (board.cells[4] == Player.None) return 4;
    
    // 4. Random
    auto rnd = Random(unpredictableSeed);
    int[] available;
    for (int i = 0; i < 9; i++) if (board.cells[i] == Player.None) available ~= i;
    if (available.length == 0) return -1;
    return available[uniform(0, available.length, rnd)];
}

void main() {
    auto nn = new NeuralNetwork([9, 18, 9]); // 9 inputs, 18 hidden, 9 outputs
    
    writeln("Generating training data...");
    double[][] trainInputs;
    double[][] trainTargets;
    
    for (int i = 0; i < 1000; i++) {
        Board b;
        Player current = (i % 2 == 0) ? Player.X : Player.O;
        // Randomize board a bit
        auto rnd = Random(unpredictableSeed);
        int moves = uniform(0, 5, rnd);
        for (int m = 0; m < moves; m++) {
            int move = getHeuristicMove(b, current);
            if (move == -1) break;
            b.makeMove(move, current);
            current = (current == Player.X) ? Player.O : Player.X;
            if (b.checkWinner() != Player.None || b.isFull()) break;
        }
        
        if (b.checkWinner() == Player.None && !b.isFull()) {
            int bestMove = getHeuristicMove(b, Player.X);
            if (bestMove != -1) {
                trainInputs ~= b.toInputs();
                double[] target = new double[9];
                target[] = 0.01; // Low probability for all
                target[bestMove] = 0.99; // High probability for best move
                trainTargets ~= target;
            }
        }
    }
    
    writeln("Training network (", trainInputs.length, " samples)...");
    nn.train(trainInputs, trainTargets, 2000, 0.1);
    
    writeln("\nTraining complete. Let's play a game! (You are O, AI is X)");
    Board gameBoard;
    Player current = Player.X;
    
    while (gameBoard.checkWinner() == Player.None && !gameBoard.isFull()) {
        gameBoard.display();
        if (current == Player.X) {
            writeln("AI is thinking...");
            nn.displayTopology();
            double[] output = nn.feedForward(gameBoard.toInputs());
            
            // Choose the best valid move
            int bestMove = -1;
            double maxVal = -1.0;
            for (int i = 0; i < 9; i++) {
                if (gameBoard.cells[i] == Player.None && output[i] > maxVal) {
                    maxVal = output[i];
                    bestMove = i;
                }
            }
            
            if (bestMove != -1) {
                gameBoard.makeMove(bestMove, Player.X);
                writeln("AI played at ", bestMove);
            } else {
                writeln("AI has no moves!");
                break;
            }
        } else {
            write("Your move (0-8): ");
            int move;
            try {
                string line = readln().strip();
                if (line.length == 0) continue;
                move = line.to!int;
                if (!gameBoard.makeMove(move, Player.O)) {
                    writeln("Invalid move, try again.");
                    continue;
                }
            } catch (Exception e) {
                writeln("Please enter a number.");
                continue;
            }
        }
        current = (current == Player.X) ? Player.O : Player.X;
    }
    
    gameBoard.display();
    Player winner = gameBoard.checkWinner();
    if (winner == Player.X) writeln("AI Wins!");
    else if (winner == Player.O) writeln("You Win!");
    else writeln("It's a Draw!");
}
