// import std.stdio;
// import std.math;
// import std.random;
// import std.algorithm;
// import std.range;
// import std.conv;
// import std.string;

// Replacement for necessary functions to avoid standard library
extern(C) {
    double exp(double);
    double sin(double);
    double cos(double);
    void writeln(const char*); // Dummy or link to emscripten
    void* malloc(size_t);
    void __assert(const char*, const char*, int) {
        // Assert handler stub
    }
}

// Simple random number generator (Xorshift)
struct SimpleRandom {
    uint state;
    this(uint seed) { state = seed; }
    double uniform(double min, double max) {
        state ^= (state << 13);
        state ^= (state >> 17);
        state ^= (state << 5);
        return min + (cast(double)(state % 10000) / 10000.0) * (max - min);
    }
}

// Minimal SDL headers for Emscripten
extern(C) {
    struct SDL_Window;
    struct SDL_Renderer;
    struct SDL_Texture;
    struct SDL_Rect { int x, y, w, h; }
    struct SDL_Event { uint type; int[13] padding; } // Rough approximation
    
    enum SDL_INIT_VIDEO = 0x00000020u;
    enum SDL_WINDOW_SHOWN = 0x00000004u;
    enum SDL_WINDOWPOS_UNDEFINED = 0x1FFF0000u;
    enum SDL_RENDERER_ACCELERATED = 0x00000002u;
    enum SDL_QUIT = 0x100u;

    int SDL_Init(uint flags);
    SDL_Window* SDL_CreateWindow(const char* title, int x, int y, int w, int h, uint flags);
    SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, int index, uint flags);
    int SDL_SetRenderDrawColor(SDL_Renderer* renderer, ubyte r, ubyte g, ubyte b, ubyte a);
    int SDL_RenderClear(SDL_Renderer* renderer);
    void SDL_RenderPresent(SDL_Renderer* renderer);
    int SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_Rect* rect);
    int SDL_RenderDrawLine(SDL_Renderer* renderer, int x1, int y1, int x2, int y2);
    int SDL_PollEvent(SDL_Event* event);
    void SDL_Quit();
    
    // Emscripten specific
    alias em_callback_func = void function();
    void emscripten_set_main_loop(em_callback_func func, int fps, int simulate_infinite_loop);
}

import pole_sim;

// Configuration
immutable int WINDOW_WIDTH = 800;
immutable int WINDOW_HEIGHT = 600;

struct EvolvableNeuron {
    double[] weights;
    double bias;
    double output;

    void init(size_t inputCount, ref SimpleRandom rnd) {
        weights = (cast(double*)malloc(double.sizeof * inputCount))[0 .. inputCount];
        foreach (ref w; weights) {
            w = rnd.uniform(-1.0, 1.0);
        }
        bias = rnd.uniform(-1.0, 1.0);
    }

    void copyFrom(EvolvableNeuron other) {
        weights = (cast(double*)malloc(double.sizeof * other.weights.length))[0 .. other.weights.length];
        foreach(i, w; other.weights) weights[i] = w;
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

    void mutate(ref SimpleRandom rnd, double weightMutationRate, double weightMutationScale) {
        foreach (ref w; weights) {
            if (rnd.uniform(0.0, 1.0) < weightMutationRate) {
                w += rnd.uniform(-weightMutationScale, weightMutationScale);
            }
        }
        if (rnd.uniform(0.0, 1.0) < weightMutationRate) {
            bias += rnd.uniform(-weightMutationScale, weightMutationScale);
        }
    }
}

struct EvolvableLayer {
    EvolvableNeuron[] neurons;

    void init(size_t neuronCount, size_t inputCount, ref SimpleRandom rnd) {
        neurons = (cast(EvolvableNeuron*)malloc(EvolvableNeuron.sizeof * neuronCount))[0 .. neuronCount];
        foreach (ref n; neurons) {
            n.init(inputCount, rnd);
        }
    }

    void copyFrom(EvolvableLayer other) {
        neurons = (cast(EvolvableNeuron*)malloc(EvolvableNeuron.sizeof * other.neurons.length))[0 .. other.neurons.length];
        foreach (i, ref n; other.neurons) {
            neurons[i].copyFrom(n);
        }
    }

    double[] feedForward(double[] inputs) {
        static double[100] outputs; // Assuming max neurons per layer is 100
        foreach (i, ref n; neurons) {
            outputs[i] = n.feedForward(inputs);
        }
        return outputs[0 .. neurons.length];
    }

    void mutate(ref SimpleRandom rnd, double weightMutationRate, double weightMutationScale) {
        foreach (ref n; neurons) {
            n.mutate(rnd, weightMutationRate, weightMutationScale);
        }
    }
}

struct EvolvableNetwork {
    EvolvableLayer[10] layers; // Fixed size
    size_t numLayers;
    double fitness;

    void init(int[] topology, ref SimpleRandom rnd) {
        numLayers = topology.length - 1;
        for (size_t i = 1; i < topology.length; i++) {
            layers[i-1].init(topology[i], topology[i-1], rnd);
        }
        fitness = 0.0;
    }

    void copyFrom(EvolvableNetwork other) {
        numLayers = other.numLayers;
        for (size_t i = 0; i < numLayers; i++) {
            layers[i].copyFrom(other.layers[i]);
        }
        fitness = 0.0;
    }

    double[] feedForward(double[] inputs) {
        double[] currentInputs = inputs;
        for (size_t i = 0; i < numLayers; i++) {
            currentInputs = layers[i].feedForward(currentInputs);
        }
        return currentInputs;
    }

