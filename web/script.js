const PI = Math.PI;

var CartPole = class {
    constructor(type = 'standard') {
        this.gravity = 9.8;
        this.mass_cart = 1.0;
        this.force_mag = 10.0;
        this.tau = 0.02; // Seconds between state updates
        this.x_threshold = 2.4;
        this.theta_threshold_radians = 12 * PI / 180;
        this.initial_theta_range = 0.05; // Default random angle range
        this.setShape(type);
        this.reset();
    }

    setShape(type) {
        this.shapeType = type;
        this.initial_theta_range = 0.05; // Reset to default
        switch (type) {
            case 'long':
                this.mass_pole = 0.1;
                this.length = 1.0;
                this.shapeName = "Long Pole";
                break;
            case 'weighted':
                this.mass_pole = 0.5;
                this.length = 0.5;
                this.shapeName = "Weighted Pole";
                break;
            case 'shortheavy':
                this.mass_pole = 1.0;
                this.length = 0.2;
                this.shapeName = "Short Heavy Pole";
                break;
            case 'triangle':
                this.mass_pole = 0.3;
                this.length = 0.6; // Higher COM
                this.shapeName = "Standard Triangle";
                break;
            case 'small_triangle':
                this.mass_pole = 0.1;
                this.length = 0.3;
                this.shapeName = "Small Triangle";
                break;
            case 'large_triangle':
                this.mass_pole = 0.5;
                this.length = 1.0;
                this.shapeName = "Large Triangle";
                break;
            case 'heavy_triangle':
                this.mass_pole = 1.0;
                this.length = 0.6;
                this.shapeName = "Heavy Triangle";
                break;
            case 'tilted_triangle':
                this.mass_pole = 0.3;
                this.length = 0.6;
                this.initial_theta_range = 0.15; // Greater initial variation
                this.shapeName = "Tilted Triangle";
                break;
            case 'standard':
            default:
                this.mass_pole = 0.1;
                this.length = 0.5;
                this.shapeName = "Standard Pole";
                break;
        }

        // Star shapes 2-10
        if (type.startsWith('star')) {
            let points = parseInt(type.substring(4));
            if (!isNaN(points) && points >= 2 && points <= 10) {
                this.mass_pole = 0.1 + (points * 0.05); // Mass scales with points
                this.length = 0.4 + (points * 0.02); // Length scales slightly
                this.shapeName = points + "-Pointed Star";
                this.shapeType = 'star';
                this.starPoints = points;
            }
        }
    }

    reset() {
        this.x = 0.0;
        this.x_dot = 0.0;
        this.theta = (Math.random() * 2 - 1) * this.initial_theta_range;
        this.theta_dot = 0.0;
    }

    update(force) {
        let total_mass = this.mass_cart + this.mass_pole;
        let polemass_length = this.mass_pole * this.length;
        let costheta = Math.cos(this.theta);
        let sintheta = Math.sin(this.theta);

        let temp = (force + polemass_length * this.theta_dot * this.theta_dot * sintheta) / total_mass;
        let thetaacc = (this.gravity * sintheta - costheta * temp) / (this.length * (4.0 / 3.0 - this.mass_pole * costheta * costheta / total_mass));
        let xacc = temp - polemass_length * thetaacc * costheta / total_mass;

        this.x = this.x + this.tau * this.x_dot;
        this.x_dot = this.x_dot + this.tau * xacc;
        this.theta = this.theta + this.tau * this.theta_dot;
        this.theta_dot = this.theta_dot + this.tau * thetaacc;

        return !this.isGameOver();
    }

    isGameOver() {
        return (this.x < -this.x_threshold || this.x > this.x_threshold || 
                this.theta < -this.theta_threshold_radians || this.theta > this.theta_threshold_radians);
    }

    getInputs() {
        return [
            this.x / this.x_threshold,
            this.x_dot / 2.0,
            this.theta / this.theta_threshold_radians,
            this.theta_dot / 2.0
        ];
    }
}

