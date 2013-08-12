/* Copyright (C) 2012-2013 Mach 30 - http://www.mach30.org 
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0

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
//#include <i2cmaster.h>
 
char incomingByte; //The byte being read to tell us whether or not a client is connected
char isClientConnected = 0; //Whether or not a client is read to receive data from the Arduino
char clientReadyMsg = 'R'; //The character that tells us whether or not the client is ready to recieve
char endMsg = 'Q'; //The message the client sends when it wants to disconnect
char discoverMsg = 'D'; //Message the client uses to automatically find out which port the Arduino is on
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
}

/*Step through continuously reading the sensor values*/
void loop() {    
    //Make sure that we're supposed to be transmitting data
    if (isClientConnected && Serial.available() == 0) {
        //Read the current value from the load cell (thrust sensor)
        thrustValue = analogRead(thrustPin);
        
        //Read the current value from the I2C temperature sensor
        //tempValue = i2cInterface.get_celcius_temp(OBJECT_TEMP);
        tempValue = -273.13;
        
        //Read the current time value in milliseconds
        timeValue = millis(); //TODO: Make sure we never get an overrun here
    
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
    }
    else if (Serial.available() > 0) {
        if (isClientConnected) {
            //Check to see if a client is ready to receive data
            incomingByte = Serial.read();
             
            //The client wants to disconnect
            if ((char)incomingByte == endMsg) {
                //Let the rest of the code know that the client has disconnected
                isClientConnected = 0;
                
                //End the serial communications
                Serial.end();                             
            }
        }
        else {
            //Check to see if a client is ready to receive data
            incomingByte = Serial.read();
            
            //The client is trying to discover which port the Arduino is on
            if ((char)incomingByte == discoverMsg) {                
                // Echoing it back will tell the client they've found an Arduino
                Serial.write(discoverMsg);
            }
            //The client is ready to receive
            else if ((char)incomingByte == clientReadyMsg) {
                //Let the rest of the code know that there's a client connected and ready to receive data
                isClientConnected = 1;
                
                //Wait for a little while before trying to send anything
                delay(500);
            }
            //The client wants to disconnect
            else if ((char)incomingByte == endMsg) {
                //Let the rest of the code know that the client has disconnected
                isClientConnected = 0;
                
                //End the serial communications
                Serial.end();  
            }
            else {
              Serial.write(incomingByte);
            }
        }
    }    
}
