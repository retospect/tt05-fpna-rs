

module tt_um_retospect_neurochip #(
    parameter MAX_COUNT = 24'd10_000_000
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

  BRAIN brain1 (
      ui_in[0],
      clk,
      ui_in[1],
      ui_in[2],
      ui_in[3],
      uo_out[0],
      ui_in[4],
      ui_in[5],
      ui_in[6],
      ui_out[1],
      ui_out[2],
      ui_out[3]
  );

endmodule  // tt_retospect

module BRAIN (
    conf_en,
    clk,
    nn_reset,
    bs_in,
    bs_out,
    IN1,
    IN2,
    IN3,
    OUT1,
    OUT2,
    OUT3
);
  input conf_en, clk, nn_reset, bs_in, IN1, IN2, IN3;
  output bs_out, OUT1, OUT2, OUT3;
  wire bs_out;
  reg [7:0] dBus;  // the decay clock bus

  // Make a 5x5 array of neurons, x=A, B, C and Y=1,2,3.
  // The axon of each neuron is connected to the dendrites of the neighbours: 
  // It connects to the A dendrite of the neuron above, the B dendrite of the
  // neuron to the right, and the C dendrite of the neuron diagonally to the
  // bottom left
  // 
  // The bitstreams are shifted in the order A1, A2,... An, B1, B2,... Bn., so
  // bs_out of A1 is connected to bs_in of A2, etc.
  //
  // The decay clock bus is connected to everyone
  // The inputs are connected to the B inputs of the neurons on the left

  // for each row, we make 5 neurons, and connect them to each other
  // with a for loop
  NEURON A (
      IN1, IN2, IN3,
      conf_en, 
      bs_in,
      bs_out,
      clk,
      nn_reset,
      F3Axon
      
  );



endmodule

module NEURON (
    A,
    B,
    C,
    conf_en,
    bs_in,
    bs_out,
    clk,
    nn_reset,
    Axon
);
  input bs_in, clk, conf_en, nn_reset, A, B, C;
  reg [7:0] dBus;  // the decay clock bus
  output bs_out, Axon;  // the bitstream shift register output
  reg [2:0] wA, wB, wC;  // the weights of the neuron
  reg [4:0] U;  // the membrane voltage as an int
  reg [2:0] tSel;  // the decay clock bus line selector
  wire bs_out = U[4];
  wire Axon = U[4];  // fires when the overflow bit is on.
  wire A, B, C;  // the dendritic inputs to the neuron

  always @(posedge clk) begin : CONFIG_OPS
    if (conf_en)  // if it is config time, shift the shift register
      // Make a gigantic shift register.
      // Shift the weight MSB first through wA, wA LSB to MSB wB etc.
      wA <= {
        wA[1:0], bs_in
      };
    wB <= {wB[1:0], wA[2]};
    wC <= {wC[1:0], wB[2]};
    tSel <= {tSel[1:0], wC[2]};
    U <= {U[2:0], tSel[2]};  // Shift the membrane voltage

    if (!conf_en & nn_reset)  // if it is reset time, reset the neuron
      U <= 1;
    if (!conf_en & !nn_reset)  // if it is not config time, do the neuron operation
      U <= U + A * wA + B * wB + C * wC;

    if (U[4])  // if the overflow bit is on, reset the neuron
      U[4] <= 0;
    // it fired automatically because AXON is also U4. 
  end

  // on the down edge of the clock, shift the membrane voltage
  always @(negedge clk) begin : SHIFT_DECAY
    // if the selected decay bus line is high,
    // shift the membrane voltage right one click
    if (dBus[tSel]) U[1:0] <= U[2:1];
    U[2] <= 0;
    // if an overflow happened we leave the overflow bit until the next
    // uptick. This is because the overflow bit is also the axon output and
    // can serve as the input to the dendrites there. 

  end
endmodule