class EvolvableNeuron {
    constructor(inputCount) {
        this.weights = new Float64Array(inputCount);
        for (let i = 0; i < inputCount; i++) {
            this.weights[i] = Math.random() * 2 - 1;
        }
        this.bias = Math.random() * 2 - 1;
        this.output = 0;
    }

    static activate(x) {
        return 1.0 / (1.0 + Math.exp(-x));
    }

    feedForward(inputs) {
        let sum = this.bias;
        for (let i = 0; i < inputs.length; i++) {
            sum += inputs[i] * this.weights[i];
        }
        this.output = EvolvableNeuron.activate(sum);
        return this.output;
    }

    mutate(rate, scale) {
        for (let i = 0; i < this.weights.length; i++) {
            if (Math.random() < rate) {
                this.weights[i] += (Math.random() * 2 - 1) * scale;
            }
        }
        if (Math.random() < rate) {
            this.bias += (Math.random() * 2 - 1) * scale;
        }
    }

    addInput() {
        let newWeights = new Float64Array(this.weights.length + 1);
        newWeights.set(this.weights);
        newWeights[this.weights.length] = Math.random() * 2 - 1;
        this.weights = newWeights;
    }

    removeInput(index) {
        if (this.weights.length <= 1) return;
        let newWeights = new Float64Array(this.weights.length - 1);
        for (let i = 0, j = 0; i < this.weights.length; i++) {
            if (i !== index) {
                newWeights[j++] = this.weights[i];
            }
        }
        this.weights = newWeights;
    }

    clone() {
        let n = new EvolvableNeuron(this.weights.length);
        n.weights.set(this.weights);
        n.bias = this.bias;
        return n;
    }
}

class EvolvableLayer {
    constructor(neuronCount, inputCount) {
        this.neurons = [];
        for (let i = 0; i < neuronCount; i++) {
            this.neurons.push(new EvolvableNeuron(inputCount));
        }
    }

    feedForward(inputs) {
        return this.neurons.map(n => n.feedForward(inputs));
    }

    mutate(rate, scale) {
        this.neurons.forEach(n => n.mutate(rate, scale));
    }

    addNeuron(inputCount) {
        this.neurons.push(new EvolvableNeuron(inputCount));
    }

    removeNeuron(index) {
        if (this.neurons.length <= 1) return;
        this.neurons.splice(index, 1);
    }

    clone() {
        let l = Object.create(EvolvableLayer.prototype);
        l.neurons = this.neurons.map(n => n.clone());
        return l;
    }
}

class EvolvableNetwork {
    constructor(topology) {
        this.layers = [];
        for (let i = 1; i < topology.length; i++) {
            this.layers.push(new EvolvableLayer(topology[i], topology[i - 1]));
        }
        this.fitness = 0;
        this.topology = topology;
    }

    feedForward(inputs) {
        let currentInputs = inputs;
        for (let layer of this.layers) {
            currentInputs = layer.feedForward(currentInputs);
        }
        return currentInputs;
    }

    mutate(rate, scale, priorityTopology = false) {
        let topologyMutated = false;
        
        if (priorityTopology && Math.random() < 0.2) {
            topologyMutated = true;
            // Physical topology mutation
            let layerIdx = Math.floor(Math.random() * this.layers.length);
            let layer = this.layers[layerIdx];
            
            if (Math.random() < 0.5) {
                // Add neuron to hidden layer
                let inputCount = (layerIdx === 0) ? this.topology[0] : this.layers[layerIdx - 1].neurons.length;
                layer.addNeuron(inputCount);
                
                // If there's a next layer, we must add an input to all its neurons
                if (layerIdx + 1 < this.layers.length) {
                    this.layers[layerIdx + 1].neurons.forEach(n => n.addInput());
                }
            } else {
                // Remove neuron
                if (layer.neurons.length > 1) {
                    let neuronIdx = Math.floor(Math.random() * layer.neurons.length);
                    layer.removeNeuron(neuronIdx);
                    
                    // If there's a next layer, we must remove an input from all its neurons
                    if (layerIdx + 1 < this.layers.length) {
                        this.layers[layerIdx + 1].neurons.forEach(n => n.removeInput(neuronIdx));
                    }
                }
            }
        }

        if (!topologyMutated || !priorityTopology) {
            this.layers.forEach(l => l.mutate(rate, scale));
        }
    }

