"""This module gives us access to the data on the microcontroller, whether
    the interface be serial, Ethernet, or something else"""

import glob
import os
import platform
import queue
import serial
#from serial.tools import list_ports
import signal
import socket
import socketserver
import struct
import sys
import threading
import time

class Singleton(type):
    """We only want on point of access to the microcontroller, and a Singleton
        model allows us to do that."""
    _instances = {}
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]

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

        self.device.write(bytes("Q", 'UTF-8'))
        
    def device_active(self):
        """Tells a caller whether or not the device is connected and active"""

        # We're going to assume if it's not None anymore that it's connected
        if self.device != None:
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

        print("Trying to find Mach 30 device(s)...")

        # Get a list of the serial devices avaialble so we can query them
        #self.device_locations = self.list_serial_ports()
        self.device_locations = [ 'COM1', 'COM2', 'COM3', 'COM4', '/dev/ttyACM0', '/dev/ttyACM1' ]
        
        # We have to walk through and try ports until we find our device
        for location in self.device_locations:
            print("Trying ", location)

            # Attempt to connect to a Shepard device via serial
            try:
                # Set up the connection
                self.device = serial.Serial(location, 115200)

                # Wait for the serial interface to come up on the device
                time.sleep(2.5)

                # If it's a Shepard device it should echo this back
                self.device.write(bytes("D", 'UTF-8'))
                self.device.flush()
                                
                # If we got a 'D' back, we have a Shepard device
                if self.device.read(1) == 'D':
                    print("Device Found on", location)

                break
            except Exception as inst:
                #print "Failed to connect:", inst
                pass

    def list_serial_ports(self):
        """Gets a list of the serial ports available on the 3 major OSes"""

        print("Listing the avaliable serial ports...")

        # Try the simple method to get a list of the serial ports first
        serial_ports = serial.tools.list_ports.comports()
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

        print("Beginning to stream data from the device...")

        # A Mach 30 device will see this as a start transmission character
        self.device.write(bytes("R", 'UTF-8'))
        self.device.flush()

        # Used to store our calculated values from the device
        data_list = []

        # Start reading the data and storing it in the queue
        while True:
            # Read the control and data bytes from the device
            control_byte = self.device.read(1)            

            # Check to see which type of data we have coming back in
            if control_byte == b'\xff': # Thrust data                
                # The thrust value is two bytes
                data_bytes = self.device.read(2)

                # Convert the raw thrust bytes to an integer
                raw_thrust = struct.unpack(">h", data_bytes[0:2])[0]

                # Apply our calibration to the raw thrust
                calib_thrust = (0.0095566744 * raw_thrust - 0.0652739447) * 4.448

                # Save our thrust value so we can send it to the client
                data_list.append(str(calib_thrust))

                #print "Thrust Data:", calib_thrust
            elif control_byte == b'\xfe': # Temperature data
                # The temperature value is two bytes
                data_bytes = self.device.read(2)

                # Convert the raw temperature bytes to an integer
                raw_temperature = struct.unpack(">h", data_bytes[0:2])[0]

                # Convert the raw to an actual temperature
                temperature = raw_temperature / 100.0

                # Save our temperature value so we can send it to the client
                data_list.append(str(temperature))

                #print "Temperature Data:", temperature
            elif control_byte == b'\xfd': # Timestamp data
                # The time value is four bytes
                data_bytes = self.device.read(4)

                time_stamp = struct.unpack(">L", data_bytes[0:4])[0]

                # Save our time stamp value so we can send it to the client
                data_list.append(str(time_stamp))

                #print "Timestamp Data:", struct.unpack(">h", data_bytes[0:2])[0]
                #print ",".join(data_list)

                # Add this line to the thread safe queue to be sent to the client                                        
                q.put(",".join(data_list))
                data_list = []

            # TODO: Add the code to queue this serial data for the TCP server

    # TODO: Make sure this works cross-platform
    def signal_handler(self, signal, frame):
        """Handles the case of the user hitting ctrl+c"""

        print("Attempting to close connection with device...")

        # Make sure the device is connected
        if self.device_active():
            self.close_device()

        sys.exit(0)

# The queue for sending data between the serial and TCP threads
q = queue.Queue(1000)

def main():
    """Just here to help us test the code incrementally"""    

    # TODO: Check to see if a TCP client is connected before starting data transmit
    # Start datastreaming, but spin it off into its own thread with a queue for thread safety
    #t = threading.Thread(target=interface.start_datastreaming)
    #t.daemon = True
    #t.start()

    # Where our client UI will connect
    HOST, PORT = "localhost", 9999

    # Create the server, binding to localhost on port 9999
    server = socketserver.TCPServer((HOST, PORT), TCPHandler)

    # TODO: Doesn't seem to help with a SocketServer object
    # Make sure we don't get locked out of the port when hitting CTRL-C
    #server.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    print("Waiting on client to connect and request streaming...")

    # Activate the server; this will keep running until you interrupt the program with Ctrl-C
    server.serve_forever()

    #while True:
        # TODO: Set this up so that we remove values from the queue to send to the TCP client
    #    item = q.get()
    #    print item
    #    q.task_done()

    #interface.start_datastreaming()

class TCPHandler(socketserver.BaseRequestHandler):
    """Handles TCP requests from our client UI."""

    in_data = None # The data coming from the client

    def handle(self):
        # self.request is the TCP socket connected to the client
        #self.data = self.request.recv(1024).strip()
        #print "{} wrote:".format(self.client_address[0])
        #print self.data
        # just send back the same data, but upper-cased
        #self.request.sendall(self.data.upper()) 

        # The client has to ask to start the data streaming
        self.in_data = self.request.recv(1024).strip()
        
        # Check to see if the client is ready for data streaming
        if self.in_data.decode("utf-8") == "R":        
            # Gives us access to a stream of the data coming back from a Shepard device
            interface = SerialInterface()

            # Find any Shepard devices that are connected
            interface.discover_device()

            # Make sure we handle the case of a user hitting ctrl+c
            signal.signal(signal.SIGINT, interface.signal_handler)

            # Start datastreaming, but spin it off into its own thread with a queue for thread safety
            t = threading.Thread(target=interface.start_datastreaming)
            t.daemon = True
            t.start()

        # Begin streaming the data to the client
        while True:
            self.request.sendall(bytes(q.get() + '\n', 'UTF-8'))
            q.task_done()

if __name__ == "__main__":
    main()    