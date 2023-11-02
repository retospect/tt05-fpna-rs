`default_nettype none

module tt_um_retospect_neurochip #(
    parameter X_MAX = 1,
    parameter Y_MAX = 1
) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire reset = !rst_n;

  // use bidirectionals as outputs
  assign uio_oe = 8'b11000010;

  wire [0:9] inbus;
  assign inbus = {ui_in[7:0], uio_in[7:6]};

  wire [0:9] outbus;
  assign {uo_out[7:0], uio_out[5:4]} = outbus;

  wire config_en = uio_in[3];
  wire bs_in = uio_in[2];
  wire bs_out;
  assign uio_out[1] = bs_out;

  // Fix yosys
  assign uio_out[7] = 1;
  assign uio_out[6] = 1;
  assign uio_out[3] = 1;
  assign uio_out[2] = 1;
  assign uio_out[0] = 1;

  wire reset_nn = uio_in[0];
  wire [X_MAX*Y_MAX:0] bs_w;

  wire [7:0] clockbus;
  retospect_clockbox clockbox (
      config_en,
      bs_in,
      bs_w[0],  // bs_out
      clk,
      reset,
      reset_nn,
      clockbus
  );

  assign bs_w[0] = bs_in;

  generate
    genvar x, y;
    for (x = 0; x < X_MAX; x = x + 1) begin
      for (y = 0; y < Y_MAX; y = y + 1) begin
        // instantiate the cnb
        retospect_cnb cnb (
            config_en,
            bs_w[x*Y_MAX+y],
            bs_w[x*Y_MAX+y+1],
            clk,
            reset,
            reset_nn,
            clockbus
        );
      end
    end
  endgenerate

  assign bs_out = bs_w[X_MAX*Y_MAX];

  // assign the output
  assign outbus = 10'b0000000000;

endmodule

module retospect_cnb (
    input wire config_en,
    input wire bs_in,
    output wire bs_out,
    input wire clk,
    input wire reset,
    input wire reset_nn,
    output wire [7:0] clockbus
);
  reg [2:0] w1, w2, w3, w4;
  reg [3:0] uT;
  reg [2:0] clockDecaySelect;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      // Reset condition
      w1 <= 3'b0;
      w2 <= 3'b0;
      w3 <= 3'b0;
      w4 <= 3'b0;
      uT <= 4'b0;  // Reset all 5 bits
      clockDecaySelect <= 3'b0;
    end else if (reset_nn) begin
      uT <= 4'b1;  // initial weight is 1 to enable "always firing" neurons
    end else if (config_en) begin
      // Shift the bits in the register: bs_in is the new bit
      // and bs_out is the old bit
      // they pass thru w1, w2, w3, w4, uT, and clockDecaySelect in order
      w1 <= {bs_in, w1[2:1]};
      w2 <= {w1[0], w2[2:1]};
      w3 <= {w2[0], w3[2:1]};
      w4 <= {w3[0], w4[2:1]};
      uT <= {w4[0], uT[3:1]};  // Shifting the entire 5-bit register
      clockDecaySelect <= {uT[0], clockDecaySelect[2:1]};
    end
  end

  // The output is the last bit of the register
  assign bs_out = clockDecaySelect[0];

endmodule

module retospect_clockbox (
    input wire config_en,
    input wire bs_in,
    output wire bs_out,
    input wire clk,
    input wire reset,
    input wire reset_nn,
    output wire [7:0] clockbus
);
  // Clock module. It creats

  assign clockbus[0] = 1'b0;
  assign clockbus[1] = 1'b1;

  reg [7:0] clock_max  [5:0];
  reg [7:0] clock_count[5:0];

  // when the clock is high and reset_nn is high, reset the clock_count to 0
  // when reset is going to high, reset the clock_count to 0
  // when reset is high, clock_count is 0
  // when config_en is high, shift the bits through the clock_max registers
  // when clock is going high and clock count is equal to clock_max, reset the clock_count to 0
  //
  always @(posedge clk) begin
    if (reset) begin
      // Reset condition
      clock_max[0]   <= 8'b00000000;
      clock_max[1]   <= 8'b00000000;
      clock_max[2]   <= 8'b00000000;
      clock_max[3]   <= 8'b00000000;
      clock_max[4]   <= 8'b00000000;
      clock_max[5]   <= 8'b00000000;
      clock_count[0] <= 8'b00000000;
      clock_count[1] <= 8'b00000000;
      clock_count[2] <= 8'b00000000;
      clock_count[3] <= 8'b00000000;
      clock_count[4] <= 8'b00000000;
      clock_count[5] <= 8'b00000000;
    end else if (reset_nn) begin
      clock_count[0] <= 8'b00000000;
      clock_count[1] <= 8'b00000000;
      clock_count[2] <= 8'b00000000;
      clock_count[3] <= 8'b00000000;
      clock_count[4] <= 8'b00000000;
      clock_count[5] <= 8'b00000000;
    end else if (config_en) begin
      // Shift the bits in the register: bs_in is the new bit
      // and bs_out is the old bit
      // they pass thru w1, w2, w3, w4, uT, and clockDecaySelect in order
      clock_max[0] <= {bs_in, clock_max[0][7:1]};
      clock_max[1] <= {clock_max[0][0], clock_max[1][7:1]};
      clock_max[2] <= {clock_max[1][0], clock_max[2][7:1]};
      clock_max[3] <= {clock_max[2][0], clock_max[3][7:1]};
      clock_max[4] <= {clock_max[3][0], clock_max[4][7:1]};
      clock_max[5] <= {clock_max[4][0], clock_max[5][7:1]};
    end else begin
      clock_count[0] <= clock_count[0] + 1;
      clock_count[1] <= clock_count[1] + 1;
      clock_count[2] <= clock_count[2] + 1;
      clock_count[3] <= clock_count[3] + 1;
      clock_count[4] <= clock_count[4] + 1;
      clock_count[5] <= clock_count[5] + 1;

    end
  end

  // clockbus[2] to clockbus[7] are 1 if the corresponding clock_max and
  // clock+count are equal

  // bs_out is the last bit of the last clock_max register
  assign bs_out = clock_max[0][0];

endmodule