    void mutate(ref SimpleRandom rnd, double weightMutationRate, double weightMutationScale) {
        for (size_t i = 0; i < numLayers; i++) {
            layers[i].mutate(rnd, weightMutationRate, weightMutationScale);
        }
    }
}

struct Population {
    EvolvableNetwork* networks;
    size_t networksCount;
    int[] topology;
    SimpleRandom rnd;

    void init(int size, int[] topology) {
        this.topology = topology;
        this.rnd = SimpleRandom(12345); // Constant seed for now
        this.networksCount = size;
        this.networks = cast(EvolvableNetwork*)malloc(EvolvableNetwork.sizeof * size);
        for (int i = 0; i < size; i++) {
            networks[i].init(topology, rnd);
        }
    }

    void evolve(double survivalRate, double weightMutationRate, double weightMutationScale) {
        // Simple sort (manual to avoid std.algorithm)
        for (int i = 0; i < networksCount; i++) {
            for (int j = i + 1; j < networksCount; j++) {
                if (networks[j].fitness > networks[i].fitness) {
                    auto tmp = networks[i];
                    networks[i] = networks[j];
                    networks[j] = tmp;
                }
            }
        }
        
        int survivorsCount = cast(int)(networksCount * survivalRate);
        if (survivorsCount < 1) survivorsCount = 1;
        
        // Use a temporary array of the same size
        static EvolvableNetwork[100] nextGen; // Max size 100
        size_t nextGenCount = 0;

        // Keep survivors
        for (int i = 0; i < survivorsCount && nextGenCount < 100; i++) {
            nextGen[nextGenCount++].copyFrom(networks[i]);
        }
        
        // Fill the rest with mutated versions of survivors
        while (nextGenCount < networksCount && nextGenCount < 100) {
            int parentIdx = cast(int)(rnd.uniform(0, survivorsCount));
            nextGen[nextGenCount].copyFrom(networks[parentIdx]);
            nextGen[nextGenCount].mutate(rnd, weightMutationRate, weightMutationScale);
            nextGenCount++;
        }
        
        for(size_t i = 0; i < nextGenCount; i++) {
            networks[i] = nextGen[i];
        }
    }
}

// Global state for main loop
SDL_Renderer* globalRenderer;
Population globalPop;
CartPole globalCP;
EvolvableNetwork globalBest;
int generation = 0;
int stepsInGen = 0;
bool isSolving = true;

void drawSimulation(SDL_Renderer* renderer, CartPole cp, EvolvableNetwork net, double[] inputs) {
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderClear(renderer);

    // Draw Cart
    int cartW = 80;
    int cartH = 40;
    int cartX = cast(int)(WINDOW_WIDTH / 2 + (cp.x / 2.4) * (WINDOW_WIDTH / 2) - cartW / 2);
    int cartY = 400;

    SDL_Rect cartRect = { cartX, cartY, cartW, cartH };
    SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);
    SDL_RenderFillRect(renderer, &cartRect);

    // Draw Pole
    int poleX1 = cartX + cartW / 2;
    int poleY1 = cartY;
    int poleLen = cast(int)(cp.length * 200);
    int poleX2 = poleX1 + cast(int)(poleLen * sin(cp.theta));
    int poleY2 = poleY1 - cast(int)(poleLen * cos(cp.theta));

    SDL_SetRenderDrawColor(renderer, 200, 50, 50, 255);
    SDL_RenderDrawLine(renderer, poleX1, poleY1, poleX2, poleY2);

    // Draw Ground
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderDrawLine(renderer, 0, cartY + cartH, WINDOW_WIDTH, cartY + cartH);

    SDL_RenderPresent(renderer);
}

extern(C) void mainLoop() {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) {
            // Emscripten handles exit differently
        }
    }

    if (isSolving) {
        // Evaluate fitness for current generation in batches or one by one
        // For simplicity, let's just evolve instantly for now or show progress
        for (int j = 0; j < globalPop.networksCount; j++) {
            auto net = &globalPop.networks[j];
            CartPole sim;
            sim.init();
            double fitness = 0;
            for (int i = 0; i < 500; i++) {
                double[] input = sim.getInputs();
                double[] output = net.feedForward(input);
                double force = (output[0] > 0.5) ? 10.0 : -10.0;
                if (!sim.update(force)) break;
                fitness++;
            }
            net.fitness = fitness;
        }

        // Find best
        globalBest.copyFrom(globalPop.networks[0]);
        for(int i = 0; i < globalPop.networksCount; i++) {
            if (globalPop.networks[i].fitness > globalBest.fitness) {
                globalBest.copyFrom(globalPop.networks[i]);
            }
        }

        generation++;
        
        if (globalBest.fitness >= 500) {
            isSolving = false;
            // writeln("Solved at Generation ", generation);
        } else {
            globalPop.evolve(0.1, 0.2, 0.05);
        }
        
        // Reset simulation for visualization
        globalCP.init();
    }

    // Visualize the best
    double[] input = globalCP.getInputs();
    double[] output = globalBest.feedForward(input);
    double force = (output[0] > 0.5) ? 10.0 : -10.0;
    globalCP.update(force);

    drawSimulation(globalRenderer, globalCP, globalBest, input);
}

extern(C) void main() {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) return;
    
    SDL_Window* window = SDL_CreateWindow("Cart-Pole Web", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_SHOWN);
    globalRenderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    int[3] topology = [4, 1, 1];
    globalPop.init(50, topology[]);
    globalCP.init();
    globalBest.init(topology[], globalPop.rnd);

    emscripten_set_main_loop(&mainLoop, 0, 1);
}
