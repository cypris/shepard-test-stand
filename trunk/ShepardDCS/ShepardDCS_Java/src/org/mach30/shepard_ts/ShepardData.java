package org.mach30.shepard_ts;

public class ShepardData
{
  
  public float thrust;
  public float temp;
  public long time;
  
  public ShepardData()
  {
    clear();
  }
  
  public ShepardData(String strVer) throws Exception
  {
    String[] parts = strVer.split(",");
    if (parts.length != 3)
    {
      throw new Exception("Invalid Shepard data string");
    }
    
    time = Integer.parseInt(parts[0]);
    thrust = Float.parseFloat(parts[1]);
    temp = Float.parseFloat(parts[2]);
  }
  
  public boolean isSet()
  {
    return thrust != Float.MIN_VALUE && temp != Float.MIN_VALUE && time != Integer.MIN_VALUE;
  }
  
  public void clear() 
  {
    thrust = Float.MIN_VALUE;
    temp = Float.MIN_VALUE;
    time = Integer.MIN_VALUE;
  }
  
  @Override
  public String toString()
  {
    return time + "," + thrust + "," + temp;
  }
  
}
