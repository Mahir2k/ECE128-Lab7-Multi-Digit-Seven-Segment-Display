`timescale 1ns / 1ps
// ECE 128 Lab 7: Up-counter (0..4095), binary->BCD, multiplexed display.
// Basys 3: 100 MHz clock, active-high center reset, active-low 7-seg/anodes.
// All logic uses the same 100 MHz clock. Clock enables avoid derived clocks.

// Generates a one-system-clock-wide tick at TICK_HZ.
module tick_generator #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer TICK_HZ = 1
) (
    input  wire clk,
    input  wire rst,
    output wire tick
);
    localparam integer DIVISOR = CLK_HZ / TICK_HZ;
    localparam integer WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);
    reg [WIDTH-1:0] div_count;

    assign tick = (div_count == DIVISOR-1);

    always @(posedge clk) begin
        if (rst || tick)
            div_count <= {WIDTH{1'b0}};
        else
            div_count <= div_count + 1'b1;
    end
endmodule

module counter12 (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  [11:0] value
);
    always @(posedge clk) begin
        if (rst)
            value <= 12'd0;
        else if (enable)
            value <= value + 12'd1;  // 4095 -> 0 automatically at 12 bits
    end
endmodule

// Sequential 12-bit Double Dabble converter, inspired by Lab 6's FSM.
// A new conversion begins automatically when the 12-bit input changes.
// Output bcd holds its previous value until the complete result is ready.
module bin_to_bcd12_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] bin,
    output reg  [15:0] bcd,
    output reg         busy,
    output reg         done
);
    reg [11:0] previous_bin;
    reg [11:0] binary_shift;
    reg [15:0] bcd_shift;
    reg [3:0]  shift_count;
    reg [15:0] adjusted_bcd;
    wire [15:0] next_bcd = {adjusted_bcd[14:0], binary_shift[11]};

    // Combinational ADD-3 stage: inspect each BCD digit before left shift.
    always @(*) begin
        adjusted_bcd = bcd_shift;
        if (adjusted_bcd[3:0]   >= 4'd5)
            adjusted_bcd[3:0]   = adjusted_bcd[3:0]   + 4'd3;
        if (adjusted_bcd[7:4]   >= 4'd5)
            adjusted_bcd[7:4]   = adjusted_bcd[7:4]   + 4'd3;
        if (adjusted_bcd[11:8]  >= 4'd5)
            adjusted_bcd[11:8]  = adjusted_bcd[11:8]  + 4'd3;
        if (adjusted_bcd[15:12] >= 4'd5)
            adjusted_bcd[15:12] = adjusted_bcd[15:12] + 4'd3;
    end

    always @(posedge clk) begin
        if (rst) begin
            bcd          <= 16'h0000;
            previous_bin <= 12'hFFF; // Ensures initial zero is converted.
            binary_shift <= 12'd0;
            bcd_shift    <= 16'd0;
            shift_count  <= 4'd0;
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;            // Done is a single-cycle pulse.
            if (!busy) begin
                if (bin != previous_bin) begin
                    previous_bin <= bin;
                    binary_shift <= bin;
                    bcd_shift    <= 16'd0;
                    shift_count  <= 4'd0;
                    busy         <= 1'b1;
                end
            end else begin
                bcd_shift    <= next_bcd;
                binary_shift <= {binary_shift[10:0], 1'b0};
                shift_count  <= shift_count + 4'd1;
                if (shift_count == 4'd11) begin
                    bcd  <= next_bcd; // Exactly 12 shifts processed.
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule

// 2-bit, modulo-4 digit-selection counter.
module scan_counter (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  [1:0] select_digit
);
    always @(posedge clk) begin
        if (rst)
            select_digit <= 2'd0;
        else if (enable)
            select_digit <= select_digit + 2'd1;
    end
endmodule

// Active-low 2-to-4 anode decoder. an[0] is the rightmost digit.
module anode_decoder (
    input  wire [1:0] select_digit,
    output reg  [3:0] an
);
    always @(*) begin
        case (select_digit)
            2'd0: an = 4'b1110;
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111;
            default: an = 4'b1111;
        endcase
    end
endmodule

// 4-to-1 mux: decimal ones/tens/hundreds/thousands from 16-bit BCD.
module bcd_mux4 (
    input  wire [15:0] bcd,
    input  wire [1:0]  select_digit,
    output reg  [3:0]  digit
);
    always @(*) begin
        case (select_digit)
            2'd0: digit = bcd[3:0];
            2'd1: digit = bcd[7:4];
            2'd2: digit = bcd[11:8];
            2'd3: digit = bcd[15:12];
            default: digit = 4'd0;
        endcase
    end
endmodule

// Basys3 active-low cathodes: seg[0]=a, ..., seg[6]=g.
// Verilog vector is written in {g, f, e, d, c, b, a} bit order.
module bcd_to_7seg (
    input  wire [3:0] digit,
    output reg  [6:0] seg
);
    always @(*) begin
        case (digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // Blank for invalid BCD.
        endcase
    end
endmodule

// Top-level file and module both named lab7_top.
module lab7_top #(
    parameter integer CLK_HZ  = 100_000_000,
    parameter integer SCAN_HZ = 4_000
) (
    input  wire        clk,
    input  wire        btnC,
    output wire [3:0]  an,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [11:0] led
);
    wire one_hz_tick;
    wire scan_tick;
    wire [11:0] binary_count;
    wire [15:0] bcd_count;
    wire [1:0]  selected_digit;
    wire [3:0]  digit_bcd;
    wire        conversion_busy, conversion_done;

    tick_generator #(.CLK_HZ(CLK_HZ), .TICK_HZ(1)) u_one_hz (
        .clk(clk), .rst(btnC), .tick(one_hz_tick)
    );
    counter12 u_counter (
        .clk(clk), .rst(btnC), .enable(one_hz_tick), .value(binary_count)
    );
    bin_to_bcd12_fsm u_bin_to_bcd (
        .clk(clk), .rst(btnC), .bin(binary_count),
        .bcd(bcd_count), .busy(conversion_busy), .done(conversion_done)
    );
    tick_generator #(.CLK_HZ(CLK_HZ), .TICK_HZ(SCAN_HZ)) u_scan_tick (
        .clk(clk), .rst(btnC), .tick(scan_tick)
    );
    scan_counter u_scan_counter (
        .clk(clk), .rst(btnC), .enable(scan_tick), .select_digit(selected_digit)
    );
    anode_decoder u_anodes (
        .select_digit(selected_digit), .an(an)
    );
    bcd_mux4 u_mux (
        .bcd(bcd_count), .select_digit(selected_digit), .digit(digit_bcd)
    );
    bcd_to_7seg u_segments (
        .digit(digit_bcd), .seg(seg)
    );

    assign dp = 1'b1;          // Decimal point OFF (active-low).
    assign led = binary_count; // Optional debug output to 12 LEDs.
endmodule