    clone() {
        let net = new EvolvableNetwork(this.topology);
        net.layers = this.layers.map(l => l.clone());
        net.fitness = this.fitness;
        return net;
    }
}

class Population {
    constructor(size, topology) {
        this.size = size;
        this.topology = topology;
        this.networks = [];
        for (let i = 0; i < size; i++) {
            this.networks.push(new EvolvableNetwork(topology));
        }
    }

    evolve(survivalRate, mutationRate, mutationScale, priorityTopology = false) {
        this.networks.sort((a, b) => b.fitness - a.fitness);

        let survivorsCount = Math.max(1, Math.floor(this.size * survivalRate));
        let survivors = this.networks.slice(0, survivorsCount);

        let nextGen = [];
        // Keep survivors
        for (let s of survivors) {
            nextGen.push(s.clone());
        }

        // Fill rest
        while (nextGen.length < this.size) {
            let parent = survivors[Math.floor(Math.random() * survivors.length)];
            let offspring = parent.clone();
            offspring.mutate(mutationRate, mutationScale, priorityTopology);
            nextGen.push(offspring);
        }

        this.networks = nextGen;
    }
}

// Global State
let canvas, ctx, statusElement;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;

if (typeof document !== 'undefined') {
    canvas = document.getElementById('canvas');
    if (canvas && canvas.getContext) {
        ctx = canvas.getContext('2d');
        canvas.width = WINDOW_WIDTH;
        canvas.height = WINDOW_HEIGHT;
    }
    statusElement = document.getElementById('status');
}

let topology = [4, 1, 1];
let population = new Population(50, topology);
let currentShape = 'standard';
let cartPole = new CartPole(currentShape);
let bestNetwork = population.networks[0].clone();
let generation = 0;
let isSolving = true;
let isPaused = false;
let prioritizeTopology = true;

function changeShape(type) {
    currentShape = type;
    cartPole.setShape(type);
    
    // Reset buttons
    document.querySelectorAll('#shape-group button').forEach(btn => btn.classList.remove('active'));
    let btnId = `${type.replace(/_/g, '')}-btn`;
    let btn = document.getElementById(btnId);
    if (btn) btn.classList.add('active');
    
    // Reset evolution for the new shape
    generation = 0;
    isSolving = true;
    population = new Population(50, topology);
    bestNetwork = population.networks[0].clone();
    bestNetwork.fitness = 0;
    
    statusElement.innerText = `Switched to ${cartPole.shapeName}. Resetting evolution...`;
}

function togglePause() {
    isPaused = !isPaused;
    let btn = document.getElementById('pause-btn');
    if (btn) {
        btn.innerText = isPaused ? "Resume" : "Pause";
        if (isPaused) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    }
}

function togglePriority() {
    prioritizeTopology = !prioritizeTopology;
    let btn = document.getElementById('priority-btn');
    if (btn) {
        btn.innerText = prioritizeTopology ? "Prioritize: Topology" : "Prioritize: Weights";
        if (prioritizeTopology) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    }
}

