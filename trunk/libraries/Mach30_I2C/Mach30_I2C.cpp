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
 * File: Mach30_I2C.cpp                                                     *
 * Main source file for the Mach 30 Arduino I2C driver.                     *
 * This is part of a library that will be used to read I2C devices on the   *
 * Shepard Test Stand and later projects. Please see http://mach30.org for  *
 * more details on this project and others.                                 *
 ***************************************************************************/

#include "Mach30_I2C.h"
#include <inttypes.h>
 #include <compat/twi.h>

Mach30_I2C::Mach30_I2C() {
}

/* Allows the caller to simply ask for the measured temperature in Celsius 
   @param boolean for whether we want the ambient or object temperature
*/
int16_t Mach30_I2C::get_celcius_temp(unsigned char ambObjTemp) {
  unsigned char lsb, msb; //The most and least significant bytes of the data (2 bytes per read)
  unsigned char device = 0x5A << 1; //The device that we want to access (MLX90614)
  int16_t tempValue; //The converted temperature value

  //Initialize the I2C bus
  i2c_init();

  //Start an I2C write transmission, waiting for the device to become available
  if(i2c_start_wait(device + WRITE_MODE)) {
    //We want to read the ambient temperature
    if(ambObjTemp) {
      //Ambient
      i2c_write(0x06);
    }
    else {
      //Object
      i2c_write(0x07);
    }

    //Shift the device into read mode and make sure we got a value
    i2c_start_wait(device + READ_MODE);
    
    //Get the two bytes that we'll combine into our Celcius value
    lsb = i2c_readAck(); //Get the Least Significant Bit from the I2C device
    msb = i2c_readAck(); //Get the Most Significant Bit from the I2C device

    //Stop the read process
    i2c_readNack();
    i2c_stop();

    //Combine the MSB and LSB bytes into a single value
    tempValue = (int16_t)(msb << 8 | lsb);

    //Convert the temperature
    tempValue = tempValue * 2;
    tempValue = tempValue - 27315;
  }   
  else {
    //Give this default to let the user know the sensor's not connected
    tempValue = -27313;
  } 

  return tempValue;
}

/* Allows the caller to initialize the I2C bus */
void Mach30_I2C::i2c_init() {
  //Activate the internal pull up resistors on the Uno Analog channels we'll be using
  //PORTC |= _BV(4);
  //PORTC |= _BV(5); 
  PORTC = (1 << PORTC4) | (1 << PORTC5);

  //Status Register - Set up the prescaler
  TWSR &= ~(_BV(TWPS0));
  TWSR &= ~(_BV(TWPS1)); 

  //Bit Rate register - Set bit rate based on the processor frequency
  TWBR = ((F_CPU / 100000) - 16) / 2;

  //Control Register - Enable I2C and ACKs in replies
  TWCR = _BV(TWEN) | _BV(TWEA);
}

/* Sends a stop condition across the I2C bus */
void Mach30_I2C::i2c_stop(void) {
  //Send the actual stop condition
  TWCR = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);

  //Wait for the stop condition to complete
  while(TWCR & (1 << TWSTO));
}

/* Reads a byte from a device with an ACK */
unsigned char Mach30_I2C::i2c_readAck(void) {
  //Set the control register up for the read
  TWCR = (1 << TWINT) | (1 << TWEN) | (1 << TWEA); //The TWEA sets up ACK

  //Wait for the read transmit to complete
  while(!(TWCR & (1 << TWINT)));

  //The data register holds the data we're looking for
  return TWDR;
}

/* Reads a byte from a device followed by sending a stop condition */
unsigned char Mach30_I2C::i2c_readNack(void) {
  //Set the control register up for the read
  TWCR = (1 << TWINT) | (1 << TWEN); //The TWEA sets up NAK

  //Wait for the read transmit to complete
  while(!(TWCR & (1 << TWINT)));

  //The data register holds the data we're looking for
  return TWDR;
}

/* Sends a start condition along with setting up address and direction.
   Does not wait on the device to become available by default. */
unsigned char Mach30_I2C::i2c_start(unsigned char addr) {
  uint8_t i2cStatus; //The Status Register value

  //Loop until the device is ready
  //while(1) {
    //Send the start condition
    TWCR = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);

    //Wait for send to complete, but don't wait forever
    //while(!(TWCR & (1 << TWINT)));
    /*for (uint32_t i = 0; i < 1; i++) {
      //If the send is complete we can move on
      if (TWCR & (1 << TWINT)) {
        break;
      }
    }*/

    //Grab the current status from the register
    i2cStatus = TW_STATUS & 0xF8;

    //Check to see if either a start or repeated start condition was transmitted
    if (i2cStatus != TW_START && i2cStatus != TW_REP_START) {
      //The device isn't ready, so get ready for the next round
      return 1;
    }

    //Send the address of the device we want to access
    TWDR = addr;
    TWCR = (1 << TWINT) | (1 << TWEN);

    //Again, wait until this transmit has completed, but don't wait forever
    /*for (int i = 0; i < 1; i++) {
      //If the send is complete we can move on
      if (TWCR & (1 << TWINT)) {
        break;
      }
    }*/

    //Grab the current status from the register
    i2cStatus = TW_STATUS & 0xF8;

    //If we got a send confirmation but a NAK back, or the data was received but we got a NAK
    if (i2cStatus != TW_MT_SLA_ACK || i2cStatus != TW_MR_SLA_ACK) {      
      return 1;
    }

    //We've presumably read the data successfully
    return 0;
  //}
}

/* Sends a start condition along with setting up address and direction.
   Waits on the device to become available by default. */
unsigned char Mach30_I2C::i2c_start_wait(unsigned char addr) {
  uint8_t i2cStatus; //The Status Register value

  //Loop until the device is ready
  while(1) {
    //Send the start condition
    TWCR = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);

    //Wait for send to complete
    while(!(TWCR & (1 << TWINT)));

    //Grab the current status from the register
    i2cStatus = TW_STATUS & 0xF8;

    //Check to see if either a start or repeated start condition was transmitted
    if (i2cStatus != TW_START && i2cStatus != TW_REP_START) {
      //The device isn't ready, so get ready for the next round
      continue;
    }

    //Send the address of the device we want to access
    TWDR = addr;
    TWCR = (1 << TWINT) | (1 << TWEN);

    //Again, wait until this transmit has completed
    while(!(TWCR & (1 << TWINT)));

    //Grab the current status from the register
    i2cStatus = TW_STATUS & 0xF8;

    //If we got a send confirmation but a NAK back, or the data was received but we got a NAK
    if (i2cStatus == TW_MT_SLA_NACK || i2cStatus == TW_MR_DATA_NACK) {
      //Stop the write and skip to the next iteration
      i2c_stop();

      continue;
    }

    //We're done here
    break;
  }
}

/* Writes one byte to an I2C device 
   @param unsigned char of the byte we want to write to the device
   @returns 0 = success, 1 = failure*/
unsigned char Mach30_I2C::i2c_write( unsigned char data) {
  uint8_t i2cStatus; //The Status Register value

  //Send the data to the device we want to write to
  TWDR = data;
  TWCR = (1 << TWINT) | (1 << TWEN);

  //Again, wait until this transmit has completed
  while(!(TWCR & (1 << TWINT)));

  //Grab the current status from the register
  i2cStatus = TW_STATUS & 0xF8;

  //See if the write is acknowledged
  if (i2cStatus != TW_MT_DATA_ACK) {
    //Failure
    return 1;
  }
  else {
    //Success
    return 0;
  }
}