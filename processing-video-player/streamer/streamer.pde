/*  OctoWS2811 movie2serial.pde - Transmit video data to 1 or more
      Teensy 3.0 boards running OctoWS2811 VideoDisplay.ino
    http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
    Copyright (c) 2013 Paul Stoffregen, PJRC.COM, LLC

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

//  1: if your LED strips have unusual color configuration,
//     edit colorWiring().  Nearly all strips have GRB wiring,
//     so normally you can leave this as-is.
//
//  2: if playing 50 or 60 Hz progressive video (or faster),
//     edit framerate in movieEvent().


import processing.video.*;
import processing.serial.*;
import java.awt.Rectangle;

static final int LED_WIDTH = 47;
static final int LED_HEIGHT = 32;
static final int VIDEO_XOFFSET = 0;
static final int VIDEO_YOFFSET = 0;
static final int VIDEO_WIDTH = 100;
static final int VIDEO_HEIGHT = 100;


Movie myMovie; // = new Movie(this, "/Users/robby/Downloads/Meredith Eves.mp4");

float gamma = 1.9;

int PINS = 8; //

int numPorts=0;  // the number of serial ports in use

Serial[] ledSerial = new Serial[1];     // each port's actual Serial port
Rectangle[] ledArea = new Rectangle[1]; // the area of the movie each port gets, in % (0-100)
boolean[] ledLayout = new boolean[1];   // layout of rows, true = even is left->right
PImage[] ledImage = new PImage[1];      // image sent to each port
int[] gammatable = new int[256];
int errorCount=0;
float framerate=0;

void setup() {
  println("Specified port: " + args[0]);
  println("Specified video: " + args[1]);
  println();
  
  myMovie = new Movie(this, args[1]);

  String[] list = Serial.list();
  delay(20);
  println("Serial Ports List:");
  println(list);
  ledSerial[0] = new Serial(this, args[0]);
  serialConfigure();  // change these to your port names
  if (errorCount > 0) exit();
  for (int i=0; i < 256; i++) {
    gammatable[i] = (int)(pow((float)i / 255.0, gamma) * 255.0 + 0.5);
  }
  size(480, 400);  // create the window
  myMovie.loop();  // start the movie :-)
}

 
// movieEvent runs for each new frame of movie data
void movieEvent(Movie m) {
  // read the movie's next frame
  m.read();
  
  //if (framerate == 0) framerate = m.getSourceFrameRate();
  framerate = 30.0; // TODO, how to read the frame rate???

  // copy a portion of the movie's image to the LED image
  int xoffset = percentage(m.width, ledArea[0].x);
  int yoffset = percentage(m.height, ledArea[0].y);
  int xwidth =  percentage(m.width, ledArea[0].width);
  int yheight = percentage(m.height, ledArea[0].height);
  ledImage[0].copy(m, xoffset, yoffset, xwidth, yheight,
                   0, 0, ledImage[0].width, ledImage[0].height);
  // convert the LED image to raw data
  byte[] ledData =  new byte[(ledImage[0].width * ledImage[0].height * 3) + 3];
  image2data(ledImage[0], ledData, ledLayout[0]);
  ledData[0] = '*';  // first Teensy is the frame sync master
  int usec = (int)((1000000.0 / framerate) * 0.75);
  ledData[1] = (byte)(usec);   // request the frame sync pulse
  ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
  // send the raw data to the LEDs  :-)
  ledSerial[0].write(ledData);
}

// image2data converts an image to OctoWS2811's raw data format.
// The number of vertical pixels in the image must be a multiple
// of PINS(8).  The data array must be the proper size for the image.
void image2data(PImage image, byte[] data, boolean layout) {
  int offset = 3;
  int x, y, xbegin, xend, xinc, mask;

  int linesPerPin = image.height / 8; // XXX this seems to break when using 6 instead of 8
  int pixel[] = new int[PINS];
  
  for (y = 0; y < linesPerPin; y++) {
    if ((y & 1) == (layout ? 0 : 1)) {
      // even numbered rows are left to right
      xbegin = 0;
      xend = image.width;
      xinc = 1;
    } else {
      // odd numbered rows are right to left
      xbegin = image.width - 1;
      xend = -1;
      xinc = -1;
    }
    for (x = xbegin; x != xend; x += xinc) {
      for (int i=0; i < PINS; i++) {
        // fetch 8 pixels from the image, 1 for each pin
        pixel[i] = image.pixels[x + (y + linesPerPin * i) * image.width];
        pixel[i] = colorWiring(pixel[i]);
      }
      // convert 8 pixels to 24 bytes -- XXX
      for (mask = 0x800000; mask != 0; mask >>= 1) {
        byte b = 0;
        for (int i=0; i < PINS; i++) {
          if ((pixel[i] & mask) != 0) b |= (1 << i);
        }
        data[offset++] = b;
      }
    }
  } 
}

// translate the 24 bit color from RGB to the actual
// order used by the LED wiring.  GRB is the most common.
int colorWiring(int c) {
//   return c;  // RGB
//  return ((c & 0xFF0000) >> 8) | ((c & 0x00FF00) << 8) | (c & 0x0000FF); // GRB - most common wiring
  int red = (c & 0xFF0000) >> 16;
  int green = (c & 0x00FF00) >> 8;
  int blue = (c & 0x0000FF);
  red = gammatable[red];
  green = gammatable[green];
  blue = gammatable[blue];
  return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
}

// ask a Teensy board for its LED configuration, and set up the info for it.
void serialConfigure() {
  // only store the info and increase numPorts if Teensy responds properly
  ledImage[numPorts] = new PImage(LED_WIDTH, LED_HEIGHT, RGB);
  ledArea[numPorts] = new Rectangle(VIDEO_XOFFSET, VIDEO_YOFFSET,
                     VIDEO_WIDTH, VIDEO_HEIGHT);
  ledLayout[numPorts] = (VIDEO_XOFFSET == 0);
  numPorts++;
}

// draw runs every time the screen is redrawn - show the movie...
void draw() {
  // show the original video
  image(myMovie, 0, 80);
  
  // then try to show what was most recently sent to the LEDs
  // by displaying all the images for each port.
  // compute the intended size of the entire LED array
  int xsize = percentageInverse(ledImage[0].width, ledArea[0].width);
  int ysize = percentageInverse(ledImage[0].height, ledArea[0].height);
  // computer this image's position within it
  int xloc =  percentage(xsize, ledArea[0].x);
  int yloc =  percentage(ysize, ledArea[0].y);
  // show what should appear on the LEDs
  image(ledImage[0], 240 - xsize / 2 + xloc, 10 + yloc);
}

// respond to mouse clicks as pause/play
boolean isPlaying = true;
void mousePressed() {
  if (isPlaying) {
    myMovie.pause();
    isPlaying = false;
  } else {
    myMovie.play();
    isPlaying = true;
  }
}

// scale a number by a percentage, from 0 to 100
int percentage(int num, int percent) {
  double mult = percentageFloat(percent);
  double output = num * mult;
  return (int)output;
}

// scale a number by the inverse of a percentage, from 0 to 100
int percentageInverse(int num, int percent) {
  double div = percentageFloat(percent);
  double output = num / div;
  return (int)output;
}

// convert an integer from 0 to 100 to a float percentage
// from 0.0 to 1.0.  Special cases for 1/3, 1/6, 1/7, etc
// are handled automatically to fix integer rounding.
double percentageFloat(int percent) {
  if (percent == 33) return 1.0 / 3.0;
  if (percent == 17) return 1.0 / 6.0;
  if (percent == 14) return 1.0 / 7.0;
  if (percent == 13) return 1.0 / 8.0;
  if (percent == 11) return 1.0 / 9.0;
  if (percent ==  9) return 1.0 / 11.0;
  if (percent ==  8) return 1.0 / 12.0;
  return (double)percent / 100.0;
}