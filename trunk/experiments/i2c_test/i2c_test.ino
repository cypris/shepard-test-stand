#include "Mach30_I2C.h"

Mach30_I2C mlxTempProbe; //Represents the Mach 30 library for reading from the MLX90614 via I2C
char st1[30]; 

/*Sets the sketch up for use*/
void setup() {  
  //Initialize the MLX90614 for use on the I2C bus
  mlxTempProbe.i2c_init();
  
  //PORTC = (1 << PORTC4) | (1 << PORTC5);
  
  //Set up serial comms
  Serial.begin(115200);
  
  //Use the LED pin as an output pin
  //pinMode(ledPin, OUTPUT);
  
  //Wait for the MAX31855 chip to stabilize
  delay(500);
}

/*Step through continuously reading the sensor values*/
void loop() {
  int objTemp; //The object temperature being measured by the MLX temp sensor
  /*long int objTemp; //The object temperature being measured by the MLX temp sensor  
  int lsb, msb, pec;
  int dev = 0x5A << 1;
  
  mlxTempProbe.i2c_init();
  mlxTempProbe.i2c_start_wait(dev + 0);
  mlxTempProbe.i2c_write(0x06);
  mlxTempProbe.i2c_start(dev + 1);
  lsb = mlxTempProbe.i2c_readAck();
  msb = mlxTempProbe.i2c_readAck();
  pec = mlxTempProbe.i2c_readNack();
  mlxTempProbe.i2c_stop();
  
  objTemp = msb * 0x100 + lsb;
  
  objTemp = objTemp *10;
  objTemp = objTemp / 5;
  objTemp = objTemp - 27315;*/

  //Pull the temperature from the 
  objTemp = mlxTempProbe.get_celcius_temp(OBJECT_TEMP);

  sprintf(st1,"object temp: %02i.%i",objTemp / 100, abs(objTemp % 100) );
  
  Serial.print(st1);  
  Serial.println("");
  
  delay(10);
}
