ArrayList<Particle> particles;
ArrayList<Attractor> attractors;
int numParticles = 12000;
int numAttractors = 900;

void setup() {
  size(800, 800);
  colorMode(HSB, 360, 100, 100, 100);
  
  particles = new ArrayList<Particle>();
  attractors = new ArrayList<Attractor>();
  
  // Create attractors - some centered, some extending beyond screen edges
  for (int i = 0; i < numAttractors; i++) {
    float x, y;
    
    if (i < numAttractors * 0.6) {
      // 60% of attractors stay within screen
      x = random(50, width - 50);
      y = random(50, height - 50);
    } else {
      // 40% of attractors can be positioned outside screen bounds
      x = random(-100, width + 100);
      y = random(-100, height + 100);
    }
    
    attractors.add(new Attractor(x, y, i >= numAttractors * 0.6));
  }
  
  // Create particles
  for (int i = 0; i < numParticles; i++) {
    particles.add(new Particle());
  }
}

void draw() {
  background(0);
  
  // Update and display attractors - make them move to change patterns
  for (Attractor attractor : attractors) {
    attractor.update(); // Add movement to attractors
    attractor.display();
  }
  
  // Update and display particles
  for (Particle particle : particles) {
    particle.update();
    particle.display();
  }
}

class Particle {
  PVector pos, vel, acc;
  float maxSpeed = 2.0;
  float maxForce = 0.05;
  color col;
  float hue;
  
  Particle() {
    pos = new PVector(random(width), random(height));
    vel = PVector.random2D();
    vel.mult(random(0.5, 2));
    acc = new PVector(0, 0);
    hue = random(360);
    col = color(hue, 80, 90, 80);
  }
  
  void update() {
    // Reset acceleration
    acc.mult(0);
    
    // Find nearest attractor and apply force
    float minDist = Float.MAX_VALUE;
    Attractor nearest = null;
    
    for (Attractor attractor : attractors) {
      float dist = PVector.dist(pos, attractor.pos);
      if (dist < minDist) {
        minDist = dist;
        nearest = attractor;
      }
    }
    
    // Add significant random movement for particle flow between circles
    PVector randomForce = PVector.random2D();
    randomForce.mult(0.08); // Increased from 0.01 to 0.08
    acc.add(randomForce);
    
    // Add attraction force with reduced strength
    if (nearest != null) {
      PVector force = attract(nearest);
      force.mult(0.6); // Reduce attraction strength to allow more movement
      acc.add(force);
      
      // Add repulsion if too close to center
      float distToCenter = PVector.dist(pos, nearest.pos);
      if (distToCenter < 20) {
        PVector repulsion = PVector.sub(pos, nearest.pos);
        repulsion.normalize();
        repulsion.mult(0.8); // Increased repulsion
        acc.add(repulsion);
      }
    }
    
    // Add inter-circle flow forces
    if (frameCount % 10 == int(random(10))) { // Randomly switch targets
      PVector flowForce = PVector.random2D();
      flowForce.mult(0.3);
      acc.add(flowForce);
    }
    
    // Update velocity and position
    vel.add(acc);
    vel.limit(maxSpeed);
    pos.add(vel);
    
    // Wrap around screen edges
    if (pos.x < 0) pos.x = width;
    if (pos.x > width) pos.x = 0;
    if (pos.y < 0) pos.y = height;
    if (pos.y > height) pos.y = 0;
    
    // Update color based on speed
    float speed = vel.mag();
    col = color(hue + speed * 20, 70 + speed * 10, 80 + speed * 20, 60);
  }
  
  PVector attract(Attractor attractor) {
    PVector force = PVector.sub(attractor.pos, pos);
    float distance = force.mag();
    distance = constrain(distance, 15, 100); // Minimum distance prevents particles from touching center
    
    // Stronger attraction force to pull particles closer to core
    float strength = (attractor.mass * 2) / (distance * distance);
    force.normalize();
    force.mult(strength);
    
    return force;
  }
  
  void display() {
    stroke(col);
    strokeWeight(random(2,3));
    point(pos.x, pos.y);
  }
}

class Attractor {
  PVector pos, vel;
  float mass;
  float radius;
  float noiseOffset;
  boolean canExceedBounds;
  
  Attractor(float x, float y, boolean exceedBounds) {
    pos = new PVector(x, y);
    vel = new PVector(0, 0);
    mass = random(20, 40);
    radius = mass * 2;
    noiseOffset = random(1000);
    canExceedBounds = exceedBounds;
  }
  
  void update() {
    // Move attractors using noise for smooth, organic movement
    float noiseScale = 0.015; // Increased from 0.005 to 0.015
    float noiseStrength = 1.2; // Increased from 0.5 to 1.2
    
    vel.x = (noise(pos.x * noiseScale, pos.y * noiseScale, frameCount * noiseScale + noiseOffset) - 0.5) * noiseStrength;
    vel.y = (noise(pos.x * noiseScale + 100, pos.y * noiseScale + 100, frameCount * noiseScale + noiseOffset) - 0.5) * noiseStrength;
    
    pos.add(vel);
    
    // Apply different boundary constraints based on attractor type
    if (canExceedBounds) {
      // Attractors that can exceed bounds - wider movement area
      if (pos.x < -150) pos.x = -150;
      if (pos.x > width + 150) pos.x = width + 150;
      if (pos.y < -150) pos.y = -150;
      if (pos.y > height + 150) pos.y = height + 150;
    } else {
      // Regular attractors stay within screen bounds
      if (pos.x < 50) pos.x = 50;
      if (pos.x > width - 50) pos.x = width - 50;
      if (pos.y < 50) pos.y = 50;
      if (pos.y > height - 50) pos.y = height - 50;
    }
    
    // More frequent random movement for faster changes
    if (frameCount % 60 == 0) { // Changed from 120 to 60 (twice as frequent)
      PVector randomMove = PVector.random2D();
      randomMove.mult(random(15, 50)); // Increased from (10, 30) to (15, 50)
      pos.add(randomMove);
      
      if (canExceedBounds) {
        pos.x = constrain(pos.x, -150, width + 150);
        pos.y = constrain(pos.y, -150, height + 150);
      } else {
        pos.x = constrain(pos.x, 50, width - 50);
        pos.y = constrain(pos.y, 50, height - 50);
      }
    }
  }
  
  void display() {
    // Attractors are now invisible - no drawing code
  }
}
