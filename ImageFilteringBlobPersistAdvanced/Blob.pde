/**
 * Blob Class
 *
 * Based on this example by Daniel Shiffman:
 * http://shiffman.net/2011/04/26/opencv-matching-faces-over-time/
 * 
 * @author: Jordi Tost @jorditost
 * @modified: 06/10/2014
 * 
 * University of Applied Sciences Potsdam, 2014
 */

class Blob {
  
  private PApplet parent;
  
  // Contour
  public Contour contour;
  
  // Am I available to be matched?
  public boolean available;
  
  // Should I be deleted?
  public boolean delete;
  
  // How long should I live if I have disappeared?
  private int persistence = 5; //127;
  public int timer;
  
  // Unique ID for each blob
  int id;
  
  // Make me
  Blob(PApplet parent, int id, Contour c) {
    this.parent = parent;
    this.id = id;
    this.contour = new Contour(parent, c.pointMat);
    
    available = true;
    delete = false;
    
    timer = persistence;
  }
  
  // Show me
  void display() {
    Rectangle r = contour.getBoundingBox();
    
    float opacity = map(timer, 0, persistence, 0, 127);
    fill(0,0,255,opacity);
    stroke(0,0,255);
    rect(r.x, r.y, r.width, r.height);
    fill(255,2*opacity);
    textSize(26);
    text(""+id, r.x+10, r.y+30);
  }
  
  void drawContour() {
    float opacity = map(timer, 0, persistence, 0, 127);
    noFill();
    stroke(0,255,0);
    contour.draw();
  }

  // Give me a new contour for this blob (shape, points, location, size)
  // Oooh, it would be nice to lerp here!
  void update(Contour newC) {
    
    contour = new Contour(parent, newC.pointMat);
    
    // Is there a way to update the contour's points without creating a new one?
    /*ArrayList<PVector> newPoints = newC.getPoints();
    Point[] inputPoints = new Point[newPoints.size()];
    
    for(int i = 0; i < newPoints.size(); i++){
      inputPoints[i] = new Point(newPoints.get(i).x, newPoints.get(i).y);
    }
    contour.loadPoints(inputPoints);*/
    
    timer = persistence;
  }

  // Count me down, I am gone
  void countDown() {    
    timer--;
  }

  // I am deed, delete me
  boolean dead() {
    if (timer < 0) return true;
    return false;
  }
  
  public Rectangle getBoundingBox() {
    return contour.getBoundingBox();
  }
}

