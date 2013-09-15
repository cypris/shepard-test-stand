package org.mach30.shepard_ts.client;

import java.awt.Component;
import java.awt.Dimension;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;

import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SpringLayout;

public class PreferencesPanel extends JPanel implements ActionListener, MouseListener
{
  
  private static int PADDING = 6;
    
  
  private UserPreferences prefs = null;
  
  private JFrame parent = null; 
  private JPanel leftPanel = null;
  private JPanel rightPanel = null;
  private SpringLayout leftLayout = null;
  private SpringLayout rightLayout = null;
  private Component lastLeft = null;  
  private Component lastRight = null;
  
  private JTextField saveLocation = null;  
  
  private JButton saveButton = null;
  
  
  private ArrayList<ActionListener> listeners = new ArrayList<ActionListener>();
  
  
  public UserPreferences getPreferences()
  {
    return prefs;
  }
  
  public void addActionListener(ActionListener l)
  {
    listeners.add(l);
  }
  
  public static PreferencesPanel getPanel()
  {
    return getPanel(UserPreferences.getInstance());
  }
  
  public static PreferencesPanel getPanel(UserPreferences initProps)
  {
    PreferencesPanel panel = new PreferencesPanel();
    panel.prefs = initProps;
    panel.initUI();

    panel.parent = new JFrame("Preferences");
    panel.parent.add(panel);
    panel.parent.pack();
    
    panel.parent.setVisible(true);
    
    return panel;
  }
  
  
  private void initUI()
  {    
    leftPanel = new JPanel();
    leftLayout = new SpringLayout();
    leftPanel.setLayout(leftLayout);

    rightPanel = new JPanel();
    rightLayout = new SpringLayout();
    rightPanel.setLayout(rightLayout);
    
    addSaveLocation();
    
    leftLayout.putConstraint(SpringLayout.SOUTH, leftPanel, PADDING, SpringLayout.SOUTH, lastLeft);
    rightLayout.putConstraint(SpringLayout.SOUTH, rightPanel, PADDING, SpringLayout.SOUTH, lastRight);

    JPanel topPanel = new JPanel();
    BoxLayout topLayout = new BoxLayout(topPanel, BoxLayout.LINE_AXIS);
    topPanel.setLayout(topLayout);
    topPanel.add(leftPanel);
    topPanel.add(rightPanel);
    
    BoxLayout layout = new BoxLayout(this, BoxLayout.PAGE_AXIS);
    this.setLayout(layout);
    add(topPanel);
    addSaveButtonPanel();
    
    setVisible(true);
  }

  private void addSaveLocation()
  {
    JLabel label = new JLabel("Save Location");
    addToLeft(label);
    
    saveLocation = new JTextField(prefs.getPreference(UserPreferences.SAVE_LOCATION_PROP, System.getProperty("user.dir")));
    saveLocation.setColumns(20);
    saveLocation.addMouseListener(this);
    addToRight(saveLocation);
  }
  
  private void addSaveButtonPanel()
  {
    JPanel panel = new JPanel();
    panel.setMaximumSize(new Dimension(100, 20));
    
    saveButton = new JButton();
    saveButton.setText("Save");
    saveButton.addActionListener(this);
    
    panel.add(saveButton);
    add(panel);
  }
  
  private void addToLeft(Component c)
  {
    leftPanel.add(c);
    
    leftLayout.putConstraint(SpringLayout.WEST, c, PADDING, SpringLayout.WEST, leftPanel);
    leftLayout.putConstraint(SpringLayout.EAST, leftPanel, PADDING, SpringLayout.EAST, c);
    if (lastLeft != null)
    {
      leftLayout.putConstraint(SpringLayout.NORTH, c, PADDING, SpringLayout.NORTH, lastLeft);
    }
    else
    {
      leftLayout.putConstraint(SpringLayout.NORTH, c, PADDING, SpringLayout.NORTH, leftPanel);
    }
    
    lastLeft = c;
  }
  
  private void addToRight(Component c)
  {
    rightPanel.add(c);
    
    rightLayout.putConstraint(SpringLayout.WEST, c, PADDING, SpringLayout.WEST, rightPanel);
    rightLayout.putConstraint(SpringLayout.EAST, rightPanel, PADDING, SpringLayout.EAST, c);
    if (lastRight != null)
    {
      rightLayout.putConstraint(SpringLayout.NORTH, c, PADDING, SpringLayout.NORTH, lastRight);
    }
    else
    {
      rightLayout.putConstraint(SpringLayout.NORTH, c, PADDING, SpringLayout.NORTH, rightPanel);
    }
    
    lastRight = c;
  }

  public void reopen()
  {
    parent.setVisible(true);
  }

  
  private void callActionListeners(String command)
  {
    ActionEvent event = new ActionEvent(this, 0, command);
    
    for (ActionListener listener : listeners)
    {
      listener.actionPerformed(event);
    }
  }
  
  @Override
  public void actionPerformed(ActionEvent event)
  {
    if (event.getSource() == saveButton)
    {
      String location = saveLocation.getText();
      if (location.charAt(location.length() - 1) != File.separatorChar)
      {
        location += File.separator;
      }
      prefs.setProperty(UserPreferences.SAVE_LOCATION_PROP, location);
      
      try
      {
        prefs.store(new FileOutputStream(UserPreferences.PREFERENCES_FILE), null);
      }
      catch (IOException e)
      {
        JOptionPane.showMessageDialog(this, "Failed to save user preferences. You may not have " +
            "permission to write to the current directory.  Try closing this program, copying it to " +
            "another location, and running it again from there.");
      }
      
      parent.setVisible(false);
      callActionListeners("Saved");
    }
  }

  @Override
  public void mouseClicked(MouseEvent event)
  {
    if (event.getSource() == saveLocation)
    {
      JFileChooser chooser = new JFileChooser(saveLocation.getText());
      chooser.setDialogTitle("Choose the location to save recorded data");
      chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
      chooser.showOpenDialog(this);
      
      // if the chooser or it's selected file is null, then the dialog was closed instead of the OK button clicked
      if (chooser != null && chooser.getSelectedFile() != null)
      {
        saveLocation.setText(chooser.getSelectedFile().getAbsolutePath());
      }
    }
  }

  @Override
  public void mouseEntered(MouseEvent arg0)
  {
  }

  @Override
  public void mouseExited(MouseEvent arg0)
  {
  }

  @Override
  public void mousePressed(MouseEvent arg0)
  {
  }

  @Override
  public void mouseReleased(MouseEvent arg0)
  {
  }

  
  private static final long serialVersionUID = 869790612914337230L;

}
