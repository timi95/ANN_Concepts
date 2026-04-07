const PI = Math.PI;

class CartPole {
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

    mutate(rate, scale) {
        this.layers.forEach(l => l.mutate(rate, scale));
    }

    clone() {
        let net = new EvolvableNetwork(this.topology);
        net.layers = this.layers.map(l => l.clone());
        net.fitness = 0;
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

    evolve(survivalRate, mutationRate, mutationScale) {
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
            offspring.mutate(mutationRate, mutationScale);
            nextGen.push(offspring);
        }

        this.networks = nextGen;
    }
}

// Global State
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const statusElement = document.getElementById('status');
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
canvas.width = WINDOW_WIDTH;
canvas.height = WINDOW_HEIGHT;

let topology = [4, 1, 1];
let population = new Population(50, topology);
let currentShape = 'standard';
let cartPole = new CartPole(currentShape);
let bestNetwork = population.networks[0].clone();
let generation = 0;
let isSolving = true;
let isPaused = false;

function changeShape(type) {
    currentShape = type;
    cartPole.setShape(type);
    
    // Reset buttons
    document.querySelectorAll('.button-group button').forEach(btn => btn.classList.remove('active'));
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

function drawSimulation(cp, net) {
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
        
        // Vertices relative to the balance point (poleX1, poleY1)
        // 1. Balance point: (poleX1, poleY1)
        // 2. Top-left vertex: rotated from (0, -triangleHeight) offset by (-triangleWidth/2, 0)
        // 3. Top-right vertex: rotated from (0, -triangleHeight) offset by (triangleWidth/2, 0)
        
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
    drawTopology(net, 50, 50, 200, 150);

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
    for (let l = 0; l < layers.length; l++) {
        let size = layers[l];
        for (let i = 0; i < size; i++) {
            ctx.fillStyle = 'white';
            ctx.strokeStyle = 'black';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(x + l * layerXStep, y + (i + 0.5) * (height / size), 8, 0, PI * 2);
            ctx.fill();
            ctx.stroke();
            
            // If it's an output/hidden layer, show activation
            if (l > 0) {
                let activation = net.layers[l-1].neurons[i].output;
                ctx.fillStyle = `rgba(0, 255, 0, ${activation})`;
                ctx.beginPath();
                ctx.arc(x + l * layerXStep, y + (i + 0.5) * (height / size), 6, 0, PI * 2);
                ctx.fill();
            }
        }
    }
}

function mainLoop() {
    if (isPaused) {
        requestAnimationFrame(mainLoop);
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
        statusElement.innerText = `Generation ${generation}, Best Fitness: ${bestNetwork.fitness}`;

        if (bestNetwork.fitness >= 500) {
            isSolving = false;
        } else {
            population.evolve(0.1, 0.2, 0.05);
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
    requestAnimationFrame(mainLoop);
}

mainLoop();
