const fs = require('fs');
const path = require('path');

// Load script content and replace 'class' with 'var' or attach to global
const scriptPath = path.resolve(__dirname, 'script.js');
let scriptContent = fs.readFileSync(scriptPath, 'utf8');

// Global mocks
global.document = { 
    getElementById: () => ({ 
        getContext: () => ({ 
            fillRect: () => {}, 
            fillText: () => {},
            beginPath: () => {},
            moveTo: () => {},
            lineTo: () => {},
            stroke: () => {},
            arc: () => {},
            fill: () => {},
            closePath: () => {}
        }), 
        classList: { add: () => {}, remove: () => {} },
        innerText: ""
    }), 
    querySelectorAll: () => [] 
};
global.window = { innerWidth: 800, innerHeight: 600 };
global.requestAnimationFrame = () => {};

// Replace class definitions to make them global
scriptContent = scriptContent.replace(/class EvolvableNeuron/g, "global.EvolvableNeuron = class EvolvableNeuron");
scriptContent = scriptContent.replace(/class EvolvableLayer/g, "global.EvolvableLayer = class EvolvableLayer");
scriptContent = scriptContent.replace(/class EvolvableNetwork/g, "global.EvolvableNetwork = class EvolvableNetwork");

eval(scriptContent);

console.log("Running Dynamic Node Mutation Tests...");

function testTopologyChange() {
    const topo = [4, 1, 1];
    const net = new EvolvableNetwork(topo);
    
    console.log("Initial topology hidden layer size:", net.layers[0].neurons.length);
    console.log("Initial output layer input count:", net.layers[1].neurons[0].weights.length);
    
    if (net.layers[0].neurons.length !== 1) throw new Error("Initial hidden size should be 1");
    if (net.layers[1].neurons[0].weights.length !== 1) throw new Error("Initial output input count should be 1");

    // Test mutate with priorityTopology
    let changed = false;
    for (let i = 0; i < 2000; i++) {
        net.mutate(0.2, 0.05, true);
        if (net.layers[0].neurons.length !== 1) {
            changed = true;
            break;
        }
    }
    
    if (!changed) throw new Error("Topology did not change after 2000 mutations with priority=true");
    console.log("Success: Topology mutation confirmed. New hidden size:", net.layers[0].neurons.length);
    
    // Verify that the next layer's weights match the current layer's neuron count
    const hiddenCount = net.layers[0].neurons.length;
    const outputInputCount = net.layers[1].neurons[0].weights.length;
    
    console.log("New hidden size:", hiddenCount);
    console.log("New output input count:", outputInputCount);
    
    if (hiddenCount !== outputInputCount) {
        throw new Error(`Inconsistent topology: Layer 0 has ${hiddenCount} neurons but Layer 1 expects ${outputInputCount} inputs`);
    }

    console.log("✅ All dynamic node tests passed!");
}

try {
    testTopologyChange();
} catch (e) {
    console.error("❌ Test failed:", e.message);
    process.exit(1);
}
