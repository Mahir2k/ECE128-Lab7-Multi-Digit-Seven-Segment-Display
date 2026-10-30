# ECE 128 — Lab 7: 0–4095 Up-Counter on Basys 3

This lab implements a 12-bit binary up-counter and shows its decimal value on the **four-digit, common-anode seven-segment display** of the Digilent Basys 3 FPGA board.

- Count range: **0000 through 4095**, then wraps to 0000.
- Count rate: **1 value per second** from the Basys 3 **100 MHz** clock.
- Conversion: sequential **12-shift Double Dabble** binary-to-BCD module, similar to Lab 6.
- Scan rate: **4,000 digit-select steps per second** (each digit selected 1,000 times/s).
- Button: **BTNC** resets the counter to 0000.
- Debug: **LED[11:0]** shows the same counter value in binary.
- All four digits are illuminated through time multiplexing; digit enables and cathodes are **active LOW**.

## Directory structure

```text
ECE128_Lab7/
├── src/
│   └── lab7_top.v                 # All synthesizable modules; lab7_top is top
├── sim/
│   └── tb_lab7_top.sv            # Top-level self-checking testbench
├── constraints/
│   └── basys3_lab7.xdc          # Digilent-verified board pin mapping
├── docs/
│   ├── ECE128_Lab7_Prelab.pdf   # Level-0, Level-1 diagrams + explanation
│   ├── level0.png / level1.png  # Diagrams for your report
│   └── Lab7_Report_Draft.md     # Report text + places for actual evidence
└── README.md
```

## Design hierarchy

```text
lab7_top
├── u_one_hz         : tick_generator (100 MHz -> 1 count pulse/s)
├── u_counter        : counter12 (12-bit count, wraps 4095 -> 0)
├── u_bin_to_bcd     : bin_to_bcd12_fsm (12 shifts, 16-bit BCD result)
├── u_scan_tick      : tick_generator (100 MHz -> 4000 scan pulses/s)
├── u_scan_counter   : scan_counter (0,1,2,3)
├── u_anodes         : anode_decoder (active-low AN0..AN3)
├── u_mux            : bcd_mux4 (selects one BCD nibble)
└── u_segments       : bcd_to_7seg (active-low CA..CG)
```

## Vivado: create project and add files

1. Open **Vivado** and select **Create Project**.
2. Choose **RTL Project** and check or leave unchecked 'Do not specify sources at this time' as preferred.
3. Choose board **Basys 3** (if installed) or part **xc7a35tcpg236-1**.
4. In **Project Manager → Add Sources → Add or Create Design Sources**, add `src/lab7_top.v`.
5. In **Add Sources → Add or Create Simulation Sources**, add `sim/tb_lab7_top.sv`.
6. In **Add Sources → Add or Create Constraints**, add `constraints/basys3_lab7.xdc`.
7. Under **Sources → Hierarchy**, right-click `lab7_top` and choose **Set as Top** for design. Under **Simulation Sources**, set `tb_lab7_top` as simulation top.

## Run simulation (do this before programming)

1. In **Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation**.
2. Add these signals to the waveform: `clk`, `btnC`, `led[11:0]`, `dut.binary_count`, `dut.bcd_count`, `dut.one_hz_tick`, `dut.selected_digit`, `an[3:0]`, `seg[6:0]`, `dut.conversion_done`.
3. Right-click `led` / `binary_count` in the waveform and select **Radix → Unsigned Decimal**; `bcd_count` is best viewed in **Hexadecimal** (e.g., 16'h1234 means decimal 1234, not hex 0x1234 as a numeric value).
4. Run until the testbench finishes (e.g., **Run All**). Expected terminal message: `ALL LAB 7 TESTS PASSED` **if** the design passes.
5. Save waveform screenshots showing normal count increments, 0009→0010, directed values 0099, 0999, 1234 and the 4095→0000 rollover. Do not confuse 'bcd_count' as a regular 16-bit binary numeric value.

**Simulation speed-up:** Testbench instantiates `lab7_top #(.CLK_HZ(1000), .SCAN_HZ(250))`. This scales time so that a 1 Hz-equivalent count takes only 1,000 simulated clock edges, and each scan step takes four edges. The synthesized default remains at 100 MHz and 1 Hz.

**If you use Icarus Verilog** (outside Vivado):

```sh
iverilog -g2012 -s tb_lab7_top -o lab7_sim src/lab7_top.v sim/tb_lab7_top.sv
vvp lab7_sim
# Optional: gtkwave lab7_top.vcd
```

## Program the Basys 3

1. Keep `lab7_top` as the **design top**. Ensure `basys3_lab7.xdc` is enabled.
2. Run **Synthesis**. Check for errors and warnings (especially unmatched ports / unconstrained pins).
3. Open **Synthesis → Report Utilization** and record **LUTs** and **FFs**. Later, after implementation, record used **Slices** as well.
4. Run **Implementation** and then **Generate Bitstream**.
5. Attach Basys 3 over USB (the board's **PROG/UART** connector) and switch its power ON.
6. Choose **Hardware Manager → Open Target → Auto Connect**.
7. Choose **Program Device** and select the generated `.bit` file.
8. Press **BTNC**; the display should reset to `0000`. Release it; it should count `0001`, `0002`, ... at about one step per second.
9. The **12 LEDs** show the underlying binary counter state.
10. Take a clear photo or video of the displayed count and capture a screenshot of your resource utilization report.

## Functional test plan

| Binary decimal input | Expected BCD (4 digits) | Segment display |
| ---: | :---: | :---: |
| 0 | `0000` | 0000 |
| 1 | `0001` | 0001 |
| 9 | `0009` | 0009 |
| 10 | `0010` | 0010 |
| 99 | `0099` | 0099 |
| 999 | `0999` | 0999 |
| 1234 | `1234` | 1234 |
| 4095 | `4095` | 4095 |
| after 4095 | `0000` | 0000 |

**Note:** Reaching 4095 from zero takes 4095 seconds (68 min 15 sec) with a true 1 Hz count, so use simulation for terminal rollover evidence. The hardware demo can demonstrate resets and the first few seconds; do not claim you observed hardware rollover unless you actually do.

## Report / GitHub requirements

Follow the instructor's requested sections: **Objectives, Introduction (with both prelab diagrams), Results (waveforms, hardware photos, utilization), Conclusion, Contribution Chart**. Each group needs **one GitHub repository**, containing source, testbench and this README. Put your repository URL in the report. Fill resource totals from **your own Vivado run**, not guessed values. The assignment's mentions of a 'real car scenario' or 'each modeling method' appear inconsistent with the stated up-counter task; ask your TA if those inherited template lines must be interpreted literally.

## Reference pin source

[Official Digilent Basys 3 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)
