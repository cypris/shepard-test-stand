package org.mach30.shepard_ts.client;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;

public class ShepardGUI
{
  
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
