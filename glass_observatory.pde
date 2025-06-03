import KinectPV2.KJoint;
import KinectPV2.*;

KinectPV2 kinect;

// Constants
final int NUM_PARTICLES = 2000;
final float GROUP_RADIUS = 25;
final float GROUP_CHANCE = 0.4;
final float WIND_STRENGTH = 0.1;
final float REPEL_STRENGTH = 1.3;
final color BACKGROUND_COLOR = #080027;
final float EDGE_MARGIN = 100;
final float EDGE_FORCE = 0.5;
final int SCATTER_TIME = 600;

// Global variables
Particle[] particles;
int scatterStartTime = -1;
int returningParticlesCount = 0;
boolean isScattering = false;
boolean isPatternFlow = false;
boolean isDefaultMode = false;
PVector lastMousePos;
int stationaryStartTime = -1;
int cursorModeStartTime = -1;
boolean inCursorMode = false;
final int DWELL_THRESHOLD = 8000; // 8 seconds
final int CUSTOM_MODE_DURATION = 4000; // 4 seconds 
boolean cursorMoved = false;

// New variables for auto mode switching
int defaultModeStartTime = -1;
boolean autoModeActive = false;
float modeTransitionLerp = 0.0; // For smooth transitions between modes
boolean isTransitioning = false;
final float TRANSITION_SPEED = 0.02; // Speed of transition between modes

// Cursor effect variables for PatternFlow mode
color cursorEffectColor = color(255, 150, 50); // Orange glow color
float cursorEffectRadius = 120; // Radius of cursor influence

float maxSizeMultiplier = 8; // Maximum size increase for particles
ArrayList<PVector> cursorTrail = new ArrayList<PVector>(); // Trail of cursor positions
int maxTrailLength = 40; // Maximum number of trail positions to keep

void setup() {
  noCursor();
  //fullScreen();
  size(800,800);
  frameRate(30);
  background(BACKGROUND_COLOR);
  isPatternFlow = true; // Start in pattern flow mode
  lastMousePos = new PVector(mouseX, mouseY);
  particles = new Particle[NUM_PARTICLES];

  kinect = new KinectPV2 (this);
  kinect.enableSkeletonColorMap(true);
  kinect.enableColorImg(true);
  kinect.init();
  
  for (int i = 0; i < NUM_PARTICLES; i++) {
    particles[i] = new Particle();
  }
  noSmooth();
}

