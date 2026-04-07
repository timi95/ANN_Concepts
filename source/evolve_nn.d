import std.stdio;
import std.math;
import std.random;
import std.algorithm;
import std.range;
import std.conv;
import core.thread;
import tictactoe;

class EvolvableNeuron {
    double[] weights;
    double bias;
    double output;

    this(size_t inputCount, ref Random rnd) {
        weights = new double[inputCount];
        foreach (ref w; weights) {
            w = uniform(-1.0, 1.0, rnd);
        }
        bias = uniform(-1.0, 1.0, rnd);
    }

    // Copy constructor for mutation/reproduction
    this(EvolvableNeuron other) {
        this.weights = other.weights.dup;
        this.bias = other.bias;
    }

    static double activate(double x) {
        return 1.0 / (1.0 + exp(-x));
    }

    double feedForward(double[] inputs) {
        double sum = bias;
        foreach (i, input; inputs) {
            sum += input * weights[i];
        }
        output = activate(sum);
        return output;
    }

    void mutate(ref Random rnd, double weightMutationRate, double weightMutationScale) {
        foreach (ref w; weights) {
            if (uniform(0.0, 1.0, rnd) < weightMutationRate) {
                w += uniform(-weightMutationScale, weightMutationScale, rnd);
            }
        }
        if (uniform(0.0, 1.0, rnd) < weightMutationRate) {
            bias += uniform(-weightMutationScale, weightMutationScale, rnd);
        }
    }
}

class EvolvableLayer {
    EvolvableNeuron[] neurons;

    this(size_t neuronCount, size_t inputCount, ref Random rnd) {
        neurons = new EvolvableNeuron[neuronCount];
        foreach (ref n; neurons) {
            n = new EvolvableNeuron(inputCount, rnd);
        }
    }

    this(EvolvableLayer other) {
        neurons = new EvolvableNeuron[other.neurons.length];
        foreach (i, n; other.neurons) {
            neurons[i] = new EvolvableNeuron(n);
        }
    }

    double[] feedForward(double[] inputs) {
        double[] outputs = new double[neurons.length];
        foreach (i, n; neurons) {
            outputs[i] = n.feedForward(inputs);
        }
        return outputs;
    }

    void mutate(ref Random rnd, double weightMutationRate, double weightMutationScale) {
        foreach (n; neurons) {
            n.mutate(rnd, weightMutationRate, weightMutationScale);
        }
    }
}

class EvolvableNetwork {
    EvolvableLayer[] layers;
    double fitness;

    this(int[] topology, ref Random rnd) {
        for (size_t i = 1; i < topology.length; i++) {
            layers ~= new EvolvableLayer(topology[i], topology[i-1], rnd);
        }
        fitness = 0.0;
    }

    this(EvolvableNetwork other) {
        layers = new EvolvableLayer[other.layers.length];
        foreach (i, l; other.layers) {
            layers[i] = new EvolvableLayer(l);
        }
        fitness = 0.0;
    }

    double[] feedForward(double[] inputs) {
        double[] currentInputs = inputs;
        foreach (layer; layers) {
            currentInputs = layer.feedForward(currentInputs);
        }
        return currentInputs;
    }

    void displayTopology() {
        writeln("\nNetwork Topology Graph:");
        
        size_t numLayers = layers.length + 1;
        size_t[] neuronCounts = new size_t[numLayers];
        
        if (layers.length > 0 && layers[0].neurons.length > 0) {
            neuronCounts[0] = layers[0].neurons[0].weights.length;
        }
        
        for (size_t i = 0; i < layers.length; i++) {
            neuronCounts[i+1] = layers[i].neurons.length;
        }
        
        size_t maxNeurons = 0;
        foreach (count; neuronCounts) {
            if (count > maxNeurons) maxNeurons = count;
        }
        
        for (size_t row = 0; row < maxNeurons; row++) {
            for (size_t col = 0; col < numLayers; col++) {
                if (row < neuronCounts[col]) {
                    write("(O)");
                } else {
                    write("   ");
                }
                
                if (col < numLayers - 1) {
                    if (row < neuronCounts[col] && row < neuronCounts[col+1]) {
                        write(" --- ");
                    } else {
                        write("     ");
                    }
                }
            }
            writeln();
        }
        
        writef("Layer sizes: ");
        foreach (i, count; neuronCounts) {
            writef("%d%s", count, i == neuronCounts.length - 1 ? "" : " -> ");
        }
        writeln("\n");
    }

    void mutate(ref Random rnd, double weightMutationRate, double weightMutationScale, double topologyMutationRate) {
        // Weight mutation
        foreach (l; layers) {
            l.mutate(rnd, weightMutationRate, weightMutationScale);
        }

        // Topology mutation: Add a neuron to a hidden layer
        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            size_t layerIdx = uniform(0, layers.length - 1, rnd); 
            
            size_t inputCount = (layerIdx == 0) ? layers[0].neurons[0].weights.length : layers[layerIdx-1].neurons.length;
            
            // Add neuron to layerIdx
            layers[layerIdx].neurons ~= new EvolvableNeuron(inputCount, rnd);
            
            // Update next layer's neurons to have one more input
            foreach (ref n; layers[layerIdx+1].neurons) {
                n.weights ~= uniform(-1.0, 1.0, rnd);
            }
        }

