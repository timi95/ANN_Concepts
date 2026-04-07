module pole_sim;

// import std.math;
// Replacement for necessary functions to avoid standard library
extern(C) {
    double cos(double);
    double sin(double);
}

struct CartPole {
    double x = 0.0;           // Cart position
    double x_dot = 0.0;       // Cart velocity
    double theta = 0.0;       // Pole angle (0 is vertical)
    double theta_dot = 0.0;   // Pole angular velocity

    // Constants (can be modified in subclasses)
    double gravity = 9.8;
    double mass_cart = 1.0;
    double mass_pole = 0.1;
    double length = 0.5; // Half-length of pole
    double force_mag = 10.0;
    double tau = 0.02; // Seconds between state updates

    static immutable double PI = 3.14159265358979323846;
    static immutable double x_threshold = 2.4;
    static immutable double theta_threshold_radians = 12 * 3.14159265358979323846 / 180;

    void init(double mass_p = 0.1, double len = 0.5) {
        this.mass_pole = mass_p;
        this.length = len;
        this.x = 0;
        this.x_dot = 0;
        this.theta = 0;
        this.theta_dot = 0;
    }

    bool update(double force) {
        double total_mass = mass_cart + mass_pole;
        double polemass_length = mass_pole * length;
        double costheta = cos(theta);
        double sintheta = sin(theta);

        double temp = (force + polemass_length * theta_dot * theta_dot * sintheta) / total_mass;
        double thetaacc = (gravity * sintheta - costheta * temp) / (length * (4.0 / 3.0 - mass_pole * costheta * costheta / total_mass));
        double xacc = temp - polemass_length * thetaacc * costheta / total_mass;

        x = x + tau * x_dot;
        x_dot = x_dot + tau * xacc;
        theta = theta + tau * theta_dot;
        theta_dot = theta_dot + tau * thetaacc;

        return !isGameOver();
    }

    bool isGameOver() const {
        return (x < -x_threshold || x > x_threshold || theta < -theta_threshold_radians || theta > theta_threshold_radians);
    }

    double[] getInputs() const {
        static double[4] inputs;
        inputs[0] = x / x_threshold;
        inputs[1] = x_dot / 2.0;
        inputs[2] = theta / theta_threshold_radians;
        inputs[3] = theta_dot / 2.0;
        return inputs[];
    }

    const(char*) getShapeName() const { return "Standard Pole"; }
    double getX() const { return x; }
    double getTheta() const { return theta; }
    double getPoleLength() const { return length * 2.0; } // Return full length for rendering
}

// Removed subclasses as they are not needed for simple web demo and cause class issues
