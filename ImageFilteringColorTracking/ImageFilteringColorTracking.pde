/**
 * ImageFilteringColorTracking
 * This sketch will help us to adjust the filter values to optimize blob detection
 * 
 * Persistence algorithm by Daniel Shifmann:
 * http://shiffman.net/2011/04/26/opencv-matching-faces-over-time/
 *
 * It uses the OpenCV for Processing library by Greg Borenstein
 * https://github.com/atduskgreg/opencv-processing
 *
 * @author: Jordi Tost (@jorditost)
 *
 * Simple version with less filter options here: 
 * https://github.com/jorditost/ImageFiltering/tree/master/ImageFilteringWithBlobPersistence
 *
 * University of Applied Sciences Potsdam, 2014
 */
 
import gab.opencv.*;
import java.awt.Rectangle;
import processing.video.*;
import SimpleOpenNI.*;
import controlP5.*;

// Image source
static int IMAGE_SRC = 0;
static int CAPTURE   = 1;
static int KINECT    = 2;
int source = IMAGE_SRC;

public static final int GRAY = 0;
public static final int S    = 1;

OpenCV opencv;
Capture video;
SimpleOpenNI kinect;
PImage src, preProcessedImage, processedImage, contoursImage;

ArrayList<Contour> contours;

// <1> Set the range of Hue values for our filter
boolean changeColor = false;
int rangeLow = 20;
int rangeHigh = 35;

// List of detected contours parsed as blobs (every frame)
ArrayList<Contour> newBlobContours;

// List of my blob objects (persistent)
ArrayList<Blob> blobList;

// Number of blobs detected over all time. Used to set IDs.
int blobCount = 0;

// Detection params
//float contrast = 1;
//int brightness = 0;
int threshold = 75;
boolean useAdaptiveThreshold = false; // use basic thresholding
int thresholdBlockSize = 500; //489;
int thresholdConstant = -20; //45;
boolean dilate = false;
boolean erode = true;
int blurSize = 1;
boolean useThresholdAfterBlur = false;
int thresholdAfterBlur = 75;
int minBlobSize = 20;
int maxBlobSize = 400;

// Control vars
ControlP5 cp5;
int buttonColor;
int buttonBgColor;

void setup() {
  frameRate(15);
  
  // IMAGE_SRC
  if (source == IMAGE_SRC) {
    src = loadImage("data/after4.jpg");
    opencv = new OpenCV(this, src);
    
  // CAPTURE
  } else if (source == CAPTURE) {
    printCameras();
    video = new Capture(this, 640, 480, "USB 2.0 Camera");
    video.start();
    opencv = new OpenCV(this, video.width, video.height);
  
  // KINECT
  } else if (source == KINECT) {
    kinect = new SimpleOpenNI(this);
    kinect.enableRGB();
    opencv = new OpenCV(this, 640, 480);
  }
  
  contours = new ArrayList<Contour>();
  
  // Blobs list
  blobList = new ArrayList<Blob>();
  
  size(opencv.width + 200, opencv.height);
  
  // Init Controls
  cp5 = new ControlP5(this);
  initControls();
  
  // Set thresholding
  toggleAdaptiveThreshold(useAdaptiveThreshold);
  toggleThresholdAfterBlur(useThresholdAfterBlur);
}

void draw() {
  
  // IMAGE
  if (source == IMAGE_SRC) {
    
    opencv.loadImage(src);
  
  // CAPTURE
  } else if (source == CAPTURE && video != null) {
    if (video.available()) {
      video.read();
    }
    
    // Load the new frame of our camera in to OpenCV
    opencv.loadImage(video);
    src = opencv.getSnapshot();
  
  // KINECT
  } else if (source == KINECT && kinect != null) {
    kinect.update();
    
    // Load the new frame of our camera in to OpenCV
    opencv.loadImage(kinect.rgbImage());
    src = opencv.getSnapshot();
  }
  
  /////////////////////
  /////////////////////
  // Check detect!!!
  /////////////////////
  /////////////////////
  
  detect();
  
  // Draw
  pushMatrix();
    
    // Leave space for ControlP5 sliders
    translate(width-src.width, 0);
    
    // Display images
    displayImages();
    
    // Display contours in the lower right window
    pushMatrix();
      scale(0.5);
      translate(src.width, src.height);
      
      // Contours
      //displayContours();
      //displayContoursBoundingBoxes();
      
      // Blobs
      displayBlobs();
      
    popMatrix(); 
    
  popMatrix();
  
  // Print text if new color expected
  textSize(18);
  stroke(255,0,0);
  fill(255,0,0);
  
  text("press the key 'R' and", 10, height-40);
  text("click to select a color", 10, height-20);
}