void draw() {
  // Update cursor trail for PatternFlow mode
  if (isPatternFlow) 
    updateCursorTrail();
  
  background(BACKGROUND_COLOR);
  
  PVector wind = new PVector(
    sin(frameCount * 0.01) * WIND_STRENGTH,
    cos(frameCount * 0.01) * WIND_STRENGTH
  );

  float cursorDistance = dist(mouseX, mouseY, lastMousePos.x, lastMousePos.y);

  // Enhanced cursor detection and auto mode switching
  if (cursorDistance < 2) { // Mouse has barely moved
    if (stationaryStartTime == -1) {
      stationaryStartTime = millis();
    } else if (!autoModeActive && millis() - stationaryStartTime > DWELL_THRESHOLD) {
      autoModeActive = true;
      performModeSwitch(true); // Direct switch to default mode
    } else if (autoModeActive && isDefaultMode && millis() - defaultModeStartTime > CUSTOM_MODE_DURATION) {
      // Reset auto mode after transition completes
      autoModeActive = false;
      performModeSwitch(false);
    }
  } else {
    // Cursor moved - exit auto mode if active
    if (autoModeActive) {
      autoModeActive = false;
      performModeSwitch(false);
    }
    stationaryStartTime = -1;
    lastMousePos.set(mouseX, mouseY);
  }

  // Update transition lerp
  if (isTransitioning) {
    if (isDefaultMode) {
      modeTransitionLerp = min(1.0, modeTransitionLerp + TRANSITION_SPEED);
      if (modeTransitionLerp >= 1.0) {
        isTransitioning = false;
      }
    } else {
      modeTransitionLerp = max(0.0, modeTransitionLerp - TRANSITION_SPEED);
      if (modeTransitionLerp <= 0.0) {
        isTransitioning = false;
      }
    }
  }

  // Handle scattering timeout
  if (isScattering && millis() - scatterStartTime > SCATTER_TIME * 1000) {
    isScattering = false;
    revertParticleStates();
  }
  
  float dispersalForce = 9000.0; // Strength of line dispersal

  for (Particle p : particles) {
    if (isScattering) {
      p.scatterRandomly();
    } else {
      // Update particles with transition awareness
      p.setTransitionState(modeTransitionLerp, isDefaultMode);
      
      if (isPatternFlow || modeTransitionLerp < 1.0) {
        float influence = dist(mouseX, mouseY, p.position.x, p.position.y);
        influence = map(influence, 0, 150, 200, 1); // closer to cursor = more force
        PVector dir = getFlowDirection(p.position.x + mouseX * 0.01, p.position.y + mouseY * 0.01);
        dir.mult(influence);
        
        // Reduce pattern flow influence during transition to default mode
        if (isTransitioning && isDefaultMode) {
          dir.mult(1.0 - modeTransitionLerp);
        }
        
        p.velocity.limit(300);
        p.applyForce(dir);
   
        float distToMouse = dist(mouseX, mouseY, p.position.x, p.position.y);
       
        if (distToMouse < cursorEffectRadius){
          PVector repulsion = PVector.sub(p.position, new PVector(mouseX, mouseY));
          float repulsionMag = map(distToMouse, 0, cursorEffectRadius, dispersalForce, 0);
          
          // Reduce cursor effects during transition to default mode
          if (isTransitioning && isDefaultMode) {
            repulsionMag *= (1.0 - modeTransitionLerp);
          }
          
          repulsion.setMag(repulsionMag);
          p.applyForce(repulsion);
          p.velocity.limit(700); // boost speed when cursor is near
          
          // Enhanced cursor effects - color and size changes
          float lerpAmt = constrain(map(distToMouse, 0, cursorEffectRadius, 1, 0), 0, 1);
          if (isTransitioning && isDefaultMode) {
            lerpAmt = lerp(lerpAmt, 0, modeTransitionLerp);
          }
          p.currentColor = lerpColor(cursorEffectColor, p.baseColor, lerpAmt);
          p.cursorSizeMultiplier = lerp(maxSizeMultiplier, 1.0, lerpAmt);
        } else {
          p.velocity.limit(2);
          p.currentColor = p.baseColor;
          p.cursorSizeMultiplier = 1.0;
        }
        
        // ATTRACT TO NEIGHBORS (TO FORM "LINES") - reduce during transition
        for (Particle other : particles) {
          float d = dist(p.position.x, p.position.y, other.position.x, other.position.y);
          if (other != p && d < 100) {
            PVector towardOther = PVector.sub(other.position, p.position);
            towardOther.setMag(0.05);
            
            // Reduce neighbor attraction during transition to default mode
            if (isTransitioning && isDefaultMode) {
              towardOther.mult(1.0 - modeTransitionLerp);
            }
            
            p.applyForce(towardOther);
          }
        }

        if (p.groupable) {
          PVector windForce = wind.copy();
          // Reduce wind during transition to default mode
          if (isTransitioning && isDefaultMode) {
            windForce.mult(1.0 - modeTransitionLerp);
          }
          p.applyForce(windForce);
        }
      }
      
      p.update(0);
    }
    p.display();
  }
 
  // Handle Kinect skeleton tracking
  ArrayList<KSkeleton> skeletonArray = kinect.getSkeletonColorMap();
   
  PVector handR = new PVector();
  PVector handL = new PVector();
   
  for (int i = 0; i < skeletonArray.size(); i++) {
    KSkeleton skeleton = (KSkeleton) skeletonArray.get(i);
    if (skeleton.isTracked()) {
      KJoint[] joints = skeleton.getJoints();
      
      println("skeleton detected");

      //Draw body
      color col = skeleton.getIndexColor();
      fill(col);
      stroke(col);
      drawBody(joints);
      
      //draw different color for each hand state
      drawHandState(joints[KinectPV2.JointType_HandRight]);
      drawHandState(joints[KinectPV2.JointType_HandLeft]);
      
      KJoint left = joints[KinectPV2.JointType_HandLeft];
      KJoint right = joints[KinectPV2.JointType_HandRight];
      
      int rightHandState = joints[KinectPV2.JointType_HandRight].getState();

      if (rightHandState == KinectPV2.HandState_Closed && !isScattering) {
        isScattering = true;
        scatterStartTime = millis(); // FIXED: Set scatter start time
        println("Scatter: ON");
      } else if (rightHandState == KinectPV2.HandState_Open && isScattering) {
        isScattering = false;
        revertParticleStates();
        println("Scatter: OFF");
      }

      handR.x = map(right.getX(), 200, 1900, 0, width);
      handR.y = map(right.getY(), 200, 1200, 0, height);
      
      handL.x = map(left.getX(), 200, 1900, 0, width);
      handL.y = map(left.getY(), 200, 1200, 0, height); // FIXED: was width, should be height
    }
  }
  
  // Apply fade to hand indicators
  fill(255);
  circle(handR.x, handR.y, 100);
  
  fill(200); 
  circle(handL.x, handL.y, 100);
}