        // Topology mutation: Remove a neuron from a hidden layer
        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            size_t layerIdx = uniform(0, layers.length - 1, rnd);
            if (layers[layerIdx].neurons.length > 1) {
                size_t neuronIdx = uniform(0, layers[layerIdx].neurons.length, rnd);
                layers[layerIdx].neurons = layers[layerIdx].neurons.remove(neuronIdx);

                // Update next layer's neurons to have one less input
                foreach (ref n; layers[layerIdx+1].neurons) {
                    if (n.weights.length > 1) {
                        n.weights = n.weights.remove(neuronIdx);
                    }
                }
            }
        }
    }
}

class Population {
    EvolvableNetwork[] networks;
    Random rnd;

    this(size_t size, int[] initialTopology) {
        rnd = Random(unpredictableSeed);
        networks = new EvolvableNetwork[size];
        foreach (ref net; networks) {
            net = new EvolvableNetwork(initialTopology, rnd);
        }
    }

    void evolve(double weightMutationRate, double weightMutationScale, double topologyMutationRate) {
        // 1. Sort by fitness
        sort!((a, b) => a.fitness > b.fitness)(networks);

        // 2. Keep the best (Elitism)
        size_t eliteCount = networks.length / 10;
        if (eliteCount == 0) eliteCount = 1;

        EvolvableNetwork[] nextGeneration;
        for (size_t i = 0; i < eliteCount; i++) {
            nextGeneration ~= new EvolvableNetwork(networks[i]);
            nextGeneration[$-1].fitness = networks[i].fitness; // Preserve fitness for logging
        }

        // 3. Fill the rest with mutated versions of the elites
        while (nextGeneration.length < networks.length) {
            size_t parentIdx = uniform(0, eliteCount, rnd);
            auto child = new EvolvableNetwork(networks[parentIdx]);
            child.mutate(rnd, weightMutationRate, weightMutationScale, topologyMutationRate);
            nextGeneration ~= child;
        }

        networks = nextGeneration;
    }
}

unittest {
    import std.random;
    auto rnd = Random(42); // Fixed seed for reproducibility

    // Test EvolvableNeuron
    auto neuron = new EvolvableNeuron(3, rnd);
    assert(neuron.weights.length == 3);
    double[] inputs = [0.5, -0.5, 0.0];
    double output = neuron.feedForward(inputs);
    assert(output >= 0.0 && output <= 1.0);

    // Test Neuron Mutation
    auto oldWeights = neuron.weights.dup;
    auto oldBias = neuron.bias;
    neuron.mutate(rnd, 1.0, 0.1); // 100% mutation rate for testing
    assert(neuron.weights != oldWeights || neuron.bias != oldBias);

    // Test EvolvableLayer
    auto layer = new EvolvableLayer(4, 3, rnd);
    assert(layer.neurons.length == 4);
    auto layerOutputs = layer.feedForward(inputs);
    assert(layerOutputs.length == 4);

    // Test EvolvableNetwork
    int[] topology = [3, 5, 2];
    auto net = new EvolvableNetwork(topology, rnd);
    assert(net.layers.length == 2);
    assert(net.layers[0].neurons.length == 5);
    assert(net.layers[1].neurons.length == 2);

    auto netOutput = net.feedForward(inputs);
    assert(netOutput.length == 2);

    // Test Network Mutation (Topology)
    size_t initialHiddenNeurons = net.layers[0].neurons.length;
    bool changed = false;
    for(int i = 0; i < 100; i++) {
        // Use a mutation rate that is high but likely to trigger only one at a time occasionally
        // or check for ANY change.
        net.mutate(rnd, 0.0, 0.0, 0.5); 
        if (net.layers[0].neurons.length != initialHiddenNeurons) {
            changed = true;
            break;
        }
    }
    assert(changed, "Topology should have changed.");

    // Test Population
    auto pop = new Population(10, [3, 2]);
    foreach(n; pop.networks) n.fitness = uniform(0.0, 1.0, rnd);
    auto bestBefore = pop.networks.maxElement!(n => n.fitness).fitness;
    
    pop.evolve(0.1, 0.1, 0.1);
    assert(pop.networks.length == 10);
    // Best fitness should be preserved due to elitism
    auto bestAfter = pop.networks.maxElement!(n => n.fitness).fitness;
    assert(bestAfter >= bestBefore);
}

