

module tt_um_retospect_neurochip #( parameter MAX_COUNT = 24'd10_000_000 ) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

BRAIN brain1(ui_in[0], clk, ui_in[1], ui_in[2], ui_in[3], uo_out[0], ui_in[4], ui_in[5], ui_in[6], ui_out[1], ui_out[2], ui_out[3]);

endmodule // tt_retospect

module BRAIN(conf_en, clk, nn_reset, bs_in, bs_out, IN1, IN2, IN3, OUT1, OUT2, OUT3);
input conf_en, clk, nn_reset, bs_in, IN1, IN2, IN3;
output bs_out, OUT1, OUT2, OUT3;
wire bs_out;
reg [7:0] dBus; // the decay clock bus

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

NEURON A1(B1Axon, IN1, False, conf_en, bs_in, bs_out, clk, nn_reset, A1Axon, dBus);
NEURON A2(B2Axon, False, False, conf_en, A1Axon, A1Axon, clk, nn_reset, A2Axon, dBus);
NEURON A3(B3Axon, False, False, conf_en, A2Axon, A2Axon, clk, nn_reset, A3Axon, dBus);
NEURON A4(B4Axon, False, False, conf_en, A3Axon, A3Axon, clk, nn_reset, A4Axon, dBus);
NEURON A5(B5Axon, False, False, conf_en, A4Axon, A4Axon, clk, nn_reset, A5Axon, dBus);
NEURON B1(C1Axon, IN2, A2Axon, conf_en, A5Axon, A5Axon, clk, nn_reset, B1Axon, dBus);
NEURON B2(C2Axon, B1Axon, A2Axon, conf_en, B1Axon, B1Axon, clk, nn_reset, B2Axon, dBus);
NEURON B3(C3Axon, B2Axon, A3Axon, conf_en, B2Axon, B2Axon, clk, nn_reset, B3Axon, dBus);
NEURON B4(C4Axon, B3Axon, A4Axon, conf_en, B3Axon, B3Axon, clk, nn_reset, B4Axon, dBus);
NEURON B5(C5Axon, B4Axon, A5Axon, conf_en, B4Axon, B4Axon, clk, nn_reset, B5Axon, dBus);
NEURON C1(D1Axon, IN3, B2Axon, conf_en, B5Axon, B5Axon, clk, nn_reset, C1Axon, dBus);
NEURON C2(D2Axon, C1Axon, B2Axon, conf_en, C1Axon, C1Axon, clk, nn_reset, C2Axon, dBus);
NEURON C3(D3Axon, C2Axon, B3Axon, conf_en, C2Axon, C2Axon, clk, nn_reset, C3Axon, dBus);
NEURON C4(D4Axon, C3Axon, B4Axon, conf_en, C3Axon, C3Axon, clk, nn_reset, C4Axon, dBus);
NEURON C5(D5Axon, C4Axon, B5Axon, conf_en, C4Axon, C4Axon, clk, nn_reset, C5Axon, dBus);
NEURON D1(F1Axon, False, C2Axon, conf_en, C5Axon, C5Axon, clk, nn_reset, D1Axon, dBus);
NEURON D2(F2Axon, D1Axon, C2Axon, conf_en, D1Axon, D1Axon, clk, nn_reset, D2Axon, dBus);
NEURON D3(F3Axon, D2Axon, C3Axon, conf_en, D2Axon, D2Axon, clk, nn_reset, D3Axon, dBus);
NEURON D4(F4Axon, D3Axon, C4Axon, conf_en, D3Axon, D3Axon, clk, nn_reset, D4Axon, dBus);
NEURON D5(F5Axon, D4Axon, C5Axon, conf_en, D4Axon, D4Axon, clk, nn_reset, D5Axon, dBus);
NEURON F1(False, False, D2Axon, conf_en, D5Axon, D5Axon, clk, nn_reset, F1Axon, dBus);
NEURON F2(False, F1Axon, D2Axon, conf_en, F1Axon, F1Axon, clk, nn_reset, F2Axon, dBus);
NEURON F3(False, F2Axon, D3Axon, conf_en, F2Axon, F2Axon, clk, nn_reset, F3Axon, dBus);
NEURON F4(False, F3Axon, D4Axon, conf_en, F3Axon, F3Axon, clk, nn_reset, F4Axon, dBus);
NEURON F5(False, F4Axon, D5Axon, conf_en, F4Axon, F4Axon, clk, nn_reset, F5Axon, dBus);

wire F1Axon, OUT1;
wire F2Axon, OUT2;
wire F3Axon, OUT3;



endmodule

module NEURON(A, B, C, conf_en, bs_in, bs_out, clk, nn_reset, Axon, dBus);
input bs_in, clk, conf_en, nn_reset, A, B, C;
input [7:0] dBus; // the decay clock bus
output bs_out, Axon; // the bitstream shift register output
reg [2:0] wA, wB, wC; // the weights of the neuron
reg [4:0] U; // the membrane voltage as an int
reg [2:0] tSel; // the decay clock bus line selector
wire bs_out = U[4];
wire Axon = U[4]; // fires when the overflow bit is on.
wire A, B, C; // the dendritic inputs to the neuron

always @(posedge clk)
begin: CONFIG_OPS
	if (conf_en) // if it is config time, shift the shift register
		// Make a gigantic shift register.
		// Shift the weight MSB first through wA, wA LSB to MSB wB etc.
		wA <= {wA[1:0], bs_in};
		wB <= {wB[1:0], wA[2]};
		wC <= {wC[1:0], wB[2]};
		tSel <= {tSel[1:0], wC[2]};
		U <= {U[2:0], tSel[2]}; // Shift the membrane voltage

	if (!conf_en & nn_reset) // if it is reset time, reset the neuron
         	U <= 1;
	if (!conf_en & !nn_reset) // if it is not config time, do the neuron operation
         		U <= U + A*wA + B*wB + C*wC;
	
   	if (U[4]) // if the overflow bit is on, reset the neuron
	 	U[4] <= 0;
		// it fired automatically because AXON is also U4. 
end

// on the down edge of the clock, shift the membrane voltage
always @(negedge clk)
begin: SHIFT_DECAY
   // if the selected decay bus line is high,
   // shift the membrane voltage right one click
   if (dBus[tSel])
      U[1:0] <= U[2:1];
      U[2] <= 0;
      // if an overflow happened we leave the overflow bit until the next
      // uptick. This is because the overflow bit is also the axon output and
      // can serve as the input to the dendrites there. 

end
endmodule

