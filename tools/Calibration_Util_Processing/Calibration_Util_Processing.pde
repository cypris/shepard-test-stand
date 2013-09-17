/* Copyright (C) 2012-2013 Mach 30 - http://www.mach30.org 
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

/*
 * This calibration software takes readings from 2 input sensors.
 * The first is a force sensor that measures the trust of the rocket motor
 * under test. The second is a thermocouple which measures the casing 
 * temperature at the throat of the motor. The raw values from these
 * sensors are matched with real world measurements which are recorded
 * to one calibration file for each sensor. When the Shepard Data
 * Collection Software (DCS) starts up, these calibration files are read
 * and the values are compared against the calibration's linear regression.
 */
 
import processing.serial.*; //The serial port configuration
import controlP5.*; //Our graphics library

boolean isReady = false; //Whether or not we're ready to receive data
boolean serialAvail = false; //Tracks whether or not we have any serial ports
boolean serialEnabled = false; //Tracks whether or not we can start reading from the serial port
char clientReadyMsg = 'R'; //The byte that tells the Arduino we're ready to start receiving data
char endMsg = 'Q'; //The byte that tells the Arduino we want to end communications //TODO: Implement an exit button to do this for us
char discoverMsg = 'D'; //The byte that tells the Arduino that we've searching for it
int X_AXIS = 1; //Specifier for an X-axis gradient
int Y_AXIS = 2; //Specifier for a Y-axis gradient
int dataID; //The ID used to separate between types of data coming from the Arduino
int curThrustRaw; //The current thrust data value in 0 to 1023 format
color c1; //Gradient color 1
color c2; //Gradient color 2
ControlP5 cp5; //The interface object that gives us access to the GUI library
Textfield txtRawValue; //Holds the raw value 0-1023 coming back from the Arduino
Textfield txtRealValue; //Holds the "real" value entered by the user
Button savePointButton; //Allows the user to save the current raw/real value pair
Button clearButton; //Clears the calibration
Button saveCalibButton; //Save the calibration
DropdownList ddl1; //The drop down list holding the serial ports
String[] serialPorts; //Serial.list();//new String[Serial.list().length]; //The serial ports that are available on the system
Serial serialPort = null; //Currently, we talk over the serial/USB cable to the Arduino
M30TextBox txtCalibPoints; //The calibration points that have already been recorded
M30Chart chrtCalibPoints; //The calibration curve

