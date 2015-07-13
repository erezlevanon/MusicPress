import themidibus.*;
import processing.video.*;


// constants and vars for midi communication;
MidiBus bus;
int channel = 1;
int midiOutPort = 3; // you should make sure this is an active midi port.
int midiInPort = 1; // make sure that exists, otherwise the program will play the notes.
int defaultVelocity = 127;

// vars to be used for video processing.
Capture cam;
PImage section; // this will represent the section of a single note.
PImage tap;     // this will represnet the section of the tap (rythem) note out.

// this vars are used to choose the arrea to read notes from.
int windowHeight = 15;
int windowWidth = 460;
int curY; // curX and curY are the coordinates for the observed window
int curX;
int numOfSections = 12; // the number of different notes to read and send.
float threshold; // (determined later) the minimum number of qualified pixels in a section to send a Note.
float thresholdP = 0.15; // between 0 and 1. the proportion of pixels out of all the pixels in the section that should qualify

int blackIndicator = 90; // the level of brightness that bellow will be considered black.

int[] values; // this will hold the number of black pixels in evey section, correspondly.
Note[] notes; // this will hold Notes to be send by the corresponding sections.
boolean[] playingNotes; // will hold true if the last time the corresponding note was send it was On. else otherwise.

// this vars are used to choose the arrea to read tap rythm from. similar to window vars.
int tapWidth = 15;
int tapHeight = 15;
int tapX;
int tapY;
float tapThreshold;
float tapThresholdP = 0.9F;

Note tapNote = new Note(channel,127,defaultVelocity); // the note that represents a tap.
boolean tapOn = false; // will be true if the last tap sent was with sendNoteOn.



void setup() {
  //GUI initialation.
  size(640, 480);
  stroke(255,0,0);
  noFill();
  
  textSize(8);
  
  // intialize thresholds for window and tap.
  threshold = ((windowHeight*windowWidth)/numOfSections)*thresholdP;
  tapThreshold = tapHeight*tapWidth*thresholdP;

  
  // video initialization.
  frameRate(30);
  cam = new Capture(this);
  cam.start();
  
  //midi initialization.
  MidiBus.list(); 
  MidiBus.availableInputs();
  bus = new MidiBus(this, midiInPort, midiOutPort);
  
  // initiateValues.
  setValues(); 
  setNotes();
  setPlayingNotes();
}

void draw() {
  // update and display video from webcam.
    if (cam.available()) {
       image(cam,0,0);
       cam.read();
       cam.loadPixels(); //makes the cam.pixels[] array that will be used later, updated.
    }
    clearValues(); // this will set all values in values array to 0.
    scanWindow(); // updates the values array according to current image.
//    scanTap(); // update the tap value and send tap note if necesarry.
    scanValues(); // print an array the shows wich values are heigher than the threshold.

  playNotes(); // play the correct notes.
}

// handle mouse events. left click will update the sections window location.
//                      right click will update the tap window location.
void mouseClicked() {
  if(mouseButton==LEFT) updateCurXY();
  else if (mouseButton==RIGHT) updateTapXY();
}
void mouseDragged() {
  if(mouseButton==LEFT) updateCurXY();
  else if (mouseButton==RIGHT) updateTapXY();
}


// this update the curX and curY vars to the closest coordinate on the screen
// so the sections window will stay fully indside the image.
void updateCurXY() {
  curY = min(height-windowHeight,max(mouseY-(windowHeight/2), 0));
  curX = min(width-windowWidth,max(mouseX-(windowWidth/2), 0));
}

// does the same ^ but for the tap window.
void updateTapXY() {
  tapY = min(height-tapHeight,max(mouseY-(tapHeight/2), 0));
  tapX = min(width-tapWidth,max(mouseX-(tapWidth/2), 0));
}

// scan the pixels in the section window and 
void scanWindow() {
  // devides the window to sections and scan their pixels to update corresponding values.
  for (int curSection = 0; curSection < numOfSections; curSection++) {
    int sectionWidth = windowWidth/numOfSections; // the width of each section.
    int xLoc = curX + curSection*windowWidth/numOfSections; // the leftmost point of the current section.
    section = cam.get(xLoc, curY, sectionWidth, windowHeight); // get the relevant pixels from the camera image.
    section.loadPixels(); // make section.pixels array available.
    for(int pix = 0; pix < section.pixels.length; pix++) { //run over every pixel in the section.
      if (brightness(section.pixels[pix]) < blackIndicator) { //if it's defined as black, raise the corresponding value in values.
        values[curSection] = values[curSection] + 1;
      }
    }
    // if the current section pass the threshold, fill it.
    fill(255,0,0);
    noFill();
    if (values[curSection] > threshold) fill(0,0,0);
    rect(xLoc, curY, sectionWidth, windowHeight); //show the section.
    noFill();
  }  
}

void scanTap() {
  tap = cam.get(tapX, tapY, tapWidth, tapHeight);
  fill(255,0,0);
  text("TAP",tapX, tapY-10);
  noFill();
  int blackPixels = 0;
  tap.loadPixels();
  for (int i = 0; i < tap.pixels.length; i++) {
    if (brightness(tap.pixels[i]) < blackIndicator) blackPixels++;
  }
  if(blackPixels > tapThreshold) {
    fill(255,0,0);
    if (!tapOn) {
      bus.sendNoteOn(tapNote);
      tapOn = true;
    }
  }else {
    if (tapOn){
      bus.sendNoteOff(tapNote);
      tapOn = false;
    }
  }
  rect(tapX, tapY, tapWidth, tapHeight);
  noFill();
}

void scanValues() { 
  for (int i = 0 ; i < values.length ; i++) {
    if (i == 0) print("[");
    if (i<values.length-1) {
      if ((values[i]>threshold)) print("1,");
      else print(" ,");
    }
    if (i == values.length - 1) {
      if ((values[i]>threshold)) print("1]");
      else print(" ]");
    }
  }
  println();
}

void playNotes() {
  for(int i = 0; i < values.length; i++) {
  if (values[i] > threshold) {
    if(!playingNotes[i]) {
      bus.sendNoteOn(notes[i]);
      playingNotes[i] = true;  
    }
  }
  else if(playingNotes[i]) {
    bus.sendNoteOff(notes[i]);
    playingNotes[i] = false;
  }
  }
}

void clearValues() {
  for (int i = 0; i < values.length; i++) values[i] = 0;
}

void setNotes() {
  notes = new Note[numOfSections];
  for (int i=0; i < numOfSections; i++) {
    if (i < 6) notes[i] = new Note(channel, i, defaultVelocity);
    else notes[i] = new Note(channel, i+30, defaultVelocity);
  }
}

void setPlayingNotes() {
  playingNotes = new boolean[numOfSections];
  for (int i = 0 ; i < playingNotes.length ; i++) {
    playingNotes[i] = false;
  }
}

void setValues() {
  values = new int[numOfSections];
}
