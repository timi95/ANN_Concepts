all: pole.js

pole.js: source/pole_web.d source/pole_sim.d
	ldc2 -mtriple=wasm32-unknown-emscripten -c source/pole_web.d source/pole_sim.d -Isource --output-bc -betterC
	emcc pole_web.bc pole_sim.bc -o pole.js -s USE_SDL=2 -s EXPORTED_FUNCTIONS='["_main", "_mainLoop"]' -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]'

clean:
	rm -f *.bc pole.js pole.wasm
