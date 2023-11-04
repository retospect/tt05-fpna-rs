`default_nettype none

// Decay Clock Definition:
// and 0, 1 are on the first two lines,
//then we have CLK_COUNT more with actual counters
parameter integer CLK_COUNT = 6;

// Array definition: THis is the size of the array
parameter integer X_MAX = 10;
parameter integer Y_MAX = 5;

// nuber of inputs and outputs
parameter integer NUM_OUTPUTS = 10;
parameter integer NUM_INPUTS = 10;

module tt_um_retospect_neurochip (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    /* verilator lint_on UNUSEDSIGNAL */
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire reset = !rst_n & ena;

  // use bidirectionals as outputs
  assign uio_oe = 8'b11000010;

  wire [9:0] inbus;
  assign inbus = {ui_in[7:0], uio_in[7:6]};

  wire [9:0] outbus;
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
  assign uio_out[0] = clockbus[0] & clockbus[1] & clockbus[2] &
         clockbus[3] & clockbus[4] & clockbus[5] & clockbus[6] & clockbus[7];

  wire reset_nn = uio_in[0];
  // bitstream wires - one for each cell and an extra for the output
  wire [X_MAX*Y_MAX:0] bs_w;
  // axon wires - one for each cell
  wire [X_MAX*Y_MAX:0] axon;
  // from the cell above (or the bottom of the array, for the
  // top one)
  wire [X_MAX*Y_MAX:0] from_above;
  // from the cell to the left (or the right edge of the array,
  // for the left one)
  wire [X_MAX*Y_MAX:0] from_left;
  // from the cell to the right (or the left edge of the array,
  // for the right one)
  wire [X_MAX*Y_MAX:0] from_right;
  // from the cell below
  // or the top of the array, for the bottom one
  wire [X_MAX*Y_MAX:0] from_below;

  wire [7:0] clockbus;
  retospect_clockbox clockbox (
      .config_en(config_en),
      .bs_in(bs_in),
      .bs_out(bs_w[0]),
      .clk(clk),
      .reset(reset),
      .reset_nn(reset_nn),
      .clockbus(clockbus)
  );

  generate
    genvar x, y;
    for (x = 0; x < X_MAX; x = x + 1) begin : gen_x
      for (y = 0; y < Y_MAX; y = y + 1) begin : gen_y
        localparam int LinIdx = x * Y_MAX + y;
        localparam int MaxLinIdx = X_MAX * Y_MAX - 1;
        // instantiate the cnb
        retospect_cnb cnb (
            .config_en(config_en),
            .bs_in(bs_w[LinIdx]),
            .bs_out(bs_w[LinIdx+1]),
            .clk(clk),
            .reset(reset),
            .reset_nn(reset_nn),
            .clockbus(clockbus),
            .axon(axon[LinIdx]),
            .dendrite1(from_above[LinIdx]),
            .dendrite2(from_left[LinIdx]),
            .dendrite3(from_right[LinIdx]),
            .dendrite4(from_below[LinIdx])
        );

        // Wire up the from_right bits
        if (LinIdx == 0) begin : gen_from_right_rollover
          assign from_right[LinIdx] = axon[MaxLinIdx];
        end else begin : gen_from_right
          assign from_right[LinIdx] = axon[LinIdx-1];
        end

        // Wire up the from_left bits
        if (LinIdx == MaxLinIdx) begin : gen_from_left_rollover
          assign from_left[LinIdx] = axon[0];
        end else begin : gen_from_left
          assign from_left[LinIdx] = axon[LinIdx+1];
        end

        // Wire up the from_above bits
        // This is a bit more complicated because we need to handle the
        // case where we are at the top of the array
        if (LinIdx < Y_MAX) begin : gen_from_above_top
          assign from_above[LinIdx] = axon[LinIdx+MaxLinIdx-Y_MAX+1];
        end else begin : gen_from_above
          assign from_above[LinIdx] = axon[LinIdx-Y_MAX];
        end


        // Hook up the outputs
        // Calculate how far apart the outputs need to be to fit in the
        // MaxLinIdx
        localparam int SPACING = MaxLinIdx / NUM_OUTPUTS;
        if (LinIdx % SPACING == 0) begin : gen_output
          if (LinIdx / SPACING < NUM_OUTPUTS) begin : gen_make_output
            // print out which xy coordinates this output is from
            // this is useful for debugging and bitstream generation
            //$display("Output %d is from x=%d, y=%d", LinIdx/SPACING, x, y);
            assign outbus[LinIdx/SPACING] = axon[LinIdx];
          end
        end
        if ((LinIdx == 1) & (LinIdx / SPACING < NUM_INPUTS)) begin : gen_connect_inputs
          assign from_below[LinIdx] = inbus[LinIdx/SPACING];
        end else begin : gen_connect_from_below_for_the_rest
          // Wire up the from_below bits
          // This is a bit more complicated because we need to handle the
          // case where we are at the bottom of the array
          if (LinIdx >= MaxLinIdx - Y_MAX) begin : gen_from_below_bottom
            assign from_below[LinIdx] = axon[LinIdx%X_MAX];
          end else begin : gen_from_below
            assign from_below[LinIdx] = axon[LinIdx+Y_MAX];
          end
        end
      end
    end
  endgenerate

  assign bs_out = bs_w[X_MAX*Y_MAX];

endmodule

module retospect_cnb (
    input wire config_en,
    input wire bs_in,
    output wire bs_out,
    input wire clk,
    input wire reset,
    input wire reset_nn,
    input wire [7:0] clockbus,
    output wire axon,
    input wire dendrite1,
    input wire dendrite2,
    input wire dendrite3,
    input wire dendrite4
);
  reg [2:0] w1, w2, w3, w4;
  reg [3:0] uT;
  reg [2:0] clockDecaySelect;

  wire my_decay;
  assign my_decay = clockbus[clockDecaySelect];

  always @(posedge clk) begin
    if (reset) begin
      // Reset condition
      w1 <= 3'b0;
      w2 <= 3'b0;
      w3 <= 3'b0;
      w4 <= 3'b0;
      uT <= 4'b0;  // Reset all 5 bits
      clockDecaySelect <= 3'b0;
    end else if (reset_nn) begin
      uT <= 4'b0001;  // initial weight is 1 to enable "always firing" neurons
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
    end else begin
      // Shift the bits in the register: bs_in is the new bit
      // and bs_out is the old bit
      // they pass thru w1, w2, w3, w4, uT, and clockDecaySelect in order
      if (my_decay) begin  // if the decay clock comes around, divide by half.
        // otherwise do nothing
        uT <= {uT[3:1], 1'b0};
      end
      if (uT[3]) begin  // clear the overflow bit if it is set
        uT[3] <= 1'b0;
      end
      if (dendrite1) begin
        uT <= uT + w1;
      end
      if (dendrite2) begin
        uT <= uT + w2;
      end
      if (dendrite3) begin
        uT <= uT + w3;
      end
      if (dendrite4) begin
        uT <= uT + w4;
      end
    end
  end

  assign axon   = uT[3];

  // The bitstream output is the last bit of the register
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
  // Clock module. It creates various clock signals

  reg [7:0] clock_max  [CLK_COUNT];
  reg [7:0] clock_count[CLK_COUNT];

  // when the clock is high and reset_nn is high, reset the clock_count to 0
  // when reset is going to high, reset the clock_count to 0
  // when reset is high, clock_count is 0
  // when config_en is high, shift the bits through the clock_max registers
  // when clock is going high and clock count is equal to clock_max, reset the clock_count to 0
  //
  always @(posedge clk) begin
    if (reset) begin
      // Reset condition
      for (integer i = 0; i < CLK_COUNT; i = i + 1) begin
        clock_max[i]   <= 8'b00000000;
        clock_count[i] <= 8'b00000000;
      end
    end else if (reset_nn) begin
      for (integer i = 0; i < CLK_COUNT; i = i + 1) begin
        clock_count[i] <= 8'b00000000;
      end
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
      // if the clock_count is higher than the clock_max, reset the
      // clock_count to 0
      // otherwise, increment the clock_count
      for (integer i = 0; i < CLK_COUNT; i = i + 1) begin
        if (clock_count[i] > clock_max[i]) begin  // if it is higher than the max, reset
          clock_count[i] <= 8'b00000000;
        end else begin
          clock_count[i] <= clock_count[i] + 1;  // otherwise increment
        end
      end
    end
  end

  // clockbus 0 = 0 (never decay)
  // clockbus 1 = 1 (decay with each timestep)
  // clockbus[2] to clockbus[CLK_COUNT] are 1 if the corresponding clock_max and
  // clock_count are equal
  assign clockbus[0] = 1'b0;
  assign clockbus[1] = 1'b1;

  generate
    genvar i;
    for (i = 0; i < CLK_COUNT; i = i + 1) begin : gen_clockbus_by_compare
      assign clockbus[i+2] = (clock_max[i] == clock_count[i]) ? 1'b1 : 1'b0;
    end
  endgenerate

  // bs_out is the last bit of the last clock_max register
  assign bs_out = clock_max[CLK_COUNT-1][0];

endmodule

