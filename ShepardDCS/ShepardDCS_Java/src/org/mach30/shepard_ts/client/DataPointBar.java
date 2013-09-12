package org.mach30.shepard_ts.client;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Graphics2D;

import javax.swing.JPanel;

public class DataPointBar extends JPanel
{

  private float maxVal = 0;
  private float minVal = 0;
  private float val = 0;
  private String datapointLabel = "";
  private String barLabel = "";
  private int barHeight = 0;

  public DataPointBar(float min, float max)
  {
    minVal = min;
    maxVal = max;
    
    initComponents();
  }
  
  private void initComponents()
  {
    setLayout(null);
    
    setBackground(Color.WHITE);
    
    this.revalidate();
    
    setVisible(true);
  }
  
  @Override
  public Dimension getPreferredSize()
  {
    return new Dimension(40, 570);
  }
  
  @Override
  public Dimension getMaximumSize()
  {
    return new Dimension(50, 4000);
  }
  
  @Override
  public void paint(Graphics g)
  {
    super.paint(g);
    
    int width = getWidth();
    int height = getHeight();
    
    g.setColor(Color.BLACK);
    g.drawRect(8, 8, width - 16, height - 32);

    g.drawString(barLabel, barLabel.length() * 5 / 2, height - 10);
    
    g.setColor(Color.BLUE);
    g.fillRect(9, height + 8 - barHeight, width - 17, barHeight - 32);

    g.setFont(Font.getFont(Font.MONOSPACED));
    ((Graphics2D)g).rotate(1.57079633);
    g.drawString(datapointLabel, 10, -12);
  }
  
  @Override
  public void setBounds(int x, int y, int width, int height)
  {
    super.setBounds(x, y, width, height);
    
    positionDatapointLabel();
  }
  
  @Override
  public void setSize(Dimension d)
  {
    super.setSize(d);
    setSize(d.width, d.height);
  }
  
  @Override
  public void setSize(int width, int height)
  {
    super.setSize(width, height);    
    positionDatapointLabel();
  }
  
  public void setLabel(String label)
  {
    barLabel = label;
  }
  
  public void setData(float point)
  {
    if (point > maxVal)
    {
      val = maxVal;
    }
    else if (point < minVal)
    {
      val = minVal;
    }
    else
    {
      val = point;
    }
    
    datapointLabel = Float.toString(point);
    
    positionDatapointLabel();
    
    repaint();
  }
  
  private void positionDatapointLabel()
  {
    int constraint = getHeight() - 40;
    constraint *= val;
    float height = constraint / maxVal;
    barHeight = Math.round(height) + 33;
    
    this.revalidate();
  }
  

  private static final long serialVersionUID = -166246168499362604L;
  
}
