/**
 * HSVColorTrackingKinect
 * Greg Borenstein
 * https://github.com/atduskgreg/opencv-processing-book/blob/master/code/hsv_color_tracking/HSVColorTracking/HSVColorTracking.pde
 *
 * Modified by Jordi Tost @jorditost (color selection + kinect rgb image)
 */
 
import SimpleOpenNI.*;
import gab.opencv.*;
import java.awt.Rectangle;

SimpleOpenNI kinect;
OpenCV opencv;
ArrayList<Contour> contours;

// <1> Set the range of Hue values for our filter
int rangeLow = 150;
int rangeHigh = 160;

void setup() {
  
  kinect = new SimpleOpenNI(this);
  kinect.enableRGB();
  
  opencv = new OpenCV(this, 640, 480);
  size(opencv.width, opencv.height, P2D);
  contours = new ArrayList<Contour>();
}

void draw() {
  
  kinect.update();
  
  image(kinect.rgbImage(), 0, 0);

  // <2> Load the new frame of our movie in to OpenCV
  opencv.loadImage(kinect.rgbImage());
  
  // <3> Tell OpenCV to work in HSV color space.
  opencv.useColor(HSB);
  
  // <4> Copy the Hue channel of our image into 
  //     the gray channel, which we process.
  opencv.setGray(opencv.getH().clone());
  
  // <5> Filter the image based on the range of 
  //     hue values that match the object we want to track.
  opencv.inRange(rangeLow, rangeHigh);
  
  //opencv.dilate();
  opencv.erode();
  
  // <6> Display the processed image for reference.
  image(opencv.getOutput(), 3*width/4, 3*height/4, width/4, height/4);
  
  // <7> Find contours in our range image.
  //     Passing 'true' sorts them by descending area.
  contours = opencv.findContours(true,true);
  
  // <8> Check to make sure we've found any contours
  if (contours.size() > 0) {
  
    // <9> Get the first contour, which will be the largest one
    Contour biggestContour = contours.get(0);
  
    // <10> Find the bounding box of the largest contour,
    //      and hence our object.
    Rectangle r = biggestContour.getBoundingBox();
  
    // <11> Draw the bounding box of our object
    noFill(); 
    strokeWeight(2); 
    stroke(255, 0, 0);
    rect(r.x, r.y, r.width, r.height);
    // <12> Draw a dot in the middle of the bounding box, on the object.
    noStroke(); 
    fill(255, 0, 0);
    ellipse(r.x + r.width/2, r.y + r.height/2, 30, 30);
  }
}

void mousePressed() {
  
  color c = get(mouseX, mouseY);
  println("r: " + red(c) + " g: " + green(c) + " b: " + blue(c));
   
  int hue = int(map(hue(c), 0, 255, 0, 180));
  println("hue to detect: " + hue);
  
  rangeLow = hue - 5;
  rangeHigh = hue + 5;
}
