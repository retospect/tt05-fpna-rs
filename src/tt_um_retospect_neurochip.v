`default_nettype none

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

    wire reset = ! rst_n;

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
    wire reset_nn = uio_in[0];

    reg [0:9] bs = 0;
    // on each rising edge, if config_en is high, load the value from bs_in
    // into the bs register and set bs_out to the output of the bs register
    // and shfit the bs register left by one bit
    always @(posedge clk) begin
	if (config_en) begin
	    bs[0:9] <= {bs_in,bs[0:8]};
	end
    end

    assign bs_out = bs[9];
    assign outbus = 10'b0000000000;

endmodule
