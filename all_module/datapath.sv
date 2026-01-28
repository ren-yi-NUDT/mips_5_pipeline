module datapath(
    input logic CLK, reset,
    output logic[31:0]out[4:0],
    output logic [31:0] PCPlus4F, InstrD, PCBranchD, SrcAD, SrcBD,
    output logic StallF, StallD, FlushE, ForwardAD, ForwardBD, BranchD, PCSrcD
);
//仿真用数据通路

logic RegWriteD, RegWriteE, RegWriteM, RegWriteW;
logic MemtoRegD, MemtoRegE, MemtoRegM, MemtoRegW;
logic MemWriteD, MemWriteE, MemWriteM;
logic [2:0] ALUControlD, ALUControlE;
logic ALUSrcD, ALUSrcE, RegDstD, RegDstE; 
logic BranchEQD, BranchNED;

// ========== 新增：jr指令相关信号 ==========
logic JumpRegD;            // jr指令标识（来自ID模块）
logic [31:0] JRTargetD;    // jr跳转目标地址（来自ID模块）

logic [1:0] ForwardAE, ForwardBE;

logic [31:0] PCPlus4D; 
logic [31:0] RDF, ALUOutE, ALUOutM, ALUOutW, RDM, ReadDataW, ResultW;
logic [31:0] SignImmD, SignImmE, SrcADinE, SrcBDinE;
logic [4:0] RsD, RtD, RdD, RsE, RtE, RdE;
logic [4:0] WriteRegE, WriteRegM, WriteRegW;
logic [31:0] WriteDataE, WriteDataM;


IF IF(
    .CLK(CLK), .StallF(StallF), .reset(reset),
    .PCSrcD(PCSrcD), 
    .JumpRegD(JumpRegD),    // 新增：传入jr指令标识
    .JRTargetD(JRTargetD),  // 新增：传入jr跳转目标地址
    .PCBranchD(PCBranchD), .RDF(RDF), .PCPlus4F(PCPlus4F)
);

ID ID(
    .CLK(~CLK), .RegWriteW(RegWriteW), .ForwardAD(ForwardAD), .ForwardBD(ForwardBD),
    .InstrD(InstrD), .PCPlus4D(PCPlus4D), .WriteRegW(WriteRegW), .ResultW(ResultW),
    .MemtoRegD(MemtoRegD), .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .ALUSrcD(ALUSrcD),
    .RegDstD(RegDstD), .PCSrcD(PCSrcD), .ALUControlD(ALUControlD), .SrcAD(SrcAD),
    .SrcBD(SrcBD), .SignImmD(SignImmD), .PCBranchD(PCBranchD), .out(out), .RsD(RsD),
    .RtD(RtD), .RdD(RdD), .BranchD(BranchD), .ALUOutM(ALUOutM), .BranchEQD(BranchEQD), .BranchNED(BranchNED),
    .JumpRegD(JumpRegD),    // 新增：输出jr指令标识
    .JRTargetD(JRTargetD)   // 新增：输出jr跳转目标地址
);

EX EX(
    .ALUControlE(ALUControlE), .ALUSrcE(ALUSrcE), .RegDstE(RegDstE), .SrcADinE(SrcADinE),
    .SrcBDinE(SrcBDinE), .SignImmE(SignImmE), .RdE(RdE), .RtE(RtE), .ALUOutM(ALUOutM), .ResultW(ResultW),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE), .ALUOutE(ALUOutE), .WriteDataE(WriteDataE), .WriteRegE(WriteRegE)
);

MEM MEM(
    .CLK(CLK), .MemWriteM(MemWriteM), .ALUOutM(ALUOutM), .WriteDataM(WriteDataM),
    .RDM(RDM)
);

WB WB(
    .MemtoRegW(MemtoRegW), .ReadDataW(ReadDataW), .ALUOutW(ALUOutW), .ResultW(ResultW)
);

