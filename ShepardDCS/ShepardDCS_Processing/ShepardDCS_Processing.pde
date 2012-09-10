/* Copyright (C) 2012 Mach 30 - http://www.mach30.org 
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
 * under test. The second is a thermocouple which measures the casing 
 * temperature at the throat of the motor.
 */

 /*The serial port configuration is set up to work with Linux and not Windows*/
import processing.serial.*;
import controlP5.*;

//Global variables
boolean isRecording = false; //Tracks whether or not the user wants to record
int dataID; //The ID used to separate between types of data coming from the Arduino
int curValue; //The current data value coming back from the Arduino
int numSamples = 1; //The number of samples taken so far
int X_AXIS = 1; //Specifier for an X-axis gradient
int Y_AXIS = 2; //Specifier for a Y-axis gradient
int numOfTicks = 1; //The number of ticks that will be drawn on the X axis
int startMillis = 0; //The number of seconds on the clock when we start recording
float runTime = 2.0; //How many seconds have passed since we started acquiring
float curVoltage; //The current voltage being returned by a sensor
float thrustTotal = 0.0; //Used to calculate the average thrust
float average; //Temp variable to hold calculated average
int[] thrustVals; //An array of the thrust values taken during testing
int[] tempVals; //An array of the temperature values taken during testing
String serialPortText = "/dev/ttyACM0";
Serial serialPort; //Currently, we talk over the serial/USB cable to the Arduino
PFont defaultFont; //The default font for the app
color c1; //Gradient color 1
color c2; //Gradient color 2
ControlP5 cp5; //The interface object that gives us access to the GUI library
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
Button clearButton; //The clears the charts, averages, maxes, etc

/*Sets this app up for operation (window, serial, value storage, etc).*/
void setup() 
{
  //Set the size of the window
  size(800, 600);
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
    .setPosition(10,15)
    .setColorValue(0xffffffff)
    .setFont(createFont("arial",18));  
    
  //Allows us to set the serial port the Arduino is on
  txtSerialPort = cp5.addTextfield("Serial Port")
     .setPosition(200,20)
     .setSize(100,20)
     .setFont(defaultFont)
     .setColor(0xffffffff)
     .setAutoClear(false)
     .setValue(serialPortText)
     .registerTooltip("The serial port that the Arduino is communicating on");
     
  //Align the caption text
  txtSerialPort.getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(0);         
     
  //Sets the file name prefix to be the motor model number
  txtMotorModel= cp5.addTextfield("Motor Model")
     .setPosition(320,20)
     .setSize(100,20)
     .setFont(defaultFont)
     .setColor(0xffffffff)
     .setAutoClear(false)
     .registerTooltip("This is prepended to the beginning of the CSV file name");
     
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

  //Button to allow/disallow data recording
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
               .setRange(0, 10)
               .setView(Chart.LINE);

  //Chart background color
  thrustChart.getColor().setBackground(0xff02344d);
  
  //Create a dataset to hold the thrust data
  thrustChart.addDataSet("curthrust");
  thrustChart.setColors("curthrust", color(255,255,255),color(255,0,0));
  thrustChart.setData("curthrust", new float[1000]);
  
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
    .setRange(0,10)
    .setValue(0.0);      
    
  //Add a vertical slider for the peak (max) thrust value
  peakThrustSlide = cp5.addSlider("PEAK")
    .setPosition(730,50)
    .setSize(20,250)
    .setRange(0,10)
    .setValue(0.0);
    
  //Add a vertical slider for the average thrust value
  avgThrustSlide = cp5.addSlider("AVG")
    .setPosition(760,50)
    .setSize(20,250)
    .setRange(0,10)
    .setValue(0.0);
    
  //Set the sliders value label to be centered above the bar
  curThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  peakThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  avgThrustSlide.getValueLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0);
  
  //The chart showing the temperature data
  tempChart = cp5.addChart("temp")
    .setPosition(30, 325)
    .setSize(650, 250)
    .setRange(0, 5)
    .setView(Chart.LINE);

  //Chart background color
  tempChart.getColor().setBackground(0xff02344d);
  
  //Create a dataset to hold the temp data
  tempChart.addDataSet("curtemp");
  tempChart.setColors("curtemp", color(255,255,255),color(255,0,0));
  tempChart.setData("curtemp", new float[1000]);
  
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
  
  //The serial port that the Arduino is connected to
  serialPort = new Serial(this, serialPortText, 115200);
  
  textFont(defaultFont);  
}

/*Draws the GUI and all its components for us*/
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

    //Save the number of seconds since we started running  
    runTime = millisElapsed(startMillis) / 1000.0f; 
  }
  else {
      recordButton.getCaptionLabel().setText("Enable Recording");
      
      //Reset the number of samples taken and the tally of the thrust values
      numSamples = 1;
      thrustTotal = 0.0;
  }
  
  //As long as we're getting data keep looping and reading from the port
  while (serialPort.available() >= 3) {
    //Figure out what type of data is coming back (from first byte)
    dataID = serialPort.read();
    
    //Check whether we have thrust or temperature data coming back
    if (dataID == 0xff) {
       //Read two bytes and combine them into the 0 to 1023 value
       curValue = (serialPort.read() << 8) | (serialPort.read());
       
       //Convert the value to it's voltage
       curVoltage = round(scaleVolts(curValue) * 1000.0) / 1000.0;
       
       //Make sure that the user wants to record before you add the data to the charts
       if(recordButton.getBooleanValue() && curVoltage > 0.0) {
         //Add the current value to the line chart at the beginning     
         thrustChart.addData(curVoltage);
         
         //Check to see if we should save a new peak thrust value
         if(peakThrustSlide.getValue() < curVoltage) {
           peakThrustSlide.setValue(curVoltage);
         }
         
         //Update the average thrust value         
         thrustTotal = thrustTotal + curVoltage; //Update the total
         average = thrustTotal / numSamples; //Calculate the average         
         avgThrustSlide.setValue(average); //Set the average      
         numSamples++;
       }
       
       //Update the slider even if we're not recording
       curThrustSlide.setValue(curVoltage);              
    }
  }
}

/*Draws X and Y scales for a chart since controlp5 doesn't include this feature*/
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

/*The 0-1023 value that we get back corresponds to a voltage 0-5*/
float scaleVolts(int val) {
  return (float)((val / 1023.0f) * 5.0f);
}

/*Figures out how many seconds have passed*/
int millisElapsed(int startMillis) {
  int curMillis = millis();
  
  //Find the simple difference between the two times
  return (curMillis - startMillis);
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

/*Called when */
void controlEvent(ControlEvent theEvent) {
  if(theEvent.isAssignableFrom(Textfield.class)) {
    println("controlEvent: accessing a string from controller '"
            +theEvent.getName()+"': "
            +theEvent.getStringValue()
            );
            
    //Save the new serial port value
    serialPortText = theEvent.getStringValue();
    
    //Set the Arduino serial port to the new value
    serialPort = new Serial(this, serialPortText, 115200);
  }
}

public void enableRecord(int theValue) {
  //Save the current number of seconds since the epoch
  startMillis = millis();
}
