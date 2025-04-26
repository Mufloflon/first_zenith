class Particle {
  PVector position, velocity, acceleration;
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
      baseColor = color(random(255), random(255), random(255));
    } else {
      baseColor = color(0);
      currentColor = baseColor;
    }
  }
  
  void update(int index) {
    // Check for grouping
    if (groupable && frameCount % 2 == index % 2 && random(1) < GROUP_CHANCE) {
      groupParticles();
    }
    
    // Apply group behaviors
    handleGroupBehavior();
    
    // Add some randomness
    acceleration.add(PVector.random2D().mult(0.05));
    
    // Occasionally rotate velocity
    if (frameCount % 60 == 0 && random(1) < 0.05) {
      velocity.rotate(random(-PI / 12, PI / 12));
    }
    
    // Update physics
    velocity.add(acceleration);
    velocity.limit(grouped ? 2 : baseSpeed + 0.5);
    position.add(velocity);
    acceleration.mult(0);
    
    handleEdges();
    updateColor();
  }
  
  void handleGroupBehavior() {
    // Fix: Check that both groupable AND groupLeader is not null
    if (groupable && groupLeader != null) {
      // Follow group leader
      PVector attraction = PVector.sub(groupLeader.position, position);
      attraction.setMag(1.5);
      acceleration.add(attraction);
      
      // Avoid other group members
      if (groupMembers != null && !groupMembers.isEmpty()) {
        for (Particle other : groupMembers) {
          if (other != null && other != this) {
            PVector repulsion = PVector.sub(position, other.position);
            float distSq = repulsion.magSq();
            if (distSq < sq(GROUP_RADIUS * 1.2)) {
              repulsion.setMag(REPEL_STRENGTH);
              acceleration.add(repulsion);
            }
          }
        }
      }
    }
  }
  
  void handleEdges() {
    // Edge repulsion
    float leftDist = position.x;
    float rightDist = width - position.x;
    float topDist = position.y;
    float bottomDist = height - position.y;
    
    if (leftDist < EDGE_MARGIN) acceleration.x += map(leftDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (rightDist < EDGE_MARGIN) acceleration.x -= map(rightDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (topDist < EDGE_MARGIN) acceleration.y += map(topDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (bottomDist < EDGE_MARGIN) acceleration.y -= map(bottomDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    
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
  }
  
  void updateColor() {
    // Color shift near groups
    if (!groupable) {
      boolean nearGroup = false;
      for (Particle other : particles) {
        if (other != this && other.groupable && other.groupLeader != null) {
          if (position.dist(other.position) < GROUP_RADIUS * 1.5) {
            currentColor = other.groupLeader.baseColor;
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
    color displayColor = groupable ? 
                         (groupLeader != null ? groupLeader.baseColor : baseColor) : 
                         currentColor;
    stroke(displayColor);
    point(position.x, position.y);
  }
  
  void applyForce(PVector force) {
    acceleration.add(force);
  }
  
  void scatter() {
    velocity = PVector.random2D().mult(baseSpeed * 3); // Added multiplier for more dramatic scatter
    if (groupable) {
      groupLeader = null;
      grouped = false;
      groupMembers.clear();
    }
  }
  
  void groupParticles() {
    for (Particle other : particles) {
      if (other != null && other != this && other.groupable) {
        float dist = position.dist(other.position);
        if (dist < GROUP_RADIUS) {
          // Establish leadership if needed
          if (groupLeader == null && other.groupLeader == null && random(1) < GROUP_CHANCE) {
            groupLeader = this;
            grouped = true;
            if (groupMembers.isEmpty()) {
              groupMembers.add(this);
            }
          }
          
          // Use existing leader or become part of another's group
          if (groupLeader == null && other.groupLeader != null) {
            groupLeader = other.groupLeader;
            grouped = true;
            groupMembers = other.groupMembers;
            if (!groupMembers.contains(this)) {
              groupMembers.add(this);
            }
          }
          
          // Add other to our group if we're the leader
          if (groupLeader == this && !groupMembers.contains(other) && random(1) < GROUP_CHANCE) {
            other.groupLeader = this;
            other.grouped = true;
            other.groupMembers = this.groupMembers;
            groupMembers.add(other);
          }
          
          // Apply spring force
          PVector spring = PVector.sub(other.position, position);
          spring.setMag(0.05);
          acceleration.add(spring);
        }
      }
    }
  }
}
