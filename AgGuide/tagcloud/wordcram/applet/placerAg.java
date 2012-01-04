import processing.core.*; 
import processing.xml.*; 

import wordcram.*; 
import wordcram.text.*; 

import java.applet.*; 
import java.awt.Dimension; 
import java.awt.Frame; 
import java.awt.event.MouseEvent; 
import java.awt.event.KeyEvent; 
import java.awt.event.FocusEvent; 
import java.awt.Image; 
import java.io.*; 
import java.net.*; 
import java.text.*; 
import java.util.*; 
import java.util.zip.*; 
import java.util.regex.*; 

public class placerAg extends PApplet {

/*
Copyright 2010 Daniel Bernier

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/*
Built with WordCram 0.3, http://code.google.com/p/wordcram/
US Constitution text from http://www.usconstitution.net/const.txt
Liberation Serif font from RedHat: https://www.redhat.com/promo/fonts/
*/




WordCram wordCram;

public void setup() {
  size(1024, 768);
  background(255);
  colorMode(RGB);
  
  initWordCram();
}

public void initWordCram() {
  wordCram = new WordCram(this)
      .fromTextFile("placerAgtags.txt")
      .withStopWords(StopWords.ENGLISH + " on")
      /*.withFont(createFont("LiberationSerif-Regular.ttf", 1))*/
      .sizedByWeight(10, 110)
	  /*.withPlacer(Placers.centerClump())
	  .withAngler(Anglers.mostlyHoriz())*/
      .withColors(color(184, 0, 24), color(212, 78, 65), color(74, 27, 65), color(22, 87, 22), color(87, 125, 53));
}

public void draw() {
  if (wordCram.hasMore()) {
    wordCram.drawNext();
  }
}

public void mouseClicked() {
  background(255);
  initWordCram();
}
  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#DFDFDF", "placerAg" });
  }
}
