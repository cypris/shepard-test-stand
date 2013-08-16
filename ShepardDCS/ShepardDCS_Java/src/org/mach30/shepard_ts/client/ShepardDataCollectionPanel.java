package org.mach30.shepard_ts.client;

import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.UnknownHostException;

import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;

import org.mach30.shepard_ts.ShepardData;

public class ShepardDataCollectionPanel extends JPanel implements ActionListener
{
  
  private static final String CONNECT = "Connect";
  private static final String RECORD = "Record";
  
  private ShepardDataPanel thrustPanel = null;
  private ShepardDataPanel tempPanel = null;
  
  Socket sock = null;
  PrintWriter out = null;
  BufferedReader in = null;
  
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
    
    JTextField server = new JTextField("localhost", 10);
    server.setToolTipText("The name or address of the computer the Data " +
        "Collection Server is located on.  If it is on the same computer as " +
        "this application, the default value of 'localhost' is sufficient.");
    topPanel.add(server);
    
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
      // TODO: fix the logic here... it doesn't always work
      if (sock != null)
      {
        disconnectFromServer();
      }
      else
      {
        connectToServer();
      }
    }
    else if (event.getSource() == recordButton)
    {
      if (sock != null && sock.isConnected())
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
          out.println("R");
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
    Thread t = new Thread(new ShepardServerCommunications(this));
    t.start();
  }
  
  private void disconnectFromServer()
  {
    if (sock.isConnected())
    {
      try
      {
        out.close();
        in.close();
        sock.close();
      }
      catch (IOException e)
      {
      }
    }
    
    out = null;
    in = null;
    sock = null;

    connectButton.setText(CONNECT);
    recordButton.setEnabled(false);

    recordButton.setText(RECORD);
    recording = false;
  }
  
  
  private class ShepardServerCommunications implements Runnable
  {
    private Component parent;
    
    public ShepardServerCommunications(Component parent)
    {
      this.parent = parent;
    }
    
    @Override
    public void run()
    {
      String host = "localhost";
      
      try
      {
        sock = new Socket(host, 9999);
        out = new PrintWriter(sock.getOutputStream(), true);
        in = new BufferedReader(new InputStreamReader(
            sock.getInputStream()));
      }
      catch (UnknownHostException uhex)
      {
        System.err.println(uhex);
        JOptionPane.showMessageDialog(parent, host
            + " was not recognized as a valid host");
        disconnectFromServer();
      }
      catch (IOException ioex)
      {
        System.err.println(ioex);
        JOptionPane.showMessageDialog(parent,
            "Unable to fully establish connection with server at " + host);
        disconnectFromServer();
      }
      
      connectButton.setText("Disconnect");
      recordButton.setEnabled(true);
      
      try
      {
        String line = "";
        ShepardData data = null;
        while ((line = in.readLine()) != null)
        {
          if (Character.isLetter(line.charAt(0)))
          {
            System.out.println(line);
          }
          else
          {
            data = new ShepardData(line);
            
            if (recording)
            {
              thrustPanel.addPoint(data.thrust, data.time);
              tempPanel.addPoint(data.temp, data.time);
            }
          }
        }
      }
      catch (Exception ex)
      {
        System.err.println(ex);
        if (sock != null)
        {
          JOptionPane.showMessageDialog(parent,
              "An error occurred receiving communications with the server");
                    
          disconnectFromServer();
        }
        sock = null;
      }
    }
    
  }
  

  private static final long serialVersionUID = -396387578285904001L;

}
