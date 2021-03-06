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
 * This Data Collection Software (DCS) takes readings from 2 input sensors.
 * The first is a force sensor that measures the trust of the rocket motor
 * under test. The second is a temperature sensor which measures the casing 
 * temperature at the throat of the motor nozzle.
 */

import processing.serial.*; //The serial port configuration
import controlP5.*; //Our graphics library

//Global general variables
boolean isReady = false; //Whether or not we're ready to receive data
boolean aboveZero = false; //Tracks whether or not the voltage has gone above zero
boolean serialEnabled = false; //Tracks whether or not we can start reading from the serial port
char clientReadyMsg = 'R'; //The byte that tells the Arduino we're ready to start receiving data
char endMsg = 'Q'; //The byte that tells the Arduino we want to end communications //TODO: Implement an exit button to do this for us
char discoverMsg = 'D'; //The byte that tells the Arduino that we've searching for it
int dataID; //The ID used to separate between types of data coming from the Arduino
int curThrustRaw; //The current thrust data value in 0 to 1023 format
int numSamples = 1; //The number of samples taken so far
int X_AXIS = 1; //Specifier for an X-axis gradient
int Y_AXIS = 2; //Specifier for a Y-axis gradient
int numOfTicks = 1; //The number of ticks that will be drawn on the X axis 
long startMillis = 0; //The number of seconds on the clock when we start recording
long curTime = 0; //The time value coming from the Arduino
float runTime = 0.0; //How many seconds have passed since we started acquiring
float curThrust; //The current thrust data value coming back from the Arduino
float thrustTotal = 0.0; //Used to calculate the average thrust
float tempTotal = 0.0; //Used to calculate the average temp
float average; //Temporary variable to hold calculated average
float tempAverage; //Temporary variable to hold calculated temperature average
float curTemp; //The current temperature as read by the thermocouple
float triggerThrust = 0.01; //The thrust level that will tell the software to start recording data.
ArrayList thrustVals; //List of the thrust values taken during testing
ArrayList tempVals; //List of the temperature values taken during testing
ArrayList timeVals; //List of the time values taken during testing

//Global GUI related variables
ControlP5 cp5; //The interface object that gives us access to the GUI library
PFont defaultFont; //The default font for the app
color c1; //Gradient color 1
color c2; //Gradient color 2
Textfield txtSerialPort; //Text field that allows us to set the Arduino serial port
Textfield txtMotorModel; //Text field that allows us to set a CSV file name prefix
Chart thrustChart; //The line chart for the thrust measurement
Chart tempChart; //The line chart for the temperature measurement
Slider curThrustSlide; //The slider that will show the current thrust value
Slider peakThrustSlide; //The slider that will show the current thrust value
Slider avgThrustSlide; //The slider that will show the current thrust value
Slider curTempSlide; //The slider that will show the current thrust value
Slider maxTempSlide; //The slider that will show the current thrust value
Slider avgTempSlide; //The slider that will show the current thrust value
Button recordButton; //The button that controls whether or not data will be recorded
Button clearButton; //Clears the charts, averages, maxes, etc
Button exitButton; //Cleanly exits the application, telling the Arduino that we want to disconnect
DropdownList ddl1; //The drop down list holding the serial ports

//Global I/O related variables
PrintWriter csvFile; //The file that we'll save the test stand data to for each run
Serial serialPort = null; //We talk over the serial/USB cable to the Arduino
String[] serialPorts; //The serial ports that are available on the system

/*
 * Sets this app up for operation (window, serial, value storage, etc).
 */
void setup() 
{
  //Initialize the arrays that hold the measured values
  thrustVals = new ArrayList();
  tempVals = new ArrayList();
  timeVals = new ArrayList();
  
  //Call the method that will set the GUI up for us
  SetupGUI();   
 
  //Call the method that will find out what serial ports are available and set up our drop down
  SetupSerial();

  //Allows us to add a handler for when the application Window is closed
  prepareExitHandler();  
}



/*
 * Draws the GUI and all its components for us
 */
