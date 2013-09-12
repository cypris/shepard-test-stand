package org.mach30.shepard_ts.server;

import jssc.SerialPortEventListener;

public class ClientlessCollectionServer extends CollectionServer
{

  public ClientlessCollectionServer() throws Exception
  {
    super();
  }

  @Override
  public void handleClient() throws Exception
  {
    SerialPortEventListener listener = null;
    
    while (listener == null)
    {
      Thread.sleep(10);
      if (port != null)
      {
        System.out.println("Initializing listener...");
        // TODO: make the instantiation of the listener an abstract getter
        listener = new EchoListener();
        port.addEventListener(listener);
        port.writeByte(READY_COMMAND);
      }
    }
  }
  
  // TODO: move this to an instance of an abstract version of ClientlessCollectionServer
  private class EchoListener extends ShepardSerialEventListener
  {
    
    public EchoListener()
    {
      super(port);
    }

    @Override
    protected void handleData()
    {
      System.out.println(this.datapoint);
    }
    
  }

}
