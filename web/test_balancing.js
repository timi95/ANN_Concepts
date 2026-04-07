const fs = require('fs');
const path = require('path');

// Mock browser environment
global.Math = Math;
global.document = {
    getElementById: (id) => ({
        getContext: (type) => ({
            fillRect: () => {},
            strokeRect: () => {},
            fillText: () => {},
            beginPath: () => {},
            moveTo: () => {},
            lineTo: () => {},
            stroke: () => {},
            fill: () => {},
            closePath: () => {},
            arc: () => {},
            measureText: () => ({ width: 0 }),
        }),
        classList: { add: () => {}, remove: () => {} },
        style: {}
    }),
    querySelectorAll: () => []
};
global.window = {
    requestAnimationFrame: () => {}
};
global.requestAnimationFrame = () => {};
global.setInterval = () => {};
global.WINDOW_WIDTH = 800;
global.WINDOW_HEIGHT = 600;

// Load script.js content
const scriptPath = path.resolve(__dirname, 'script.js');
const scriptContent = fs.readFileSync(scriptPath, 'utf8');

// Extract classes from script.js to avoid top-level side effects
const classesOnly = scriptContent.split('// Global State')[0];
// Replace "class X" with "global.X = class X"
const classesExported = classesOnly.replace(/class (\w+)/g, 'global.$1 = class $1');
eval(classesExported);

function assert(condition, message) {
    if (!condition) {
        throw new Error('Assertion failed: ' + (message || 'unspecified'));
    }
}

console.log('Running Cart-Pole Balancing logic tests...');

// Test 1: Gravity check
(function testGravity() {
    console.log('Test: Gravity - pole should fall when tilted and no force applied');
    const cp = new CartPole('standard');
    cp.theta = 0.05; // Tilted to the right
    cp.theta_dot = 0.0;
    
    // Run for a few steps
    for (let i = 0; i < 10; i++) {
        cp.update(0); // No force
    }
    
    assert(cp.theta > 0.05, 'Pole should tilt further to the right under gravity');
    console.log('  Passed: Pole falls under gravity');
})();

// Test 2: Balancing check (simple proportional controller)
(function testBalancing() {
    console.log('Test: Balancing - simple PD controller should keep pole upright longer than no control');
    
    const runSim = (controller) => {
        const cp = new CartPole('standard');
        cp.theta = 0.05;
        let steps = 0;
        while (!cp.isGameOver() && steps < 1000) {
            const force = controller(cp);
            cp.update(force);
            steps++;
        }
        return steps;
    };

    const noControl = () => 0;
    const pdControl = (cp) => {
        // Simple PD controller: force = Kp * theta + Kd * theta_dot
        const Kp = 100;
        const Kd = 20;
        return Kp * cp.theta + Kd * cp.theta_dot;
    };

    const stepsNoControl = runSim(noControl);
    const stepsPdControl = runSim(pdControl);

    console.log(`  Steps without control: ${stepsNoControl}`);
    console.log(`  Steps with PD control: ${stepsPdControl}`);

    assert(stepsPdControl > stepsNoControl, 'PD controller should perform better than no control');
    assert(stepsPdControl > 100, 'PD controller should survive for a reasonable amount of time');
    
    console.log('  Passed: PD controller improves balance');
})();

// Test 3: Limits check
(function testLimits() {
    console.log('Test: Limits - game should end when thresholds are exceeded');
    const cp = new CartPole('standard');
    
    cp.x = 2.5; // Exceeds x_threshold (2.4)
    assert(cp.isGameOver(), 'Game should be over when x exceeds threshold');
    
    cp.reset();
    cp.theta = 0.3; // Exceeds theta_threshold_radians (~0.21)
    assert(cp.isGameOver(), 'Game should be over when theta exceeds threshold');
    
    console.log('  Passed: Limits correctly detected');
})();

// Test 4: Force effect
(function testForceEffect() {
    console.log('Test: Force - applying positive force should accelerate cart to the right');
    const cp = new CartPole('standard');
    cp.theta = 0;
    cp.x = 0;
    cp.x_dot = 0;
    
    cp.update(10); // Positive force
    assert(cp.x_dot > 0, 'Cart should have positive velocity after positive force');
    
    console.log('  Passed: Force correctly affects cart physics');
})();

console.log('\nAll balancing tests passed successfully!');
