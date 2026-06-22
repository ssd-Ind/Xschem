# Open-Source Analog EDA Stack

One-shot installer for a complete open-source analog IC design environment on Ubuntu/Debian.

**Tools installed:**

| Tool | Role |
|------|------|
| [Xschem](https://github.com/StefanSchippers/xschem) | Schematic capture & netlist generation |
| [Sky130 PDK](https://github.com/google/skywater-pdk) | SkyWater 130 nm process models & standard cells |
| [xschem_sky130](https://github.com/StefanSchippers/xschem_sky130) | Sky130 symbol library for Xschem |
| [ngspice](https://ngspice.sourceforge.io) | SPICE simulator |
| [Magic VLSI](https://github.com/RTimothyEdwards/magic) | Layout editor with DRC/LVS |

All tools are built from source and always pull the **latest stable release** — no version pins.

---

## Requirements

- Ubuntu 22.04 LTS or later (Debian-based)
- ~10 GB free disk space (Sky130 PDK submodules are large)
- `sudo` access for `make install` steps
- Internet connection

---

## Quick Start

```bash
git clone https://github.com/ssd-Ind/Xschem.git
cd Xschem
chmod +x install_analog.sh
./install_analog.sh
```

The script will install all system dependencies, build every tool from source, and configure the environment automatically. Expect the first run to take **30–60 minutes** depending on your machine and internet speed (ngspice and Sky130 PDK are the slowest steps).

After installation completes, launch xschem with the Sky130 environment:

```bash
cd ~/.xschem/xschem_library/xschem_sky130
xschem
```

---

## Selective Installation

Each step can be skipped independently if you already have a tool installed or want to re-run just one component:

```bash
./install_analog.sh --skip-deps       # skip apt packages
./install_analog.sh --skip-xschem     # skip Xschem build
./install_analog.sh --skip-pdk        # skip Sky130 PDK clone
./install_analog.sh --skip-ngspice    # skip ngspice build
./install_analog.sh --skip-magic      # skip Magic VLSI build
```

Re-runs are safe — the script is idempotent. Existing clones are updated with `git pull` rather than re-cloned.

---

## Directory Layout

After a full install, your filesystem will look like this:

```
~/
├── eda/                              # all source clones (INSTALL_DIR)
│   ├── xschem/                       # Xschem source
│   ├── ngspice/                      # ngspice source
│   ├── magic/                        # Magic VLSI source
│   └── foundry/
│       └── skywater-pdk/             # Sky130 PDK (models, standard cells)
│           └── libraries/
│               ├── sky130_fd_pr/     # primitive devices (original)
│               ├── sky130_fd_pr_ngspice/  # patched copy for ngspice
│               ├── sky130_fd_sc_hd/  # high-density std cells
│               └── ...               # other cell libraries
│
└── .xschem/                          # Xschem runtime config
    ├── simulations/
    │   └── .spiceinit                # ngspice startup config for Sky130
    └── xschem_library/
        └── xschem_sky130/            # Sky130 symbols + xschemrc
            └── xschemrc              # Xschem startup config (launch from here)
```

---

## Configuration Files

### `xschemrc`

Xschem's Tcl startup configuration. It is placed in `~/.xschem/xschem_library/xschem_sky130/` and **must be the working directory when you launch xschem** — which is why the launch command uses `cd` first.

What it configures:

- **Library search paths** — points xschem to Sky130 symbol libraries so MOSFET, resistor, capacitor, and other PDK components appear in the component browser
- **Simulation directory** — directs generated netlists to `~/.xschem/simulations/`
- **ngspice integration** — wires the Simulate button to call ngspice with the correct flags
- **Sky130 Tcl helpers** — utility functions like `sky130_save_fet_params` that auto-generate `.save` files for node tracking in transient simulations

If you move your `INSTALL_DIR` or `FOUNDRY_DIR`, update the `PDK_ROOT` path inside `xschemrc` to match.

### `.spiceinit`

ngspice's startup script, placed in `~/.xschem/simulations/`. ngspice reads it automatically every time it is invoked from xschem.

```spice
* Speed up ngspice startup for Sky130
set ngbehavior=hsa
set skywaterpdk
```

- **`set ngbehavior=hsa`** — enables HSPICE-A compatibility mode. Sky130 model cards were written with HSPICE syntax; without this flag, ngspice misparses `.param` statements and model cards, producing errors or incorrect simulation results.
- **`set skywaterpdk`** — activates Sky130-specific workarounds inside ngspice for parameter ordering and subcircuit expansion.

**Without `.spiceinit`, Sky130 simulations will fail or silently produce wrong waveforms.**

---

## Sky130 Primitive Device Patch

The install script creates a patched copy of `sky130_fd_pr` named `sky130_fd_pr_ngspice`. This patch (sourced from `xschem_sky130/sky130_fd_pr.patch`) reorders the `nf` parameter before dependent expressions (`AD`, `AS`, `PD`, `PS`) in FET model cards.

ngspice evaluates parameters sequentially, so if `nf` appears after an expression that depends on it, it is treated as undefined. This patch is only needed when using ngspice — commercial simulators handle out-of-order parameters gracefully.

---

## Updating

To update all tools to their latest versions, just re-run the script:

```bash
./install_analog.sh
```

Each tool's source directory will be `git pull`-ed, then rebuilt and reinstalled. For ngspice specifically, the script automatically picks up any new `ngspice-NN` release tag.

---

## Troubleshooting

**xschem opens but Sky130 symbols are missing**
The working directory matters. Always launch from `~/.xschem/xschem_library/xschem_sky130/` so `xschemrc` is picked up. Launching from `$HOME` will open xschem without PDK paths configured.

**ngspice throws model errors on simulation**
Check that `~/.xschem/simulations/.spiceinit` exists and contains `set ngbehavior=hsa`. Without it, Sky130 model syntax is not parsed correctly.

**Sky130 PDK clone is very slow or hangs**
The `skywater-pdk` repo and its submodules are large (~5–8 GB). This is expected. If a submodule update stalls, re-run the script — `git submodule update` resumes from where it left off.

**`patch` fails during PDK setup**
This means `sky130_fd_pr_ngspice` already exists from a previous partial run but is in an inconsistent state. Remove it and re-run:
```bash
rm -rf ~/eda/foundry/skywater-pdk/libraries/sky130_fd_pr_ngspice
./install_analog.sh --skip-deps --skip-xschem --skip-ngspice --skip-magic
```

**ngspice `autogen.sh` fails**
Make sure `autoconf`, `automake`, and `libtool` are installed. These are included in the `install_deps` step; if you used `--skip-deps`, install them manually:
```bash
sudo apt-get install autoconf automake libtool
```

---

## References

- [Xschem documentation](http://xschem.sourceforge.net/stefan/xschem_man/xschem_man.html)
- [ngspice manual](https://ngspice.sourceforge.io/docs/ngspice-manual.pdf)
- [SkyWater PDK documentation](https://skywater-pdk.readthedocs.io)
- [Magic VLSI documentation](http://opencircuitdesign.com/magic/documentation.html)
- [Efabless / Tiny Tapeout](https://tinytapeout.com) — for submitting Sky130 designs to fabrication