function drawSimulation(cp, net) {
    if (!ctx) return;
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

    // Draw Cart
    let cartW = 80;
    let cartH = 40;
    let cartX = (WINDOW_WIDTH / 2 + (cp.x / 2.4) * (WINDOW_WIDTH / 2) - cartW / 2);
    let cartY = 400;

    ctx.fillStyle = '#646464';
    ctx.fillRect(cartX, cartY, cartW, cartH);

    // Draw Pole
    let poleX1 = cartX + cartW / 2;
    let poleY1 = cartY;
    let poleLen = cp.length * 200;
    let poleX2 = poleX1 + poleLen * Math.sin(cp.theta);
    let poleY2 = poleY1 - poleLen * Math.cos(cp.theta);

    if (cp.shapeType.includes('triangle')) {
        // Draw Triangle balancing on its point
        let triangleWidth = 40 + cp.mass_pole * 60; // Base width scales with mass
        let triangleHeight = poleLen * 1.5; // Scale height slightly for visualization
        
        let cosT = Math.cos(cp.theta);
        let sinT = Math.sin(cp.theta);
        
        let dxLeft = -triangleWidth / 2;
        let dyTop = -triangleHeight;
        let dxRight = triangleWidth / 2;
        
        let x2 = poleX1 + (dxLeft * cosT - dyTop * sinT);
        let y2 = poleY1 + (dxLeft * sinT + dyTop * cosT);
        let x3 = poleX1 + (dxRight * cosT - dyTop * sinT);
        let y3 = poleY1 + (dxRight * sinT + dyTop * cosT);

        ctx.fillStyle = 'rgba(200, 50, 50, 0.7)';
        ctx.strokeStyle = '#C83232';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(poleX1, poleY1);
        ctx.lineTo(x2, y2);
        ctx.lineTo(x3, y3);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
    } else if (cp.shapeType === 'star') {
        // Draw Star balancing on one of its points
        let points = cp.starPoints;
        let outerRadius = poleLen;
        let innerRadius = poleLen * 0.4;
        
        ctx.fillStyle = 'rgba(255, 215, 0, 0.8)'; // Golden star
        ctx.strokeStyle = '#DAA520';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        // We want one point to be at the balance point (poleX1, poleY1)
        // So we offset the center of the star
        let centerX = poleX1 + outerRadius * Math.sin(cp.theta);
        let centerY = poleY1 - outerRadius * Math.cos(cp.theta);
        
        // The angle needs to be adjusted so one point is at (poleX1, poleY1)
        // Offset angle to make the first point at the bottom (relative to rotation)
        let angleOffset = cp.theta + Math.PI / 2; 
        
        for (let i = 0; i < 2 * points; i++) {
            let radius = (i % 2 === 0) ? outerRadius : innerRadius;
            let angle = angleOffset + (i * Math.PI / points);
            let x = centerX + radius * Math.cos(angle);
            let y = centerY + radius * Math.sin(angle);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
    } else {
        ctx.strokeStyle = '#C83232';
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(poleX1, poleY1);
        ctx.lineTo(poleX2, poleY2);
        ctx.stroke();
    }

    // Draw Ground
    ctx.strokeStyle = 'black';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, cartY + cartH);
    ctx.lineTo(WINDOW_WIDTH, cartY + cartH);
    ctx.stroke();

    // Draw Topology
    drawTopology(net, WINDOW_WIDTH - 300, 50, 200, 150);

    // Info
    ctx.fillStyle = 'black';
    ctx.font = '16px sans-serif';
    ctx.fillText(`Generation: ${generation}`, 20, 30);
    ctx.fillText(`Best Fitness: ${bestNetwork.fitness.toFixed(0)}`, 20, 50);
    ctx.fillText(`Shape: ${cp.shapeName}`, 20, 70);
    if (!isSolving) {
        ctx.fillStyle = 'green';
        ctx.fillText("SOLVED!", 20, 90);
    }
}