// Update cursor trail for enhanced effects
void updateCursorTrail() {
  // Add current mouse position to trail
  cursorTrail.add(new PVector(mouseX, mouseY));
  
  // Remove old positions to maintain trail length
  while (cursorTrail.size() > maxTrailLength) {
    cursorTrail.remove(0);
  }
}

// Perform the actual mode switch during the invisible moment or directly
void performModeSwitch(boolean toDefaultMode) {
  if (toDefaultMode) {
    // Switch to default mode
    isDefaultMode = true;
    isPatternFlow = false;
    defaultModeStartTime = millis();
    isTransitioning = true;
    
    // Prepare all particles for transition to default mode
    for (Particle p : particles) {
      p.prepareForDefaultMode();
    }
  } else {
    // Switch to pattern flow
    isDefaultMode = false;
    isPatternFlow = true;
    isTransitioning = true;
    
    // Prepare particles for transition back to pattern flow
    for (Particle p : particles) {
      p.prepareForPatternFlow();
    }
  }
}

void drawBody(KJoint[] joints) {
  drawBone(joints, KinectPV2.JointType_Head, KinectPV2.JointType_Neck);
  drawBone(joints, KinectPV2.JointType_Neck, KinectPV2.JointType_SpineShoulder);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_SpineMid);
  drawBone(joints, KinectPV2.JointType_SpineMid, KinectPV2.JointType_SpineBase);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_ShoulderRight);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_ShoulderLeft);
  drawBone(joints, KinectPV2.JointType_SpineBase, KinectPV2.JointType_HipRight);
  drawBone(joints, KinectPV2.JointType_SpineBase, KinectPV2.JointType_HipLeft);

  // Right Arm    
  drawBone(joints, KinectPV2.JointType_ShoulderRight, KinectPV2.JointType_ElbowRight);
  drawBone(joints, KinectPV2.JointType_ElbowRight, KinectPV2.JointType_WristRight);
  drawBone(joints, KinectPV2.JointType_WristRight, KinectPV2.JointType_HandRight);
  drawBone(joints, KinectPV2.JointType_HandRight, KinectPV2.JointType_HandTipRight);
  drawBone(joints, KinectPV2.JointType_WristRight, KinectPV2.JointType_ThumbRight);

  // Left Arm
  drawBone(joints, KinectPV2.JointType_ShoulderLeft, KinectPV2.JointType_ElbowLeft);
  drawBone(joints, KinectPV2.JointType_ElbowLeft, KinectPV2.JointType_WristLeft);
  drawBone(joints, KinectPV2.JointType_WristLeft, KinectPV2.JointType_HandLeft);
  drawBone(joints, KinectPV2.JointType_HandLeft, KinectPV2.JointType_HandTipLeft);
  drawBone(joints, KinectPV2.JointType_WristLeft, KinectPV2.JointType_ThumbLeft);

  // Right Leg
  drawBone(joints, KinectPV2.JointType_HipRight, KinectPV2.JointType_KneeRight);
  drawBone(joints, KinectPV2.JointType_KneeRight, KinectPV2.JointType_AnkleRight);
  drawBone(joints, KinectPV2.JointType_AnkleRight, KinectPV2.JointType_FootRight);

  // Left Leg
  drawBone(joints, KinectPV2.JointType_HipLeft, KinectPV2.JointType_KneeLeft);
  drawBone(joints, KinectPV2.JointType_KneeLeft, KinectPV2.JointType_AnkleLeft);
  drawBone(joints, KinectPV2.JointType_AnkleLeft, KinectPV2.JointType_FootLeft);

  drawJoint(joints, KinectPV2.JointType_HandTipLeft);
  drawJoint(joints, KinectPV2.JointType_HandTipRight);
  drawJoint(joints, KinectPV2.JointType_FootLeft);
  drawJoint(joints, KinectPV2.JointType_FootRight);
  drawJoint(joints, KinectPV2.JointType_ThumbLeft);
  drawJoint(joints, KinectPV2.JointType_ThumbRight);
  drawJoint(joints, KinectPV2.JointType_Head);
}

