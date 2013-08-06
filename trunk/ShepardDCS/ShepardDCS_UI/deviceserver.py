"""This module gives us access to the data on the microcontroller, whether
    the interface be serial, Ethernet, or something else"""

import glob
import os
import platform
import Queue
import serial
from serial.tools import list_ports
import signal
import struct
import sys
import time

class Singleton(type):
    """We only want on point of access to the microcontroller, and a Singleton
        model allows us to do that."""
    _instances = {}
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]

# TODO: Create a base class for the Shepard device interfaces
class DeviceInterface:
    """Base class that all Shepard device interface classes need to extend"""
    # Singleton model to ensure there's only one point of access to the device
    __metaclass__ = Singleton

    # The OS that we're running on
    os_name = None

    # Holds the locations that we need to query to find the microcontroller
    device_locations = None

    # Holds the interface object that connects us to the microcontroller
    device = None

    def __init__(self): 
        # We need to know the OS for some specific calls and file locations
        self.os_name = platform.system()                  

    def close_device(self):
        """Attempts to gracefully close the connection with the Mach 30 device"""

        device.write("E")
        
    def device_active(self):
        """Tells a caller whether or not the device is connected and active"""

        # We're going to assume if it's not None anymore that it's connected
        if device != None:
            return True
        else:
            return False

    def discover_device(self):
        """Queries possible serial devices to see if they're Shepard devices.
            We expect this to be overridden."""
        # We expect this to be overridden
        pass  

    def start_datastreaming(self):
        """Streams the data from the device into the cross-thread queue"""
        # We expect this to be overridden
        pass


class SerialInterface(DeviceInterface):
    """Handles serial communications with the microcontroller."""
    # Use the Singleton model to ensure there's only one point of access to the serial device
    # This should be carried over from the base class, but I'm not positive
    #__metaclass__ = Singleton    

    def __init__(self):        
        DeviceInterface.__init__(self)    

    def discover_device(self):        
        """Queries possible serial devices to see if they're Shepard devices"""

        print "Trying to find Mach 30 device(s)..."

        # Get a list of the serial devices avaialble so we can query them
        self.device_locations = self.list_serial_ports()        
        
        # We have to walk through and try ports until we find our device
        for location in self.device_locations:
            print "Trying ", location

            # Attempt to connect to a Shepard device via serial
            try:
                # Set up the connection
                self.device = serial.Serial(location, 115200)

                # Wait for the serial interface to come up on the device
                time.sleep(2.5)

                # If it's a Shepard device it should echo this back
                self.device.write("D")
                                
                # If we got a 'D' back, we have a Shepard device
                if self.device.read(1) == 'D':
                    print "Device Found on", location

                break
            except Exception as inst:
                #print "Failed to connect:", inst
                pass

    def list_serial_ports(self):
        """Gets a list of the serial ports available on the 3 major OSes"""

        print "Listing the avaliable serial ports..."

        # Try the simple method to get a list of the serial ports first
        serial_ports = list_ports.comports()
        port_files = [] # Holds just the names of the ports and nothing else                

        # TODO: There will most likely be some extra work that is required for the Windows ports
        # Figure out which OS we're dealing with
        if self.os_name == "Windows": # Windows = COM ports             
            pass
        elif self.os_name == "Linux": # Linux = /dev/tty*
            # If we didn't find any ports try some defaults
            if len(serial_ports) > 0:
                # Add all the ports into the list we'll return
                for cur_port in serial_ports:
                    port_files.append(cur_port[0])
            else:
                port_files = glob.glob("/dev/tty*")
            
        else: # MacOS?            
            pass            

        return port_files

    def start_datastreaming(self):
        """Streams the data from the device into the cross-thread queue"""

        print "Beginning to stream data from the device..."

        # A Mach 30 device will see this as a start transmission character
        self.device.write("R")

        # Start reading the data and storing it in the queue
        while True:
            # Read the control and data bytes from the device
            control_byte = self.device.read(1)
            data_bytes = self.device.read(2)

            # Check to see which type of data we have coming back in
            if control_byte == '\xff': # Thrust data
                print "Thrust Data:", struct.unpack(">h", data_bytes[0:2])[0]
            elif control_byte == '\xfe': # Temperature data
                print "Temperature Data:", struct.unpack(">h", data_bytes[0:2])[0]
            elif control_byte == '\xfd': # Timestamp data
                print "Timestamp Data:", struct.unpack(">h", data_bytes[0:2])[0]

            # TODO: Add the code to queue this serial data for the TCP server

# TODO: Fix this so it works cross-platform (and works period)
#    def signal_handler(signal, frame):
#        """Handles the case of the user hitting ctrl+c"""

#        print "Attempting to close connection with device..."

        # Make sure the device is connected
#        if interface.device_active():
#            interface.close_device()
#
#        sys.exit(0)

def main():
    """Just here to help us test the code incrementally"""    

    # The queue for sending data between the serial and TCP threads
    q = Queue.Queue(100)

    # Gives us access to a stream of the data coming back from a Shepard device
    interface = SerialInterface()

    # TODO: Fix this so it works
    # Make sure we handle the case of a user hitting ctrl+c
    #signal.signal(signal.SIGINT, interface.signal_handler)

    # Find any Shepard devices that are connected
    interface.discover_device()

    # TODO: Check to see if a TCP client is connected before starting data transmit
    # TODO: Spin this off into its own thread
    interface.start_datastreaming()

if __name__ == "__main__":
    main()    