package org.mach30.shepard_ts.client;

import javax.swing.JApplet;
import javax.swing.JFrame;
import javax.swing.SwingUtilities;

public class ShepardGUI
{

//  private static JApplet applet;
//
//  static JApplet getApplet() {
//      return applet;
//  }
//  
//  @Override
//  public void init()
//  {
//    try {
//      UIManager.setLookAndFeel("com.sun.java.swing.plaf.nimbus.NimbusLookAndFeel");
//      SwingUtilities.invokeAndWait(new Runnable() {
//          public void run() {
//              ShepardDataCollectionPanel panel = new ShepardDataCollectionPanel();
//              add(panel);
//              applet = ShepardGUI.this;
//          }
//      });
//  }
//  catch (Exception e) {
//      //Do nothing
//  }
//  }
  
  public static void main(String[] args)
  {
    SwingUtilities.invokeLater(new Runnable() {
      
      @Override
      public void run()
      {
        JFrame frame = new JFrame("Shepard Data Collection System");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.add(new ShepardDataCollectionPanel());
        frame.pack();
        frame.setVisible(true);
      }
    });
  }
  
}
