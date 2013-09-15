package org.mach30.shepard_ts.client;

import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
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

  
  private boolean connected = false;  
  private boolean recording = false;
  private UserPreferences preferences = UserPreferences.getInstance();
  private FileOutputStream output = null;
  
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
    return new Dimension(640, 480);
  }
  
  @Override
  public Dimension getPreferredSize()
  {
    return new Dimension(800, 600);
  }
  
  private void initUI()
  {
    BoxLayout layout = new BoxLayout(this, BoxLayout.PAGE_AXIS);
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

    add(topPanel);
        
    thrustPanel = new ShepardDataPanel("Thrust (N)", 42);
    add(thrustPanel);
    tempPanel = new ShepardDataPanel("Temperature (C)", 380);
    add(tempPanel);
    
    setVisible(true);
  }

  @Override
  public void actionPerformed(ActionEvent event)
  {
    if (event.getSource() == connectButton)
    {
      if (!connected)
      {
        connectToServer();
      }
    }
    else if (event.getSource() == recordButton)
    {
      if (connected)
      {
        if (recording)
        {
          recordButton.setText(RECORD);
          recording = false;
          
          try
          {
            output.close();
          }
          catch (IOException e)
          {
          }
          output = null;
        }
        else
        {
          try
          {
            output = new FileOutputStream(getFileName());
            
            recordButton.setText("Stop Recording");
            recording = true;
          }
          catch (FileNotFoundException e)
          {
            output = null;
            JOptionPane.showMessageDialog(this, "Unable to open the output file for writing.  Make sure you have permission to write to " + 
                preferences.getPreference(UserPreferences.SAVE_LOCATION_PROP) + " or change your default save location under Preferences.");
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
      preferences = prefPanel.getPreferences();
    }
  }
    
  private void connectToServer()
  {
    connectButton.setText("Connecting...");
    Thread t = new Thread(new ShepardServerCommunications(this));
    t.start();
  }
  
  private String getFileName()
  {
    DateFormat format = new SimpleDateFormat("yyyy-MM-dd__HH_mm");
    
    String ret = new String();
    ret += preferences.getPreference(UserPreferences.SAVE_LOCATION_PROP);
    ret += format.format(new Date());
    
    String notationStr = notation.getText().trim();
    if (!notationStr.isEmpty()) 
    {
      ret += "__" + notationStr;
    }
    
    ret += ".csv";
    
    return ret;
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
            output.write(this.datapoint.toString().getBytes());
            output.write('\n');
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
