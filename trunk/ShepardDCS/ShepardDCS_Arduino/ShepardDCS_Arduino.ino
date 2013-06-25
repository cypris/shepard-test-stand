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
 * The first is a force sensor (load cell) that measures the trust of the rocket motor
 * under test. The second is a non-contact IR temperature sensor which measures the casing 
 * temperature at the throat of the motor. The temperature sensor uses I2C for its
 * interface and thus requires the Mach30_I2C library.
 */

#include "Mach30_I2C.h"
 
char incomingByte; //The byte being read to tell us whether or not a client is connected
char isClientConnected = 0; //Whether or not a client is read to receive data from the Arduino
char clientReady = 'R'; //The character that tells us whether or not the client is ready to recieve
int thrustPin = A0; //A0 is the input pin for load cell (thrust measurement)
int thrustValue = 0; //The value 0-1023 from the load cell's analog pin
int tempValue = 0; //The object temperature (in sans-decimal point Celsius format) of the I2C temperature sensor
unsigned long timeValue = 0; //The timestamp in milliseconds since the program started
int ledPin = 13; //The LED pin is used in serial comms
Mach30_I2C i2cInterface; //Represents the Mach 30 library for reading from the MLX90614 via I2C

/*Sets the sketch up for use*/
void setup() {
  //Initialize the MLX90614 sensor
  i2cInterface.i2c_init();

  //Set up serial comms
  Serial.begin(115200);
  
  //Use the LED pin as an output pin
  pinMode(ledPin, OUTPUT);
  
  //Wait for things to complete before moving on
  delay(500);
}

/*Step through continuously reading the sensor values*/
void loop() {
  //If a client hasn't connected, we need to see if one wants to
  if (Serial.available() > 0 && !isClientConnected) {    
    //Check to see if a client is ready to receive data
    incomingByte = Serial.read();    

    //Check to see if were told the client is ready
    if ((char)incomingByte == clientReady) {
      //Let the rest of the code know that there's a client connected and ready to receive data
      isClientConnected = 1;
    }  
    else {
      delay(25);
    }    
  }
  
  //Make sure that we're supposed to be transmitting data
  if (isClientConnected) {
    //Read the current value from the load cell (thrust sensor)
    thrustValue = analogRead(thrustPin);
    
    //Read the current value from the I2C temperature sensor
    tempValue = i2cInterface.get_celcius_temp(OBJECT_TEMP);
    
    //Read the current time value in milliseconds
    timeValue = millis();
  
    //Send the thrust value to the Processing app
    Serial.write(0xff); //ID/control byte so Processing can distinguish sensors
    Serial.write((thrustValue >> 8) & 0xff); //The first byte
    Serial.write(thrustValue & 0xff); //The second byte
      
    //Send the temperature value to the Processing app
    Serial.write(0xfe); //ID/control byte so Processing can distinguish sensors    
    Serial.write((tempValue >> 8) & 0xff); //First byte
    Serial.write(tempValue & 0xff); //Second byte
      
    //Send the time stamp to the Processing app
    Serial.write(0xfd); //ID/control byte so Processing can distinguish sensors
    Serial.write((timeValue >> 8) & 0xff); //First byte
    Serial.write(timeValue & 0xff); //Second byte
    
    //There should be a fairly large delay here, but we're going to
    //deal with some errors in order to get a faster sample rate.
    //delay(2);
  }
}