void drawJoint(KJoint[] joints, int jointType) {
  pushMatrix();
  translate(joints[jointType].getX(), joints[jointType].getY(), joints[jointType].getZ());
  ellipse(0, 0, 25, 25);
  popMatrix();
}

void drawBone(KJoint[] joints, int jointType1, int jointType2) {
  pushMatrix();
  translate(joints[jointType1].getX(), joints[jointType1].getY(), joints[jointType1].getZ());
  ellipse(0, 0, 25, 25);
  popMatrix();
  line(joints[jointType1].getX(), joints[jointType1].getY(), joints[jointType1].getZ(), 
       joints[jointType2].getX(), joints[jointType2].getY(), joints[jointType2].getZ());
}

void drawHandState(KJoint joint) {
  noStroke();
  handState(joint.getState());
  pushMatrix();
  translate(joint.getX(), joint.getY(), joint.getZ());
  ellipse(0, 0, 70, 70);
  popMatrix();
}

void handState(int handState) {
  switch(handState) {
  case KinectPV2.HandState_Open:
    fill(0, 255, 0);
    break;
  case KinectPV2.HandState_Closed:
    fill(255, 0, 0);
    break;
  case KinectPV2.HandState_Lasso:
    fill(0, 0, 255);
    break;
  case KinectPV2.HandState_NotTracked:
    fill(255, 255, 255);
    break;
  }
}

void mousePressed() {
  if (!isScattering) {
    scatterStartTime = millis();
    isScattering = true;
  } else {
    isScattering = false;
    revertParticleStates();
  }
}

void resetAllStates() {
  isScattering = false;
  isPatternFlow = false;
  autoModeActive = false;
  revertParticleStates();
}

void revertParticleStates() {
  for (Particle p : particles) {
    p.revertToOriginalState();
  }
}

PVector getFlowDirection(float x, float y) {
  float angle = noise(x * 0.002, y * 0.002, frameCount * 0.01) * TWO_PI * 4;
  return new PVector(cos(angle), sin(angle));
}

// Enhanced Particle class with smooth transitions
class Particle {
  PVector position, velocity, acceleration, targetPosition;
  PVector originalPosition, originalVelocity;
  color baseColor;
  color currentColor;
  boolean grouped = false;
  boolean groupable;
  float baseSpeed;
  Particle groupLeader = null;
  ArrayList<Particle> groupMembers = new ArrayList<>();

  boolean isReturning = false;
  boolean inCursorMode = false;
  float cursorModeLerp = 0;

  boolean inDefaultMode = false;
  float transitionLerp = 0.0;
  boolean isTransitioning = false;

  float cursorSizeMultiplier = 1.0;
  float baseSizeMultiplier = 1.0;
  
  // Trail system for default mode
  ArrayList<PVector> trail = new ArrayList<PVector>();
  int maxTrailLength = 15; // Reduced for better performance
  float trailDecay = 0.95;
  
  // Smooth transition variables
  PVector transitionStartPos;
  PVector transitionTargetPos;
  float transitionStartTime;

  Particle() {
    position = new PVector(random(width), random(height));
    originalPosition = new PVector(position.x, position.y);
    baseSpeed = random(1, 2.5);
    velocity = PVector.random2D().mult(baseSpeed);
    originalVelocity = velocity.copy();
    acceleration = new PVector(0, 0);
    baseColor = color(random(255), random(255), random(255));
    currentColor = baseColor;
    baseSizeMultiplier = random(0.8, 1.2);
    targetPosition = position.copy();
    groupable = random(1) < 0.7;
    transitionStartPos = position.copy();
    transitionTargetPos = position.copy();
  }

