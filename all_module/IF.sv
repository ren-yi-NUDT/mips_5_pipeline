module IF(
    input logic CLK, StallF, reset,
    input logic PCSrcD,
    input logic JumpRegD,            // 新增：jr指令标识
    input logic [31:0] PCBranchD,
    input logic [31:0] JRTargetD,    // 新增：jr跳转目标地址（rs寄存器值）
    output logic [31:0] RDF, PCPlus4F
);

logic [31:0] PCC, PCF;

always_ff @(posedge CLK) begin
    if(reset) PCF <= 32'b0;
    else if (!StallF) PCF <= PCC;
end

assign PCPlus4F = PCF + 4;

// PC选择逻辑 - 优先响应jr跳转，再处理分支跳转，最后PC+4
assign PCC = JumpRegD ? JRTargetD : (PCSrcD ? PCBranchD : PCPlus4F);

imem InstructionMem(PCF[7:2], RDF);

endmodule


// 仿真使用下面的一版，上面的一版没做pc限位，会重复执行指令序列，适合上板展示
// module IF(
//     input logic CLK, StallF, reset,
//     input logic PCSrcD,
//     input logic JumpRegD,            // 新增：jr指令标识
//     input logic [31:0] PCBranchD,
//     input logic [31:0] JRTargetD,    // 新增：jr跳转目标地址（rs寄存器值）
//     output logic [31:0] RDF, PCPlus4F
// );

// logic [31:0] PCC, PCF;
// logic [5:0]  PCFetch;
// always_ff @(posedge CLK) begin
//     if(reset) PCF <= 32'b0;
//     else if (!StallF) PCF <= PCC;
// end

// assign PCPlus4F = PCF + 4;

// // PC选择逻辑 - 优先响应jr跳转，再处理分支跳转，最后PC+4
// assign PCC = JumpRegD ? JRTargetD : (PCSrcD ? PCBranchD : PCPlus4F);
// assign PCFetch = (PCF >= 32'd80) ? 6'd20 : PCF[7:2];

// imem InstructionMem(PCFetch, RDF);

// endmodule