//reg between IF & ID
always_ff @(posedge CLK) begin
    // jr跳转时需清空ID阶段指令（和分支跳转逻辑一致）
    if (reset || PCSrcD || JumpRegD) begin
        InstrD <= 0;
        PCPlus4D <= 0;
    end else if (!StallD) begin
        InstrD <= RDF;
        PCPlus4D <= PCPlus4F;
    end
end 

//reg between ID & EX
always_ff @(posedge CLK) begin
    if (reset || FlushE) begin 
        {RegWriteE, MemtoRegE, MemWriteE, ALUControlE, ALUSrcE, RegDstE} <= 0;
        SrcADinE <= 0;
        SrcBDinE <= 0;
        SignImmE <= 0;
        RsE <= 0;
        RtE <= 0;
        RdE <= 0;
    end else begin
        {RegWriteE, MemtoRegE, MemWriteE, ALUControlE, ALUSrcE, RegDstE} <= {RegWriteD, MemtoRegD, MemWriteD, ALUControlD, ALUSrcD, RegDstD};
        SrcADinE <= SrcAD;
        SrcBDinE <= SrcBD;
        SignImmE <= SignImmD;
        RsE <= RsD;
        RtE <= RtD;
        RdE <= RdD;
    end
end 

//reg between EX & MEM
always_ff @(posedge CLK) begin
    if (reset) begin
        {RegWriteM, MemtoRegM, MemWriteM} <= 0;
        ALUOutM <= 0;
        WriteDataM <= 0;
        WriteRegM <= 0;
    end else begin
        {RegWriteM, MemtoRegM, MemWriteM} <= {RegWriteE, MemtoRegE, MemWriteE};
        ALUOutM <= ALUOutE;
        WriteDataM <= WriteDataE;
        WriteRegM <= WriteRegE;
    end
end 

//reg between MEM & WB
always_ff @(posedge CLK) begin
    if (reset) begin
        {RegWriteW, MemtoRegW} <= 0;
        ReadDataW <= 0;
        ALUOutW <= 0;
        WriteRegW <= 0;
    end else begin
        {RegWriteW, MemtoRegW} <= {RegWriteM, MemtoRegM};
        ReadDataW <= RDM;
        ALUOutW <= ALUOutM;
        WriteRegW <= WriteRegM;
    end
end 

// ========== 修改：流水线控制逻辑 - 加入JumpRegD处理 ==========
logic lwstall, branchstall;
always_comb begin
    // 前推逻辑（原有，保持不变）
    if ((RsE != 0) && (RsE == WriteRegM) && RegWriteM) ForwardAE = 2'b10;
    else if ((RsE != 0) && (RsE == WriteRegW) && RegWriteW) ForwardAE = 2'b01;
    else ForwardAE = 2'b00;

    if ((RtE != 0) && (RtE == WriteRegM) && RegWriteM) ForwardBE = 2'b10;
    else if ((RtE != 0) && (RtE == WriteRegW) && RegWriteW) ForwardBE = 2'b01;
    else ForwardBE = 2'b00;

    lwstall = ((RsD == RtE) || (RtD == RtE)) && MemtoRegE;

    ForwardAD = (RsD != 0) && (RsD == WriteRegM) && RegWriteM || 
        (RsD != 0) && (RsD == WriteRegE) && RegWriteE;
    ForwardBD = (RtD != 0) && (RtD == WriteRegM) && RegWriteM ||
        (RtD != 0) && (RtD == WriteRegE) && RegWriteE;

    branchstall = (BranchEQD | BranchNED) && RegWriteE && (WriteRegE == RsD || WriteRegE == RtD) 
                || (BranchEQD | BranchNED) && MemtoRegM && (WriteRegM == RsD || WriteRegM == RtD);

    // 新增：jr跳转触发stall（和分支/加载冒险逻辑一致）
    StallF = (lwstall | branchstall | JumpRegD);
    StallD = (lwstall | branchstall | JumpRegD);
    FlushE = (lwstall | branchstall | PCSrcD | JumpRegD);
end 


endmodule