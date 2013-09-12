package org.mach30.shepard_ts.client;

import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.BoxLayout;
import javax.swing.JButton;
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
  
  private ShepardDataPanel thrustPanel = null;
  private ShepardDataPanel tempPanel = null;
  
  boolean connected = false;
  
  JButton connectButton = null;
  JButton recordButton = null;
  JButton clearButton = null;
  
  boolean recording = false;

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
    
    JTextField notation = new JTextField(10);
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
        }
        else
        {
          recordButton.setText("Stop Recording");
          recording = true;
        }
      }
    }
    else if (event.getSource() == clearButton)
    {
      thrustPanel.clear();
      tempPanel.clear();
    }
  }
    
  private void connectToServer()
  {
    connectButton.setText("Connecting...");
    Thread t = new Thread(new ShepardServerCommunications(this));
    t.start();
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
          listener = new ShepardDataListener();
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
      
      public ShepardDataListener() 
      {
        super(port);
      }

      @Override
      protected void handleData()
      {
        if (recording)
        {
          thrustPanel.addPoint(this.datapoint.thrust, this.datapoint.time);
          tempPanel.addPoint(this.datapoint.temp, this.datapoint.time);
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
