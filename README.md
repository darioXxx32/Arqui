# FPGA Lab: Universal Shift Register / Hierarchical Adder / 64-bit ALU

**Author:** Dario  
**Course:** Computer Architecture — Lab 5 (VHDL / FPGA)  
**Repo (canonical):** https://github.com/darioXxx32/Arqui/tree/main  
**ZIP Backup (Drive):** https://drive.google.com/file/d/DRIVE_FILE_ID/view?usp=sharing  
*(replace DRIVE_FILE_ID or paste full Drive link)*

---

## What this repo contains (short)
This project implements and tests three small but important datapath components in VHDL:

**Part 1 — Universal shift register**
- `universal_shift.vhd` — parametric shift register (SISO, SIPO, PISO, PIPO)
- `tb_universal_shift.vhd` — testbench with wave checks & reports

**Part 2 — Hierarchical adder**
- `half_adder.vhd`
- `full_adder.vhd`
- `adder16.vhd` (with cin)
- `adder16_nocin.vhd` (no external cin; uses half-adder on LSB)
- `adder64.vhd` (instantiates 4x adder16)
- `tb_adder64.vhd` — testbench for basic and boundary cases

**Part 3 — 64-bit ALU**
- `alu64.vhd` — combinational core + registered outputs, operations selected by 4-bit opcode
- `tb_alu64.vhd` — testbench (logic ops, add/sub, shifts, mul lower-64, flags)

Also: `figures/` folder with example screenshots (waveforms, schematic views) and a ZIP backup (in Drive).

---

## Quick goals (what I tested)
- Shift register: verify all four modes (load, serial in/out, parallel in/out).
- Adder: 0+0, all-ones + 1 (overflow), ripple carry test, random sample.
- ALU: AND/OR/XOR/NOT, ADD/SUB with signed overflow detection, shifts (SLL/SRL/SRA), ROTL/ROTR, MUL(low64) and pass-B. Zero flag generation. Outputs are registered (clocked).

---

## How to run simulations (Vivado / XSim) — quick steps

> These TBs were developed targeting Vivado simulation (XSim). If you use ModelSim or GHDL the steps are similar but with different commands.

1. Open Vivado and create a new project (RTL project, no default part needed for simulation).
2. Add the VHDL sources and testbenches to the project (all `.vhd` files).
3. In **Sources**, mark the testbench you want to simulate as the top (e.g., `tb_alu64`).
4. Set VHDL standard if needed: Vivado usually supports VHDL-93/2008. If you see weird attribute/indexing errors try switching to VHDL-2008.
5. Run **Simulation > Run Behavioral Simulation**.

If you prefer CLI (approximate example used in logs):
```bash
# elaboration (example)
xelab --incr --debug typical -L xil_defaultlib xil_defaultlib.tb_alu64 -log elaborate.log

# run simulation (example)
xsim tb_alu64_behav -R