////////////////////
// Blob Detection
////////////////////

void detect() {
  
  println("detect - " + random(0,100));
  opencv.useColor();
  
  ///////////////////////////////
  // <1> SELECT COLOR
  ///////////////////////////////
  
  // <3> Tell OpenCV to work in HSV color space.
  opencv.useColor(HSB);
  
  // <4> Copy the Hue channel of our image into 
  //     the gray channel, which we process.
  opencv.setGray(opencv.getH().clone());
  
  // <5> Filter the image based on the range of 
  //     hue values that match the object we want to track.
  opencv.inRange(rangeLow, rangeHigh);
  
  //opencv.brightness(brightness);
  /*if (contrast > 1) {
    opencv.contrast(contrast);
  }*/
  
  // Save snapshot for display
  preProcessedImage = opencv.getSnapshot();
  
  ///////////////////////////////
  // <2> PROCESS IMAGE
  // - Threshold
  // - Noise Supression
  ///////////////////////////////
    
  // Adaptive threshold - Good when non-uniform illumination
  if (useAdaptiveThreshold) {
    
    // Block size must be odd and greater than 3
    if (thresholdBlockSize%2 == 0) thresholdBlockSize++;
    if (thresholdBlockSize < 3) thresholdBlockSize = 3;
    
    opencv.adaptiveThreshold(thresholdBlockSize, thresholdConstant);
    
  // Basic threshold - range [0, 255]
  } else {
    opencv.threshold(threshold);
  }
  
  // Reduce noise - Dilate and erode to close holes
  if (dilate) opencv.dilate();
  if (erode)  opencv.erode();
  
  // Blur
  if (blurSize > 1) {
    opencv.blur(blurSize);
  }
  
  if (useThresholdAfterBlur) {
    opencv.threshold(thresholdAfterBlur);
  }
  
  // Save snapshot for display
  processedImage = opencv.getSnapshot();
  
  ///////////////////////////////
  // <3> FIND CONTOURS  
  ///////////////////////////////
  
  detectBlobs();
  // Passing 'true' sorts them by descending area.
  //contours = opencv.findContours(true, true);
  
  // Save snapshot for display
  contoursImage = opencv.getSnapshot();
}

void detectBlobs() {
  
  // Contours detected in this frame
  // Passing 'true' sorts them by descending area.
  contours = opencv.findContours(true, true);
  
  newBlobContours = getBlobsFromContours(contours);
  
  //println(contours.length);
  
  // Check if the detected blobs already exist, are new, or some has disappeared. 
  
  blobPersistence();
}

void blobPersistence() {
  // SCENARIO 1 
  // blobList is empty
  if (blobList.isEmpty()) {
    // Just make a Blob object for every face Rectangle
    for (int i = 0; i < newBlobContours.size(); i++) {
      //println("+++ New blob detected with ID: " + blobCount);
      blobList.add(new Blob(this, blobCount, newBlobContours.get(i)));
      blobCount++;
    }
  
  // SCENARIO 2 
  // We have fewer Blob objects than face Rectangles found from OpenCV in this frame
  } else if (blobList.size() <= newBlobContours.size()) {
    boolean[] used = new boolean[newBlobContours.size()];
    // Match existing Blob objects with a Rectangle
    for (Blob b : blobList) {
       // Find the new blob newBlobContours.get(index) that is closest to blob b
       // set used[index] to true so that it can't be used twice
       float record = 50000;
       int index = -1;
       for (int i = 0; i < newBlobContours.size(); i++) {
         float d = dist(newBlobContours.get(i).getBoundingBox().x, newBlobContours.get(i).getBoundingBox().y, b.getBoundingBox().x, b.getBoundingBox().y);
         //float d = dist(blobs[i].x, blobs[i].y, b.r.x, b.r.y);
         if (d < record && !used[i]) {
           record = d;
           index = i;
         } 
       }
       // Update Blob object location
       used[index] = true;
       b.update(newBlobContours.get(index));
    }
    // Add any unused blobs
    for (int i = 0; i < newBlobContours.size(); i++) {
      if (!used[i]) {
        //println("+++ New blob detected with ID: " + blobCount);
        blobList.add(new Blob(this, blobCount, newBlobContours.get(i)));
        //blobList.add(new Blob(blobCount, blobs[i].x, blobs[i].y, blobs[i].width, blobs[i].height));
        blobCount++;
      }
    }
  
  // SCENARIO 3 
  // We have more Blob objects than blob Rectangles found from OpenCV in this frame
  } else {
    // All Blob objects start out as available
    for (Blob b : blobList) {
      b.available = true;
    } 
    // Match Rectangle with a Blob object
    for (int i = 0; i < newBlobContours.size(); i++) {
      // Find blob object closest to the newBlobContours.get(i) Contour
      // set available to false
       float record = 50000;
       int index = -1;
       for (int j = 0; j < blobList.size(); j++) {
         Blob b = blobList.get(j);
         float d = dist(newBlobContours.get(i).getBoundingBox().x, newBlobContours.get(i).getBoundingBox().y, b.getBoundingBox().x, b.getBoundingBox().y);
         //float d = dist(blobs[i].x, blobs[i].y, b.r.x, b.r.y);
         if (d < record && b.available) {
           record = d;
           index = j;
         } 
       }
       // Update Blob object location
       Blob b = blobList.get(index);
       b.available = false;
       b.update(newBlobContours.get(i));
    } 
    // Start to kill any left over Blob objects
    for (Blob b : blobList) {
      if (b.available) {
        b.countDown();
        if (b.dead()) {
          b.delete = true;
        } 
      }
    } 
  }
  
  // Delete any blob that should be deleted
  for (int i = blobList.size()-1; i >= 0; i--) {
    Blob b = blobList.get(i);
    if (b.delete) {
      blobList.remove(i);
    } 
  }
}

