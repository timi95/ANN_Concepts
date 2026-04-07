module pole_sim;

import std.math;

interface IBalanceable {
    bool update(double force);
    bool isGameOver() const;
    double[] getInputs() const;
    string getShapeName() const;
    
    // For rendering
    double getX() const;
    double getTheta() const;
    double getPoleLength() const;
}

class CartPole : IBalanceable {
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

    // Boundaries
    static immutable double x_threshold = 2.4;
    static immutable double theta_threshold_radians = 12 * PI / 180;

    this(double mass_p = 0.1, double len = 0.5) {
        this.mass_pole = mass_p;
        this.length = len;
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
        return [x / x_threshold, x_dot / 2.0, theta / theta_threshold_radians, theta_dot / 2.0];
    }

    string getShapeName() const { return "Standard Pole"; }
    double getX() const { return x; }
    double getTheta() const { return theta; }
    double getPoleLength() const { return length * 2.0; } // Return full length for rendering
}

class CartLongPole : CartPole {
    this() {
        super(0.1, 1.0); // Longer pole
    }
    override string getShapeName() const { return "Long Pole"; }
}

class CartWeightedPole : CartPole {
    this() {
        super(0.5, 0.5); // Heavier pole
    }
    override string getShapeName() const { return "Weighted Pole"; }
}

class CartShortHeavyPole : CartPole {
    this() {
        super(1.0, 0.2); // Short and heavy
    }
    override string getShapeName() const { return "Short Heavy Pole"; }
}

class CartTriangle : CartPole {
    this() {
        super(0.3, 0.6); // Higher COM for triangle
    }
    override string getShapeName() const { return "Standard Triangle"; }
}

class CartSmallTriangle : CartPole {
    this() {
        super(0.1, 0.3);
    }
    override string getShapeName() const { return "Small Triangle"; }
}

class CartLargeTriangle : CartPole {
    this() {
        super(0.5, 1.0);
    }
    override string getShapeName() const { return "Large Triangle"; }
}

class CartHeavyTriangle : CartPole {
    this() {
        super(1.0, 0.6);
    }
    override string getShapeName() const { return "Heavy Triangle"; }
}

class CartStar : CartPole {
    int points;
    this(int p) {
        this.points = p;
        super(0.1 + (p * 0.05), 0.4 + (p * 0.02));
    }
    override string getShapeName() const { 
        import std.format;
        return format("%d-Pointed Star", points); 
    }
    int getPoints() const { return points; }
}

unittest {
    import std.stdio;
    writeln("Running CartPole unit tests...");

    // Test 1: Gravity
    auto cp = new CartPole();
    cp.theta = 0.05;
    cp.theta_dot = 0.0;
    
    for (int i = 0; i < 10; i++) {
        cp.update(0.0);
    }
    assert(cp.theta > 0.05, "Pole should fall under gravity");
    writeln("  Passed: Gravity check");

    // Test 2: PD Control
    cp = new CartPole();
    cp.theta = 0.05;
    int steps = 0;
    while (!cp.isGameOver() && steps < 1000) {
        double force = 100.0 * cp.theta + 20.0 * cp.theta_dot;
        cp.update(force);
        steps++;
    }
    assert(steps > 100, "PD controller should balance for a while");
    writeln("  Passed: PD control check (survived ", steps, " steps)");

    // Test 3: Limits
    cp = new CartPole();
    cp.x = 2.5;
    assert(cp.isGameOver(), "Should be game over if x > threshold");
    
    cp = new CartPole();
    cp.theta = 0.3;
    assert(cp.isGameOver(), "Should be game over if theta > threshold");
    writeln("  Passed: Limits check");

    // Test 4: Force
    cp = new CartPole();
    cp.update(10.0);
    assert(cp.x_dot > 0, "Positive force should cause positive velocity");
    writeln("  Passed: Force check");
    
    writeln("All CartPole unit tests passed.");
}
