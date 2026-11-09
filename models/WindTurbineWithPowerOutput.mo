
model WindTurbineWithPowerOutput
  "Wind turbine with an exposed electrical power output"

  extends Buildings.Electrical.DC.Sources.WindTurbine;

  Modelica.Blocks.Interfaces.RealOutput PGenerated(unit="W")
    "Generated wind power";

equation
  PGenerated = gain.y;

end WindTurbineWithPowerOutput;
