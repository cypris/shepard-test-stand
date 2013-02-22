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
 
#include "Adafruit_MAX31855.h"
 
int thrustPin = A0; //A0 is the input pin for FSR (thrust measurement)
int thrustValue = 0; //The value 0-1023 from the FSR's analog pin
double tempValue = 0.0; //The value (in Celsius) of the thermocouple
unsigned long timeValue = 0; //The timestamp in milliseconds since the program started
int thermoDO = 3; //The "Data Out" digital pin
int thermoCS = 4; //The "Chip Select" digital pin
int thermoCLK = 5; //The "Clock" digital pin
int ledPin = 13; //The LED pin is used in serial comms

//Set the Adafruit breakout board up for use
Adafruit_MAX31855 thermocouple(thermoCLK, thermoCS, thermoDO);

/*Sets the sketch up for use*/
void setup() {
  //Set up serial comms
  Serial.begin(115200);
  
  //Use the LED pin as an output pin
  pinMode(ledPin, OUTPUT);
  
  //Wait for the MAX31855 chip to stabilize
  delay(500);
}

/*Step through continuously reading the sensor values*/
void loop() {
  //Read the current value from the FSR (thrust sensor)
  thrustValue = analogRead(thrustPin);
  
  //Read the current value from the thermocouple
  tempValue = thermocouple.readCelsius();
  
  //Read the current time value in milliseconds
  timeValue = millis();

  //Send the thrust value to the Processing app
  Serial.write(0xff); //ID/control byte so Processing can distinguish sensors
  Serial.write((thrustValue >> 8) & 0xff); //The first byte
  Serial.write(thrustValue & 0xff); //The second byte
    
  //Send the temperature value to the Processing app
  Serial.write(0xfe); //ID/control byte so Processing can distinguish sensors
  Serial.write((round(tempValue * 1000.0f) >> 8) & 0xff);
  Serial.write(round(tempValue * 1000.0f) & 0xff);
    
  //Send the time stamp to the Processing app
  Serial.write(0xfd); //ID/control byte so Processing can distinguish sensors
  Serial.write((timeValue >> 8) & 0xff);
  Serial.write(timeValue & 0xff);  
  
  //There should be a fairly large delay here, but we're going to
  //deal with some errors in order to get a faster sample rate.
  delay(2);
}
