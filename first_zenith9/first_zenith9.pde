// Constants
final int NUM_PARTICLES = 8000;
final float GROUP_RADIUS = 30;
final float GROUP_CHANCE = 0.2;
final float WIND_STRENGTH = 0.1;
final float REPEL_STRENGTH = 1.3;
final color BACKGROUND_COLOR = #080027;
final float EDGE_MARGIN = 100;
final float EDGE_FORCE = 0.5;

// Global variables
Particle[] particles;

void setup() {
  noCursor();
  fullScreen();
  frameRate(30);
  background(BACKGROUND_COLOR);
  
  // Initialize particles
  particles = new Particle[NUM_PARTICLES];
  for (int i = 0; i < NUM_PARTICLES; i++) {
    boolean isGroupable = random(1) < 0.7;
    particles[i] = new Particle(isGroupable);
  }
}

void draw() {
  // Apply fade effect
  fill(BACKGROUND_COLOR, 20);
  noStroke();
  rect(0, 0, width, height);
  
  // Calculate wind force
  PVector wind = new PVector(
    sin(frameCount * 0.01) * WIND_STRENGTH, 
    cos(frameCount * 0.01) * WIND_STRENGTH
  );
  
  // Update and display particles
  for (int i = 0; i < particles.length; i++) {
    Particle p = particles[i];
    if (p.groupable) {
      p.applyForce(wind);
    }
    p.update(i);
    p.display();
  }
}

void mousePressed() {
  for (Particle p : particles) {
    p.scatter();
  }
}
