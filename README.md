### ANN Concepts: Neuroevolution and Reinforcement Learning

This repository explores various Artificial Neural Network (ANN) concepts, specifically focusing on neuroevolution and reinforcement learning. It features simulations of Tic-Tac-Toe and Cart-Pole (Inverted Pendulum) where neural networks are trained through backpropagation or evolved using genetic algorithms.

### Features

| Feature | Status |
| :--- | :--- |
| **Neuroevolution** | Evolve neural networks to solve problems without explicit training data. |
| **Backpropagation** | Classic training of neural networks using supervised learning. |
| **Dynamic Topology** | Real-time visualization of the neural network's structure, weights, and neuron activations. |
| **Prioritize Topology** | **Enabled by default**. Structural changes (adding/removing neurons) are prioritized over weight adjustments during evolution. |
| **D Programming Language** | High-performance implementation for native simulations. |
| **Pure JavaScript/Canvas** | Browser-based simulation without WebAssembly or external dependencies. |

### Cart-Pole Simulation Variants
You can switch between multiple physical shapes in the simulation to see how the neuroevolution adapts:
- **Standard Pole**: The classic balancing task.
- **Long/Weighted/Short Heavy Poles**: Varied physics for increased difficulty.
- **Triangle Shapes**: Balancing a triangle on its vertex (includes Small, Large, Heavy, and Tilted variants).

### Project Structure

- `source/nn.d`: Core neural network implementation with backpropagation.
- `source/mut_nn.d`: Structure-mutation oriented neural network model.
- `source/evolve_nn.d`: Neuroevolution logic for the Tic-Tac-Toe game.
- `source/tictactoe.d`: Tic-Tac-Toe game logic and board representation.
- `source/pole_sim.d`: Physical simulation of the Cart-Pole system.
- `source/pole_evolve.d`: Neuroevolution logic for the Cart-Pole simulation (text-based).
- `source/pole_sdl.d`: Visual Cart-Pole simulation using SDL2.
- `source/app.d`: Main entry point for the Tic-Tac-Toe backpropagation training and play.

### Requirements

- [D Compiler](https://dlang.org/download.html) (DMD, LDC, or GDC)
- [Dub](https://dub.pm/) (D's package manager)
- **For SDL Simulation**:
    - SDL2 library installed on your system.

### Installation & Usage

This project uses `dub` for building and running.

#### 1. Tic-Tac-Toe (Backpropagation)
Train a network on heuristic data and then play against it.
```bash
dub run :tictactoe
```

#### 2. Tic-Tac-Toe (Neuroevolution)
Evolve a population of networks to play Tic-Tac-Toe.
```bash
dub run :evolve
```

#### 3. Cart-Pole (Neuroevolution - Text)
Evolve a network to balance the pole, with text-based feedback.
```bash
dub run :pole
```

#### 4. Cart-Pole (Neuroevolution - SDL Visual)
Evolve a network to balance the pole with a real-time SDL2 visualization.
```bash
dub run :pole-sdl
```

#### 5. Web Simulation (JavaScript & HTML5 Canvas)
The Cart-Pole simulation can also be run in a web browser using pure JavaScript and HTML5 Canvas.

**How to Run:**
1. Navigate to the `web/` directory.
2. Open `index.html` in a web browser using a local web server (e.g., `python -m http.server`).
3. The simulation will run automatically, showing the evolution process and the best network's performance.

The web version features a real-time visualization of the cart-pole system and the neural network's topology, including weight strengths and neuron activations.

**Running Tests:**
To verify the browser simulation logic, run the Node.js test scripts:

1.  **Shape Change Tests**: Validates physical constants and state resets across different pole configurations.
    ```bash
    node web/test_shapes.js
    ```
2.  **Balancing Logic Tests**: Verifies the core physics engine, gravity, and boundary conditions.
    ```bash
    node web/test_balancing.js
    ```
3.  **Priority Switch Tests**: Verifies the "Prioritize Topology" mutation logic.
    ```bash
    node web/test_priority.js
    ```
4.  **Dynamic Node Mutation Tests**: Validates addition and removal of hidden nodes.
    ```bash
    node web/test_dynamic_nodes.js
    ```

To run the native D unit tests:
```bash
dub test
```

### Configuration

You can find the build configurations in `dub.json`. The project supports multiple executables:
- `tictactoe`: Supervised learning for Tic-Tac-Toe.
- `evolve`: Neuroevolution for Tic-Tac-Toe.
- `pole`: Neuroevolution for Cart-Pole.
- `pole-sdl`: Visual neuroevolution for Cart-Pole.

### Notes

- The `mut_nn.d` module provides a structure-mutation oriented approach to neural network evolution.
- During simulations, the neural network graph updates continuously to reflect changing weights and architecture.

### License

Proprietary (See `dub.json`)