void draw() {    
  //Set the background up as a gradient
  setGradient(0, 0, width, height, c1, c2, Y_AXIS);
  
  //Draw the X and Y scales on the thrust chart
  drawScale(30, 50, 650, 250, runTime, 30); 
  
  //Draw the X and Y scales on the temperature chart
  drawScale(30, 325, 650, 250, runTime, 200);
  
  //Check to see if we should toggle the text on the button
  if(recordButton.getBooleanValue()) {
    recordButton.getCaptionLabel().setText("Disable Recording");     
  }
  else {
    recordButton.getCaptionLabel().setText("Enable Recording");                  
  } 

  //Read data from the serial port and display it
  ReadSerial();  
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



/*
 * Clear button click which clears the charts, averages, and maxes
 */
public void Clear(int theValue) {
  //Reset everything so that we can make another run
  numSamples = 1;
  thrustTotal = 0.0;
  tempTotal = 0.0;
  startMillis = 0;
  aboveZero = false;
  
  //Reset the lists that hold data to write to file
  thrustVals.clear();
  tempVals.clear();
  timeVals.clear();
  
  //Clear the charts and reset their values  
  thrustChart.setData("curthrust", new float[10]);
  tempChart.setData("curtemp", new float[10]);
  
  //Reset the sliders  
  peakThrustSlide.setValue(0.0);
  avgThrustSlide.setValue(0.0);
  maxTempSlide.setValue(0.0);
  avgTempSlide.setValue(0.0);
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
 * Draws X and Y scales for a chart since controlp5 doesn't include this feature
 */
void drawScale(int chartX, int chartY, int chartWidth, int chartHeight, float xHighVal, float yHighVal) {
  //Draw the rectangles that we'll be drawing the scales on
  fill(0xff02344d);
  //Reset the stroke so that we don't get while lines where we don't want
  stroke(0xff02344d);
  
  //The X scale background
  rect(chartX, chartY + chartHeight, chartWidth, 20);
  
  //The Y scale background
  rect(chartX - 30, chartY, 30, chartHeight + 20);
  
  //Get ready to draw white lines and set up the scale font
  stroke(0xffffffff);
  fill(0xffffffff);
  textFont(defaultFont, 9);
  
  //Draw the horizontal line of the scale  
  line(chartX, chartY + chartHeight, chartX + chartWidth, chartY + chartHeight);
  
  //Draw the vertical line of the scale
  line(chartX - 1, chartY, chartX - 1, chartY + chartHeight);
  
  //Take care of the 0 position lines and value
  line(chartX - 1, chartY + chartHeight, chartX - 1, chartY + chartHeight + 8); //The 0 position X marker
  line(chartX - 1, chartY + chartHeight, chartX - 9, chartY + chartHeight); //The 0 position Y marker
  text("0", chartX - 12, chartY + chartHeight + 12);
  
  //Draw the max value ticks
  line(chartX + chartWidth, chartY + chartHeight, chartX + chartWidth, chartY + chartHeight + 8); //The max value X marker
  text(round(xHighVal * 10.0f) / 10.0f + "", chartX + chartWidth - 13, chartY + chartHeight + 20);
  line(chartX - 1, chartY, chartX - 8, chartY); //The max value Y marker
  text(round(yHighVal), chartX - 30, chartY + 8);
  
  //Autoscale the X axis
  if(xHighVal <= 0.5) {
    //We want 5 tick marks
    numOfTicks = 5; 
  }
  else if(xHighVal > 0.5 && xHighVal <= 5.0) {
    //We want 10 tick marks
    numOfTicks = 10;
  }
  else {
    //We want 10 tick marks
    numOfTicks = 10;
  }
  
  //Step through and draw the ticks
  for(int i = 1; i < numOfTicks; i++) {
    //Draw the value ticks
    line(chartX + (chartWidth / numOfTicks) * i, chartY + chartHeight, chartX + (chartWidth / numOfTicks) * i, chartY + chartHeight + 8); //The max value X marker
    text(round((xHighVal / numOfTicks * i) * 10.0f) / 10.0f + "", chartX + (chartWidth / numOfTicks) * i - 6, chartY + chartHeight + 20);
  }
  
  //Autoscale the Y axis
  if(yHighVal <= 5) {
    //We want 5 tick marks
    numOfTicks = 5; 
  }
  else {
    //We want 15 tick marks
    numOfTicks = 10;
  }
  
  //Step through and draw the ticks
  for(int i = 1; i < numOfTicks; i++) {
    //Draw the value ticks
    line(chartX - 1, chartY + round(chartHeight / numOfTicks) * i, chartX - 8, chartY + round(chartHeight / numOfTicks) * i); //The max value Y marker
    //line(chartX, (chartY + chartHeight) - (chartHeight / numOfTicks) * i, chartX - 8, (chartY + chartHeight) - (chartHeight / numOfTicks) * i);
    text(round(yHighVal / numOfTicks * i) + "", chartX - 30, (chartY + (chartHeight + 3)) - round(chartHeight / numOfTicks) * i);    
  }
  
  //Draw the rectangles that we'll be drawing the scales on
  fill(0xff02344d);
  //Reset the stroke so that we don't get while lines where we don't want
  stroke(0xff02344d);
}



/*
 * The 0-1023 value that we get back corresponds to a voltage 0-5
 */
float scaleVolts(int val) {
  return (float)((val / 1023.0f) * 5.0f);
}



/*
 * Figures out how many seconds have passed
 */
long millisElapsed(long startMillis) {
  long curMillis = millis();
  
  //Find the simple difference between the two times
  return (curMillis - startMillis);
}



/*
 * Sets up the background gradient so that things look a little nicer
 */
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
 * Reads the values from serial and displays them on the GUI
 */
public void ReadSerial() {
  //Make sure that we're ready to read from the serial port
  if (serialEnabled) {
    /*if(!isReady) {      
      //Tell the Arduino we're ready
      serialPort.write(clientReady);
      
      //Don't hammer the serial interface for no reason
      delay(500);
    }*/    
    
    //As long as we're getting data keep looping and reading from the port
    while (serialPort.available() >= 3) {
      //Make sure we don't keep asking for the Arduino to start sending data
      isReady = true;
      
      //Figure out what type of data is coming back (from first byte)
      dataID = serialPort.read(); 
      
      //Check to see if we have thrust data coming in
      if (dataID == 0xff) {
         //Read two bytes and combine them into the 0 to 1023 value
         curThrustRaw = (serialPort.read() << 8) | (serialPort.read());
         
         //Convert the value to it's voltage
         //curThrust = round(scaleVolts(curThrustRaw) * 1000.0) / 1000.0;             
         
         //If the raw thrust value is 0, don't display 0.17...
         if(curThrustRaw == 0) {
           curThrust = 0.0;
         }
         else {
           //Convert the thrust to Newtons so that the value matches the Estes documentation
           //curThrust = 0.0160651931 * curThrustRaw + 0.1727283196;
           //curThrust = 0.0079036704 * curThrustRaw - 0.3970384711; //Old calibration
           curThrust = 0.0095566744 * curThrustRaw - 0.0652739447;//Gives us the thrust in English pounds
           curThrust = curThrust * 4.448; //Gives us the thrust in Newtons
         }
         
         //Make sure that the user wants to record before you add the data to the charts
         if(recordButton.getBooleanValue() && curThrust > triggerThrust) {
           //Check to see if we've been above zero yet and initialize our start time variable
           if(!aboveZero) {
             //Save the current number of seconds since the epoch
             //startMillis = millis();
             startMillis = curTime;       
    
             //Make sure we don't enter this again
             aboveZero = true;
           }         
  
           //Add the current value to the line chart at the beginning     
           thrustChart.addData(curThrust);         
           
           //Save this thrust value to be written to file later
           thrustVals.add(curThrust);
           
           //Check to see if we should save a new peak thrust value
           if(peakThrustSlide.getValue() < curThrust) {
             peakThrustSlide.setValue(curThrust);
           }
           
           //Update the average thrust value         
           thrustTotal = thrustTotal + curThrust; //Update the total
           average = thrustTotal / numSamples; //Calculate the average         
           avgThrustSlide.setValue(average); //Set the average      
            //numSamples++;
        }
        else if(!recordButton.getBooleanValue() && aboveZero) {
          println("Writing File\n");
          
          //Filename is based on provided motor model and time stamp
          csvFile = createWriter("data/" + txtMotorModel.getText() + "_" + year() + "_" + month() + "_" + day() + "_" + hour() + "_" + minute() + "_" + second() + ".csv");
          
          //Write a header for the data to the file
          csvFile.println("Time (sec),Thrust (N),Temperature (°C)");
          
          //Step through the data and write it to the file in comma delimited format
          for(int i = 0; i < thrustVals.size(); i++) {
            //Add the current data record to the CSV file          
            csvFile.println(timeVals.get(i) + "," + thrustVals.get(i) + "," + tempVals.get(i));
          }
          
          //Make sure all data is written to the file and close it
          csvFile.flush();
          csvFile.close();
    
          //Reset the flag that tracks whether or not we're above 0
          aboveZero = false;
        }
         
        //Update the slider even if we're not recording
        curThrustSlide.setValue(curThrust);              
      }
      //Check to see if we have temperature data coming in
      else if(dataID == 0xfe) {
        //Read the temp value from the serial port as a string
        curTemp = ((serialPort.read() << 8) | (serialPort.read())) / 100.0f;
        
        //Make sure that the user wants to record before you add the data to the charts
        if(recordButton.getBooleanValue() && curThrust > triggerThrust) {
          //Add the current value to the line chart at the beginning     
          tempChart.addData(curTemp);
          
          //Save the temperature value so that it can be written to file later
          tempVals.add(curTemp);
          
          //Check to see if we should save a new peak thrust value
          if(maxTempSlide.getValue() < curTemp) {
            maxTempSlide.setValue(curTemp);
          }
           
          //Update the average thrust value         
          tempTotal = tempTotal + curTemp; //Update the total
          tempAverage = tempTotal / numSamples; //Calculate the average         
          avgTempSlide.setValue(tempAverage); //Set the average      
          numSamples++;      
        }
  
        //Set the current temp slider even if we're not recording
        curTempSlide.setValue(curTemp);      
      }
      //Check to see if we have temperature data coming in
      else if(dataID == 0xfd) {
        //Read the time stamp from the serial port as a string
        curTime = ((serialPort.read() << 24) | (serialPort.read() << 16) | (serialPort.read() << 8) | (serialPort.read()));
        
        //Make sure that the user wants to record before you add the data to the charts
        if(recordButton.getBooleanValue() && curThrust > triggerThrust) {
          //Check to see if we have a bad sample that we should discard
          if(curTime < 0) {
            // Remove the last thrust and temp values to discard the entire sample
            thrustVals.remove(thrustVals.size() - 1);
            tempVals.remove(tempVals.size() - 1);
            
            break;
          }
          
          //Update the run time
          runTime = (curTime - startMillis) / 1000.0f;                   
            
          //Save the current time value
          timeVals.add(runTime);
        }
      }        
    }
  }
}



/*
 * Sets the GUI up for use.
 */
public void SetupGUI() {
  //Set the size of the window
  size(800, 600);
  
  //TODO: Need to figure out how to make the ControlP5 elements scale to the screen. This will probably require custom coding.
  //Make sure the user can resize the window
  /*if (frame != null) {
    frame.setResizable(true);
  }*/
  
  smooth();
  
  //The font that our GUI will use
  defaultFont = createFont("arial",12);
  
  //Colors for the gradient
  c1 = 0xff9f9f9f;//color(255, 0, 0);
  c2 = 0xff545454;//color(0, 255, 0);
  
  //Our GUI library object
  cp5 = new ControlP5(this);
  
  //Set a general label for the app's upper left corner
  cp5.addTextlabel("label")
    .setText("Shepard Test Stand")
    .setPosition(5,15)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial",18));
  
  //Set a label for the drop down menu
  cp5.addTextlabel("label1")
    .setText("SERIAL PORT")
    .setPosition(195,8)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial", 9));        
     
  //Sets the file name prefix to be the motor model number
  txtMotorModel= cp5.addTextfield("")
     .setPosition(320,20)
     .setSize(100,20)
     .setFont(defaultFont)
     .setColor(0xffffffff)
     .setAutoClear(false)
     .registerTooltip("This is prepended to the beginning of the CSV file name");
     
  //Set a label for the drop down menu
  cp5.addTextlabel("label2")
    .setText("MOTOR MODEL")
    .setPosition(315,8)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial", 9));
     
  //Align the caption text
  txtMotorModel.getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(0);
     
  //Button to allow/disallow data recording
  recordButton = cp5.addButton("enableRecord")
     .setPosition(440, 20)
     .setSize(100, 20)
     .setId(1)
     .setSwitch(true)
     .setCaptionLabel("Enable Recording")
     .registerTooltip("Controls whether or not to record data to file");

  //Align the caption text to the center of the button
  recordButton.getCaptionLabel().alignX(ControlP5.CENTER); 

  //Button to clear the data
  clearButton = cp5.addButton("Clear")
     .setPosition(560, 20)
     .setSize(100, 20)
     .setId(2)
     .registerTooltip("Clear chart, average, and max data");

  //Align the caption text to the center of the button
  clearButton.getCaptionLabel().alignX(ControlP5.CENTER);  
    
  //The chart showing the thrust data
  thrustChart = cp5.addChart("thrust")
               .setPosition(30, 50)
               .setSize(650, 250)
               .setRange(0, 30)
               .setView(Chart.LINE);
               
  //Button to exit cleanly, telling the Arduino we want to disconnect
  exitButton = cp5.addButton("Exit")
     .setPosition(680, 20)
     .setSize(100, 20)
     .setId(2)
     .registerTooltip("Exits cleanly");

  //Align the caption text to the center of the button
  exitButton.getCaptionLabel().alignX(ControlP5.CENTER);               

  //Chart background color
  thrustChart.getColor().setBackground(0xff02344d);
  
  //Create a dataset to hold the thrust data
  thrustChart.addDataSet("curthrust");
  thrustChart.setColors("curthrust", color(255,255,255),color(255,0,0));
  thrustChart.setData("curthrust", new float[10]);
  
  //Set a general label for the app's upper left corner
  cp5.addTextlabel("thrustlabel")
    .setText("Thrust (N)")
    .setPosition(30,50)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial",12));
  
  //Add a vertical slider for the current thrust value
  curThrustSlide = cp5.addSlider("CUR")
    .setPosition(700,50)
    .setSize(20,250)
    .setRange(0,30)
    .setValue(0.0);      
    
  //Add a vertical slider for the peak (max) thrust value
  peakThrustSlide = cp5.addSlider("PEAK")
    .setPosition(730,50)
    .setSize(20,250)
    .setRange(0,30)
    .setValue(0.0);
    
  //Add a vertical slider for the average thrust value
  avgThrustSlide = cp5.addSlider("AVG")
    .setPosition(760,50)
    .setSize(20,250)
    .setRange(0,30)    
    .setValue(0.0);
    
  //Set the sliders value label to be centered above the bar
  curThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  peakThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  avgThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  
  //The chart showing the temperature data (max of 200 C set from NAR test procedures doc)
  tempChart = cp5.addChart("temp")
    .setPosition(30, 325)
    .setSize(650, 250)
    .setRange(0, 200)
    .setView(Chart.LINE);

  //Chart background color
  tempChart.getColor().setBackground(0xff02344d);
  
  //Create a dataset to hold the temp data
  tempChart.addDataSet("curtemp");
  tempChart.setColors("curtemp", color(255,255,255),color(255,0,0));
  tempChart.setData("curtemp", new float[10]);
  
  //Set a general label for the app's upper left corner
  cp5.addTextlabel("templabel")
    .setText("Temperature (°C)")
    .setPosition(30,325)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial",12));
  
  //Add a vertical slider for the current thrust value
  curTempSlide = cp5.addSlider("CUR2")
    .setPosition(700,325)
    .setSize(20,250)
    .setRange(0,200)
    .setValue(0.0)
    .setDecimalPrecision(1);

  //Slider labels by default use the controller name and conflicts arise
  controlP5.Label curTempLabel = curTempSlide.captionLabel();
  curTempLabel.set("CUR");  
    
  //Add a vertical slider for the peak (max) thrust value
  maxTempSlide = cp5.addSlider("MAX")
    .setPosition(730,325)
    .setSize(20,250)
    .setRange(0,200)
    .setValue(0.0)
    .setDecimalPrecision(1);
    
  //Add a vertical slider for the average thrust value
  avgTempSlide = cp5.addSlider("AVG2")
    .setPosition(760,325)
    .setSize(20,250)
    .setRange(0,200)
    .setValue(0.0)
    .setDecimalPrecision(1);
    
  //Slider labels by default use the controller name and conflicts arise
  controlP5.Label avgTempLabel = avgTempSlide.captionLabel();
  avgTempLabel.set("AVG");
    
  //Set the sliders value label to be centered above the bar
  curTempSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  maxTempSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  avgTempSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  
  //Create and add the dropdown list
  ddl1 = cp5.addDropdownList("Select Port", 200, 40, 100, 40);
  ddl1.setItemHeight(18);
  ddl1.setBarHeight(18);
  ddl1.captionLabel().style().marginTop = 5;  
  
  textFont(defaultFont);
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
