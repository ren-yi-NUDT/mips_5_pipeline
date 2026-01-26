module EX(
    input logic [2:0] ALUControlE, 
    input logic ALUSrcE, RegDstE,
    input logic [31:0] SrcADinE, SrcBDinE, SignImmE,
    input logic [4:0] RdE, RtE,
    input logic [31:0] ALUOutM, ResultW,
    input logic [1:0] ForwardAE, ForwardBE,
    output logic [31:0] ALUOutE, WriteDataE,
    output logic [4:0] WriteRegE
);

logic [31:0] SrcAE, SrcBE;


always_comb begin
    // 第一步：初始化所有信号（杜绝不定态）
    SrcAE = SrcADinE;
    WriteDataE = SrcBDinE;
    WriteRegE = 5'b0;
    SrcBE = 32'b0;

    // 第二步：处理写寄存器地址选择（RegDstE）
    WriteRegE = RegDstE ? RdE : RtE;
    // 强制$0规范：写$0无效，兜底置0
    if (WriteRegE == 5'b0) WriteRegE = 5'b0;

    // 第三步：处理SrcAE前推（ALU第一个操作数，符合MIPS前推规则）
    case(ForwardAE)
        2'b00: SrcAE = SrcADinE;   // 无转发
        2'b01: SrcAE = ResultW;    // 转发WB阶段数据
        2'b10: SrcAE = ALUOutM;    // 转发MEM阶段数据
        2'b11: SrcAE = SrcADinE;   // 无效编码，默认无转发
    endcase

    // 第四步：处理WriteDataE前推（sw指令写内存数据）
    case(ForwardBE)
        2'b00: WriteDataE = SrcBDinE;  // 无转发
        2'b01: WriteDataE = ResultW;   // 转发WB阶段数据
        2'b10: WriteDataE = ALUOutM;   // 转发MEM阶段数据
        2'b11: WriteDataE = SrcBDinE;  // 无效编码，默认无转发
    endcase

    // 第五步：选择ALU第二个操作数（立即数/寄存器数据）
    SrcBE = ALUSrcE ? SignImmE : WriteDataE;
end

ALU ALU(
    .Control(ALUControlE),
    .A(SrcAE),
    .B(SrcBE),
    .ALUOut(ALUOutE)
);

endmodule
