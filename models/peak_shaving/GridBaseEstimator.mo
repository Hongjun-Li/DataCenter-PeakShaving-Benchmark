
within;

block GridBaseEstimator
  "Estimate grid import assuming zero battery power"

  parameter Real etaConv(min=0.001, max=1) = 0.9
    "AC/DC converter efficiency";

  Modelica.Blocks.Interfaces.RealInput PDC(unit="W")
    "DC load power consumption";

  Modelica.Blocks.Interfaces.RealInput PAC(unit="W")
    "AC load power consumption";

  Modelica.Blocks.Interfaces.RealInput PPV(unit="W")
    "PV power generation";

  Modelica.Blocks.Interfaces.RealInput PWind(unit="W")
    "Wind power generation";

  Modelica.Blocks.Interfaces.RealOutput PGridBase(unit="W")
    "Estimated grid import with battery idle";

  Modelica.Units.SI.Power PDCNet
    "DC load minus PV and wind generation";

equation

  PDCNet = PDC - PPV - PWind;

  PGridBase =
    PAC +
    (if PDCNet >= 0 then
       PDCNet/etaConv
     else
       etaConv*PDCNet);

end GridBaseEstimator;
