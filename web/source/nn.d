import std.stdio;
import std.math;
import std.random;
import std.algorithm;
import std.range;
import std.conv;

class Neuron {
    double[] weights;
    double bias;
    double output;
    double delta;

    this(size_t inputCount, ref Random rnd) {
        weights = new double[inputCount];
        foreach (ref w; weights) {
            w = uniform(-0.5, 0.5, rnd);
        }
        bias = uniform(-0.5, 0.5, rnd);
    }

    static double activate(double x) {
        return 1.0 / (1.0 + exp(-x));
    }

    static double activateDerivative(double x) {
        return x * (1.0 - x);
    }

    double feedForward(double[] inputs) {
        double sum = bias;
        foreach (i, input; inputs) {
            sum += input * weights[i];
        }
        output = activate(sum);
        return output;
    }

    void updateWeights(double[] inputs, double learningRate) {
        foreach (i, input; inputs) {
            weights[i] += learningRate * delta * input;
        }
        bias += learningRate * delta;
    }
}

class Layer {
    Neuron[] neurons;
    double[] lastInputs;
    double[] lastOutputs;

    this(size_t neuronCount, size_t inputCount, ref Random rnd) {
        neurons = new Neuron[neuronCount];
        foreach (ref n; neurons) {
            n = new Neuron(inputCount, rnd);
        }
    }

    double[] feedForward(double[] inputs) {
        lastInputs = inputs.dup;
        lastOutputs = new double[neurons.length];
        foreach (i, n; neurons) {
            lastOutputs[i] = n.feedForward(inputs);
        }
        return lastOutputs;
    }
}

class NeuralNetwork {
    Layer[] layers;
    Random rnd;

    this(int[] topology) {
        rnd = Random(unpredictableSeed);
        for (size_t i = 1; i < topology.length; i++) {
            layers ~= new Layer(topology[i], topology[i-1], rnd);
        }
    }

    double[] feedForward(double[] inputs) {
        double[] currentInputs = inputs;
        foreach (layer; layers) {
            currentInputs = layer.feedForward(currentInputs);
        }
        return currentInputs;
    }

    void backPropagate(double[] targetOutputs, double learningRate) {
        // 1. Output layer deltas
        Layer outputLayer = layers[$-1];
        foreach (i, neuron; outputLayer.neurons) {
            double error = targetOutputs[i] - neuron.output;
            neuron.delta = error * Neuron.activateDerivative(neuron.output);
        }

        // 2. Hidden layer deltas
        for (long i = layers.length - 2; i >= 0; i--) {
            Layer currentLayer = layers[i];
            Layer nextLayer = layers[i+1];
            foreach (j, neuron; currentLayer.neurons) {
                double error = 0.0;
                foreach (nextNeuron; nextLayer.neurons) {
                    error += nextNeuron.delta * nextNeuron.weights[j];
                }
                neuron.delta = error * Neuron.activateDerivative(neuron.output);
            }
        }

        // 3. Update weights
        foreach (layer; layers) {
            foreach (neuron; layer.neurons) {
                neuron.updateWeights(layer.lastInputs, learningRate);
            }
        }
    }

    void train(double[][] inputs, double[][] targets, int epochs, double learningRate) {
        for (int e = 0; e < epochs; e++) {
            double totalError = 0;
            foreach (i, input; inputs) {
                double[] output = feedForward(input);
                backPropagate(targets[i], learningRate);
                
                foreach (j, o; output) {
                    totalError += pow(targets[i][j] - o, 2);
                }
            }
            if (e % 1000 == 0) writeln("Epoch ", e, " Error: ", totalError);
        }
    }

    void displayTopology() {
        writeln("\nNetwork Topology Graph:");
        
        // Determine the number of layers (including input)
        size_t numLayers = layers.length + 1;
        size_t[] neuronCounts = new size_t[numLayers];
        
        // Input layer (from first layer's input count)
        if (layers.length > 0) {
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
}
