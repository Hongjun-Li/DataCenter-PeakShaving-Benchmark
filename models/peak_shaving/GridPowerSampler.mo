
within;

block GridPowerSampler
  "Sample and hold estimated grid power"

  parameter Modelica.Units.SI.Time samplePeriod = 900
    "Sampling period";

  Modelica.Blocks.Interfaces.RealInput u(unit="W")
    "Continuous estimated grid power";

  Modelica.Blocks.Interfaces.RealOutput y(unit="W")
    "Sampled grid power";

protected
  discrete Modelica.Units.SI.Power pSampled(start=0, fixed=true)
    "Held grid power value";

equation
  y = pSampled;

  when sample(0, samplePeriod) then
    pSampled = u;
  end when;

end GridPowerSampler;