// Heuristic player for evaluation (can't import from app.d easily as it has its own main)
int getHeuristicMove(Board board, Player p) {
    Player other = (p == Player.X) ? Player.O : Player.X;
    for (int i = 0; i < 9; i++) {
        if (board.cells[i] == Player.None) {
            Board temp = board;
            temp.makeMove(i, p);
            if (temp.checkWinner() == p) return i;
        }
    }
    for (int i = 0; i < 9; i++) {
        if (board.cells[i] == Player.None) {
            Board temp = board;
            temp.makeMove(i, other);
            if (temp.checkWinner() == other) return i;
        }
    }
    if (board.cells[4] == Player.None) return 4;
    auto rndTmp = Random(unpredictableSeed);
    int[] available;
    for (int i = 0; i < 9; i++) if (board.cells[i] == Player.None) available ~= i;
    if (available.length == 0) return -1;
    return available[uniform(0, available.length, rndTmp)];
}

double evaluateFitness(EvolvableNetwork net, int games = 20) {
    double score = 0;
    for (int i = 0; i < games; i++) {
        Board b;
        Player ai = (i % 2 == 0) ? Player.X : Player.O;
        Player heuristic = (ai == Player.X) ? Player.O : Player.X;
        Player current = Player.X;

        while (b.checkWinner() == Player.None && !b.isFull()) {
            if (current == ai) {
                double[] output = net.feedForward(b.toInputs());
                int bestMove = -1;
                double maxVal = -double.max;
                for (int j = 0; j < 9; j++) {
                    if (b.cells[j] == Player.None && output[j] > maxVal) {
                        maxVal = output[j];
                        bestMove = j;
                    }
                }
                if (bestMove != -1) b.makeMove(bestMove, ai);
                else break;
            } else {
                int move = getHeuristicMove(b, heuristic);
                if (move != -1) b.makeMove(move, heuristic);
                else break;
            }
            current = (current == Player.X) ? Player.O : Player.X;
        }

        Player winner = b.checkWinner();
        if (winner == ai) score += 1.0;
        else if (winner == Player.None) score += 0.5;
        else score -= 0.5; // Penalize loss
    }
    return score / games;
}

void playAndDisplay(EvolvableNetwork net) {
    Board b;
    Player ai = Player.X; // AI always plays X for visualization
    Player heuristic = Player.O;
    Player current = Player.X;

    writeln("\n--- Sample Game: Best Network (X) vs Heuristic (O) ---");
    while (b.checkWinner() == Player.None && !b.isFull()) {
        // ANSI escape code to clear screen (or at least move to top)
        // \033[H moves cursor to top left, \033[J clears from cursor to end of screen
        write("\033[H\033[2J");
        stdout.flush();

        writeln("\n--- Sample Game: Best Network (X) vs Heuristic (O) ---");
        b.display();
        
        if (current == ai) {
            net.displayTopology();
            double[] output = net.feedForward(b.toInputs());
            int bestMove = -1;
            double maxVal = -double.max;
            for (int j = 0; j < 9; j++) {
                if (b.cells[j] == Player.None && output[j] > maxVal) {
                    maxVal = output[j];
                    bestMove = j;
                }
            }
            if (bestMove != -1) {
                writeln("AI (X) plays at ", bestMove);
                b.makeMove(bestMove, ai);
            } else {
                writeln("AI (X) has no valid moves!");
                break;
            }
        } else {
            int move = getHeuristicMove(b, heuristic);
            if (move != -1) {
                writeln("Heuristic (O) plays at ", move);
                b.makeMove(move, heuristic);
            } else {
                writeln("Heuristic (O) has no valid moves!");
                break;
            }
        }
        current = (current == Player.X) ? Player.O : Player.X;
        
        stdout.flush();
        Thread.sleep(500.msecs);
    }
    
    write("\033[H\033[2J");
    writeln("\n--- Sample Game: Best Network (X) vs Heuristic (O) ---");
    b.display();
    Player winner = b.checkWinner();
    if (winner == ai) writeln("Result: AI (X) Wins!");
    else if (winner == Player.None) writeln("Result: Draw!");
    else writeln("Result: Heuristic (O) Wins!");
    writeln("---------------------------------------------------\n");
    Thread.sleep(1.seconds);
}

void main() {
    int[] initialTopology = [9, 18, 9];
    auto pop = new Population(50, initialTopology);
    
    writeln("Starting NeuroEvolution for Tic-Tac-Toe...");
    
    for (int gen = 0; gen < 50; gen++) {
        foreach (net; pop.networks) {
            net.fitness = evaluateFitness(net);
        }
        
        auto best = pop.networks.maxElement!(n => n.fitness);
        
        if (gen % 5 == 0) {
            writefln("Gen %d: Best Fitness = %.2f, Topology = %s", gen, best.fitness, 
                best.layers.map!(l => l.neurons.length).array);
            playAndDisplay(best);
        }
        
        pop.evolve(0.1, 0.2, 0.05);
    }

    auto finalBest = pop.networks.maxElement!(n => n.fitness);
    writefln("\nEvolution Complete. Final Best Fitness: %.2f", finalBest.fitness);
    writefln("Final Topology: %s", finalBest.layers.map!(l => l.neurons.length).array);
}