/*Sets this app up for operation (window, serial, value storage, etc).*/
void setup() 
{
  //Set the size of the window
  size(800, 600);
  
    //Colors for the gradient
  c1 = 0xff9f9f9f;
  c2 = 0xff545454;
  
  //Our GUI library object
  cp5 = new ControlP5(this);
  
  //Set a general label for the app's upper left corner
  cp5.addTextlabel("label")
    .setText("Mach 30: Shepard Test Stand - Calibration")
    .setPosition(5,5)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial",18));
  
  //Button to record the current raw/real data point pair
  savePointButton = cp5.addButton("savePoint")
     .setPosition(205, 55)
     .setSize(100, 20)
     .setId(1)     
     .setCaptionLabel("Save Point")
     .registerTooltip("Save the current raw/real pair to the calibration file");
     
  //Align the caption text to the center of the button
  savePointButton.getCaptionLabel().alignX(ControlP5.CENTER);
  
  //Button to clear the last calibration point
  clearButton = cp5.addButton("deletePoint")
     .setPosition(315, 55)
     .setSize(100, 20)
     .setId(2)     
     .setCaptionLabel("Delete Last Point")
     .registerTooltip("Clears the last calibration point");
     
  //Align the caption text to the center of the button
  clearButton.getCaptionLabel().alignX(ControlP5.CENTER);
  
  //Button to clear the current calibration
  clearButton = cp5.addButton("clearCalib")
     .setPosition(425, 55)
     .setSize(100, 20)
     .setId(2)
     .setCaptionLabel("Clear Calibration")
     .registerTooltip("Clears the previous calibration points");
     
  //Align the caption text to the center of the button
  clearButton.getCaptionLabel().alignX(ControlP5.CENTER);
  
  //Button to clear the current calibration
  saveCalibButton = cp5.addButton("saveCalib")
     .setPosition(535, 55)
     .setSize(100, 20)
     .setId(2)
     .setCaptionLabel("Save Calibration")
     .registerTooltip("Save the entire calibration to file");
     
  //Align the caption text to the center of the button
  saveCalibButton.getCaptionLabel().alignX(ControlP5.CENTER);
  
  //Set a label for the drop down menu
  cp5.addTextlabel("label1")
    .setText("SERIAL PORT")
    .setPosition(660,40)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial", 9));
  
  ddl1 = cp5.addDropdownList(Serial.list()[0], 660, 75, 100, 40);
  ddl1.setItemHeight(18);
  ddl1.setBarHeight(18);
  ddl1.captionLabel().style().marginTop = 5;
    
  //Sets the file name prefix to be the motor model number
  txtRawValue= cp5.addTextfield("RAW VALUE")
     .setPosition(5,45)
     .setSize(80,30)
     .setFont(createFont("arial",18))
     .setColor(0xffffffff)
     .setAutoClear(true)
     .registerTooltip("The raw data coming from the Arduino");
     
  //Align the caption text
  txtRawValue.getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(0);
    
  //Allows the user to enter the real-world value that corresponds to the calibration value
  txtRealValue= cp5.addTextfield("REAL VALUE")
     .setPosition(100,45)
     .setSize(80,30)
     .setFont(createFont("arial",18))
     .setColor(0xffffffff)
     .setAutoClear(true)
     .registerTooltip("The real value to associate with the raw value")
     .setText("0.00");
     
  //Align the caption text
  txtRealValue.getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(0);
  
  //Set up the textbox that will hold the previously saved calibration points
  txtCalibPoints = new M30TextBox("CALIBRATION POINTS", 5, 90, 100, 500);
  
  //Add our data header to the calibration points text box
  txtCalibPoints.addLine("Raw (X),Real (Y)");
  
  //Set up the chart that will track our progress on the calibration
  chrtCalibPoints = new M30Chart("CALIBRATION CURVE", 115, 90, 680, 500, true, 0, 1);
  
  //Call the method that will find out what serial ports are available and set up our drop down
  SetupSerial();

  //Allows us to add a handler for when the application Window is closed
  prepareExitHandler();
}

/*Draws the GUI and all its components for us*/
void draw() {
  //Set the background up as a gradient
  setGradient(0, 0, width, height, c1, c2, Y_AXIS);
  
  //Draw our other UI elements
  txtCalibPoints.draw();
  chrtCalibPoints.draw();
  
  //Make sure that we have a serial port available
  if(serialEnabled) {
    //As long as we're getting data keep looping and reading from the port
    while (serialPort.available() >= 3) {
      //Make sure we don't keep asking for the Arduino to start sending data
      isReady = true;
    
      //Figure out what type of data is coming back (from first byte) 0xff = thrust, 0xfe = temp, 0xfd = time
      dataID = serialPort.read();
      
      //Check to see if we have thrust data coming in (ignore temp and time)
      if (dataID == 0xff) {
         //Read two bytes and combine them into the 0 to 1023 value
         curThrustRaw = (serialPort.read() << 8) | (serialPort.read());
         
         //Set the value of the raw value textfield
         txtRawValue.setText(curThrustRaw + "");
      }
    }
  }
}

/*
 * Called when the dropdown list is changed
 */
void controlEvent(ControlEvent theEvent) {  
  if (theEvent.isGroup()) {     
    //Check to make sure we have serial ports available
    if (ddl1.getItem((int)theEvent.value()).getName() != "None Available") {      
      //Check to make sure the serial port is already running
      if (serialPort != null) {     
        //Stop the serial port so that it can be reset
        serialPort.stop();
      }
      
      //Set the Arduino serial port to the new value
      serialPort = new Serial(this, serialPorts[int(theEvent.group().value())], 115200);
      
      //Let the rest of the code know that we can read from serial now
      serialEnabled = true;
      
      //Wait for the serial port to get up and going
      delay(2500);
                        
      //Tell the Arduino we're ready
      serialPort.write(clientReadyMsg);
      //serialPort.write(82);      
    }        
  }
}

