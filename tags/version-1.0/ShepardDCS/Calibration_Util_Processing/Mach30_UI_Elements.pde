/* Copyright (C) 2013 Mach 30 - http://www.mach30.org 
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
 * Holds classes for different types of UI elements that were created by
 * Mach 30, or customized from the ControlP5 library.
 */
 
/*
 * Holds a TextBox UI element that enables the use of multi-line text.
 */
class M30TextBox {
    int xPos; //The X position within the window
    int yPos; //The Y position within the window
    int elemWidth; //The width of the element
    int elemHeight; //The height of the element
    int lastLength; //The length of the string before the last addition
    String labelText; //The label for this text box
    String boxText = ""; //The actual text that this box contains
    color bgColor = 0xff02344d; //The background color of the
    color borderColor = 0xff016c9e; //The border color of the textbox 
    color textColor = 0xffffffff; //The color of the text within the box
    
    
    /*
     * The constructor for the textbox object. It sets the x and y
     * positions, and the height/width of the box.
     */
    M30TextBox(String label, int x, int y, int eWidth, int eHeight) {
      //Save all of the constructor values
      xPos = x;
      yPos = y;
      elemWidth = eWidth;
      elemHeight = eHeight;
      labelText = label;
      
      //Draw the label for the text box
      cp5.addTextlabel("M30CaptionLabel")
        .setText(labelText)
        .setPosition(xPos - 5, yPos - 12)
        .setColorValue(0xffffffff)
        .setFont(createFont("arial", 9));
    }
    
    /*
     * Handles the task of drawing the textbox. It sets up two rectangles,
     * on behind that creates the border, and one in front that creates the
     * text area.
     */
    void draw() {      
      //Draw the border rectangle
      fill(borderColor);
      rect(xPos, yPos, elemWidth, elemHeight);
      
      //Draw the content rectangle
      fill(bgColor);
      rect(xPos + 2, yPos + 2, elemWidth - 4, elemHeight - 4);
      
      //Set the boxes text
      fill(textColor);
      text(boxText, xPos + 5, yPos + 15);
    }
    
    /*
     * Allows the user to set the text of this textbox, complete
     * with newline characters.
     */
    void addLine(String newLine) {
       //Save the beginning of the current string so that we know where to split it delete the last line
       lastLength = boxText.length();
       
       //Save this text so that it can be drawn on the next draw() call
       boxText += newLine + '\n';   
    }
    
    /*
     * Allows the user to remove the last line that was added from the textbox.
     */
    void deleteLine() {
      //Reset the text to the way it was before the last edition
      boxText = boxText.substring(0, lastLength);      
    }
    
    /*
     * Allows the user to clear the textbox
     */
    void clearLines() {
      //Clear the box's text string
      boxText = "";
    }
}


/*
 * Holds a chart UI element that autoscales.
 */
class M30Chart {
    boolean showDots; //Tracks whether or not to display dots for the points along the line
    int xPos; //The X position within the window
    int yPos; //The Y position within the window
    int elemWidth; //The width of the element
    int elemHeight; //The height of the element
    String labelText; //The label for this text box
    Chart calibChart; //The line chart for the thrust measurement
    int curPen1Index = 0; //Where we're inserting point data in the pen 1 index
    float[][] pen1Points = new float[2][100]; //The points that make up the curve
    color bgColor = 0xff02344d; //The background color of the
    color borderColor = 0xff016c9e; //The border color of the textbox 
    color contentColor = 0xffffffff; //The color of the text within the box
    int xPrec = 0; //The number of decimal places for the x-axis values
    int yPrec = 0; //The number of decimal places for the y-axis values
    int axisOffset = 40; //How far in from the edge of the chart the axis sets
    float xMax = 1.0; //The max value for the X axis
    float yMax = 1.0; //The max value for the Y axis
    int xTicDist = 1; //The distance between the tics on the X axis
    int yTicDist = 1; //The distance between the tics on the Y axis
    
    /*
     * The constructor for the textbox object. It sets the x and y
     * positions, and the height/width of the box.
     */
    M30Chart(String label, int x, int y, int eWidth, int eHeight, boolean dots, int newXPrec, int newYPrec) {
      //Save all of the constructor values
      xPos = x;
      yPos = y;
      elemWidth = eWidth;
      elemHeight = eHeight;
      labelText = label;
      showDots = dots;
      xPrec = newXPrec;
      yPrec = newYPrec;
      
      
      //Draw the label for the text box
      cp5.addTextlabel("M30ChartLabel")
        .setText(labelText)
        .setPosition(xPos - 5, yPos - 12)
        .setColorValue(0xffffffff)
        .setFont(createFont("arial", 9)); 
   
      //Step through and set the array to an initial condition
      for(int i = 0; i < pen1Points[0].length; i++) {
        //Set the current index to -1
        pen1Points[0][i] = -1;
        pen1Points[1][i] = -1;
      }    
    }
    
