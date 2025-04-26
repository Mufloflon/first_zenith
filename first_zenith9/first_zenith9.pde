int numParticles = 4000;
Particle[] particles;
//float groupRadius = random(50, 130);
float groupRadius = 30;
float groupChance = 0.2;
float windStrength = 0.1;
float repelStrength = 1.3; //0.3

void setup() {
  noCursor();
  fullScreen();
  frameRate(60);
  background(#080027);
  particles = new Particle[numParticles];
  for (int i = 0; i < numParticles; i++) {
    boolean isGroupable = random(1) < 0.7;
    particles[i] = new Particle(isGroupable);
  }
}

void draw() {
  fill(#080027, 20);
  noStroke();
  rect(0, 0, width, height);

  PVector wind = new PVector(sin(frameCount * 0.01) * windStrength, cos(frameCount * 0.01) * windStrength);

  for (int i = 0; i < particles.length; i++) {
    Particle p = particles[i];
    if (p.groupable) p.applyForce(wind);
    p.update(i);
    p.display();
  }
}

void mousePressed() {
  for (Particle p : particles) {
    p.scatter();
  }
}

class Particle {
  PVector position, velocity, acceleration;
  color c;
  color baseColor;
  color currentColor;

  boolean grouped = false;
  boolean groupable;
  float baseSpeed;

  Particle groupLeader = null;
  ArrayList<Particle> groupMembers = new ArrayList<>();

  Particle(boolean groupable) {
    this.groupable = groupable;
    position = new PVector(random(width), random(height));
    baseSpeed = groupable ? random(1, 2.5) : random(0.05, 0.2);
    velocity = PVector.random2D().mult(baseSpeed);
    acceleration = new PVector(0, 0);

    if (groupable) {
      c = color(random(255), random(255), random(255));
      baseColor = c;
    } else {
      baseColor = color(0);
      currentColor = baseColor;
    }
  }

  void update(int index) {
    if (groupable && frameCount % 2 == index % 2 && random(1) < groupChance) {
      groupParticles();
    }

    if (groupable && groupLeader != null) {
      PVector attraction = PVector.sub(groupLeader.position, position);
      attraction.setMag(1.5);
      acceleration.add(attraction);

      for (Particle other : groupMembers) {
        if (other != this) {
          PVector repulsion = PVector.sub(position, other.position);
          float distSq = repulsion.magSq();
          if (distSq < sq(groupRadius * 1.2)) {
            repulsion.setMag(repelStrength);
            acceleration.add(repulsion);
          }
        }
      }
    }

    acceleration.add(PVector.random2D().mult(0.05));

    if (frameCount % 60 == 0 && random(1) < 0.05) {
      velocity.rotate(random(-PI / 12, PI / 12));
    }

    velocity.add(acceleration);
    velocity.limit(grouped ? 2 : baseSpeed + 0.5);
    position.add(velocity);
    acceleration.mult(0);

    // Edge repulsion
    float margin = 100;
    float edgeForce = 0.5;

    float leftDist = position.x;
    float rightDist = width - position.x;
    float topDist = position.y;
    float bottomDist = height - position.y;

    if (leftDist < margin) acceleration.x += map(leftDist, 0, margin, edgeForce, 0);
    if (rightDist < margin) acceleration.x -= map(rightDist, 0, margin, edgeForce, 0);
    if (topDist < margin) acceleration.y += map(topDist, 0, margin, edgeForce, 0);
    if (bottomDist < margin) acceleration.y -= map(bottomDist, 0, margin, edgeForce, 0);

    // Bounce with inward nudge
    if (position.x <= 0) {
      position.x = 1;
      velocity.x = abs(velocity.x);
    } else if (position.x >= width) {
      position.x = width - 1;
      velocity.x = -abs(velocity.x);
    }

    if (position.y <= 0) {
      position.y = 1;
      velocity.y = abs(velocity.y);
    } else if (position.y >= height) {
      position.y = height - 1;
      velocity.y = -abs(velocity.y);
    }

    // Color shift near groups
    if (!groupable) {
      boolean nearGroup = false;
      for (Particle other : particles) {
        if (other != this && other.groupable && other.groupLeader != null) {
          if (position.dist(other.position) < groupRadius * 1.5) {
            currentColor = other.groupLeader.c;
            nearGroup = true;
            break;
          }
        }
      }
      if (!nearGroup) {
        currentColor = baseColor;
      }
    }
  }

  void display() {
    strokeWeight(int(random(0.5, 4)));
    stroke(groupable ? (groupLeader != null ? groupLeader.c : c) : currentColor);
    point(position.x, position.y);
  }

  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void scatter() {
    velocity = PVector.random2D().mult(baseSpeed);
    if (groupable) {
      groupLeader = null;
      grouped = false;
      groupMembers.clear();
    }
  }

  void groupParticles() {
    for (Particle other : particles) {
      if (other != this && other.groupable) {
        float dist = position.dist(other.position);
        if (dist < groupRadius) {
          if (groupLeader == null && random(1) < groupChance) {
            groupLeader = this;
            groupMembers.add(this);
          }
          if (!groupMembers.contains(other) && random(1) < groupChance) {
            groupMembers.add(other);
          }
          other.groupLeader = groupLeader;
          other.grouped = true;
          other.groupMembers = this.groupMembers;

          PVector spring = PVector.sub(other.position, position);
          spring.setMag(0.05);
          acceleration.add(spring);
        }
      }
    }
  }
}
