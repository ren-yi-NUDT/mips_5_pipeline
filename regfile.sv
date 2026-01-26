module regfile(input logic clk,
               input logic we3,
               input logic[4:0] ra1,
               input logic[4:0] ra2,
               input logic[4:0] wa3,
               input logic[31:0]wd3,
               output logic[31:0]rd1, rd2,
               output logic[31:0]out[4:0]
			   );
	
	logic[31:0]rf[31:0];

	initial for (int i=0; i<32; i++) rf[i] = 32'b0;
	//three ported register file
	// read two ports combinationally
	// write third port on rising edge of clk
	// register 0 hardwired to0
	// note:for pipelined processor,write third port on falling edge of clk
	// 来自课本可复用代码
	always_ff@(posedge clk)
		if (we3)
			rf[wa3] <= wd3;

	assign rd1 = (ra1!= 0)?rf[ra1]:0;
	assign rd2 = (ra2!= 0)?rf[ra2]:0;


	assign out[0] = rf[2];
	assign out[1] = rf[3];
	assign out[2] = rf[4];
	assign out[3] = rf[5];
	assign out[4] = rf[7];
endmodule
