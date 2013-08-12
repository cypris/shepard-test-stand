package org.mach30.shepard_ts.server;

import java.util.Arrays;
import java.util.List;

public class DataCollectionServer
{
  private static final String NO_TCP = "-notcp";
    
  public static void main(String[] args)
  {
    try
    {
      CollectionServer server = new TcpCollectionServer();
      
      List<String> arglist = Arrays.asList(args);
      if (arglist.size() > 0 && NO_TCP.equals(arglist.get(0)))
      {
        server = new ClientlessCollectionServer();
        arglist = arglist.subList(1, arglist.size());
      }
      
      server.init(arglist);
      server.listen();
      server.handleClient();
    }
    catch (Exception ex)
    {
      System.err.println();
      System.err.println("A fatal exception has occurred");
      ex.printStackTrace(System.err);
      
      System.exit(-1);
    }
  }
  
}
