package org.mach30.shepard_ts.client;

import java.io.FileInputStream;
import java.util.Properties;

public class UserPreferences extends Properties
{
  private static UserPreferences instance = null;
  
  public static String PREFERENCES_FILE = "config.properties";
  public static String SAVE_LOCATION_PROP = "SaveLocation"; 
  
  private UserPreferences()
  {
  }
  
  public String getPreference(String name)
  {
    return getProperty(name);
  }
  
  public String getPreference(String name, String def)
  {
    return getProperty(name, def);
  }
  
  public static UserPreferences getInstance()
  {
    if (instance == null)
    {
      try
      {
        instance = new UserPreferences();
        instance.load(new FileInputStream(UserPreferences.PREFERENCES_FILE));
      }
      catch (Exception ex)
      {
        instance = null;
      }
    }
    
    return instance;
  }
  
  private static final long serialVersionUID = 5665324892155253321L;
  
}
