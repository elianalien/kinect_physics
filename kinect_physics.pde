
// Kinect Physics by Amnon Owed (15/09/12)
// edited by Arindam Sen
// edited by Elian Daiva (4/11/2014) 
// ********all right reserved************
 
// import libraries
import processing.video.*;
//import processing.opengl.*; // opengl
import SimpleOpenNI.*; // kinect
import blobDetection.*; // blobs
import toxi.geom.*; // toxiclibs shapes and vectors
import toxi.processing.*; // toxiclibs display
import shiffman.box2d.*; // shiffman's jbox2d helper library
import org.jbox2d.collision.shapes.*; // jbox2d
import org.jbox2d.dynamics.joints.*;
import org.jbox2d.common.*; // jbox2d
import org.jbox2d.dynamics.*; // jbox2d

/////////////////////////////////////////////////////////////////////////////////////////////////////
SimpleOpenNI context; // declare SimpleOpenNI object
BlobDetection theBlobDetection; // declare BlobDetection object
ToxiclibsSupport gfx; // ToxiclibsSupport for displaying polygons
PolygonBlob poly; // declare custom PolygonBlob object (see class for more info)
/////////////////////////////////////////////////////////////////////////////////////////////////////
PImage blobs; // PImage to hold incoming imagery and smaller one for blob detection
PImage pipa;
Movie fire, asep, volcano;
/////////////////////////////////////////////////////////////////////////////////////////////////////
int kinectWidth = 640; // the kinect's dimensions to be used later on for calculations
int kinectHeight = 480;
PImage cam = createImage(640, 480, RGB);
/////////////////////////////////////////////////////////////////////////////////////////////////////
float reScale; // Variable to center and rescale from 640x480 to higher custom resolutions
color bgColor, blobColor; // background and blob color
/////////////////////////////////////////////////////////////////////////////////////////////////////
// three color palettes (artifact from me storing many interesting color palettes as strings in an external data file ;-)
String[] palettes = {
  "-1117720,-13683658,-8410437,-9998215,-1849945,-5517090,-4250587,-14178341,-5804972,-3498634", 
  "-67879,-9633503,-8858441,-144382,-4996094,-16604779,-588031", 
  "-1978728,-724510,-15131349,-13932461,-4741770,-9232823,-3195858,-8989771,-2850983,-10314372"
};
color[] colorPalette;
///////////////////////////////////////////////////////////////////////////////////////////////////// 
Box2DProcessing box2d; // the main PBox2D object in which all the physics-based stuff is happening
ArrayList<CustomShape> polygons = new ArrayList<CustomShape>(); // polygon termasuk tipe ArrayList // list to hold all the custom shapes (circles, polygons)

void setup() {
  // it's possible to customize this, for example 1920x1080
  size(1080, 500, OPENGL); //default: 640, 480
  context = new SimpleOpenNI(this);
  //*********************************************************//
  pipa = loadImage("data/pipabend.png");
  pipa.resize(60,100);
  fire = new Movie(this, "api kecil.mov");
  fire.loop();
  volcano = new Movie(this, "Volcano.mov");
  volcano.loop();
  // initialize SimpleOpenNI object
  if (!context.enableDepth() || !context.enableUser()) { 
    println("Kinect not connected!"); 
    exit();
  } else {
    context.setMirror(true); // mirror kinect reading to be more intuitive    
    // calculate the reScale value
    // currently it's rescaled to fill the complete width (cuts of top-bottom)
    // it's also possible to fill the complete height (leaves empty sides)
    reScale = (float) width / kinectWidth;    
    // create a smaller blob image for speed and efficiency
    // PImage blobs;
    blobs = createImage(kinectWidth/3, kinectHeight/3, RGB); // default: kinectWidth/3, kinectHeight/3	
    // initialize blob detection object to the blob image dimensions
    // BlobDetection theBlobDetection;
    // ****************************************** Setting blob treshold ***************************************** //
    theBlobDetection = new BlobDetection(blobs.width, blobs.height);
    theBlobDetection.setThreshold(0.3); // defaults: 0.3

    // initialize ToxiclibsSupport object	
    gfx = new ToxiclibsSupport(this);
    
    box2d = new Box2DProcessing(this); // setup box2d
    box2d.createWorld();               // create world
    box2d.setGravity(0, -40);          // set gravity

    // set random colors (background, blob)
    setRandomColors(1);
    
    float gap = kinectWidth / 21;
    for (int i=0; i<20; i++)
    {
      drawString(gap * (i+1), 2, 10);
    }
  }
}

