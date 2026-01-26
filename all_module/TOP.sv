module TOP(
    input logic clk_pre, reset, T1, T0,
    output logic success_led,
    output logic [10:0] disp_7seg
);

//==================clock_civer==================
integer cnt_peri = 0, cnt_disp = 0;
logic CLK = 0;

always_ff @ (posedge clk_pre) begin
   cnt_peri <= cnt_peri + 1;
   cnt_disp <= cnt_disp + 1;
   if (cnt_peri == 5000000) begin 
       cnt_peri <= 0;
       CLK <= CLK ^ 1;
	end
   if (cnt_disp == 100000) begin
		cnt_disp <= 0;
		case (disp_pos)
			0: disp_pos <= 1;
			1: disp_pos <= 2;
			2: disp_pos <= 3;
			3: disp_pos <= 0;
		endcase
	end
end

//==================datapath例化==================
logic [31:0] outputreg [4:0];
datapath dp(.CLK(CLK), .reset(reset), .out(outputreg));

always_comb begin
   
    if(
        (outputreg[0] == 32'h0000000e &&
        outputreg[1] == 32'h0000000d &&
        outputreg[2] == 32'h0000000d &&
        outputreg[3] == 32'h0000000f &&
        outputreg[4] == 32'h00000050 ) ||

        (outputreg[4] == 32'h0000000e &&
        outputreg[3] == 32'h0000000d &&
        outputreg[2] == 32'h0000000d &&
        outputreg[1] == 32'h0000000f &&
        outputreg[0] == 32'h00000050 )
    ) // 这里做两种判断是因为懒得去试
    success_led = 1'b1;
    else success_led = 1'b0;
end

//==================display==================
logic [3:0] disp_number, disp_A0, disp_A1, disp_B0, disp_B1;
integer disp_pos = 0;
logic [31:0] ansFinal;
always_comb begin 

    if(T1) begin
        if(T0) ansFinal = outputreg[4];
        else ansFinal = outputreg[3];
    end else begin
        if(T0) ansFinal = outputreg[2];
        else ansFinal = outputreg[1];
    end

    disp_A1 = ansFinal / 1000;
    disp_A0 = ansFinal / 100 - disp_A1 * 10;
    disp_B1 = ansFinal / 10 - disp_A1 * 100 - disp_A0 * 10;
    disp_B0 = ansFinal - disp_A1 * 1000 - disp_A0 * 100 - disp_B1 * 10;

	case (disp_pos)
		0: begin disp_7seg[10:7] = 4'b1110; disp_number = disp_B0; end
		1: begin disp_7seg[10:7] = 4'b1101; disp_number = disp_B1; end
		2: begin disp_7seg[10:7] = 4'b1011; disp_number = disp_A0; end
		3: begin disp_7seg[10:7] = 4'b0111; disp_number = disp_A1; end
		default: begin disp_7seg[10:7] = 4'b0000; disp_number = 0; end
	endcase

    case (disp_number)
        4'd0: disp_7seg[6:0] = 7'b0000001;
        4'd1: disp_7seg[6:0] = 7'b1001111;
        4'd2: disp_7seg[6:0] = 7'b0010010;
        4'd3: disp_7seg[6:0] = 7'b0000110;
        4'd4: disp_7seg[6:0] = 7'b1001100;
        4'd5: disp_7seg[6:0] = 7'b0100100;
        4'd6: disp_7seg[6:0] = 7'b0100000;
        4'd7: disp_7seg[6:0] = 7'b0001111;
        4'd8: disp_7seg[6:0] = 7'b0000000;
        4'd9: disp_7seg[6:0] = 7'b0000100;
        default: disp_7seg[6:0] = 7'b1111111;
    endcase
end

endmodule