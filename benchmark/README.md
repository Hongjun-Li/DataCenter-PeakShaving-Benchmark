# DataCenter-PeakShaving-Benchmark: Grid-Connected Data Center Battery Peak Shaving with Renewable-Aware Dispatch

## License and third-party dependencies

The original code authored for **DataCenter-PeakShaving-Benchmark** is available under the **MIT License**, Copyright (c) 2026 Hongjun Li. See [`LICENSE`](LICENSE) for the full text. This license applies only to code for which the project author holds the necessary licensing rights; it does **not** supersede copyright and license conditions on materials adapted from third parties.

The benchmark is an independent adaptation of elements of the [LBNL Modelica Buildings Library](https://github.com/lbl-srg/modelica-buildings). **Buildings 14.0.0 is not committed to this repository**. The dependency installer downloads the official release into the local `Buildings 14.0.0/` directory, which Git ignores. The downloaded library and adapted material remain subject to the applicable original notices and license terms; see `Buildings 14.0.0/UsersGuide/License.mo` after installation. The benchmark is not endorsed by LBNL, the Modelica Association, or the Buildings Library contributors.

## Quick start (Windows PowerShell)

Install Docker Desktop (or another compatible Docker engine) and ensure Docker is running. From the repository root, execute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\benchmark\run_submission.ps1
```

The runner invokes `benchmark/install_buildings.ps1` to check for or download **Buildings 14.0.0** from its official release, initializes **Modelica Standard Library 4.1.0** in the OpenModelica Docker volume, runs the 48-hour Starter simulation, generates the battery-idle baseline when missing, and computes the score. The tested container image is `openmodelica/openmodelica:v1.27.1-minimal`. First-time setup requires network access.

## 1. Objective
Design and implement a **rule-based battery dispatch controller** for a grid-connected data center with photovoltaic (PV) and wind generation. The grid remains the primary electricity supply, while renewable generation reduces grid imports and the battery shifts energy to reduce peak grid demand.

The primary objective is to **maximize the reduction in peak grid import relative to a battery-idle baseline**, subject to battery operating constraints and the benchmark's evaluation rules.

This benchmark focuses on rule-based dispatch. Reinforcement learning, electricity-price optimization, thermal energy storage, and modifications to the physical plant are outside its scope.

The benchmark is an independent engineering adaptation of `Buildings.Examples.ChillerPlant.DataCenter.Renewables` from LBNL Buildings 14.0.0. The local integration corrects the electrical load sign convention and exposes the signals needed by the battery controller. **It is not an official LBNL or Modelica Association benchmark.**

## 2. Software and Simulation Environment
| Item | Specification |
|---|---|
| Modeling language | Modelica |
| Simulator | OpenModelica 1.27.1 |
| Docker image | `openmodelica/openmodelica:v1.27.1-minimal` |
| Modelica Standard Library | 4.1.0 (`4.1.0+maint.om` was installed in the verified environment) |
| Buildings Library | LBNL Buildings 14.0.0 |
| Host execution environment | Windows PowerShell with Docker installed and running |
| Simulation start | 0 s |
| Simulation stop | 172800 s (48 h) |
| Output intervals | 192 |
| Numerical tolerance | `1e-6` |
| Output format | OpenModelica MAT (`.mat`) |
| Warm-up period | 0–86400 s (Day 0) |
| Evaluation period | 86400–172800 s (Day 1) |

The evaluation window includes its boundary timestamps. The peak is evaluated over recorded simulation points in this interval, including event-related points when available; it is **not** a 15-minute averaged demand metric.

## 3. Participant Task
**Edit only:**

`benchmark/starter/GridAwareBatteryControl.mo`

This is the participant's battery dispatch controller. Its public signals are:

| Signal | Direction | Unit | Meaning |
|---|---|---|---|
| `PGridBase` | Input | W | Estimated grid import **without battery dispatch** |
| `SOC` | Input | 1 | Battery state of charge |
| `y` | Output | W | Commanded battery power |

Power-command sign convention:

- `y > 0`: battery charging (increases grid demand, all else equal).

- `y < 0`: battery discharging (reduces grid demand, all else equal).

- `y = 0`: battery idle.

The provided Starter Controller contains the placeholder equation `y = 0;`. Participants replace this behavior with their own rule-based policy while retaining a compatible Modelica interface. They may tune control parameters, but must not change the battery's physical capabilities or the benchmark evaluation setup.

`PGridBase` is obtained from data-center AC/DC demand and PV/wind output using `GridBaseEstimator`; it is not a direct feedback measurement of `gri.P.real`. `GridPowerSampler` provides the controller with a sampled signal in the integrated Starter model.

## 4. Physical System and Operating Constraints
The integrated system uses the Buildings data-center plant, grid connection, PV generation, wind generation, and a DC battery connected through an electrical converter.

| Battery parameter | Value |
|---|---:|
| Nominal energy capacity | 2000 kWh |
| Minimum SOC | 0.10 |
| Maximum SOC | 0.90 |
| Maximum charging power | +200 kW |
| Maximum discharging power | −400 kW |
| Charging efficiency | 0.90 |
| Discharging efficiency | 0.90 |
| Converter nominal efficiency parameter | 0.90 |

The sign convention above applies to the battery command; the measured grid import used for scoring is `gri.P.real` from the integrated electrical model. Actual AC-side grid-power changes should be determined by simulation rather than assuming a fixed one-to-one relation with DC-side battery commands.

Participants must not change physical plant models, weather inputs, renewable generation, battery sizing, device limits, simulation settings, or evaluator code.

## 5. Benchmark Metric and Validity Rules
### 5.1 Primary metric: peak reduction percentage
Let:

- $P_{\mathrm{peak,idle}}$: maximum Day 1 grid import in the Battery-Idle baseline, in watts.

- $P_{\mathrm{peak,submission}}$: maximum Day 1 grid import in the submitted controller simulation, in watts.

The raw reduction is:

$$
\Delta P_{\mathrm{peak}} = P_{\mathrm{peak,idle}} - P_{\mathrm{peak,submission}}
$$

$$
R_{\mathrm{raw}} = 100\frac{P_{\mathrm{peak,idle}} - P_{\mathrm{peak,submission}}}{P_{\mathrm{peak,idle}}}
$$

The evaluator computes the peak from `gri.P.real` over **86400–172800 s** using the corresponding MAT results. A fixed **100 W near-zero tolerance** avoids reporting a misleading negative score for negligible numerical differences between the idle and Starter models:

$$
R_{\mathrm{normalized}} =

\begin{cases}

0, & |\Delta P_{\mathrm{peak}}|\leq 100\ \mathrm{W}\\

\max(0,R_{\mathrm{raw}}), & \text{otherwise}

\end{cases}
$$

For a submission passing all implemented validity checks, the final numerical score (in percent) equals $R_{\mathrm{normalized}}$. If the implemented checks fail, the final score is **0%**. A zero score does not by itself distinguish an invalid run from a valid controller with no measured improvement; consult the reported `Benchmark valid` field.

The Reference Controller's `PGridTarget = 550e3` W is **an internal tunable control target, not a benchmark pass/fail threshold**.

### 5.2 Implemented validity checks
The current scoring scripts check the following within the evaluation period unless otherwise stated:

1. **SOC bounds:** $0.10\leq SOC\leq0.90$, with the evaluator's small numerical tolerance.

2. **Command power bounds:** maximum charge at most +200 kW; maximum discharge magnitude at most 400 kW.

3. **Evaluation-day net SOC depletion:**

   $$
   SOC(86400)-SOC(172800)\leq0.25

   $$

4. **Time range:** both the baseline and submitted results begin at approximately 0 s and end at approximately 172800 s or later.

5. **Basic data validity:** evaluation-point counts are positive and selected grid-power, SOC, and command values pass the evaluator's numerical sanity checks.

6. **Result-file presence:** the unified PowerShell runner checks that required MAT files exist and are nonempty before scoring.

The **0.25 net SOC depletion limit is an evaluation fairness rule, not a physical battery limit**. It constrains evaluation-day energy depletion but does **not** guarantee energy-neutral operation. The current validity tests are basic screening, not exhaustive protection against damaged, malformed, incomplete, or deliberately modified result data.

### 5.3 Additional reported metrics
The evaluators also report peak reduction in kW, minimum and maximum SOC, maximum charging/discharging power, starting and ending Day 1 SOC, and their difference.

A full 15-minute rolling-demand metric is **not currently implemented** and is not part of the official score.

## 6. First-Time Environment Setup

The supported workflow is **Windows PowerShell + Docker**. Run commands from the cloned repository root, which initially contains `benchmark/`, `models/`, and `scripts/`. **Do not expect `Buildings 14.0.0/` to be present immediately after cloning.** The runner installs this ignored third-party dependency automatically when missing.

Before starting:

- Install Docker and start the Docker engine.
- Ensure the Docker image `openmodelica/openmodelica:v1.27.1-minimal` can be pulled.
- Allow network access for the first Buildings 14.0.0 download and first Modelica 4.1.0 package installation.
- Preserve the repository's relative directory structure.

The unified runner first invokes `benchmark/install_buildings.ps1`. This PowerShell script fetches the official Buildings 14.0.0 ZIP release if necessary, extracts the `Buildings 14.0.0/` directory beside `benchmark/`, and checks its version declaration in `package.mo`. The library is intentionally omitted from Git but remains available locally for the `.mos` scripts' `loadFile("Buildings 14.0.0/package.mo")` calls.

Next, the runner invokes `benchmark/setup_environment.mos` through OpenModelica. The script installs/loads **Modelica Standard Library 4.1.0**, including dependencies such as `ModelicaServices` and `Complex`, into the persistent Docker volume `openmodelica-libraries`.

The Modelica package setup was tested against an initially empty Docker volume; the Buildings installation was separately validated using an official ZIP and an isolated temporary directory. The updated unified runner was successfully regression-tested in the configured environment. A completely fresh end-to-end run on a different machine has not yet been demonstrated.

Optional standalone Modelica environment setup:

```powershell
docker run --rm `
  -v "${PWD}:/work" `
  -v openmodelica-libraries:/root/.openmodelica `
  -w /work `
  openmodelica/openmodelica:v1.27.1-minimal `
  omc benchmark/setup_environment.mos
```

Successful setup reports `Modelica 4.1.0 installation result: true` and `Modelica 4.1.0 load result: true`. A message that the library is already installed is normal on subsequent runs.

## 7. How to Run a Submission
Modify only:

`benchmark/starter/GridAwareBatteryControl.mo`

From the project root, run:

```powershell

powershell -NoProfile -ExecutionPolicy Bypass `

  -File ".\benchmark\run_submission.ps1"

```

The unified runner performs these actions:

1. Checks for Buildings 14.0.0; downloads and extracts the official release when missing.
2. Checks/initializes the Modelica 4.1.0 environment in Docker.
3. Deletes the previous `RenewablesStarter48h_res.mat` to avoid scoring a stale Starter result.
4. Simulates the Starter integration model for 48 hours.
5. Generates `RenewablesBatteryIdleWind48h_res.mat` using `benchmark/evaluation/generate_baseline.mos` if the baseline is missing.
6. Checks that the required MAT result files exist and are nonempty.
7. Executes `benchmark/evaluation/score_submission.mos` and displays raw reduction, normalized score, validity, and final score.

Outputs are written at the project root or inside the evaluation directory:

| File | Purpose |
|---|---|
| `RenewablesStarter48h_res.mat` | Fresh submission simulation |
| `RenewablesBatteryIdleWind48h_res.mat` | Battery-idle baseline (generated if missing) |
| `benchmark/evaluation/submission_score.log` | Full submission scoring log |

Expected final lines for the **unmodified Starter**:

```text

\=== DataCenter-PeakShaving-Benchmark Score ===

Peak reduction [%]: -0.00242306

Normalized benchmark score [%]: 0

Benchmark valid: true

Final benchmark score [%]: 0

```

A negative near-zero raw reduction for the idle Starter is a numerical comparison artifact and is normalized to zero by the 100 W rule. Actual values can differ slightly across solver environments.

**Important:** The unified runner regenerates the Starter result on every invocation, but only regenerates the Battery-Idle baseline **if its result file is absent**. If the physical plant, library/software versions, weather inputs, or simulation settings change, delete the obsolete baseline file and regenerate it before comparing scores. Do not submit or modify MAT files manually as a substitute for controller simulation.

## 8. Verified Baselines and Reference Solution
Under the fixed, previously tested environment and simulation settings:

| Model | Day 1 peak grid import | Peak reduction | Score |
|---|---:|---:|---:|
| Battery-Idle | 620.301 kW | Baseline | N/A |
| Starter, `y = 0` | 620.316 kW | About −0.015 kW (numerical difference) | **0%** |
| Reference, 60-second control | 555.054 kW | 65.2464 kW | **10.5185%** |

Reference validation measurements:

| Quantity | Result |
|---|---:|
| Minimum evaluation-day SOC | 0.148179 |
| Maximum evaluation-day SOC | 0.475305 |
| Maximum charging command | +200 kW |
| Maximum discharging command | −72.2841 kW |
| Day 1 starting SOC | 0.385158 |
| Day 1 ending SOC | 0.190191 |
| Day 1 SOC change, end minus start | −0.194967 |
| Energy fairness check | PASS |
| Time range check | PASS |
| Basic data check | PASS |
| Overall implemented validity checks | PASS |

The Reference Solution is a **tested example**, not a mathematically optimal policy. It uses a **60-second sampled rule-based controller** and a 60-second grid-power sampler. Its source includes a `dispatchPeriod` parameter, but the currently verified Reference does **not** implement a separate active 900-second supervisory-dispatch state; do not describe it as a completed two-timescale architecture.

The earlier 900-second sampled controller achieved approximately **3.30%** peak reduction and served as a development comparison. It is not the final Reference Solution.

The Battery-Idle baseline was regenerated from its Modelica source and reproduced the original **620.301 kW** Day 1 peak, with a measured peak difference of **0 W**.

## 9. Submission Rules, Reproducibility, and Limitations
### 9.1 Allowed changes
Participants may edit the Starter Controller's rule-based dispatch logic and its control tuning, while preserving the required interface and physical operating limits.

### 9.2 Disallowed changes
Do not modify:

- The Buildings library source, including licensing material.

- Physical data-center cooling and electrical network models.

- PV/wind generation, weather inputs, and renewable power signals.

- Battery capacity, physical efficiencies, or maximum charge/discharge power.

- SOC safety limits.

- Simulation duration, initialization settings, or evaluation window.

- Benchmark evaluator code or supplied baseline data.

Only the designated Starter controller is participant-editable. The Reference Solution must not be used as a submitted solution in a blind evaluation.

### 9.3 Reproducibility notes
- All compared controllers use the same 48-hour simulated scenario, with Day 0 as warm-up and Day 1 as evaluation.

- Warm-up is not proof of periodic steady state.

- Actual grid import is measured from `gri.P.real`, not inferred from battery command alone.

- The Starter and Battery-Idle results show an approximately 15 W difference in peak power; this is within the defined 100 W near-zero normalization tolerance.

- An initialization warning involving `dataCenterContinuousTimeControl.cooTow\.TAppCor` in the Buildings cooling-tower model may occur even when initialization and simulation succeed.

- An alias-variable nominal/start-value warning may also appear in successful simulations.

- A successful `checkModel()` alone does not guarantee that a full simulation will compile and complete. The verified workflow runs the full model.

### 9.4 Current limitations
- One fixed 48-hour weather/load scenario is used; this is not a multi-scenario generalization test.

- The benchmark does not enforce strict end-of-day charge neutrality or a fixed Day 1 starting SOC across strategies. Pre-warm-up control choices may affect available energy at the start of evaluation.

- The net SOC depletion limit of 0.25 is a pragmatic fairness safeguard, not a proof of equal energy usage.

- Peak reduction is measured on simulation result records, including available events; it is not a guarantee of a hard continuous-time grid import limit.

- Current MAT result validation is basic. The evaluator does not comprehensively verify every variable, every time-series segment, source-model provenance, or resistance to intentional manipulation.

- This project has been verified primarily in a Windows PowerShell + Docker environment. Portability to other host operating systems has not been established.

## 10. Project Files and Dependencies

The repository contains the following version-controlled files. It does **not** contain Buildings 14.0.0, OpenModelica-generated C code, compiled binaries, MAT results, or evaluation logs. The `benchmark/` directory alone is not standalone; all listed source folders must retain their relative paths.

### 10.1 Participant-facing files

- `README.md` and `benchmark/README.md` — overview, tasks, installation, run instructions, and evaluation rules.
- `LICENSE` — MIT license for original project-authored code (subject to third-party notices on adapted material).
- `.gitignore` — generated files and downloaded Buildings dependency.
- `benchmark/install_buildings.ps1` — download/check Buildings 14.0.0.
- `benchmark/setup_environment.mos` — install/load Modelica Standard Library 4.1.0.
- `benchmark/run_submission.ps1` — integrated simulation and scoring runner.
- `benchmark/starter/GridAwareBatteryControl.mo` — **the only controller source participants should edit**.
- `benchmark/starter/RenewablesStarter.mo` — Starter integration model.

### 10.2 Reference solution (development/verification only)

- `benchmark/reference/GridAwareBatteryControlFast.mo` — verified 60-second rule-based control example.
- `benchmark/reference/RenewablesReference.mo` — complete Reference integration model.

The public developer repository contains the Reference solution for reproducibility. A blind participant distribution must exclude the Reference source.

### 10.3 Evaluation files

- `benchmark/evaluation/generate_baseline.mos` — regenerate the Battery-Idle baseline.
- `benchmark/evaluation/score_submission.mos` — score a Starter/submission result.
- `benchmark/evaluation/score_reference.mos` — Reference verification (developer use).

`benchmark/evaluation/submission_score.log` is generated at runtime and not committed.

### 10.4 Shared physical and electrical models

- `models/WindTurbineWithPowerOutput.mo`
- `models/peak_shaving/GridBaseEstimator.mo`
- `models/peak_shaving/GridPowerSampler.mo`
- `models/peak_shaving/RenewablesBatteryIdleWithWindOutput.mo`

### 10.5 Simulation scripts

- `scripts/peak_shaving/simulate_starter_48h.mos` — Starter 48-hour simulation.
- `scripts/peak_shaving/simulate_reference_48h.mos` — Reference 48-hour simulation.

### 10.6 External dependencies (not committed)

- `Buildings 14.0.0/` — fetched from the official [Buildings 14.0.0 release](https://github.com/lbl-srg/modelica-buildings/releases/tag/v14.0.0) by `benchmark/install_buildings.ps1`, then retained locally and ignored by Git.
- Modelica Standard Library 4.1.0 — installed through OpenModelica's package manager.
- `openmodelica/openmodelica:v1.27.1-minimal` — tested Docker image.
- `openmodelica-libraries` — persistent Docker volume for Modelica packages.

### 10.7 Generated results (excluded from Git)

- `RenewablesBatteryIdleWind48h_res.mat`
- `RenewablesStarter48h_res.mat`
- `RenewablesReference48h_res.mat`
- Other generated MAT files, C/object files, executables, temporary artifacts, and scoring logs.

The baseline is generated on demand when missing. The unified runner regenerates the Starter result on each run.

## 11. Third-Party Software and Licensing

**Original Buildrix-independent project code:** original code authored for DataCenter-PeakShaving-Benchmark is distributed under the **MIT License**, Copyright (c) 2026 Hongjun Li. See the repository-root [`LICENSE`](LICENSE). This statement does not claim MIT ownership of third-party material.

**Buildings Library:** the benchmark adapts the LBNL Modelica Buildings Library 14.0.0, developed by Lawrence Berkeley National Laboratory and contributors. The Buildings Library has a revised BSD-style license with an additional provision about voluntarily supplied enhancements; relevant files may also include third-party notices. Consult the complete library license at `Buildings 14.0.0/UsersGuide/License.mo` after installation, and retain applicable original copyright notices and conditions for any redistributed or adapted material. The dependency is downloaded separately rather than committed to this repository.

**Other dependencies:** OpenModelica, the Modelica Standard Library, and their components have their own licenses. Follow those terms when redistributing binaries, Docker images, libraries, or derivative content.

This is an independent benchmark. It is **not** an official LBNL or Modelica Association benchmark, and no endorsement by the library authors or their institutions is implied.

## 12. Repository Layout and Packaging

The **GitHub source repository** should contain:

```text
DataCenter-PeakShaving-Benchmark/
├── .gitignore
├── LICENSE
├── README.md
├── benchmark/
│   ├── README.md
│   ├── install_buildings.ps1
│   ├── run_submission.ps1
│   ├── setup_environment.mos
│   ├── starter/
│   ├── reference/
│   └── evaluation/
├── models/
│   └── peak_shaving/
└── scripts/
    └── peak_shaving/
```

After first use, an **additional local folder** `Buildings 14.0.0/` is created at the repository root; `.gitignore` excludes it from the commit. OpenModelica also generates simulation artifacts that should not be committed.

For a future source ZIP, retain the same repository layout and the installer. Any offline archive bundling Buildings Library files must also include and preserve the applicable third-party license material. The complete unified runner was regression-tested after integrating the installer, but a fresh-machine clone-and-run test remains a useful publication check.

For blind benchmarking, distribute a separate participant package without the Reference controller; confirm that the participant package still contains everything required by the intended evaluation procedure.