void draw() {
  image(volcano,0,0);//image(volcano,0,0,1280,720);
  image(pipa,0,-10);
  image(fire,800,200,300,300);
  
  context.update();
  cam = context.userImage();
  cam.loadPixels();
  color black = color(0,0,0);  
  
  for (int i=0; i<cam.pixels.length; i++)
  { 
    color pix = cam.pixels[i];
    int blue = pix & 0xff;
    if (blue == ((pix >> 8) & 0xff) && blue == ((pix >> 16) & 0xff))
    {
      cam.pixels[i] = black;
    }
  }   
  
  cam.updatePixels();
  
  // copy the image into the smaller blob image
  blobs.copy(cam, 0, 0, cam.width, cam.height, 0, 0, blobs.width, blobs.height);
  // blur the blob image
  blobs.filter(BLUR, 1);
  // detect the blobs
  theBlobDetection.computeBlobs(blobs.pixels);
  // initialize a new polygon
  poly = new PolygonBlob();
  // create the polygon from the blobs (custom functionality, see class)
  poly.createPolygon();
  // create the box2d body from the polygon
  poly.createBody();
  // update and draw everything (see method)
  updateAndDrawBox2D();
  // destroy the person's body (important!)
  poly.destroyBody();
  // set the colors randomly every 240th frame
  //setRandomColors(240)
   //flipHalf();
}

void drawString(float x, float size, int cards) {  
  float gap = kinectHeight/cards;
  // anchor card
  CustomShape s1 = new CustomShape(x, -40, size, BodyType.DYNAMIC);
  polygons.add(s1);  
  CustomShape last_shape = s1;
  CustomShape next_shape;
  for (int i=0; i<cards; i++)
  {
    float y = -20 + gap * (i+1);
    next_shape = new CustomShape(x, -20 + gap * (i+1), size, BodyType.DYNAMIC);
    DistanceJointDef jd = new DistanceJointDef();
    Vec2 c1 = last_shape.body.getWorldCenter();
    Vec2 c2 = next_shape.body.getWorldCenter();

  // offset the anchors so the cards hang vertically
    c1.y = c1.y + size / 5;
    c2.y = c2.y - size / 5;
    jd.initialize(last_shape.body, next_shape.body, c1, c2);
    jd.length = box2d.scalarPixelsToWorld(gap - 1);
    box2d.createJoint(jd);
    polygons.add(next_shape);
    last_shape = next_shape;
  }
} 

void movieEvent(Movie m) {
  m.read();
}

void updateAndDrawBox2D() {
  // if frameRate is sufficient, add a polygon and a circle with a random radius

  if (frameRate > 5) {
    //CustomShape shape1 = new CustomShape(kinectWidth/2, -50, -1,BodyType.DYNAMIC) ;
    CustomShape shape2 = new CustomShape(25, 150, random(2.5, 5),BodyType.DYNAMIC); // lingkaran
    //polygons.add(shape1);
    polygons.add(shape2);
  }
  // take one step in the box2d physics world
  box2d.step();
 
  // center and reScale from Kinect to custom dimensions
  translate(0, (height-kinectHeight*reScale)/2);
  scale(reScale);
 
  // display the person's polygon  
  noStroke();
  fill(blobColor);
  gfx.polygon2D(poly);
 
  // display all the shapes (circles, polygons)
  // go backwards to allow removal of shapes
  for (int i=polygons.size()-1; i>=0; i--) {
    CustomShape cs = polygons.get(i);
    // if the shape is off-screen remove it (see class for more info)    
    if (cs.done()) {
      polygons.remove(i);
    // otherwise update (keep shape outside person) and display (circle or polygon)
    } else {
      cs.update();
      cs.display();
    }
  }
}

// sets the colors every nth frame
void setRandomColors(int nthFrame) {
  if (frameCount % nthFrame == 0) {
    // turn a palette into a series of strings
    String[] paletteStrings = split(palettes[int(random(palettes.length))], ",");
    // turn strings into colors
    colorPalette = new color[paletteStrings.length];
    for (int i=0; i<paletteStrings.length; i++) {
      colorPalette[i] = int(paletteStrings[i]);
    }
    // set background color to first color from palette
    bgColor =colorPalette[0]; // colorPalette[0]
    // set blob color to second color from palette
    blobColor = colorPalette[1];
    // set all shape colors randomly
    for (CustomShape cs: polygons) { cs.col = getRandomColor(); }
  }
}

// returns a random color from the palette (excluding first aka background color)
color getRandomColor() {
  return colorPalette[int(random(1, colorPalette.length))];
}


