package org.mach30.shepard_ts.server;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import jssc.SerialPort;
import jssc.SerialPortEvent;
import jssc.SerialPortEventListener;
import jssc.SerialPortException;
import jssc.SerialPortList;

public abstract class CollectionServer
{
  
  private static final String PORT              = "-port";
  private static final String RATE              = "-rate";
  private static final String DATA_BITS         = "-dbits";
  private static final String STOP_BITS         = "-sbits";
  private static final String PARITY            = "-parity";
  private static final String CONNECTION_DELAY  = "-conxdelay";
  private static final String CONNECTION_RETRYS = "-retrys";
  
  private static final byte DISCOVERY_COMMAND = (byte)0x44; // D
  protected static final byte READY_COMMAND = (byte)0x52; // R
  protected static final byte QUIT_COMMAND = (byte)0x51; // R
  
  private String portName  = null;
  private int baudRate     = 115200;
  private int dataBits     = 8;
  private int stopBits     = 1;
  private int parity       = 0;
  private int delay        = 2500;
  private int retrys       = 2;
  
  protected SerialPort port = null;
  
  // TODO: see if there's a better way to handle this than making it static.
  // currently, this seems to be the only way to make it so that the threads
  // can see it
  static boolean deviceConnected = false;
  
  protected String status = "";
  protected boolean errorStatus = false;
  
  
  public CollectionServer() throws Exception
  {
    
  }
  
  public final void init() throws Exception
  {
    List<String> args = new ArrayList<String>();
    // although this currently just handles argument parsing, it could 
    // conceivably handle more in the future
    parseArgs(args);
  }
  
  /**
   * Initialize the server, handling any arguments passed
   * @param args
   * @throws Exception
   */
  public final void init(List<String> args) throws Exception
  {
    // although this currently just handles argument parsing, it could 
    // conceivably handle more in the future
    parseArgs(args);
  }
  
  /**
   * Begin listening to the port the data collection hardware is connected to.
   * If a port was not specified, this will also attempt to discover the port 
   * the hardware is connected to.  
   * 
   * Note: when this function is complete, a port may not yet be connected.
   * @throws Exception
   */
  public void listen() throws Exception 
  {
    Thread t = new Thread(new PortDetector());
    t.start();
  }
    
  public abstract void handleClient() throws Exception;  
  
  
  protected void parseArgs(List<String> args) throws Exception {
    Iterator<String> iter = args.iterator();
    String arg = null;
    String param = null;
    int intParam = -1;
    
    while (iter.hasNext()) {
      arg = iter.next();
      
      // currently all of the arguments require a parameter to follow them, so
      // check to make sure there's another parameter, otherwise we're done
      if (!iter.hasNext()) {
        break;
      }
      param = iter.next();
      
      if (PORT.equals(arg)) 
      {
        portName = param;
      }
      else
      {
        try {
          intParam = Integer.parseInt(param);
          if (intParam < 0) {
            throw new NumberFormatException();
          }
        } catch (NumberFormatException nfex) {
          throw new Exception("Failed to parse parameter for " + arg + " argument.  Expected a positive integer value");
        }
        
        if (RATE.equals(arg))
        {
          baudRate = intParam;
        }
        else if (DATA_BITS.equals(arg))
        {
          dataBits = intParam;
        }
        else if (STOP_BITS.equals(arg))
        {
          stopBits = intParam;
        }
        else if (PARITY.equals(arg))
        {
          parity = intParam;
        }
        else if (CONNECTION_DELAY.equals(arg)) 
        {
          delay = intParam;
        }
        else if (CONNECTION_RETRYS.equals(arg)) 
        {
          retrys = intParam;
        }
      }      
    }
  }  
  
  private String[] getPortNames() {
    String[] portNames = null;
    
    if (port != null)
    {
      portNames = new String[1];
      portNames[0] = portName;
    }
    else
    {
      portNames = SerialPortList.getPortNames();
    }
    
    return portNames;
  }
  
  protected void setStatus(String message)
  {
    status = message;
    System.out.println(status);
  }
  
  protected void setErrorStatus(String message)
  {
    status = message;
    errorStatus = true;
    System.err.println(status);
  }
  
  
  private class PortDetector implements Runnable
  {
    
    private Exception ex = null;

    SerialPort currport = null; 
    
    @Override
    public void run()
    {
      String[] names = getPortNames();
      String name = null;
      
      for (int attempt = 0; attempt < retrys && currport == null; ++attempt)
      {
        setStatus("Starting attempt " + (attempt + 1) + " of " + retrys + " at connecting to the DAta Acquisition hardware");
        
        for (int portNameIdx = 0; portNameIdx < names.length; portNameIdx++)
        {
          name = names[portNameIdx];
  
          setStatus("Trying " + name);
          currport = new SerialPort(name);
          
          try
          {        
            if (!currport.openPort())
            {
              setErrorStatus("Failed to open port " + portName);
            }
            else if (!currport.setParams(baudRate, dataBits, stopBits, parity))
            {
              setErrorStatus("Unable to initialize serial connection");
            }
            else
            {
              DetectionListener listener = new DetectionListener();
              // currently, try to handle all the comm events, including flow
              // control
              currport.addEventListener(listener, SerialPort.MASK_RXCHAR
                | SerialPort.MASK_RXFLAG | SerialPort.MASK_CTS
                | SerialPort.MASK_DSR | SerialPort.MASK_RLSD);
              
              // delay for a bit to let the serial communications initialize
              int delayPart = delay / 10;
              for (int delayNum = 0; delayNum < 10; delayNum++)
              {
                System.out.print(".");
                Thread.sleep(delayPart);
              }
              
              // write the discovery command to attempt communication
              currport.writeByte(DISCOVERY_COMMAND);
  
              // delay for a little bit longer, just-in-case
              System.out.print(".");
              Thread.sleep(delayPart);
  
              // this is the end-of-line for the "Trying" message
              System.out.println();
              
              // if a connection was detected, update the connected port and break
              // out of the loop to stop discovery
              if (listener.isConnected())
              {
                currport.removeEventListener();
                
                port = currport;
                
                setStatus("Connected on port " + name);
                
                deviceConnected = true;
                
                break;
              }
              else
              {
                currport.removeEventListener();
                currport.closePort();
                currport = null;
              }
            }
          }
          catch (SerialPortException spex)
          {
            ex = new Exception("An error occurred initializing the serial connection", spex);
          }
          catch (InterruptedException iex)
          {
            ex = new Exception("An interrupt was encountered.", iex);
          }
        }
        
        setStatus("Attempt " + (attempt + 1) + " of " + retrys + " failed to locate the Data Acquisition hardware.");
      }
      
      if (currport == null)
      {
        setErrorStatus("Unable to connect to Data Collection Hardware");
      }
    }
    
    @SuppressWarnings("unused")
    // TODO: figure out how to handle exceptions here, or if it's even useful to get one
    public Exception getException() {
      return ex;
    }
   
    
    private class DetectionListener implements SerialPortEventListener
    {
      
      private boolean connected = false;

      @Override
      public void serialEvent(SerialPortEvent event)
      {
        if (event.isRXCHAR() || event.isRXFLAG())
        {
          try
          {
            byte[] buffer = currport.readBytes(event.getEventValue());
            
            if (!connected && buffer.length == 1)
            {
              connected = true;
            }
          } 
          catch (SerialPortException spex)
          {
          }
        }
      }
      
      public boolean isConnected()
      {
        return connected;
      }
      
    }
    
  }
  
}
