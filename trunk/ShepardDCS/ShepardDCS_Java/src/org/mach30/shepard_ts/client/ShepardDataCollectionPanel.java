package org.mach30.shepard_ts.client;

import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URL;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JFileChooser;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;

import jssc.SerialPortEventListener;

import org.mach30.shepard_ts.server.CollectionServer;
import org.mach30.shepard_ts.server.ShepardSerialEventListener;

public class ShepardDataCollectionPanel extends JPanel implements ActionListener
{
  
  private static final String CONNECT = "Connect";
  private static final String RECORD = "Record";
  private static final String CSV_HEADER = "TIME(ms),THRUST(N),TEMPERATURE(c)";

  
  private boolean connected = false;  
  private boolean recording = false;
  private UserPreferences preferences = UserPreferences.getInstance();
  private FileOutputStream csvOutput = null;
  
  private ShepardDataPanel thrustPanel = null;
  private ShepardDataPanel tempPanel = null;
  
  private JTextField notation = null;
  private JButton connectButton = null;
  private JButton recordButton = null;
  private JButton clearButton = null;
  private JButton prefButton = null;
  private PreferencesPanel prefPanel = null;

  public ShepardDataCollectionPanel()
  {
    initUI();
  }
  
  @Override
  public Dimension getMinimumSize()
  {
    return new Dimension(854, 480);
  }
  
  @Override
  public Dimension getPreferredSize()
  {
    return new Dimension(1000, 600);
  }
  
  private void initUI()
  {
    BoxLayout layout = new BoxLayout(this, BoxLayout.LINE_AXIS);
    this.setLayout(layout);
    
    JPanel topPanel = new JPanel();
    BoxLayout topLayout = new BoxLayout(topPanel, BoxLayout.LINE_AXIS);
    topPanel.setLayout(topLayout);
    
    JLabel title = new JLabel("Shepard Test Stand");
    title.setFont(new Font(Font.SANS_SERIF, Font.PLAIN, 20));
    topPanel.add(title);
    
    notation = new JTextField(10);
    notation.setToolTipText("The motor model or other notation about what " +
        "the data being recorded is about");
    topPanel.add(notation);    
    
    connectButton = new JButton(CONNECT);
    connectButton.addActionListener(this);
    connectButton.setToolTipText("Connect / disconnect from the Shepard Data " +
        "Collection Server");
    topPanel.add(connectButton);
    
    recordButton = new JButton(RECORD);
    recordButton.addActionListener(this);
    recordButton.setToolTipText("Toggle recording of data from the Data " +
        "Collection hardware");
    topPanel.add(recordButton);
    
    clearButton = new JButton("Clear");
    clearButton.addActionListener(this);
    recordButton.setToolTipText("Clear the data currently graphed");
    topPanel.add(clearButton);

    prefButton = new JButton("Preferences");
    prefButton.addActionListener(this);
    prefButton.setToolTipText("Set application preferences");
    topPanel.add(prefButton);

    JFileChooser fileChooser = new JFileChooser();
    fileChooser.setToolTipText("The location to save recorded data");
    fileChooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
    
    JPanel leftPanel = new JPanel();
    BoxLayout leftLayout = new BoxLayout(leftPanel, BoxLayout.PAGE_AXIS);
    leftPanel.setLayout(leftLayout);
    
    leftPanel.add(topPanel);
        
    thrustPanel = new ShepardDataPanel("Thrust (N)", 42);
    leftPanel.add(thrustPanel);
    tempPanel = new ShepardDataPanel("Temperature (C)", 380);
    leftPanel.add(tempPanel);
    
    add(leftPanel);

    JPanel rightPanel = new JPanel();
    BoxLayout rightLayout = new BoxLayout(rightPanel, BoxLayout.PAGE_AXIS);
    rightPanel.setLayout(rightLayout);
    rightPanel.setBackground(Color.WHITE);
    
    URL shepardLogoPath = this.getClass().getResource("/resources/images/Shepard-200px.png");
    ImagePanel shepardLogo = new ImagePanel(shepardLogoPath);
    rightPanel.add(shepardLogo);
    
    URL mach30LogoPath = this.getClass().getResource("/resources/images/Mach30stacked-lt-200px.png");
    ImagePanel mach30Logo = new ImagePanel(mach30LogoPath);
    rightPanel.add(mach30Logo);
    
    add(rightPanel);

    setBackground(Color.WHITE);
    setVisible(true);
  }

