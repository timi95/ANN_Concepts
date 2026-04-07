import std.stdio;
import std.math;
import std.random;
import std.algorithm;
import std.range;
import std.conv;
import core.thread;
import pole_sim;

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
        foreach (l; layers) {
            l.mutate(rnd, weightMutationRate, weightMutationScale);
        }

        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            size_t layerIdx = uniform(0, layers.length - 1, rnd); 
            size_t inputCount = (layerIdx == 0) ? layers[0].neurons[0].weights.length : layers[layerIdx-1].neurons.length;
            layers[layerIdx].neurons ~= new EvolvableNeuron(inputCount, rnd);
            foreach (ref n; layers[layerIdx+1].neurons) {
                n.weights ~= uniform(-1.0, 1.0, rnd);
            }
        }

        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            size_t layerIdx = uniform(0, layers.length - 1, rnd);
            if (layers[layerIdx].neurons.length > 1) {
                size_t neuronIdx = uniform(0, layers[layerIdx].neurons.length, rnd);
                layers[layerIdx].neurons = layers[layerIdx].neurons.remove(neuronIdx);
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
        sort!((a, b) => a.fitness > b.fitness)(networks);
        size_t eliteCount = networks.length / 10;
        if (eliteCount == 0) eliteCount = 1;
        EvolvableNetwork[] nextGeneration;
        for (size_t i = 0; i < eliteCount; i++) {
            nextGeneration ~= new EvolvableNetwork(networks[i]);
            nextGeneration[$-1].fitness = networks[i].fitness;
        }
        while (nextGeneration.length < networks.length) {
            size_t parentIdx = uniform(0, eliteCount, rnd);
            auto child = new EvolvableNetwork(networks[parentIdx]);
            child.mutate(rnd, weightMutationRate, weightMutationScale, topologyMutationRate);
            nextGeneration ~= child;
        }
        networks = nextGeneration;
    }
}

double evaluateFitness(EvolvableNetwork net, string shapeType = "Standard Pole", int maxSteps = 500) {
    IBalanceable cp;
    switch (shapeType) {
        case "Long Pole": cp = new CartLongPole(); break;
        case "Weighted Pole": cp = new CartWeightedPole(); break;
        case "Short Heavy Pole": cp = new CartShortHeavyPole(); break;
        case "Triangle Shape": cp = new CartTriangle(); break;
        default: cp = new CartPole(); break;
    }
    int steps = 0;
    while (!cp.isGameOver() && steps < maxSteps) {
        double[] input = cp.getInputs();
        double[] output = net.feedForward(input);
        double force = (output[0] > 0.5) ? 10.0 : -10.0;
        cp.update(force);
        steps++;
    }
    return cast(double)steps;
}

void displaySimulation(EvolvableNetwork net, string shapeType = "Standard Pole", int maxSteps = 500) {
    IBalanceable cp;
    switch (shapeType) {
        case "Long Pole": cp = new CartLongPole(); break;
        case "Weighted Pole": cp = new CartWeightedPole(); break;
        case "Short Heavy Pole": cp = new CartShortHeavyPole(); break;
        case "Triangle Shape": cp = new CartTriangle(); break;
        default: cp = new CartPole(); break;
    }
    int steps = 0;
    writeln("\n--- Cart-Pole Simulation [", cp.getShapeName(), "] ---");
    while (!cp.isGameOver() && steps < maxSteps) {
        write("\033[H\033[2J");
        writeln("\n--- Cart-Pole Simulation [", cp.getShapeName(), "] ---");
        writeln("Step: ", steps);
        
        // Basic visualization
        int width = 40;
        int cartPos = cast(int)((cp.getX() + 2.4) / (2 * 2.4) * width);
        if (cartPos < 0) cartPos = 0;
        if (cartPos >= width) cartPos = width - 1;

        foreach (i; 0 .. width) {
            if (i == cartPos) write("=");
            else if (i == width / 2) write("|");
            else write("-");
        }
        writeln();
        
        // Pole visualization (very simple)
        foreach (i; 0 .. width) {
            if (i == cartPos) {
                if (cp.getTheta() < -0.05) write("/");
                else if (cp.getTheta() > 0.05) write("\\");
                else write("|");
            } else write(" ");
        }
        writeln();
        
        writef("x: %6.2f, theta: %6.2f deg\n", cp.getX(), cp.getTheta() * 180 / PI);
        net.displayTopology();

        double[] input = cp.getInputs();
        double[] output = net.feedForward(input);
        double force = (output[0] > 0.5) ? 10.0 : -10.0;
        cp.update(force);
        steps++;
        
        stdout.flush();
        Thread.sleep(20.msecs);
    }
    writeln("\nGame Over at step: ", steps);
    Thread.sleep(1.seconds);
}

void main() {
    int[] initialTopology = [4, 1, 1];
    auto pop = new Population(50, initialTopology);
    
    string[] shapes = ["Standard Pole", "Long Pole", "Weighted Pole", "Short Heavy Pole", "Triangle Shape"];
    writeln("Starting NeuroEvolution for Cart-Pole [Various Shapes]...");
    
    // We'll rotate shapes every 20 generations for variety in ASCII version
    for (int gen = 0; gen < 100; gen++) {
        string currentShape = shapes[(gen / 25) % shapes.length];
        
        foreach (net; pop.networks) {
            net.fitness = evaluateFitness(net, currentShape);
        }
        
        auto best = pop.networks.maxElement!(n => n.fitness);
        
        if (gen % 10 == 0) {
            writefln("Gen %d: Best Steps = %.0f [Shape: %s], Topology = %s", gen, best.fitness, currentShape,
                best.layers.map!(l => l.neurons.length).array);
            displaySimulation(best, currentShape, 200);
        }
        
        if (best.fitness >= 500) {
            writefln("Problem solved for %s at generation %d!", currentShape, gen);
            displaySimulation(best, currentShape, 500);
            if (gen > 80) break; // Keep going for a bit to try other shapes if early success
        }
        
        pop.evolve(0.1, 0.2, 0.05);
    }

    auto finalBest = pop.networks.maxElement!(n => n.fitness);
    writefln("\nEvolution Complete. Final Best Steps: %.0f", finalBest.fitness);
    writefln("Final Topology: %s", finalBest.layers.map!(l => l.neurons.length).array);
}
