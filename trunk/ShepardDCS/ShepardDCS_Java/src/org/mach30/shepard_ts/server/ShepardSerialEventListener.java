package org.mach30.shepard_ts.server;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;

import org.mach30.shepard_ts.ShepardData;

import jssc.SerialPort;
import jssc.SerialPortEvent;
import jssc.SerialPortEventListener;
import jssc.SerialPortException;

public abstract class ShepardSerialEventListener implements SerialPortEventListener
{
  
  private SerialPort port = null;
    
  // this is a class variable so that if the data transmitted for a control 
  // code spans events, we can try to read the data again in the next event
  private int controlCode = 0;

  private int leftoverBytes = 0;
  // this should be more than enough for any leftovers
  private byte[] leftover = new byte[256];
  // buffer used for conversion from bytes to value types
  private ByteBuffer convBuf = ByteBuffer.allocate(256); 
  
  // the time the first datapoint was collected, used for measuring sample rate
  private long start = 0;
  private long samples = 0;
  
  protected ShepardData datapoint = new ShepardData();
  
  
  public ShepardSerialEventListener()
  {    
  }

  public ShepardSerialEventListener(SerialPort serialPort)
  {    
    port = serialPort;
  }
  
  public void setSerialPort(SerialPort serialPort)
  {
    port = serialPort;
  }
  
  protected abstract void handleData();
  
  @Override
  public void serialEvent(SerialPortEvent event)
  {
    // RX events are the only ones with data
    if (event.isRXCHAR() || event.isRXFLAG())
    {
      if (start == 0)
      {
        start = System.currentTimeMillis();
      }
      
      int i = 0;
      System.out.println("Processing " + event.getEventValue() + " bytes of data...");
      try
      {
        // retrieve all the data available, and wrap it in a stream for 
        // ease-of-access
        byte[] buffer = port.readBytes(event.getEventValue());
        if (leftoverBytes > 0)
        {
          byte[] newbuf = new byte[buffer.length + leftoverBytes];
          System.arraycopy(leftover, 0, newbuf, 0, leftoverBytes);
          System.arraycopy(buffer, 0, newbuf, leftoverBytes, buffer.length);
          buffer = newbuf;
          leftoverBytes = 0;
        }
        ByteArrayInputStream stream = new ByteArrayInputStream(buffer);
        
        // iterate over all of the available bytes and read the data
        byte[] valbuf = new byte[2];
        int intval = 0;
        while (stream.available() > 0) 
        {
          // if there is no control code set from the last event, attempt
          // to process the next byte as a control code            
          if (controlCode == 0) 
          {
            controlCode = stream.read();
          }
          
          // try to read the data based upon the control code
          switch (controlCode)
          {
            case 0xff : // thrust
              intval = readShort(stream, valbuf);
              if (intval != Integer.MIN_VALUE)
              {
                datapoint.thrust = (0.0095566744f * (float)intval - 0.0652739447f) * 4.448f;
              }
              break;
            case 0xfe : // temperature
              intval = readShort(stream, valbuf);
              if (intval != Integer.MIN_VALUE)
              {
                datapoint.temp = intval / 100.0f;
              }
              break;
            case 0xfd : // time stamp
              intval = readShort(stream, valbuf);
              if (intval != Integer.MIN_VALUE)
              {
                datapoint.time = intval;
              }
              break;
            default :
              System.out.println("Encountered unknown control code " + controlCode);
              break;
          }
          
          if (datapoint.isSet())
          {
            handleData();
            i++;
            datapoint.clear();
          }
        }
      } 
      catch (SerialPortException spex)
      {
      }
      catch (IOException ioex)
      {          
      }
      
      samples += i;
      double rate = System.currentTimeMillis() - start;
      rate /= 1000.0f;
      rate = samples / rate;
      rate = Math.round(rate);
      System.out.println(i + " data points, ~" + (int)rate + "Samples/s");
    }
  }
  
  private int readShort(ByteArrayInputStream stream, byte[] valbuf) 
      throws IOException
  {
    int ret = Integer.MIN_VALUE;
    
    if (stream.available() > 1)
    {
      // read the bytes
      stream.read(valbuf);
      convBuf.put(valbuf);
      convBuf.rewind();
      
      // get the value they represent
      ret = convBuf.getShort();
      
      convBuf.rewind();

      // reset the control code to indicate that that the current one was read
      controlCode = 0;
    }
    else
    {
      leftoverBytes = stream.read(leftover);
    }
    
    return ret;
  }

}