  void setTransitionState(float globalTransitionLerp, boolean targetIsDefaultMode) {
    transitionLerp = globalTransitionLerp;
    inDefaultMode = targetIsDefaultMode;
    isTransitioning = globalTransitionLerp > 0.0 && globalTransitionLerp < 1.0;
  }

  void enterCursorMode() {
    inCursorMode = true;
  }

  void exitCursorMode() {
    inCursorMode = false;
  }

  void prepareForDefaultMode() {
    transitionStartPos = position.copy();
    // Clear existing trail when transitioning
    trail.clear();
  }
  
  void prepareForPatternFlow() {
    transitionStartPos = position.copy();
    // Gradually clear trail when transitioning back
    if (trail.size() > 5) {
      for (int i = 0; i < 3; i++) {
        if (trail.size() > 0) trail.remove(0);
      }
    }
  }

  void scatterRandomly() {
    applyForce(PVector.random2D().mult(5));
  }

  void revertToOriginalState() {
    velocity.mult(0.7); // Smoother slowdown
    currentColor = baseColor;
    cursorSizeMultiplier = 1.0;
    // Gradually clear trail
    if (trail.size() > 0) {
      trail.remove(0);
    }
  }

  void update(int index) {
    if (inCursorMode && cursorModeLerp < 1.0) cursorModeLerp += 0.01;
    else if (!inCursorMode && cursorModeLerp > 0.0) cursorModeLerp -= 0.01;
    cursorModeLerp = constrain(cursorModeLerp, 0.0, 1.0);

    // Handle trail updates based on transition state
    if (transitionLerp > 0.5) { // In default mode or transitioning to it
      // Add current position to trail
      trail.add(new PVector(position.x, position.y));
      
      // Remove old trail positions with smooth reduction
      int targetTrailLength = (int)map(transitionLerp, 0.5, 1.0, 5, maxTrailLength);
      while (trail.size() > targetTrailLength) {
        trail.remove(0);
      }
      
      // Apply default mode movement
      updateDefaultMovement();
    } else {
      // Gradually reduce trail when transitioning back to pattern flow
      if (trail.size() > 0 && frameCount % 2 == 0) {
        trail.remove(0);
      }
    }

    // Apply pattern flow behavior with transition blending
    if (transitionLerp < 1.0) {
      updatePatternFlowMovement(index);
    }

    // Blend movements based on transition state
    velocity.add(acceleration);
    
    // Adjust velocity limits based on mode
    float maxVel = lerp(baseSpeed + 0.5, 4.0, transitionLerp);
    velocity.limit(maxVel);

    position.add(velocity);
    acceleration.mult(0);

    handleEdges();
    updateColor();
  }
  
  void updateDefaultMovement() {
    // Smooth flowing motion for default mode
    float angle = noise(position.x * 0.008, position.y * 0.008, frameCount * 0.003) * TWO_PI * 2;
    PVector flowForce = new PVector(cos(angle), sin(angle));
    flowForce.mult(0.4 * transitionLerp); // Scale by transition amount
    acceleration.add(flowForce);
    
    // Add some gentle randomness
    acceleration.add(PVector.random2D().mult(0.1 * transitionLerp));
  }
  
  void updatePatternFlowMovement(int index) {
    float patternStrength = 1.0 - transitionLerp;
    
    if (frameCount % 2 == index % 2 && random(1) < GROUP_CHANCE * patternStrength) {
      groupParticles();
    }

    handleGroupBehavior();

    float noiseStrength = lerp(0.02, 0.1, 1.0 - cursorModeLerp) * patternStrength;
    acceleration.add(PVector.random2D().mult(noiseStrength));

    if (frameCount % 60 == 0 && random(1) < 0.05 * patternStrength) {
      velocity.rotate(random(-PI / 12, PI / 12));
    }
  }

  void handleGroupBehavior() {
    if (groupLeader != null) {
      PVector attraction = PVector.sub(groupLeader.position, position);
      attraction.setMag(1.5 * (1.0 - transitionLerp)); // Reduce during transition
      acceleration.add(attraction);

      for (Particle other : groupMembers) {
        if (other != this) {
          PVector repulsion = PVector.sub(position, other.position);
          float distSq = repulsion.magSq();
          if (distSq < sq(GROUP_RADIUS)) {
            repulsion.setMag(REPEL_STRENGTH * (1.0 - transitionLerp));
            acceleration.add(repulsion);
          }
        }
      }
    }
  }