    /*
     * Allows the caller to add a point onto the chart.
     */
    void addPen1Point(float xVal, float yVal) {
      //Add the values to pen 1's array
      pen1Points[0][curPen1Index] = xVal;
      pen1Points[1][curPen1Index] = yVal;
      
      //Get ready for the next point
      curPen1Index++;
    }
    
    /*
     * Draws the chart when all the other UI components are drawn.
     */
    void draw() {
      //Draw the border rectangle
      fill(borderColor);
      rect(xPos, yPos, elemWidth, elemHeight);
      
      //Draw the content rectangle
      fill(bgColor);
      rect(xPos + 2, yPos + 2, elemWidth - 4, elemHeight - 4);
      
      //Set the charct content's color
      fill(contentColor);
      stroke(contentColor);
      
      //Draw the skeleton of the scale
      strokeWeight(2);
      line(xPos + axisOffset, yPos + 10, xPos + axisOffset, yPos + elemHeight - axisOffset);
      line(xPos + axisOffset, yPos + elemHeight - axisOffset, xPos + elemWidth - 20, yPos + elemHeight - axisOffset);
      
      //Add the 0 point onto the axis
      text("0", xPos + axisOffset - 15, yPos + elemHeight - axisOffset + 15);
      
      //See if we have any points to deal with
      if(curPen1Index > 0) {        
        //Find the max and min values for the X scale
        xMax = max(pen1Points[0]);
        yMax = max(pen1Points[1]);        
  
        //Draw the tic lines for these max values
        line(xPos + axisOffset - 5, yPos + 9, xPos + axisOffset, yPos + 9);
        line(xPos + elemWidth - 20, yPos + elemHeight - axisOffset + 1, xPos + elemWidth - 20, yPos + elemHeight - (axisOffset - 5)); 
  
        //TODO: Draw the inbetween lines and values for the scale
        
        //Find out what the distance in pixels should be between the tics
        xTicDist = ((xPos + elemWidth - 20) - (xPos + axisOffset)) / 5;
        yTicDist = ((yPos + elemHeight - axisOffset) - (yPos + 10)) / 5;
        
        //Step through and add the values and tics to the X axis
        for(int i = 0; i < 5; i++) {
          //Draw the X axis tics
          line((xPos + elemWidth - 20 - xTicDist * i), (yPos + elemHeight - axisOffset + 1), (xPos + elemWidth - 20 - xTicDist * i), (yPos + elemHeight - (axisOffset - 5)));
          
          //Check to see if we have decimal places
          if(xPrec == 0) {
            //Add the X axis text
            text(nf(round(ceil(xMax) - (ceil(xMax) / 5) * i), 0, xPrec), (xPos + elemWidth - 35 - xTicDist * i), (yPos + elemHeight - 15));
          }
          else {
            //Add the X axis text
            text(nf(ceil(xMax) - (ceil(xMax) / 5.0) * i, 0, xPrec), (xPos + elemWidth - 35 - xTicDist * i), (yPos + elemHeight - 15));
          }
          
          //Draw the Y axis tics
          line((xPos + axisOffset - 5), (yPos + 9 + yTicDist * i), (xPos + axisOffset), (yPos + 9 + yTicDist * i));
                   
          //Check to see if we have decimal places
          if(yPrec == 0) {
            //Add the Y axis text
            text(nf(round(ceil(yMax) - (ceil(yMax) / 5) * i), 0, yPrec), (xPos + 5), (yPos + 13 + yTicDist * i));
          }
          else {
            //Add the Y axis text
            text(nf(ceil(yMax) - (ceil(yMax) / 5.0) * i, 0, yPrec), (xPos + 5), (yPos + 13 + yTicDist * i));
          }
        }        
      } 

      //Step through each of the calibration points and draw a circle for them
      for(int i = 0; i < pen1Points[0].length; i++) {
        //If we've reached the end of the array we need to exit the loop
        if(pen1Points[0][i] == -1) {
          break;          
        }
        
        //Draw the current calibration point's circle scaling the position in pixels to the position in values
        ellipse(((xPos + elemWidth - 20) - (xPos + axisOffset)) * (pen1Points[0][i] / xMax) + (xPos + axisOffset), (yPos + elemHeight - axisOffset) - (pen1Points[1][i] / yMax) * ((yPos + (elemHeight - axisOffset)) - (yPos + 10)), 5, 5);

        //Check to see if we need to start drawing lines
        if(i >= 1) {
          //Draw the lines between the points
          line(((xPos + elemWidth - 20) - (xPos + axisOffset)) * (pen1Points[0][i] / xMax) + (xPos + axisOffset), 
              (yPos + elemHeight - axisOffset) - (pen1Points[1][i] / yMax) * ((yPos + (elemHeight - axisOffset)) - (yPos + 10)),
              ((xPos + elemWidth - 20) - (xPos + axisOffset)) * (pen1Points[0][i - 1] / xMax) + (xPos + axisOffset), 
              (yPos + elemHeight - axisOffset) - (pen1Points[1][i - 1] / yMax) * ((yPos + (elemHeight - axisOffset)) - (yPos + 10)));  
        }        
      }            
    }
}