function drawTopology(net, x, y, width, height) {
    let layers = [net.topology[0], ...net.layers.map(l => l.neurons.length)];
    let layerXStep = width / (layers.length - 1 || 1);
    
    // Draw layer labels
    ctx.fillStyle = 'black';
    ctx.font = 'bold 12px sans-serif';
    ctx.textAlign = 'center';
    for (let l = 0; l < layers.length; l++) {
        let label = "Hidden";
        if (l === 0) label = "Input";
        if (l === layers.length - 1) label = "Output";
        ctx.fillText(label, x + l * layerXStep, y - 10);
    }
    ctx.textAlign = 'left';

    // Draw connections
    for (let l = 0; l < net.layers.length; l++) {
        let currentLayer = net.layers[l];
        let prevLayerSize = layers[l];
        let nextLayerSize = layers[l+1];
        
        for (let i = 0; i < prevLayerSize; i++) {
            for (let j = 0; j < nextLayerSize; j++) {
                let weight = currentLayer.neurons[j].weights[i];
                ctx.strokeStyle = weight > 0 ? `rgba(0, 0, 255, ${Math.abs(weight)})` : `rgba(255, 0, 0, ${Math.abs(weight)})`;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(x + l * layerXStep, y + (i + 0.5) * (height / prevLayerSize));
                ctx.lineTo(x + (l + 1) * layerXStep, y + (j + 0.5) * (height / nextLayerSize));
                ctx.stroke();
            }
        }
    }

    // Draw neurons
    const inputLabels = ["x", "x'", "θ", "θ'"];
    for (let l = 0; l < layers.length; l++) {
        let size = layers[l];
        for (let i = 0; i < size; i++) {
            let nX = x + l * layerXStep;
            let nY = y + (i + 0.5) * (height / size);
            
            ctx.fillStyle = 'white';
            ctx.strokeStyle = 'black';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(nX, nY, 8, 0, PI * 2);
            ctx.fill();
            ctx.stroke();
            
            // If it's an output/hidden layer, show activation
            let activation = 0;
            if (l > 0) {
                activation = net.layers[l-1].neurons[i].output;
                ctx.fillStyle = `rgba(0, 255, 0, ${activation})`;
                ctx.beginPath();
                ctx.arc(nX, nY, 6, 0, PI * 2);
                ctx.fill();
            }

            // Neuron Labels & Values
            ctx.fillStyle = 'black';
            ctx.font = '10px sans-serif';
            if (l === 0) {
                // Input Labels (left of neurons)
                ctx.textAlign = 'right';
                ctx.fillText(inputLabels[i] || `i${i}`, nX - 12, nY + 4);
            } else if (l === layers.length - 1) {
                // Output Labels (right of neurons)
                ctx.textAlign = 'left';
                let action = activation > 0.5 ? "Right" : "Left";
                ctx.fillText(`${activation.toFixed(2)} (${action})`, nX + 12, nY + 4);
            } else {
                // Hidden values (right/bottom of neurons)
                ctx.textAlign = 'left';
                ctx.fillText(activation.toFixed(2), nX + 10, nY + 4);
            }
        }
    }
}

function mainLoop() {
    if (isPaused) {
        if (typeof window !== 'undefined' && window.requestAnimationFrame) {
            window.requestAnimationFrame(mainLoop);
        }
        return;
    }

    if (isSolving) {
        for (let net of population.networks) {
            let sim = new CartPole(currentShape);
            let fitness = 0;
            for (let i = 0; i < 500; i++) {
                let inputs = sim.getInputs();
                let output = net.feedForward(inputs);
                let force = (output[0] > 0.5) ? 10.0 : -10.0;
                if (!sim.update(force)) break;
                fitness++;
            }
            net.fitness = fitness;
        }

        // Find best
        let best = population.networks.reduce((prev, curr) => (curr.fitness > prev.fitness) ? curr : prev);
        if (best.fitness > bestNetwork.fitness) {
            bestNetwork = best.clone();
            bestNetwork.fitness = best.fitness;
        }

        generation++;
        if (statusElement) {
            statusElement.innerText = `Generation ${generation}, Best Fitness: ${bestNetwork.fitness}`;
        }

        if (bestNetwork.fitness >= 500) {
            isSolving = false;
        } else {
            population.evolve(0.1, 0.2, 0.05, prioritizeTopology);
        }
        
        cartPole.reset();
    }

    // Run best network simulation
    let inputs = cartPole.getInputs();
    let output = bestNetwork.feedForward(inputs);
    let force = (output[0] > 0.5) ? 10.0 : -10.0;
    cartPole.update(force);
    if (cartPole.isGameOver()) cartPole.reset();

    drawSimulation(cartPole, bestNetwork);
    if (typeof requestAnimationFrame !== 'undefined') {
        requestAnimationFrame(mainLoop);
    }
}

if (typeof requestAnimationFrame !== 'undefined') {
    mainLoop();
}