ArrayList<Contour> getBlobsFromContours(ArrayList<Contour> newContours) {
  
  ArrayList<Contour> newBlobs = new ArrayList<Contour>();
  
  for (Contour contour : newContours) {
      
    Rectangle r = contour.getBoundingBox();
    
    if (//(float(r.width)/float(displayWidth) > 0.3 || float(r.height)/float(displayWidth) > 0.3) ||
        (r.width > maxBlobSize || r.height > maxBlobSize) ||
        (r.width < minBlobSize && r.height < minBlobSize))
      continue;
    
    newBlobs.add(contour);
  }
  
  return newBlobs;
}

///////////////////////
// Display Functions
///////////////////////

void displayImages() {
  
  pushMatrix();
  scale(0.5);
  image(src, 0, 0);
  image(preProcessedImage, src.width, 0);
  image(processedImage, 0, src.height);
  image(src, src.width, src.height);
  popMatrix();
  
  stroke(255);
  fill(255);
  textSize(12);
  text("Source", 10, 25); 
  text("After color filtering", src.width/2 + 10, 25); 
  text("Processed Image", 10, src.height/2 + 25); 
  text("Tracked Points", src.width/2 + 10, src.height/2 + 25);
}

void displayBlobs() {
  
  for (Blob b : blobList) {
    strokeWeight(1);
    b.display();
  }
}

void displayContours() {
  
  // Contours
  for (int i=0; i<contours.size(); i++) {
  
    Contour contour = contours.get(i);
    
    noFill();
    stroke(0, 255, 0);
    strokeWeight(3);
    contour.draw();
  }
}

void displayContoursBoundingBoxes() {
  
  for (int i=0; i<contours.size(); i++) {
    
    Contour contour = contours.get(i);
    Rectangle r = contour.getBoundingBox();
    
    if (//(r.width < minBlobSize || r.height < minBlobSize))
        (r.width > maxBlobSize || r.height > maxBlobSize) ||
        (r.width < minBlobSize && r.height < minBlobSize))
      continue;
    
    stroke(255, 0, 0);
    fill(255, 0, 0, 150);
    strokeWeight(2);
    rect(r.x, r.y, r.width, r.height);
  }
}

//////////////////////////
// CONTROL P5 Functions
//////////////////////////