/*
 * Called when the "Save Point" button is clicked
 */
public void savePoint(int theValue) {
  //Add the comma separated raw and real values to the textbox
  txtCalibPoints.addLine(txtRawValue.getText() + "," + txtRealValue.getText());
  
  //Add the current point to the chart
  chrtCalibPoints.addPen1Point(Float.parseFloat(txtRawValue.getText()), Float.parseFloat(txtRealValue.getText()));
}

/*
 * Called when the "Delete Last Point" button is clicked.
 */
public void deletePoint() {
  //Delete only the last line entered in the textbox
  txtCalibPoints.deleteLine();
}

/*
 * Called when the "Clear Calibration button is clicked.
 */
public void clearCalib() {
  //Delete all the lines of text from the textbox
  txtCalibPoints.clearLines();
  
  //Add our data header to the calibration points text box
  txtCalibPoints.addLine("Raw (X),Real (Y)");
  
}

/*
 * Called when the Save Calibration button is clicked
 */
public void saveCalib() {
  //TODO - Implement this
  ;; 
}

/*Sets up the background gradient so that things look a little nicer*/
void setGradient(int x, int y, float w, float h, color c1, color c2, int axis ) {

  noFill();

  if (axis == Y_AXIS) {  // Top to bottom gradient
    for (int i = y; i <= y+h; i++) {
      float inter = map(i, y, y+h, 0, 1);
      color c = lerpColor(c1, c2, inter);
      stroke(c);
      line(x, i, x+w, i);
    }
  }  
  else if (axis == X_AXIS) {  // Left to right gradient
    for (int i = x; i <= x+w; i++) {
      float inter = map(i, x, x+w, 0, 1);
      color c = lerpColor(c1, c2, inter);
      stroke(c);
      line(i, y, i, y+h);
    }
  }
}

/*
 * Sets up the serial related drop down
 */
public void SetupSerial() {
  char character; //The character we're waiting for during autodiscovery
  
  //Check to see if there are any serial ports
  if (Serial.list().length == 0) {
    ddl1.addItem("None Available", 0);
  }
  else if (Serial.list().length > 0) {
    //Get a list of the seril ports on the system
    serialPorts = Serial.list();
    
    //Step through and add all of the serial ports to the dropdown list
    for(int i = 0; i < serialPorts.length; i++) {
      ddl1.addItem(serialPorts[i], i);     
      
      //Set the Arduino serial port to the new value
      /*serialPort = new Serial(this, serialPorts[i], 115200);
      
      //Wait for the serial port to get up and going
      delay(2500);
      
      //Try to send the discovery character to the port to see what happens      
      serialPort.write(discoverMsg);
      println("HERE1");
      //Wait for a few cycles for a response
      while (serialPort.available() == 0) {
        //TODO: Wait for a number of milliseconds before moving onto the next port
      }
      println("HERE2");
                     
      //Figure out if we got the discovery character back
      character = serialPort.readChar();
      
      println(character);
      
      //Check to see what character we got
      if (character == 'D') {
        break;
        //TODO: Put the autoselect code in here to select the right serial port
      }      
      
      //Stop the serial port so that it can be reset
      serialPort.stop();*/
    }    
  }
}

/*
 * Allows us to set things up to be shut down when the application window closes.
 */
private void prepareExitHandler() {
  Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
    public void run () {      
      try {          
        //Call the method/function that will clean up for us before exit
        stop();
      }
      catch (Exception ex) {
          ex.printStackTrace(); // not much else to do at this point
      }             
   }
  }));
}

private void Exit() {
  //Let the Arduino know that we want to disconnect
  serialPort.write(endMsg);
 
  //Stop the serial port
  serialPort.stop();
  
  //Exit the application
  exit();
}

/*
 * Called when the window is closed so we can clean up
 */
void stop() {   
  //Stop the serial port
  serialPort.stop(); 
}