  void handleEdges() {
    float leftDist = position.x;
    float rightDist = width - position.x;
    float topDist = position.y;
    float bottomDist = height - position.y;

    if (leftDist < EDGE_MARGIN) acceleration.x += map(leftDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (rightDist < EDGE_MARGIN) acceleration.x -= map(rightDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (topDist < EDGE_MARGIN) acceleration.y += map(topDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);
    if (bottomDist < EDGE_MARGIN) acceleration.y -= map(bottomDist, 0, EDGE_MARGIN, EDGE_FORCE, 0);

    position.x = constrain(position.x, 1, width - 1);
    position.y = constrain(position.y, 1, height - 1);
  }

  void updateColor() {
    if (groupLeader != null) {
      currentColor = lerpColor(groupLeader.baseColor, baseColor, transitionLerp);
    } else {
      currentColor = baseColor;
    }
  }

  void display() {
    // Draw trail with transition-aware opacity
    if (trail.size() >= 2 && transitionLerp > 0.3) {
      drawTrail();
    }
    
    float cursorDist = dist(position.x, position.y, mouseX, mouseY);
    float cursorInfluence = constrain(map(cursorDist, 0, 100, 1, 0), 0, 1);
    cursorInfluence *= (1.0 - transitionLerp); // Reduce cursor influence during transition
    float proximityBoost = map(cursorInfluence, 0, 1, 1, 2);

    // Adjust stroke weight based on mode and transition
    float weight = lerp(
      lerp(2, 5, cursorModeLerp), // pattern flow weight
      random(1.5, 3.5), // default mode weight
      transitionLerp
    );
    weight *= proximityBoost;
    strokeWeight(weight);

    color col = currentColor;
    col = lerpColor(col, color(255, 100, 0), cursorInfluence);

    stroke(col);
    point(position.x, position.y);
  }
  
  void drawTrail() {
    if (trail.size() < 2) return;
    
    float trailOpacity = map(transitionLerp, 0.3, 1.0, 0.3, 1.0);
    
    for (int i = 1; i < trail.size(); i++) {
      PVector current = trail.get(i);
      PVector previous = trail.get(i - 1);
      
      // Calculate trail opacity based on position in trail (newer = more opaque)
      float segmentAlpha = map(i, 0, trail.size() - 1, 30, 180) * trailOpacity;
      
      // Calculate stroke weight that gets thinner towards the tail
      float trailWeight = map(i, 0, trail.size() - 1, 0.5, 2.5);
      
      // Set color with alpha for trail effect
      color trailColor = color(red(baseColor), green(baseColor), blue(baseColor), segmentAlpha);
      stroke(trailColor);
      strokeWeight(trailWeight);
      
      // Draw line segment
      line(previous.x, previous.y, current.x, current.y);
    }
  }

  void applyForce(PVector f) {
    PVector force = f.copy();
    // Scale forces during transition
    if (isTransitioning) {
      force.mult(1.0 - transitionLerp * 0.5); // Reduce external forces during transition
    }
    acceleration.add(force);
  }

  void scatter() {
    velocity = PVector.random2D().mult(baseSpeed * 3);
    if (groupable) {
      groupLeader = null;
      grouped = false;
      groupMembers.clear();
    }
    // Clear trail when scattering
    trail.clear();
  }

  void groupParticles() {
    for (Particle other : particles) {
      if (other != this) {
        float dist = position.dist(other.position);
        if (dist < GROUP_RADIUS) {
          if (groupLeader == null && other.groupLeader == null && random(1) < GROUP_CHANCE) {
            groupLeader = this;
            grouped = true;
            groupMembers.add(this);
          }

          if (groupLeader == null && other.groupLeader != null) {
            groupLeader = other.groupLeader;
            grouped = true;
            groupMembers = other.groupMembers;
            if (!groupMembers.contains(this)) groupMembers.add(this);
          }

          if (groupLeader == this && !groupMembers.contains(other) && random(1) < GROUP_CHANCE) {
            other.groupLeader = this;
            other.grouped = true;
            other.groupMembers = this.groupMembers;
            groupMembers.add(other);
          }

          PVector spring = PVector.sub(other.position, position);
          spring.setMag(0.6 * (1.0 - transitionLerp)); // Reduce spring force during transition
          acceleration.add(spring);
        }
      }
    }
  }
}
