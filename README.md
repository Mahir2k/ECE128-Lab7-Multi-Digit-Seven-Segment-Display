ECE 128 — Lab 7: 0–4095 Up-Counter on Basys 3
Project Overview
In this lab, we designed, simulated, and implemented a 12-bit binary up-counter on the Digilent Basys 3 FPGA board. We displayed the counter value in decimal on the board's four-digit, common-anode seven-segment display. The counter progressed from 0000 to 4095 and was designed to roll over to 0000 after reaching its maximum value.

We used the Basys 3's 100 MHz onboard clock and a clock-enable generator to increment the counter at 1 count per second. We converted each 12-bit binary value into four BCD digits using a sequential 12-shift Double Dabble algorithm based on our Lab 6 work. We refreshed the display using a 4,000-step-per-second digit scan, selecting each of the four digits approximately 1,000 times per second. Both the digit enables and seven-segment cathodes were active LOW.

We also connected BTNC to reset the count to 0000 and used LED[11:0] to show the same counter value in binary.
Project Structure
ECE128_Lab7/
├── src/
│   └── lab7_top.v                # Synthesizable Verilog modules
├── sim/
│   └── tb_lab7_top.sv            # Self-checking top-level testbench
├── constraints/
│   └── basys3_lab7.xdc          # Basys 3 pin constraints
├── docs/
│   ├── ECE128_Lab7_Prelab.pdf   # Level-0 and Level-1 diagrams
│   ├── level0.png                # Level-0 diagram
│   ├── level1.png                # Level-1 diagram
│   └── Lab7_Report_Draft.md     # Report drafting notes
└── README.md
Design Hierarchy
We implemented the system as modular Verilog components connected through the lab7_top module:
lab7_top
├── u_one_hz         : tick_generator   (100 MHz → 1 count enable/s)
├── u_counter        : counter12        (12-bit counter, modulo 4096)
├── u_bin_to_bcd     : bin_to_bcd12_fsm (12-step binary-to-BCD converter)
├── u_scan_tick      : tick_generator   (4,000 scan enables/s)
├── u_scan_counter   : scan_counter     (digit selection: 0, 1, 2, 3)
├── u_anodes         : anode_decoder    (active-low digit enables)
├── u_mux            : bcd_mux4         (four-to-one BCD digit selector)
└── u_segments       : bcd_to_7seg      (active-low seven-segment decoder)
The one-second clock-enable generator controlled the binary counter. The binary-to-BCD FSM produced a 16-bit packed BCD result with thousands, hundreds, tens, and ones digits. A two-bit scan counter, 2-to-4 anode decoder, and 4-to-1 multiplexer selected the appropriate digit for the seven-segment decoder. This rapid time multiplexing made all four digits appear continuously illuminated.
Vivado Project Setup
We created an RTL project in Xilinx Vivado 2023.1 for the Digilent Basys 3 target device (xc7a35tcpg236-1). We added src/lab7_top.v as the design source, sim/tb_lab7_top.sv as the simulation source, and constraints/basys3_lab7.xdc as the board constraints file. We selected lab7_top as the design top and tb_lab7_top as the simulation top.
Behavioral Simulation and Verification
We ran a behavioral simulation using the self-checking testbench. To keep the simulation practical, we instantiated the design with reduced timing parameters, CLK_HZ = 1000 and SCAN_HZ = 250. This allowed the simulated counter to advance after 1,000 simulated clock cycles while preserving the design's counting and scanning logic. The actual FPGA implementation used its default 100 MHz clock configuration.

We inspected the clk, btnC, led[11:0], binary_count, bcd_count, one_hz_tick, selected_digit, an[3:0], seg[6:0], and conversion_done signals. We viewed the binary count as unsigned decimal and the BCD bus in hexadecimal notation, where a packed BCD pattern such as 16'h1234 corresponds to the decimal digits 1234.

Our testbench checked normal increments, binary-to-BCD conversion, digit scanning, reset, and the counter's upper boundary. It included representative values such as 0, 1, 9, 10, 99, 999, 1234, 4094, and 4095, and it verified rollover to zero. The Vivado Tcl Console reported:
ALL LAB 7 TESTS PASSED
Counter value	Expected four-digit BCD display	Test result
0	0000	Passed
1	0001	Passed
9	0009	Passed
10	0010	Passed
99	0099	Passed
999	0999	Passed
1234	1234	Passed
4095	4095	Passed
After 4095	0000	Passed


We used simulation, rather than a continuous physical-board recording, to verify the 4095-to-0000 rollover. At one count per second, reaching 4095 from zero takes 4,095 seconds (68 minutes 15 seconds).
FPGA Synthesis and Implementation
After the simulation passed, we ran Synthesis, Implementation, and Generate Bitstream in Vivado. We reviewed the synthesis and implemented utilization reports, then programmed the Basys 3 through the Hardware Manager using the USB programming connection.
FPGA resource	Synthesis	Implementation	Available
Slice LUTs	52	50	20,800
Slice registers	117	117	41,600
Slices	—	37	8,150
Bonded I/O	26	26	106
BUFGCTRL	1	1	32


The final implementation used approximately 0.24% of LUTs, 0.28% of slice registers, and 0.45% of slices. The binary-to-BCD conversion FSM accounted for the largest share of the logic resources. LUT usage decreased slightly from 52 after synthesis to 50 after implementation, while the register count remained unchanged.
Hardware Demonstration
We programmed the Basys 3 and documented the display and binary LED activity with photographs. The four-digit display showed decimal counter values while LED[11:0] reflected the corresponding binary value. Our demonstration video recorded the board operation and reset behavior using BTNC.

Demonstration video: [Insert video link]
Conclusion
We completed a working FPGA design that combined a 12-bit sequential counter, a clock-enable generator, Double Dabble binary-to-BCD conversion, and a multiplexed four-digit seven-segment display. The self-checking simulation passed all directed test cases, and we programmed the design onto the Basys 3. The completed implementation used only a small fraction of the board's logic resources. This lab reinforced our understanding of hierarchical Verilog design, clock enables, FSM-based conversion, active-low display control, simulation, and hardware validation.
Report and Repository
We documented the Level-0 and Level-1 prelab diagrams, simulation results, hardware photographs, resource utilization, and group contributions in our Lab 7 report. The repository contains the Verilog design, the self-checking testbench, the XDC constraints, and this README.

Reference
- Official Digilent Basys 3 Master XDC
