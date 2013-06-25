#include "Mach30_I2C.h"

/*Sets the sketch up for use*/
void setup() {
  //Set up serial comms
  Serial.begin(115200);
  
  //Use the LED pin as an output pin
  //pinMode(ledPin, OUTPUT);
  
  //Wait for the MAX31855 chip to stabilize
  delay(500);
}

/*Step through continuously reading the sensor values*/
void loop() {
  Serial.write(0xff);
}
