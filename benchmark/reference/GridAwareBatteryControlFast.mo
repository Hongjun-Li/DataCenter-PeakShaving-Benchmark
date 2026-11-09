
within;

block GridAwareBatteryControlFast
  "Rule-based battery control with fast peak protection"

  parameter Modelica.Units.SI.Power PGridTarget = 550e3
    "Maximum target grid import";

  parameter Modelica.Units.SI.Power safetyMargin = 10e3
    "Fast peak protection margin";

  parameter Modelica.Units.SI.Power PChargeThreshold = 450e3
    "Charge below this battery-idle grid power";

  parameter Modelica.Units.SI.Power PChargeMax = 200e3
    "Maximum battery charging power";

  parameter Modelica.Units.SI.Power PDischargeMax = 400e3
    "Maximum battery discharging power";

  parameter Modelica.Units.SI.Energy EMax = 500e3*4*3600
    "Battery capacity";

  parameter Real SOCMin = 0.10;
  parameter Real SOCMax = 0.90;

  parameter Real etaCha = 0.90;
  parameter Real etaDis = 0.90;
  parameter Real etaConv = 0.90;

  parameter Modelica.Units.SI.Time dispatchPeriod = 900
    "Regular dispatch period";

  parameter Modelica.Units.SI.Time protectionPeriod = 60
    "Fast protection period";

  Modelica.Blocks.Interfaces.RealInput PGridBase(unit="W")
    "Estimated battery-idle grid import";

  Modelica.Blocks.Interfaces.RealInput SOC(unit="1")
    "Battery state of charge";

  Modelica.Blocks.Interfaces.RealOutput y(unit="W")
    "Battery power: positive charge, negative discharge";

protected
  discrete Modelica.Units.SI.Power yCmd(
    start=0,
    fixed=true);

  Modelica.Units.SI.Power pChargeLimit;
  Modelica.Units.SI.Power pDischargeLimit;

  Modelica.Units.SI.Power pFastTarget;

equation

  pFastTarget = PGridTarget - safetyMargin;

  pChargeLimit = max(
    0,
    (SOCMax-SOC)*EMax/(etaCha*protectionPeriod)
  );

  pDischargeLimit = max(
    0,
    (SOC-SOCMin)*EMax*etaDis/protectionPeriod
  );

  y = yCmd;

  // Fast peak protection runs every 60 seconds.
  when sample(0, protectionPeriod) then

    if PGridBase > pFastTarget then

      // Discharge as needed to protect the grid limit.
      yCmd = -min(
        PDischargeMax,
        min(
          etaConv*(PGridBase-pFastTarget),
          pDischargeLimit
        )
      );

    elseif PGridBase < PChargeThreshold then

      // Charge only during low grid demand.
      yCmd = min(
        PChargeMax,
        min(
          etaConv*(PGridTarget-PGridBase),
          pChargeLimit
        )
      );

    else

      yCmd = 0;

    end if;

  end when;

end GridAwareBatteryControlFast;
