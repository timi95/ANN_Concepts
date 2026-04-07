/+ dub.sdl:
    name "pole_sdl"
    dependency "bindbc-sdl" version="~>1.4.6"
    versions "SDL_2_0_10"
    dependency "bindbc-loader" version="~>1.1.5"
+/
import std.stdio;
import std.math;
import std.random;
import std.algorithm;
import std.range;
import std.conv;
import std.format;
import core.thread;
import pole_sim;

import bindbc.sdl;
import bindbc.loader;

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

    void mutate(ref Random rnd, double weightMutationRate, double weightMutationScale, double topologyMutationRate, bool priorityTopology = true) {
        bool topologyMutated = false;

        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            topologyMutated = true;
            size_t layerIdx = uniform(0, layers.length - 1, rnd); 
            size_t inputCount = (layerIdx == 0) ? layers[0].neurons[0].weights.length : layers[layerIdx-1].neurons.length;
            layers[layerIdx].neurons ~= new EvolvableNeuron(inputCount, rnd);
            foreach (ref n; layers[layerIdx+1].neurons) {
                n.weights ~= uniform(-1.0, 1.0, rnd);
            }
        }

        if (layers.length > 1 && uniform01(rnd) < topologyMutationRate) {
            topologyMutated = true;
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

        if (!topologyMutated || !priorityTopology) {
            foreach (l; layers) {
                l.mutate(rnd, weightMutationRate, weightMutationScale);
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

    void evolve(double weightMutationRate, double weightMutationScale, double topologyMutationRate, bool priorityTopology = true) {
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
            child.mutate(rnd, weightMutationRate, weightMutationScale, topologyMutationRate, priorityTopology);
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

const int WINDOW_WIDTH = 800;
const int WINDOW_HEIGHT = 800; // Increased to 800 to fit topology below

void drawChar(SDL_Renderer* renderer, char c, int x, int y, int size) {
    // Very basic 3x5 bitmapped font drawn with lines/points
    static const ubyte[5][128] font = [
        '0': [0b111, 0b101, 0b101, 0b101, 0b111],
        '1': [0b010, 0b110, 0b010, 0b010, 0b111],
        '2': [0b111, 0b001, 0b111, 0b100, 0b111],
        '3': [0b111, 0b001, 0b111, 0b001, 0b111],
        '4': [0b101, 0b101, 0b111, 0b001, 0b001],
        '5': [0b111, 0b100, 0b111, 0b001, 0b111],
        '6': [0b111, 0b100, 0b111, 0b101, 0b111],
        '7': [0b111, 0b001, 0b001, 0b001, 0b001],
        '8': [0b111, 0b101, 0b111, 0b101, 0b111],
        '9': [0b111, 0b101, 0b111, 0b001, 0b111],
        '.': [0b000, 0b000, 0b000, 0b000, 0b010],
        '-': [0b000, 0b000, 0b111, 0b000, 0b000],
        'I': [0b111, 0b010, 0b010, 0b010, 0b111],
        'N': [0b101, 0b111, 0b111, 0b101, 0b101],
        'P': [0b111, 0b101, 0b111, 0b100, 0b100],
        'U': [0b101, 0b101, 0b101, 0b101, 0b111],
        'T': [0b111, 0b010, 0b010, 0b010, 0b111],
        'H': [0b101, 0b101, 0b111, 0b101, 0b101],
        'D': [0b110, 0b101, 0b101, 0b101, 0b110],
        'E': [0b111, 0b100, 0b111, 0b100, 0b111],
        'O': [0b111, 0b101, 0b101, 0b101, 0b111],
    ];

    if (c >= 128) return;
    auto bits = font[c];
    if (bits[0] == 0 && bits[1] == 0 && bits[2] == 0 && bits[3] == 0 && bits[4] == 0 && c != ' ') return;
    for (int row = 0; row < 5; row++) {
        for (int col = 0; col < 3; col++) {
            if (bits[row] & (1 << (2 - col))) {
                SDL_Rect r = { x + col * size, y + row * size, size, size };
                SDL_RenderFillRect(renderer, &r);
            }
        }
    }
}

void drawString(SDL_Renderer* renderer, string s, int x, int y, int size) {
    int curX = x;
    foreach (char c; s) {
        drawChar(renderer, c, curX, y, size);
        curX += 4 * size;
    }
}

void drawTopology(SDL_Renderer* renderer, EvolvableNetwork net, double[] currentInputs) {
    int startY = 400; // Start below the simulation (which occupies top 400)
    int graphWidth = WINDOW_WIDTH;
    int graphHeight = 400;

    size_t numLayers = net.layers.length + 1;
    size_t[] neuronCounts = new size_t[numLayers];
    
    if (net.layers.length > 0 && net.layers[0].neurons.length > 0) {
        neuronCounts[0] = net.layers[0].neurons[0].weights.length;
    }
    
    for (size_t i = 0; i < net.layers.length; i++) {
        neuronCounts[i+1] = net.layers[i].neurons.length;
    }

    int layerSpacing = graphWidth / (cast(int)numLayers + 1);
    int neuronRadius = 10;

    // Pre-calculate neuron positions
    struct Point { int x, y; }
    Point[][] positions;
    positions.length = numLayers;

    for (size_t col = 0; col < numLayers; col++) {
        int x = (cast(int)col + 1) * layerSpacing;
        int count = cast(int)neuronCounts[col];
        int neuronSpacing = graphHeight / (count + 1);
        positions[col].length = count;
        for (int row = 0; row < count; row++) {
            positions[col][row] = Point(x, startY + (row + 1) * neuronSpacing);
        }
    }

    // Draw connections (weights) first so they are behind neurons
    for (size_t l = 0; l < net.layers.length; l++) {
        EvolvableLayer layer = net.layers[l];
        for (size_t nIdx = 0; nIdx < layer.neurons.length; nIdx++) {
            EvolvableNeuron neuron = layer.neurons[nIdx];
            Point currentPos = positions[l+1][nIdx];
            
            // Current neuron's activation
            double activation = neuron.output;

            for (size_t wIdx = 0; wIdx < neuron.weights.length; wIdx++) {
                Point prevPos = positions[l][wIdx];
                double weight = neuron.weights[wIdx];
                
                // Pre-synaptic activation (either from currentInputs or previous layer's neurons)
                double preActivation = 0.0;
                if (l == 0) {
                   if (wIdx < currentInputs.length) preActivation = currentInputs[wIdx];
                } else {
                   preActivation = net.layers[l-1].neurons[wIdx].output;
                }

                // Color based on weight: Blue for positive, Red for negative
                // Intensity reflects both weight and pre-synaptic activation
                double signal = weight * preActivation;
                int baseIntensity = cast(int)(abs(weight) * 150);
                int dynamicIntensity = cast(int)(abs(signal) * 105);
                int intensity = baseIntensity + dynamicIntensity;

                if (intensity > 255) intensity = 255;
                if (intensity < 30) intensity = 30; // Minimum visibility

                if (weight > 0) {
                    SDL_SetRenderDrawColor(renderer, 30, 30, cast(ubyte)intensity, 255);
                } else {
                    SDL_SetRenderDrawColor(renderer, cast(ubyte)intensity, 30, 30, 255);
                }

                // Thickness simulation with multiple lines if weight is large
                int thickness = cast(int)(abs(weight) * 2);
                if (thickness < 1) thickness = 1;
                if (thickness > 5) thickness = 5;

                for (int t = -thickness/2; t <= thickness/2; t++) {
                     SDL_RenderDrawLine(renderer, prevPos.x, prevPos.y + t, currentPos.x, currentPos.y + t);
                }

                // Label weights - only if not too many or for specific significant weights
                if (abs(weight) > 0.5) {
                    string wStr = format("%.1f", weight);
                    int tx = prevPos.x + (currentPos.x - prevPos.x) / 3;
                    int ty = prevPos.y + (currentPos.y - prevPos.y) / 3;
                    
                    // Set color for weight text (light grey)
                    SDL_SetRenderDrawColor(renderer, 50, 50, 50, 255);
                    drawString(renderer, wStr, tx, ty, 1);
                }
            }
        }
    }

    // Draw neurons (circles) and layer labels
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    foreach (col; 0 .. numLayers) {
        // Label layers
        string label;
        if (col == 0) label = "INPUT";
        else if (col == numLayers - 1) label = "OUTPUT";
        else label = "HIDDEN";
        
        int labelX = (cast(int)col + 1) * layerSpacing - (cast(int)label.length * 4) / 2;
        drawString(renderer, label, labelX, startY + 20, 2);

        foreach (row, pos; positions[col]) {
            // Determine neuron color based on activation
            double activation = 0.0;
            if (col == 0) {
                if (row < currentInputs.length) activation = currentInputs[row];
            } else {
                activation = net.layers[col-1].neurons[row].output;
            }

            // Map activation (usually 0 to 1 or normalized input) to color
            // Use yellow/white for high activation, dark gray for low
            ubyte colorVal = cast(ubyte)(100 + 155 * clamp(activation, 0.0, 1.0));
            
            SDL_Rect r = { pos.x - neuronRadius, pos.y - neuronRadius, neuronRadius * 2, neuronRadius * 2 };
            SDL_SetRenderDrawColor(renderer, colorVal, colorVal, colorVal, 255);
            SDL_RenderFillRect(renderer, &r);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderDrawRect(renderer, &r);
        }
    }
}

void drawSimulation(SDL_Renderer* renderer, IBalanceable cp, EvolvableNetwork net, double[] currentInputs) {
    // Background
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderClear(renderer);

    // Info Text
    drawString(renderer, "SHAPE: " ~ cp.getShapeName(), 20, 20, 2);

    // Ground
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderDrawLine(renderer, 0, 300, WINDOW_WIDTH, 300);

    // Cart
    int cartWidth = 80;
    int cartHeight = 40;
    int cartX = cast(int)(WINDOW_WIDTH / 2 + (cp.getX() / 2.4) * (WINDOW_WIDTH / 2 - 50) - cartWidth / 2);
    int cartY = 300 - cartHeight;

    SDL_Rect cartRect = { cartX, cartY, cartWidth, cartHeight };
    SDL_SetRenderDrawColor(renderer, 100, 100, 250, 255);
    SDL_RenderFillRect(renderer, &cartRect);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderDrawRect(renderer, &cartRect);

    // Pole
    double poleLength = cp.getPoleLength() * 300.0; // Scale for visual
    int poleEndX = cast(int)(cartX + cartWidth / 2 + sin(cp.getTheta()) * poleLength);
    int poleEndY = cast(int)(cartY - cos(cp.getTheta()) * poleLength);

    // Different colors or visual features for different shapes
    if (cp.getShapeName() == "Long Pole") {
        SDL_SetRenderDrawColor(renderer, 50, 200, 50, 255);
    } else if (cp.getShapeName() == "Weighted Pole") {
        SDL_SetRenderDrawColor(renderer, 200, 50, 200, 255);
        // Draw a weight at the end
        SDL_Rect weight = { poleEndX - 10, poleEndY - 10, 20, 20 };
        SDL_RenderFillRect(renderer, &weight);
    } else if (cp.getShapeName() == "Short Heavy Pole") {
        SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);
    } else if (cp.getShapeName().canFind("Triangle")) {
        SDL_SetRenderDrawColor(renderer, 255, 165, 0, 255); // Orange
        // Draw a triangle
        // We use the mass to influence the width slightly
        double mass = 0.3; // Default
        if (cp.getShapeName().canFind("Small")) mass = 0.1;
        else if (cp.getShapeName().canFind("Large")) mass = 0.5;
        else if (cp.getShapeName().canFind("Heavy")) mass = 1.0;

        int baseHalfWidth = cast(int)(15 + mass * 30);
        
        double theta = cp.getTheta();
        double cosT = cos(theta);
        double sinT = sin(theta);
        
        // Scale visual height slightly
        double visualHeight = poleLength * 1.5;
        
        SDL_Point[4] points = [
            { cartX + cartWidth / 2, cartY },
            { cast(int)(cartX + cartWidth / 2 + (-baseHalfWidth * cosT - (-visualHeight) * sinT)),
              cast(int)(cartY + (-baseHalfWidth * sinT + (-visualHeight) * cosT)) },
            { cast(int)(cartX + cartWidth / 2 + (baseHalfWidth * cosT - (-visualHeight) * sinT)),
              cast(int)(cartY + (baseHalfWidth * sinT + (-visualHeight) * cosT)) },
            { cartX + cartWidth / 2, cartY }
        ];
        SDL_RenderDrawLines(renderer, points.ptr, 4);
    } else if (cp.getShapeName().canFind("Star")) {
        SDL_SetRenderDrawColor(renderer, 255, 215, 0, 255); // Gold
        auto star = cast(CartStar)cp;
        int pointsCount = star ? star.getPoints() : 5;
        double outerRadius = poleLength;
        double innerRadius = poleLength * 0.4;
        
        double theta = cp.getTheta();
        double angleOffset = theta - PI / 2.0;
        
        // One point should be at the balance point (cartX + cartWidth / 2, cartY)
        // Center of the star
        double centerX = cartX + cartWidth / 2 + sin(theta) * outerRadius;
        double centerY = cartY - cos(theta) * outerRadius;
        
        SDL_Point[] starPoints;
        starPoints.length = pointsCount * 2 + 1;
        
        for (int i = 0; i < 2 * pointsCount; i++) {
            double radius = (i % 2 == 0) ? outerRadius : innerRadius;
            double angle = angleOffset + (i * PI / pointsCount);
            starPoints[i] = SDL_Point(cast(int)(centerX + radius * cos(angle)), 
                                      cast(int)(centerY + radius * sin(angle)));
        }
        starPoints[pointsCount * 2] = starPoints[0];
        SDL_RenderDrawLines(renderer, starPoints.ptr, cast(int)starPoints.length);
    } else {
        SDL_SetRenderDrawColor(renderer, 250, 100, 100, 255);
    }

    if (!cp.getShapeName().canFind("Triangle")) {
        for (int i = -2; i <= 2; i++) {
            SDL_RenderDrawLine(renderer, cartX + cartWidth / 2 + i, cartY, poleEndX + i, poleEndY);
        }
    }

    // Draw Topology below
    drawTopology(renderer, net, currentInputs);

    SDL_RenderPresent(renderer);
}

struct SimResult {
    bool quit;
    int selection;
}

SimResult displaySDLSelf(EvolvableNetwork net, SDL_Renderer* renderer, string[] shapes, int initialSelection, int maxSteps = 500) {
    int selection = initialSelection;
    string currentShape = shapes[selection];
    IBalanceable cp;
    auto createCP = (string type) {
        switch (type) {
            case "Long Pole": return cast(IBalanceable)new CartLongPole();
            case "Weighted Pole": return cast(IBalanceable)new CartWeightedPole();
            case "Short Heavy Pole": return cast(IBalanceable)new CartShortHeavyPole();
            case "Standard Triangle": return cast(IBalanceable)new CartTriangle();
            case "Small Triangle": return cast(IBalanceable)new CartSmallTriangle();
            case "Large Triangle": return cast(IBalanceable)new CartLargeTriangle();
            case "Heavy Triangle": return cast(IBalanceable)new CartHeavyTriangle();
            default: 
                if (type.canFind("Star")) {
                    import std.string;
                    int p = 5;
                    auto parts = type.split("-");
                    if (parts.length > 0) p = parts[0].to!int;
                    return cast(IBalanceable)new CartStar(p);
                }
                return cast(IBalanceable)new CartPole();
        }
    };
    cp = createCP(currentShape);
    
    int steps = 0;
    SDL_Event e;
    bool quit = false;

    while (!cp.isGameOver() && steps < maxSteps && !quit) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit = true;
            if (e.type == SDL_KEYDOWN) {
                bool changed = false;
                switch (e.key.keysym.sym) {
                    case SDLK_0: selection = 0; changed = true; break;
                    case SDLK_1: selection = 1; changed = true; break;
                    case SDLK_2: selection = 2; changed = true; break;
                    case SDLK_3: selection = 3; changed = true; break;
                    case SDLK_4: selection = 4; changed = true; break;
                    case SDLK_5: selection = 5; changed = true; break;
                    case SDLK_6: selection = 6; changed = true; break;
                    case SDLK_7: selection = 7; changed = true; break;
                    case SDLK_8: selection = 8; changed = true; break;
                    case SDLK_9: selection = 9; changed = true; break;
                    case SDLK_a: selection = 10; changed = true; break;
                    case SDLK_b: selection = 11; changed = true; break;
                    case SDLK_c: selection = 12; changed = true; break;
                    case SDLK_d: selection = 13; changed = true; break;
                    case SDLK_e: selection = 14; changed = true; break;
                    case SDLK_f: selection = 15; changed = true; break;
                    case SDLK_g: selection = 16; changed = true; break;
                    case SDLK_ESCAPE: quit = true; break;
                    default: break;
                }
                if (changed) {
                    currentShape = shapes[selection];
                    cp = createCP(currentShape);
                    steps = 0; // Reset steps for new shape
                    writeln("Switched to shape during visualization: ", currentShape);
                }
            }
        }

        double[] input = cp.getInputs();
        double[] output = net.feedForward(input);
        
        drawSimulation(renderer, cp, net, input);
        
        if (steps == 0) {
            net.displayTopology();
        }

        double force = (output[0] > 0.5) ? 10.0 : -10.0;
        cp.update(force);
        steps++;

        SDL_Delay(20); // ~50 FPS
    }
    return SimResult(quit, selection);
}

void main() {
    // Initialize SDL2
    SDLSupport ret = loadSDL();
    if (ret != sdlSupport) {
        if (ret == SDLSupport.noLibrary) {
            writeln("The SDL2 shared library failed to load.");
        } else if (ret == SDLSupport.badLibrary) {
            writeln("The version of the SDL2 shared library is incompatible.");
        }
        return;
    }

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        writefln("SDL could not initialize! SDL_Error: %s", to!string(SDL_GetError()));
        return;
    }
    scope(exit) SDL_Quit();

    SDL_Window* window = SDL_CreateWindow("Cart-Pole NeuroEvolution", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_SHOWN);
    if (window == null) {
        writefln("Window could not be created! SDL_Error: %s", to!string(SDL_GetError()));
        return;
    }
    scope(exit) SDL_DestroyWindow(window);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        writefln("Renderer could not be created! SDL_Error: %s", to!string(SDL_GetError()));
        return;
    }
    scope(exit) SDL_DestroyRenderer(renderer);

    int[] initialTopology = [4, 1, 1];
    auto pop = new Population(50, initialTopology);
    
    string[] shapes = [
        "Standard Pole", "Long Pole", "Weighted Pole", "Short Heavy Pole", 
        "Standard Triangle", "Small Triangle", "Large Triangle", "Heavy Triangle",
        "2-Pointed Star", "3-Pointed Star", "4-Pointed Star", "5-Pointed Star",
        "6-Pointed Star", "7-Pointed Star", "8-Pointed Star", "9-Pointed Star",
        "10-Pointed Star"
    ];
    writeln("Select a shape to balance (0-9, a-g):");
    foreach (i, s; shapes) {
        if (i < 10) writef("%d: %s\n", i, s);
        else writef("%c: %s\n", cast(char)('a' + (i - 10)), s);
    }
    
    int selection = 0;
    
    writeln("Starting NeuroEvolution for Cart-Pole with SDL Visualization...");
    writeln("Press 0-9, a-g on your keyboard to change shape during evolution.");
    
    string currentShape = shapes[selection];
    bool quit = false;
    bool priorityTopology = true;
    for (int gen = 0; gen < 200 && !quit; gen++) {
        foreach (net; pop.networks) {
            net.fitness = evaluateFitness(net, currentShape);
        }
        
        auto best = pop.networks.maxElement!(n => n.fitness);
        
        writefln("Gen %d: Best Steps = %.0f [Shape: %s]", gen, best.fitness, currentShape);
        
        if (gen % 5 == 0 || best.fitness >= 500) {
            auto result = displaySDLSelf(best, renderer, shapes, selection, 500);
            quit = result.quit;
            if (selection != result.selection) {
                selection = result.selection;
                currentShape = shapes[selection];
                writeln("Shape updated in evolution loop to: ", currentShape);
            }
        }
        
        if (!quit && best.fitness >= 500 && gen > 10) {
             writefln("Problem solved for %s at generation %d!", currentShape, gen);
             break;
        }

        // Check for key presses to change shape (very simple)
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit = true;
            if (e.type == SDL_KEYDOWN) {
                switch (e.key.keysym.sym) {
                    case SDLK_0: selection = 0; break;
                    case SDLK_1: selection = 1; break;
                    case SDLK_2: selection = 2; break;
                    case SDLK_3: selection = 3; break;
                    case SDLK_4: selection = 4; break;
                    case SDLK_5: selection = 5; break;
                    case SDLK_6: selection = 6; break;
                    case SDLK_7: selection = 7; break;
                    case SDLK_p: 
                        priorityTopology = !priorityTopology;
                        writefln("Priority Topology: %s", priorityTopology);
                        break;
                    case SDLK_ESCAPE: quit = true; break;
                    default: break;
                }
                currentShape = shapes[selection];
                writeln("Switched to shape: ", currentShape);
            }
        }
        
        pop.evolve(0.1, 0.2, 0.05, priorityTopology);
    }

    writeln("Evolution Complete.");
}
