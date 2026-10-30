`timescale 1ns / 1ps
// Self-checking top-level testbench. Simulation uses a faster virtual clock
// configuration: 1000 clock cycles = one counter increment, not 100 million.
module tb_lab7_top;
    reg clk = 1'b0;
    reg btnC = 1'b1;
    wire [3:0]  an;
    wire [6:0]  seg;
    wire        dp;
    wire [11:0] led;

    lab7_top #(.CLK_HZ(1000), .SCAN_HZ(250)) dut (
        .clk(clk), .btnC(btnC), .an(an), .seg(seg), .dp(dp), .led(led)
    );
    always #5 clk = ~clk;  // 10 ns clock in simulation

    function automatic [15:0] decimal_to_bcd(input integer n);
        decimal_to_bcd = ((n / 1000) << 12) | (((n / 100) % 10) << 8) |
                         (((n / 10) % 10) << 4) | (n % 10);
    endfunction

    function automatic [6:0] seven_seg(input [3:0] digit);
        case(digit)
            0: seven_seg = 7'b1000000;
            1: seven_seg = 7'b1111001;
            2: seven_seg = 7'b0100100;
            3: seven_seg = 7'b0110000;
            4: seven_seg = 7'b0011001;
            5: seven_seg = 7'b0010010;
            6: seven_seg = 7'b0000010;
            7: seven_seg = 7'b1111000;
            8: seven_seg = 7'b0000000;
            9: seven_seg = 7'b0010000;
            default: seven_seg = 7'b1111111;
        endcase
    endfunction

    task automatic check_value(input integer expected);
        reg [15:0] correct_bcd;
        begin
            correct_bcd = decimal_to_bcd(expected);
            // Allow the FSM's 12 shifts plus control overhead to finish.
            repeat (18) @(negedge clk);
            if (led !== expected[11:0])
                $fatal(1, "LED mismatch: expected=%0d actual=%0d", expected, led);
            if (dut.bcd_count !== correct_bcd)
                $fatal(1, "BCD mismatch: value=%0d expected=%h actual=%h",
                       expected, correct_bcd, dut.bcd_count);
            if (dp !== 1'b1)
                $fatal(1, "Decimal point should remain off");
            $display("PASS: decimal %4d -> BCD %h", expected, dut.bcd_count);
        end
    endtask

    task automatic wait_for_value(input integer expected);
        integer cycles;
        begin
            cycles = 0;
            while (led !== expected[11:0] && cycles < 300) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (led !== expected[11:0])
                $fatal(1, "Timeout waiting for counter=%0d", expected);
            check_value(expected);
        end
    endtask

    task automatic load_value(input integer value);
        begin
            // Testbench-only hierarchical poke, not FPGA design behavior.
            @(negedge clk);
            dut.u_counter.value = value[11:0];
            check_value(value);
        end
    endtask

    task automatic check_scanned_digits(input integer value);
        reg [3:0] digit_seen;
        reg [6:0] expected_seg;
        integer i;
        begin
            digit_seen = 4'b0000;
            for (i = 0; i < 40; i = i + 1) begin
                @(negedge clk);
                case (an)
                    4'b1110: begin
                        expected_seg = seven_seg(value % 10);
                        digit_seen[0] = 1'b1;
                    end
                    4'b1101: begin
                        expected_seg = seven_seg((value / 10) % 10);
                        digit_seen[1] = 1'b1;
                    end
                    4'b1011: begin
                        expected_seg = seven_seg((value / 100) % 10);
                        digit_seen[2] = 1'b1;
                    end
                    4'b0111: begin
                        expected_seg = seven_seg((value / 1000) % 10);
                        digit_seen[3] = 1'b1;
                    end
                    default: $fatal(1, "Invalid anode pattern %b", an);
                endcase
                if (seg !== expected_seg)
                    $fatal(1, "Segment mismatch: an=%b expected=%b got=%b",
                           an, expected_seg, seg);
            end
            if (digit_seen !== 4'b1111)
                $fatal(1, "Not all four digits scanned: seen=%b", digit_seen);
            $display("PASS: all four digits and segment patterns for %4d", value);
        end
    endtask

    initial begin
        // Optional for Icarus Verilog/GTKWave; ignored if unsupported by tool.
        $dumpfile("lab7_top.vcd");
        $dumpvars(0, tb_lab7_top);

        repeat (4) @(negedge clk);
        btnC = 1'b0;
        check_value(0);

        // Normal 1-Hz-equivalent counting (accelerated in simulation).
        wait_for_value(1);
        wait_for_value(2);
        wait_for_value(3);
        wait_for_value(4);
        wait_for_value(5);
        wait_for_value(6);
        wait_for_value(7);
        wait_for_value(8);
        wait_for_value(9);
        wait_for_value(10);
        wait_for_value(11);

        // Directed corner cases for binary-to-BCD conversion.
        load_value(99);
        load_value(999);
        load_value(1234);
        check_scanned_digits(1234);

        // Check terminal count and automatic 4095 -> 0 rollover.
        load_value(4094);
        wait_for_value(4095);
        wait_for_value(0);

        // Check center-button reset from a nonzero value.
        load_value(1999);
        @(negedge clk);
        btnC = 1'b1;
        repeat (3) @(negedge clk);
        btnC = 1'b0;
        check_value(0);
        $display("ALL LAB 7 TESTS PASSED");
        $finish;
    end

    initial begin
        #250000;
        $fatal(1, "Global testbench timeout");
    end
endmodule
