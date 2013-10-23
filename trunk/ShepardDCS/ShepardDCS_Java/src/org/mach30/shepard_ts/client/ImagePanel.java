package org.mach30.shepard_ts.client;

import java.awt.Dimension;
import java.awt.Graphics;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.net.URL;

import javax.imageio.ImageIO;
import javax.swing.JPanel;

public class ImagePanel extends JPanel
{
  private BufferedImage image = null;

  public ImagePanel(URL imageUrl)
  {
    try
    {
      image = ImageIO.read(imageUrl);
    }
    catch (IOException ioex)
    {
    }
  }
  
  @Override
  public Dimension getPreferredSize()
  {
    return getMinimumSize();
  }
  
  @Override
  public Dimension getMinimumSize()
  {
    return new Dimension(image.getWidth(), image.getHeight());
  }
  
  @Override
  public Dimension getMaximumSize()
  {
    return getMinimumSize();
  }
  
  @Override
  protected void paintComponent(Graphics g)
  {
    super.paintComponent(g);
    g.drawImage(image, 0, 0, null);
  }

  private static final long serialVersionUID = -501225012350538790L;
  
}
