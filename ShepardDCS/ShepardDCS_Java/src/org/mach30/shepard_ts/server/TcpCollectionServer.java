package org.mach30.shepard_ts.server;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Iterator;
import java.util.List;

import jssc.SerialPortEventListener;
import jssc.SerialPortException;

public class TcpCollectionServer extends CollectionServer
{
  
  private static final String SERVER_PORT_ARG = "-tcpport";
  
  private ServerSocket serverSocket = null;
  private Socket clientSocket = null;
  
  private int serverPort = 9999;
  
  private PrintWriter clientOut = null;
  private BufferedReader clientIn = null;
  
  public TcpCollectionServer() throws Exception
  {
    super();
  }
  
  @Override
  protected void parseArgs(List<String> args) throws Exception
  {
    super.parseArgs(args);
    
    Iterator<String> iter = args.iterator();
    while (iter.hasNext())
    {
      if (SERVER_PORT_ARG.equals(iter.next()) && iter.hasNext())
      {
        serverPort = Integer.parseInt(iter.next());
      }
    }
  }

  @Override
  public void handleClient() throws Exception
  {
    try 
    {
      serverSocket = new ServerSocket(serverPort);
    }
    catch (IOException ioex)
    {
      close();
      throw new Exception("Failed to listen on port " + serverPort);
    }
    
    Thread clientThread = new Thread(new TcpClientComms());
    clientThread.start();

    SerialPortEventListener listener = null;    
    String lastStatus = status;
    while (listener == null)
    {
      if (!lastStatus.equals(status))
      {
        lastStatus = status;
        if (clientOut != null) {
          clientOut.println(lastStatus);
        }
      }
      
      Thread.sleep(10);
      
      if (port != null)
      {
        System.out.println("Initializing listener...");
        // TODO: make an abstract getter for the listener
        listener = new TcpWriteOnEventListener();
        port.addEventListener(listener);
      }
    }
  }
  
  private void close()
  {
    try
    {
      clientSocket.close();
    }
    catch (IOException ioex)
    {      
    }
    try
    {
      serverSocket.close();
    }
    catch (IOException ioex)
    {      
    }
    if (port.isOpened())
    {
      try
      {
        port.writeByte(QUIT_COMMAND);
      }
      catch (SerialPortException spex)
      {
      }
    }
    try
    {
      port.closePort();
    }
    catch (SerialPortException spex)
    {      
    }
  }
  
  
  private class TcpClientComms implements Runnable
  {

    @Override
    public void run()
    {
      while (clientSocket == null)
      {
        // wait to accept a connection with the client.  if an error is
        // encountered, reset the socket and go back to attempting a 
        // connection
        try 
        {
          clientSocket = serverSocket.accept();
          System.out.println("Established connection with client");
        }
        catch (IOException ioex)
        {
          System.err.println("Failed to establish connection with client");
          System.err.println(ioex);
          clientSocket = null;
        }
      
        // attempt to open read/write streams with the client socket.  if an
        // exception is encountered, reset the socket to null and continue
        // the loop so that we can try to reestablish a connection
        try
        {
          clientOut = new PrintWriter(clientSocket.getOutputStream(), true);
          clientIn = new BufferedReader(new InputStreamReader(
              clientSocket.getInputStream()));
        }
        catch (IOException ioex)
        {
          System.err.println("Failed to complete connection with clinet.");
          System.err.println(ioex);
          closeClientConnection();
          continue;
        }
        
        // at this point, a good connection is established.
        
        clientOut.println("Connection established");
        if (!status.isEmpty())
        {
          clientOut.println("Current server status: " + status);
        }
        
        
        try
        {
          String input = null;
          while ((input = clientIn.readLine()) != null)
          {
            // if the device is not yet connected, wait to execute client commands
            while (port == null || !CollectionServer.deviceConnected)
            {
              System.out.println("Waiting for device connection... (" + (port == null) + "," + !CollectionServer.deviceConnected + ")");
              try
              {
                Thread.sleep(250);
              }
              catch (InterruptedException e)
              {
              }
            }
            
            System.out.println("Received from client: " + input);
            if ("R".equals(input))
            {
              System.out.println("Ready command received.  Initiating " +
                  "communication with DCS hardware...");
              try
              {
                port.writeByte(READY_COMMAND);
                System.out.println("Command sent to DCS.");
              }
              catch (SerialPortException spex)
              {
                System.err.println(spex);
                close();
              }
            }

            if ("Q".equals(input))
            {
              System.out.println("Quit command received.  Stopping data collection...");
              try
              {
                port.writeByte((byte) 0x51);
                System.out.println("Command sent to DCS.");
              }
              catch (SerialPortException spex)
              {
                System.err.println(spex);
                close();
              }
            }
          }
          
          // if we've reached here, it means that the client has been disconnected
          closeClientConnection();
        }
        catch (Exception ex)
        {
          System.err.println("An error was encountered communicating with the client");
          System.err.println(ex);
          closeClientConnection();
        }
      }
    }
    
    /**
     * Call this method as a result of a handled exception in order to close
     * the client socket and reset it to null.
     */
    private void closeClientConnection()
    {
      try
      {
        clientIn.close();
        clientOut.close();
        clientSocket.close();
      }
      catch (IOException ioex2)
      {
      }
      clientSocket = null;
      clientIn = null;
      clientOut = null;
    }
    
  }
  

  // TODO: move this to an implementation of the abstract TcpCollectionServer
  private class TcpWriteOnEventListener extends ShepardSerialEventListener
  {
        
    public TcpWriteOnEventListener()
    {
      super(port);
    }

    @Override
    protected void handleData()
    {
      // verify that there's still a connection to the client
      if (clientOut != null)
      {
        clientOut.println(this.datapoint);
      }
    }
    
  }
  
}
