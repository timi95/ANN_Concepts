const fs = require('fs');
const path = require('path');

// Mock browser environment
global.document = {
    getElementById: (id) => ({
        innerText: '',
        classList: {
            add: () => {},
            remove: () => {}
        }
    }),
    querySelectorAll: () => []
};

// Load script.js
const scriptPath = path.join(__dirname, 'script.js');
let scriptContent = fs.readFileSync(scriptPath, 'utf8');

// Ensure functions and variables are global
scriptContent = scriptContent.replace(/let isPaused = false;/, 'global.isPaused = false;');
scriptContent = scriptContent.replace(/function togglePause\(\) \{/, 'global.togglePause = function() {');

// Strip out DOM-related code that we've already mocked or don't need
scriptContent = scriptContent.replace(/const canvas = document\.getElementById\('canvas'\);/, 'const canvas = { getContext: () => ({ fillRect: () => {}, beginPath: () => {}, moveTo: () => {}, lineTo: () => {}, stroke: () => {}, fill: () => {}, closePath: () => {}, arc: () => {}, fillText: () => {} }), width: 800, height: 600 };');
scriptContent = scriptContent.replace(/const ctx = canvas\.getContext\('2d'\);/, 'const ctx = canvas.getContext("2d");');
scriptContent = scriptContent.replace(/const statusElement = document\.getElementById\('status'\);/, 'const statusElement = { innerText: "" };');
scriptContent = scriptContent.replace(/requestAnimationFrame\(mainLoop\);/g, ''); // Don't start the loop automatically

// Evaluate script
try {
    // console.log("Script content snippet:", scriptContent.substring(0, 500));
    eval(scriptContent);
    // console.log("isPaused after eval:", typeof isPaused);
} catch (e) {
    console.error("Eval failed:", e);
    process.exit(1);
}

// Test Toggle Pause
console.log("Testing Toggle Pause...");
if (typeof isPaused === 'undefined') {
    // Check if it's on global
    if (typeof global.isPaused !== 'undefined') {
        console.log("Found isPaused on global");
        isPaused = global.isPaused;
        togglePause = global.togglePause;
    } else {
        console.error("isPaused is not defined anywhere");
        process.exit(1);
    }
}

if (isPaused !== false) {
    console.error("Initial isPaused should be false");
    process.exit(1);
}

togglePause();
if (isPaused !== true) {
    console.error("isPaused should be true after toggle");
    process.exit(1);
}

togglePause();
if (isPaused !== false) {
    console.error("isPaused should be false after second toggle");
    process.exit(1);
}

console.log("✅ Pause toggle test passed!");
