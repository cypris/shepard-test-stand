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

import processing.serial.*; //The serial port configuration
import controlP5.*; //Our graphics library

//Global variables
boolean isRecording = false; //Tracks whether or not the user wants to record
boolean aboveZero = false; //Tracks whether or not the voltage has gone above zero
int dataID; //The ID used to separate between types of data coming from the Arduino
int curThrustRaw; //The current thrust data value in 0 to 1023 format
int numSamples = 1; //The number of samples taken so far
int X_AXIS = 1; //Specifier for an X-axis gradient
int Y_AXIS = 2; //Specifier for a Y-axis gradient
int numOfTicks = 1; //The number of ticks that will be drawn on the X axis
int bufferCount = 0; //Tracks the number of buffer samples to take after the 0 point is reached
int bufferSamples = 20; //Number of samples before and after thrust value goes above 0
long startMillis = 0; //The number of seconds on the clock when we start recording
long curTime = 0; //The time value coming from the Arduino
float runTime = 0.0; //How many seconds have passed since we started acquiring
float curThrust; //The current thrust data value coming back from the Arduino
float thrustTotal = 0.0; //Used to calculate the average thrust
float tempTotal = 0.0; //Used to calculate the average temp
float average; //Temporary variable to hold calculated average
float tempAverage; //Temporary variable to hold calculated temperature average
float curTemp; //The current temperature as read by the thermocouple
float triggerThrust = 0.33;
ArrayList thrustVals; //List of the thrust values taken during testing
ArrayList tempVals; //List of the temperature values taken during testing
ArrayList timeVals; //List of the time values taken during testing
String serialPortText = "COM5";
String incomingData = ""; //The comma delimited list of values from the Arduino
Serial serialPort; //Currently, we talk over the serial/USB cable to the Arduino
PrintWriter csvFile; //The file that we'll save the test stand data to for each run 
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
  //Initialize the arrays that hold the measured values
  thrustVals = new ArrayList();
  tempVals = new ArrayList();
  timeVals = new ArrayList();
  
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
               .setRange(0, 30)
               .setView(Chart.LINE);

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
  }
  else {
      recordButton.getCaptionLabel().setText("Enable Recording");                  
  }
  
  //As long as we're getting data keep looping and reading from the port
  while (serialPort.available() >= 3) {
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
         curThrust = 0.0160651931 * curThrustRaw + 0.1727283196;
       }
       
       //Make sure that the user wants to record before you add the data to the charts
       if(recordButton.getBooleanValue() && curThrust > triggerThrust) {
         //Check to see if we've been above zero yet and initialize our start time variable
         if(!aboveZero) {
           //Save the current number of seconds since the epoch
           startMillis = millis();
  
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
      else if(recordButton.getBooleanValue() && curThrust == 0.0 && aboveZero) {
        println("Writing File\n");
        
        //Filename is based on provided motor model and time stamp
        csvFile = createWriter("data/" + txtMotorModel.getText() + "_" + hour() + "_" + minute() + "_" + second() + ".csv");
        
        //Step through the data and write it to the file in comma delimited format
        for(int i = 0; i < thrustVals.size(); i++) {
          csvFile.println(thrustVals.get(i) + "," + tempVals.get(i) + "," + timeVals.get(i));
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
      curTemp = ((serialPort.read() << 8) | (serialPort.read())) / 1000.0f;           
      
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
    
    //Make sure that the user wants to record before you add the data to the charts
    if(recordButton.getBooleanValue() && curThrust > triggerThrust) {
      //Save the number of seconds since we started running  
      runTime = millisElapsed(startMillis) / 1000.0f;
      
      //Save the current time value
      timeVals.add(runTime);
    }
    
    //Reading the time stamp from the Arduino over serial ended up being too problemmatic.
    //Times weren't updating properly, some time stamps were getting corrupted due to serial
    //errors, etc.
    //Check to see if we have time data coming in
    /*else if(dataID == 0xfd) {
      //Read the temp value from the serial port as a string
      incomingData = serialPort.readString();
      
      //Sometimes we get corrupted data over the serial port
      //because we're trying to get the sample data too fast.
      try {
        //Make sure that the user wants to record before you add the data to the charts
        if(recordButton.getBooleanValue() && curVoltage > 0.0) {
          //Check to see if this is the first time value we've gotten
          if(startMillis == 0) {
            //Convert the string double value to a numic double      
            startMillis = Long.parseLong(incomingData);          
          }
          else {
            //Parse the millis so that we can calculate a runtime
            curTime = Long.parseLong(incomingData);
            
            //Update the run time
            runTime = (curTime - startMillis) / 1000.0f;                   
          }
        }
      }
      catch(Exception e) {
        //Place the previous temperature value in the place of our corrupted value
        println("Problem with time");
      }
    }*/
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
long millisElapsed(long startMillis) {
  long curMillis = millis();
  
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

/*Clear button click which clears the charts, averages, and maxes*/
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
