/****************************************************************************
* Copyright (C) 2013 Mach 30 - http://www.mach30.org                        *
*                                                                           *
* Licensed under the Apache License, Version 2.0 (the "License");           *
* you may not use this file except in compliance with the License.          *
* You may obtain a copy of the License at                                   *
*                                                                           *
*       http://www.apache.org/licenses/LICENSE-2.0                          *
*                                                                           *
* Unless required by applicable law or agreed to in writing, software       *
* distributed under the License is distributed on an "AS IS" BASIS,         *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  *
* See the License for the specific language governing permissions and       *
* limitations under the License.                                            *
****************************************************************************/

/****************************************************************************
 * File: Mach30_I2C.h                                                       *
 * Include file for the Mach 30 Arduino I2C driver.                         *
 * This is part of a library that will be used to read I2C devices on the   *
 * Shepard Test Stand and later projects. Please see http://mach30.org for  *
 * more details on this project and others.                                 *
 ***************************************************************************/

//Support Arduino 1.0 and later versions
#if (ARDUINO >= 100)
 #include "Arduino.h"
#else
 #include "WProgram.h"
#endif

//Whether we're reading from or writing to the I2C device
#define READ_MODE 1
#define WRITE_MODE 0

 //Whether we want the sensors ambient or object temperatures
 #define OBJECT_TEMP 0
 #define AMBIENT_TEMP 1

class Mach30_I2C {
  public:
    Mach30_I2C();
    void i2c_init(void); // Initialize the I2C interface
    int16_t get_celcius_temp(unsigned char); //Combines all of the methods into one for the caller    
    unsigned char i2c_readAck(void); //Reads a byte and leaves the transmission going
    unsigned char i2c_readNack(void); //Reads a byte and shuts the transmission down
    unsigned char i2c_start(unsigned char); //Sends the start signal and sets up for transmission
    unsigned char i2c_start_wait(unsigned char); //Sends the start signal and sets up for transmission
    unsigned char i2c_write(unsigned char); //Writes a character to a device
    void i2c_stop(void); //Stops a transmission
};