void initControls() {
  
  // Slider for contrast
  /*cp5.addSlider("contrast")
     .setLabel("contrast")
     .setPosition(20,90)
     .setRange(0.0,6.0)
     ;*/
     
  // Slider for threshold
  cp5.addSlider("threshold")
     .setLabel("threshold")
     .setPosition(20,140)
     .setRange(0,255)
     ;
  
  // Toggle to activae adaptive threshold
  /*cp5.addCheckBox("checkAdaptiveThreshold")
     .setSize(10,10)
     .setPosition(20,204)
     .setItemsPerRow(2)
     .setSpacingColumn(50)
     .addItem("useAdaptiveThreshold", 0)
     ;*/
  cp5.addToggle("toggleAdaptiveThreshold")
     .setLabel("use adaptive threshold")
     .setSize(10,10)
     .setPosition(20,164)
     ;
     
  // Slider for adaptive threshold block size
  cp5.addSlider("thresholdBlockSize")
     .setLabel("a.t. block size")
     .setPosition(20,200)
     .setRange(1,700)
     ;
     
  // Slider for adaptive threshold constant
  cp5.addSlider("thresholdConstant")
     .setLabel("a.t. constant")
     .setPosition(20,220)
     .setRange(-100,100)
     ;
  
  // Dilate / Erode selection
  cp5.addCheckBox("toggleDilateErode")
     .setSize(10,10)
     .setPosition(20,270)
     .setItemsPerRow(2)
     .setSpacingColumn(50)
     .addItem("dilate", 0)
     .addItem("erode", 1)
     ;
     
  // Slider for blur size
  cp5.addSlider("blurSize")
     .setLabel("blur size")
     .setPosition(20,290)
     .setRange(1,20)
     ;
     
  // Threshold after blur
  /*cp5.addCheckBox("checkThresholdAfterBlur")
     .setSize(10,10)
     .setPosition(20,340)
     .setItemsPerRow(2)
     .setSpacingColumn(50)
     .addItem("useThresholdAfterBlur", 0)
     ;*/
  cp5.addToggle("toggleThresholdAfterBlur")
     .setLabel("use threshold after blur")
     .setSize(10,10)
     .setPosition(20,314)
     ;
     
  // Slider for threshold after blur
  cp5.addSlider("thresholdAfterBlur")
     .setLabel("threshold")
     .setPosition(20,350)
     .setRange(0,255)
     ;
     
  // Slider for minimal blob size
  cp5.addSlider("minBlobSize")
     .setLabel("min blob size")
     .setPosition(20,400)
     .setRange(0,60)
     ;
     
  // Slider for maximal blob size
  cp5.addSlider("maxBlobSize")
     .setLabel("max blob size")
     .setPosition(20,420)
     .setRange(100,800)
     ;
     
  // Store the default background color, we gonna need it later
  //buttonColor = cp5.getController("contrast").getColor().getForeground();
  //buttonBgColor = cp5.getController("contrast").getColor().getBackground();
}

void toggleDilateErode(float[] a) {
  dilate = (a[0] == 1);
  erode  = (a[1] == 1);
  
  println("dilate: " + dilate);
  println("erode: " + erode);
}

void toggleThresholdAfterBlur(boolean theFlag) {
  useThresholdAfterBlur = theFlag;
  
  if (useThresholdAfterBlur) {
    setLock(cp5.getController("thresholdAfterBlur"), false);
  } else {
    setLock(cp5.getController("thresholdAfterBlur"), true);
  }
}

void toggleAdaptiveThreshold(boolean theFlag) {
  
  useAdaptiveThreshold = theFlag;
  
  if (useAdaptiveThreshold) {
    
    // Lock basic threshold
    setLock(cp5.getController("threshold"), true);
       
    // Unlock adaptive threshold
    setLock(cp5.getController("thresholdBlockSize"), false);
    setLock(cp5.getController("thresholdConstant"), false);
       
  } else {
    
    // Unlock basic threshold
    setLock(cp5.getController("threshold"), false);
       
    // Lock adaptive threshold
    setLock(cp5.getController("thresholdBlockSize"), true);
    setLock(cp5.getController("thresholdConstant"), true);
  }
}

void setLock(Controller theController, boolean theValue) {
  
  theController.setLock(theValue);
  
  if (theValue) {
    theController.setColorBackground(color(150,150));
    theController.setColorForeground(color(100,100));
  
  } else {
    theController.setColorBackground(color(buttonBgColor));
    theController.setColorForeground(color(buttonColor));
  }
}

//////////////////
// Mouse Events
//////////////////

void mousePressed() {
  
  if (changeColor) {
    color c = get(mouseX, mouseY);
    println("r: " + red(c) + " g: " + green(c) + " b: " + blue(c));
     
    int hue = int(map(hue(c), 0, 255, 0, 180));
    println("hue to detect: " + hue);
    
    rangeLow = hue - 5;
    rangeHigh = hue + 5;
  }
}

void keyPressed() {
  if (key == 'r') {
    changeColor = true;
  }
}

void keyReleased() {
  changeColor = false;
}

//////////////////
// Camera Utils
//////////////////

void printCameras() {
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
  }
}
