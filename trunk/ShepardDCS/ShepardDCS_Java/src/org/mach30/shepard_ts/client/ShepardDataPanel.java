package org.mach30.shepard_ts.client;

import info.monitorenter.gui.chart.Chart2D;
import info.monitorenter.gui.chart.IAxis;
import info.monitorenter.gui.chart.IAxis.AxisTitle;
import info.monitorenter.gui.chart.IRangePolicy;
import info.monitorenter.gui.chart.ITrace2D;
import info.monitorenter.gui.chart.rangepolicies.RangePolicyFixedViewport;
import info.monitorenter.gui.chart.traces.Trace2DLtd;
import info.monitorenter.util.Range;

import java.awt.Color;
import java.awt.Dimension;

import javax.swing.BoxLayout;
import javax.swing.JPanel;

public class ShepardDataPanel extends JPanel
{
  
  private ITrace2D trace = null;
  
  private Chart2D chart = null;
  private DataPointBar maxBar = null;
  private DataPointBar minBar = null;
  private DataPointBar avgBar = null;
  
  private float max = Float.NEGATIVE_INFINITY;
  private float min = Float.MAX_VALUE;
  private float sum = 0.0f;
  private float numPoints = 0.0f;
  
  private float yMax = min;

  public ShepardDataPanel(String yAxisTitle, float yAxisMax)  
  {
    initComponents(yAxisMax);
    setYAxisInfo(yAxisTitle, yAxisMax);
  }

  private void initComponents(float yAxisMax)
  {
    BoxLayout layout = new BoxLayout(this, BoxLayout.LINE_AXIS);
    setLayout(layout);
    
    chart = new Chart2D();
    trace = new Trace2DLtd(10000); 
    trace.setColor(Color.BLUE);
    chart.addTrace(trace);
    chart.setPreferredSize(new Dimension(800, 570));
    add(chart);
    
    maxBar = new DataPointBar(0.0f, yAxisMax);
    maxBar.setLabel("Max");
    add(maxBar);
    
    minBar = new DataPointBar(0.0f, yAxisMax);
    minBar.setLabel("Min");
    add(minBar);
    
    avgBar = new DataPointBar(0.0f, yAxisMax);
    avgBar.setLabel("Avg");
    add(avgBar);

    setVisible(true);
  }
  
  public void setYAxisInfo(String yAxisTitle, float yAxisMax)
  {  
    yMax = yAxisMax;
    
    chart.getAxesXBottom().get(0).setAxisTitle(new AxisTitle("Time (ms)"));
    IAxis<?> yAxis = chart.getAxesYLeft().get(0);
    yAxis.setAxisTitle(new AxisTitle(yAxisTitle));
    IRangePolicy rangePolicy = new RangePolicyFixedViewport(new Range(0, yMax));
    yAxis.setRangePolicy(rangePolicy);
  }

  public void clear()
  {
    trace.removeAllPoints();
    max = 0;
    min = yMax;
  }

  public void addPoint(float val, long timestamp)
  {
    trace.addPoint(timestamp, val);
    
    if (val > max)
    {
      max = val;
      maxBar.setData(val);
    }
    else if (val < min)
    {
      min = val;
      minBar.setData(val);
    }
    
    ++numPoints;
    sum += val;
    avgBar.setData(sum / numPoints);
  }
  
  private static final long serialVersionUID = -7559126468381303833L;
  
}
