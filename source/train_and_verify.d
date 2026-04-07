import std.stdio;
import std.algorithm;
import std.random;
import nn;
import tictactoe;
import std.string;
import std.conv;
import std.math;

// Heuristic player to generate training data
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
    auto nn = new NeuralNetwork([9, 36, 18, 9]); // Increased capacity and refined layers
    
    writeln("Generating training data...");
    double[][] trainInputs;
    double[][] trainTargets;
    
    auto rndGen = Random(unpredictableSeed);

    for (int i = 0; i < 4000; i++) {
        Board b;
        Player firstPlayer = (i % 2 == 0) ? Player.X : Player.O;
        Player current = firstPlayer;
        
        // Play a partial game
        int maxMoves = uniform(0, 7, rndGen);
        for (int m = 0; m < maxMoves; m++) {
            int move = getHeuristicMove(b, current);
            if (move == -1) break;
            b.makeMove(move, current);
            if (b.checkWinner() != Player.None || b.isFull()) break;
            current = (current == Player.X) ? Player.O : Player.X;
        }
        
        if (b.checkWinner() == Player.None && !b.isFull()) {
            // Training on move for X
            int bestMove = getHeuristicMove(b, Player.X);
            if (bestMove != -1) {
                trainInputs ~= b.toInputs();
                double[] target = new double[9];
                target[] = 0.01;
                target[bestMove] = 0.99;
                trainTargets ~= target;
            }
            
            // Mirror training: help generalize
            // We can also rotate/flip board, but let's keep it simple for now.
        }
    }
    
    writeln("Training network (", trainInputs.length, " samples)...");
    nn.train(trainInputs, trainTargets, 3000, 0.1); // More epochs, constant LR for now
    
    // Evaluation
    writeln("\nEvaluating performance (Playing 100 games AI X vs Heuristic O)...");
    int aiWins = 0;
    int heuristicWins = 0;
    int draws = 0;
    
    for(int g=0; g<100; g++) {
        Board game;
        Player curr = (g % 2 == 0) ? Player.X : Player.O;
        while(game.checkWinner() == Player.None && !game.isFull()) {
            if(curr == Player.X) {
                double[] outv = nn.feedForward(game.toInputs());
                int move = -1;
                double maxVal = -1.0;
                for(int i=0; i<9; i++) {
                    if(game.cells[i] == Player.None && outv[i] > maxVal) {
                        maxVal = outv[i];
                        move = i;
                    }
                }
                game.makeMove(move, Player.X);
            } else {
                int move = getHeuristicMove(game, Player.O);
                game.makeMove(move, Player.O);
            }
            curr = (curr == Player.X) ? Player.O : Player.X;
        }
        Player winner = game.checkWinner();
        if(winner == Player.X) aiWins++;
        else if(winner == Player.O) heuristicWins++;
        else draws++;
    }
    
    writeln("Results: AI Wins: ", aiWins, ", Heuristic Wins: ", heuristicWins, ", Draws: ", draws);
    if (aiWins > heuristicWins) writeln("Training SUCCESSFUL: AI is better than heuristic!");
    else writeln("Training could be better, AI still struggling.");
}
