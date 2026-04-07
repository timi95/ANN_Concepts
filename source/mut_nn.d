import std.stdio;
import std.conv;
import std.traits;
import std.file;
import std.path;
import std.math;
import std.string;
import std.datetime;
import std.process;
import std.parallelism;
import std.algorithm: remove;

int numInputs(int a) { return a; }

//Struct neuron model [inputs, sigmoid, output] 
class Neuron {

		double[] inputs;
		double[] weights;

		double output;

		double sigmoid(double input) {

			input = 1/(1+exp(input * (-1) ));
			double output = input;

			return output;
		}

	// sum the product of all weights and inputs
		double sumProd(double[] all_weights, double[] all_inputs) {

			assert(all_weights.length == all_inputs.length);
			double sum = 0.0;
	        for(int i=0;i<all_inputs.length;i++) {
	            sum += all_weights[i]*all_inputs[i];
	        }

			return sum;
		}

		double getOutput(){
			return this.output;
		}

		this(double[] weights, double[] inputs ) { // @suppress(dscanner.style.undocumented_declaration)
			this.inputs = inputs;
			this.weights = weights;
			// f(x) = activateFunc(sum(prod(all_weights, all_inputs)))
			this.output = sigmoid(sumProd(this.weights, this.inputs));

		}

}



class NeuralNetwork {
	Neuron[][] topology;
	Neuron[] layer;
	double[] inputs;
	double[] weights;

	// returns a neuron
	auto neuronFactory(	double[] weights, double[] inputs) {
		return new Neuron(weights, inputs);
	}

	public void setInputs(double[] inputs) { this.inputs = inputs; }
	public void setWeights(double[] weights) {this.weights = weights; }

// adds neurons to a layer
	Neuron[][] populateNetwork(int[] Sizes) {
		if(Sizes.length == 0)
		{
			writeln("Default initialization");
			this.layer ~= this.neuronFactory(this.inputs,this.weights);
			this.topology ~= this.layer;
		} else {
				writeln("Populating Network");
				for(int n=0; n < Sizes.length; n++) {
					// adding nodes to the layer
					for(int i=0 ; i < Sizes[n] ; i++)
					{ this.layer ~= this.neuronFactory(this.inputs,this.weights); }

					//adding layers to the topology
					 this.topology ~= this.layer;

					// empty layer Cache
					this.layer = [];
				}

				writeln("Populating Network complete!");
		}

		return this.topology;
	}

	void display() { // this prints out the structure of the resulting topology
		writeln("\n\nDisplaying !....");
		writeln("\n\nTopology length: ",this.topology.length);
		writeln("\nTopology structure: ",this.topology);

		writeln("\n\nTopology structure");
		int count = 1;
		for ( int i=0; i<this.topology.length ;i++ ) {
			writeln("\n LAYER [",i,"] \n");
			for ( int j=0; j<this.topology[i].length ; j++, count++ ) {
				write("node[",count,"] ->",this.topology[i][j].getOutput," | ");
			}
			writeln;
		}

	}


	this(int[] layer_sizes=[] ) {
		this.populateNetwork(layer_sizes);
	}

}

void main()
{
	double[] weights = [0.0,0.1,0.5,1.5]; // randomize these
	double[] inputs  = [1.1,0.6,0.4,0.5];


	NeuralNetwork nn = new NeuralNetwork([2,1]);
	nn.setWeights(weights);
	nn.setInputs(inputs);
	nn.weights.writeln;
	nn.inputs.writeln;

	nn.display();
	writeln("Removing!");
	nn.topology[0] = nn.topology[0].remove(1);
	nn.display();

}