  @Override
  public void actionPerformed(ActionEvent event)
  {
    if (event.getSource() == connectButton)
    {
      if (!connected)
      {
        // currently no option to disconnect
        connectToServer();
      }
    }
    else if (event.getSource() == recordButton)
    {
      if (connected)
      {
        if (recording)
        {
          // if recording, disable recording and close the output file.
          recordButton.setText(RECORD);
          recording = false;
          
          try
          {
            csvOutput.close();
          }
          catch (IOException e)
          {
          }
          csvOutput = null;
        }
        else
        {
          // try to open the output file.  if it succeeds without issue, the header line is
          // appended to the file and the record state is enabled.
          try
          {
            csvOutput = new FileOutputStream(getFileName());
            
            // add the header
            addLineToCSV(CSV_HEADER);
            
            recordButton.setText("Stop Recording");
            recording = true;
          }
          catch (IOException e)
          {
            csvOutput = null;
            JOptionPane.showMessageDialog(
                this,
                "Unable to open the output file for writing.  Make sure you have permission " +
                "to write to " + preferences.getPreference(UserPreferences.SAVE_LOCATION_PROP) + 
                " or change your default save location under Preferences.");
          }
        }
      }
    }
    else if (event.getSource() == clearButton)
    {
      thrustPanel.clear();
      tempPanel.clear();
    }
    else if (event.getSource() == prefButton)
    {
      // open the preferences panel, initializing it if necessary
      if (prefPanel == null)
      {
        prefPanel = PreferencesPanel.getPanel();
        prefPanel.addActionListener(this);
      }
      else
      {
        prefPanel.reopen();
      }
    }
    else if (event.getSource() == prefPanel)
    {
      // retrieve the updated preferences.  this may not be necessary since there should only be one
      // instance of the preferences.
      preferences = prefPanel.getPreferences();
    }
  }
    
  private void connectToServer()
  {
    connectButton.setText("Connecting...");
    Thread t = new Thread(new ShepardServerCommunications(this));
    t.start();
  }
  
  /**
   * Get the current name of the output file.  The name is based upon the current date/time, and 
   * includes the notation that the user has specified.  The notation string is also modified to 
   * replace special characters (such as directory separators) with an underscore.
   * @return The user specified notation prefixed with the current date/time stamp, with a CSV 
   *     extension.
   */
  private String getFileName()
  {
    DateFormat format = new SimpleDateFormat("yyyy-MM-dd__HH_mm");
    
    String ret = new String();
    ret += preferences.getPreference(UserPreferences.SAVE_LOCATION_PROP);
    ret += format.format(new Date());
    
    String notationStr = notation.getText().trim();
    if (!notationStr.isEmpty()) 
    {
      ret += "__" + notationStr.replaceAll(" \t/\\:", "_");
    }
    
    ret += ".csv";
    
    return ret;
  }
  
  /**
   * Append a line to the CSV file.  A newline character is added after the string is written.
   * @param str A string to append
   * @throws IOException
   */
  private void addLineToCSV(String str) throws IOException
  {
    csvOutput.write(str.getBytes());
    csvOutput.write('\n');
  }
  
  
  private class ShepardGUICollectionServer extends CollectionServer
  {

    private Component parent = null;

    public ShepardGUICollectionServer(Component parent) throws Exception
    {
      super();
      this.parent = parent;
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
          listener = new ShepardDataListener(parent);
          port.addEventListener(listener);
          port.writeByte(READY_COMMAND);
        }
        else if (errorStatus) 
        {
          JOptionPane.showMessageDialog(parent, status);
          break;
        }
      }
    }
    
    
    private class ShepardDataListener extends ShepardSerialEventListener
    {
      
      private Component parent = null;
      
      public ShepardDataListener(Component parent) 
      {
        super(port);
        this.parent = parent;
      }

      @Override
      protected void handleData()
      {
        if (recording)
        {
          thrustPanel.addPoint(this.datapoint.thrust, this.datapoint.time);
          tempPanel.addPoint(this.datapoint.temp, this.datapoint.time);
          
          try
          {
            addLineToCSV(this.datapoint.toString());
          }
          catch (IOException e)
          {
            recording = false;
            JOptionPane.showMessageDialog(parent, "An error occurred appending data to the data file.  Recording has automatically been stopped.");
          }
        }
      }
      
    }
    
  }  
  
  private class ShepardServerCommunications implements Runnable
  {
    
    private Component parent = null;
    
    public ShepardServerCommunications(Component parent)
    {
      this.parent = parent;
    }
    
    @Override
    public void run()
    {
      try 
      {
        CollectionServer server = new ShepardGUICollectionServer(parent);
  
        server.init();
        server.listen();
        server.handleClient();
        
        connected = true;
      }
      catch (Exception ex)
      {
        System.err.println(ex);
        JOptionPane.showMessageDialog(parent,
            "Unable to fully establish connection with data collection hardware");
      }
      connectButton.setText("Connected");
      connectButton.setEnabled(false);
      recordButton.setEnabled(true);
    }
    
  }
  

  private static final long serialVersionUID = -396387578285904001L;

}
