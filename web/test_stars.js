const fs = require('fs');
const path = require('path');

// Mock browser environment
const scriptPath = path.resolve(__dirname, 'script.js');
const scriptContent = fs.readFileSync(scriptPath, 'utf8');

// Use vm to run script and extract classes
const vm = require('vm');
const context = vm.createContext({
    console: console,
    Math: Math,
    document: {
        getElementById: () => null
    },
    window: {
        setInterval: () => {}
    },
    setInterval: () => {},
    Image: class {}
});

vm.runInContext(scriptContent, context);

function testStarShapes() {
    console.log("Running Star Shape tests...");
    const CartPole = context.CartPole;
    if (!CartPole) {
        console.log("Keys in context:", Object.keys(context));
        console.error("CartPole is not defined in context");
        process.exit(1);
    }
    const cp = new CartPole('star5');
    
    // Test 5-pointed star properties
    console.assert(cp.shapeType === 'star', "Shape type should be 'star'");
    console.assert(cp.starPoints === 5, "Star points should be 5");
    console.assert(cp.shapeName === "5-Pointed Star", "Shape name should be '5-Pointed Star'");
    
    // Test other stars
    for (let i = 2; i <= 10; i++) {
        cp.setShape('star' + i);
        console.assert(cp.starPoints === i, `Star points should be ${i} for star${i}`);
        console.assert(cp.shapeName === `${i}-Pointed Star`, `Shape name should be '${i}-Pointed Star' for star${i}`);
        
        // Check scaling
        const expectedMass = (0.1 + (i * 0.05)).toFixed(2);
        const expectedLength = (0.4 + (i * 0.02)).toFixed(2);
        console.assert(cp.mass_pole.toFixed(2) === expectedMass, `Mass for ${i}-star should be ${expectedMass}, got ${cp.mass_pole.toFixed(2)}`);
        console.assert(cp.length.toFixed(2) === expectedLength, `Length for ${i}-star should be ${expectedLength}, got ${cp.length.toFixed(2)}`);
    }
    
    console.log("Star Shape tests passed!");
}

testStarShapes();
