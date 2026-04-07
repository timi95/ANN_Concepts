const fs = require('fs');
const path = require('path');

// Mock DOM environment
global.Math = Math;
global.Float64Array = Float64Array;
global.document = {
    getElementById: (id) => {
        if (id === 'canvas') return { getContext: () => ({ fillRect: () => {}, fillStyle: '', stroke: () => {}, beginPath: () => {}, moveTo: () => {}, lineTo: () => {}, fillText: () => {}, font: '', strokeStyle: '', lineWidth: 0, arc: () => {}, fill: () => {} }), width: 800, height: 600 };
        if (id === 'status') return { innerText: '' };
        if (id.endsWith('-btn')) return { id: id, classList: { add: () => {}, remove: () => {} } };
        return null;
    },
    querySelectorAll: () => [
        { id: 'standard-btn', classList: { add: () => {}, remove: () => {} } },
        { id: 'long-btn', classList: { add: () => {}, remove: () => {} } },
        { id: 'weighted-btn', classList: { add: () => {}, remove: () => {} } },
        { id: 'shortheavy-btn', classList: { add: () => {}, remove: () => {} } },
        { id: 'triangle-btn', classList: { add: () => {}, remove: () => {} } }
    ]
};

// Handle window and requestAnimationFrame
global.window = {};
global.requestAnimationFrame = () => {};

// Load script.js and execute it in this context
const scriptPath = path.join(__dirname, 'script.js');
const scriptContent = fs.readFileSync(scriptPath, 'utf8');

// For this test, we need the classes and functions defined in script.js
// Injecting them into global scope because script.js defines them at top level
const scriptLines = scriptContent.split('\n');
const scriptWithGlobal = scriptLines.map(line => {
    if (line.startsWith('let ') || line.startsWith('const ') || line.startsWith('var ')) {
        // If it's a top-level declaration, attach it to global
        // This is a simple hack for testing
        return 'global.' + line.substring(line.indexOf(' ') + 1);
    }
    return line;
}).join('\n');

eval(scriptWithGlobal);

function assert(condition, message) {
    if (!condition) {
        console.error('FAILED:', message);
        process.exit(1);
    } else {
        console.log('PASSED:', message);
    }
}

console.log('Running Shape Change Tests...');

// Verify that the global variables from script.js are accessible
if (typeof cartPole === 'undefined') {
    console.error('FAILED: cartPole is not defined after eval');
    process.exit(1);
}

// Test 1: Initial state
assert(cartPole.shapeType === 'standard', 'Initial shape should be standard');
assert(cartPole.mass_pole === 0.1, 'Initial mass_pole should be 0.1');
assert(cartPole.length === 0.5, 'Initial length should be 0.5');

// Test 2: Change to Long Pole
changeShape('long');
assert(cartPole.shapeType === 'long', 'Shape should be long');
assert(cartPole.mass_pole === 0.1, 'Long pole mass should be 0.1');
assert(cartPole.length === 1.0, 'Long pole length should be 1.0');
assert(generation === 0, 'Generation should be reset to 0 after shape change');

// Test 3: Change to Weighted Pole
changeShape('weighted');
assert(cartPole.shapeType === 'weighted', 'Shape should be weighted');
assert(cartPole.mass_pole === 0.5, 'Weighted pole mass should be 0.5');
assert(cartPole.length === 0.5, 'Weighted pole length should be 0.5');

// Test 4: Change to Short Heavy Pole
changeShape('shortheavy');
assert(cartPole.shapeType === 'shortheavy', 'Shape should be shortheavy');
assert(cartPole.mass_pole === 1.0, 'Short heavy pole mass should be 1.0');
assert(cartPole.length === 0.2, 'Short heavy pole length should be 0.2');

// Test 5: Change to Triangle
changeShape('triangle');
assert(cartPole.shapeType === 'triangle', 'Shape should be triangle');
assert(cartPole.mass_pole === 0.3, 'Triangle mass should be 0.3');
assert(cartPole.length === 0.6, 'Triangle length should be 0.6');

// Test 6: Change back to Standard
changeShape('standard');
assert(cartPole.shapeType === 'standard', 'Should change back to standard');
assert(cartPole.mass_pole === 0.1, 'Standard pole mass should be 0.1');
assert(cartPole.length === 0.5, 'Standard pole length should be 0.5');

console.log('\nAll Shape Change Tests Passed Successfully!');
