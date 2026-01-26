module ID(
    input logic CLK,                  
    input logic RegWriteW,            
    input logic ForwardAD, ForwardBD, 
    input logic [31:0] InstrD,        
    input logic [31:0] PCPlus4D,     
    input logic [4:0] WriteRegW,      
    input logic [31:0] ResultW, ALUOutM, 
    
    output logic RegWriteD,          
    output logic MemtoRegD,           
    output logic MemWriteD,           
    output logic ALUSrcD,             
    output logic RegDstD,            
    output logic PCSrcD,              
    output logic [2:0] ALUControlD,   
    output logic [31:0] SrcAD, SrcBD, 
    output logic [31:0] SignImmD,     
    output logic [31:0] PCBranchD,    
    output logic [31:0] out[4:0],     // regfile的输出
    output logic [4:0] RsD, RtD, RdD, 
    output logic BranchD,             
    output logic BranchNED,          
    output logic BranchEQD, 
    // 输出信号（新增JumpRegD：jr指令标识；JRTargetD：jr跳转目标地址）          
    output logic JumpRegD,            // 新增：标识当前指令为jr（寄存器跳转）
    output logic [31:0] JRTargetD     // 新增：jr跳转目标地址（rs寄存器值）
);

// -------------------- 步骤1：提取指令字段（MIPS标准格式） --------------------
// 指令位分布：[31:26]opcode, [25:21]rs, [20:16]rt, [15:11]rd, [10:6]shamt, [5:0]funct
assign RsD = InstrD[25:21];          // 提取rs寄存器地址（5位）
assign RtD = InstrD[20:16];          // 提取rt寄存器地址（5位）
assign RdD = InstrD[15:11];          // 提取rd寄存器地址（5位）
logic [5:0] OpcodeD;
assign OpcodeD = InstrD[31:26];      // 提取操作码（6位）
logic [5:0] FunctD;
assign FunctD = InstrD[5:0];         // 提取功能码（仅R型指令有效）

// -------------------- 实例化子模块 --------------------
logic [31:0] Rd1, Rd2;  // regfile读端口输出
regfile rf(
    .clk(CLK),
    .we3(RegWriteW),        
    .ra1(RsD),                  
    .ra2(RtD),                     
    .wa3(WriteRegW),            
    .wd3(ResultW),                 
    .rd1(Rd1),                      
    .rd2(Rd2),                      
    .out(out)                      
);


aludec alu_dec(
    .opcode(OpcodeD),
    .funct(FunctD),
    .alucontrol(ALUControlD)
);


assign SignImmD = {{16{InstrD[15]}}, InstrD[15:0]};


assign PCBranchD = PCPlus4D + (SignImmD << 2);

// -------------------- 生成译码阶段控制信号 --------------------
// 基于opcode生成RegWriteD/MemtoRegD/MemWriteD/ALUSrcD/RegDstD
// 覆盖所有目标指令：lw/sw/addi/beq/bne/andi/ori/R型(add/sub/and/or/xor/slt) + jr
always_comb begin
    // 默认值（避免综合器警告，无效指令时保持0）
    RegWriteD = 1'b0;
    MemtoRegD = 1'b0;
    MemWriteD = 1'b0;
    ALUSrcD   = 1'b0;
    RegDstD   = 1'b0;
    BranchD   = 1'b0;  // 标识是否为分支指令（beq/bne）
    BranchNED = 1'b0;  // 新增：默认非bne指令
    BranchEQD = 1'b0;  // 新增：默认非beq指令
    JumpRegD  = 1'b0;  // 新增：默认非jr指令

    case(OpcodeD)
        6'b100011: begin  // lw（加载字）
            RegWriteD = 1'b1;  // 写寄存器
            MemtoRegD = 1'b1;  // 数据来自内存（而非ALU）
            ALUSrcD   = 1'b1;  // ALU源B为立即数（地址计算）
        end
        6'b101011: begin  // sw（存储字）
            MemWriteD = 1'b1;  // 写内存
            ALUSrcD   = 1'b1;  // ALU源B为立即数（地址计算）
        end
        6'b001000: begin  // addi（立即数加法）
            RegWriteD = 1'b1;  // 写寄存器
            ALUSrcD   = 1'b1;  // ALU源B为立即数
        end
        6'b001100: begin  // andi（立即数与）
            RegWriteD = 1'b1;  // 写寄存器
            ALUSrcD   = 1'b1;  // ALU源B为立即数
        end
        6'b001101: begin  // ori（立即数或）
            RegWriteD = 1'b1;  // 写寄存器
            ALUSrcD   = 1'b1;  // ALU源B为立即数
        end
        6'b000100: begin  // beq（相等分支）
            BranchD   = 1'b1;  // 标识为分支指令
            BranchEQD = 1'b1;  // 新增：标识为beq指令
        end
        6'b000101: begin  // bne（不等分支）
            BranchD   = 1'b1;  // 标识为分支指令
            BranchNED = 1'b1;  // 新增：标识为bne指令
        end
        6'b000000: begin  // R型指令（add/sub/and/or/xor/slt + jr）
            // 判断是否为jr指令（funct=001000）
            if (FunctD == 6'b001000) begin
                JumpRegD  = 1'b1;  // 标识为jr指令
                RegWriteD = 1'b0;  // jr不写寄存器
            end else begin
                RegWriteD = 1'b1;  // 其他R型指令写寄存器
                RegDstD   = 1'b1;  // 写rd寄存器（而非rt）
            end
            // ALUSrcD=0：ALU源B为寄存器rd2（非立即数）
        end
        default: ;        // 无效指令，控制信号保持默认
    endcase
end


assign SrcAD = ForwardAD ? ALUOutM : Rd1;
assign SrcBD = ForwardBD ? ALUOutM : Rd2;

// 新增：jr跳转目标地址 = 处理转发后的rs寄存器值（SrcAD）
assign JRTargetD = SrcAD;

// -------------------- 生成分支选择信号PCSrcD --------------------
// PCSrcD=1表示触发分支跳转：beq（SrcAD==SrcBD）或bne（SrcAD!=SrcBD）
always_comb begin
    PCSrcD = 1'b0;  // 默认不跳转
    if (BranchD) begin  // 仅分支指令才判断是否跳转
        if (BranchEQD) begin  // 新增：直接用BranchEQD判断beq，更直观
            PCSrcD = (SrcAD == SrcBD) ? 1'b1 : 1'b0;
        end else if (BranchNED) begin  // 新增：直接用BranchNED判断bne
            PCSrcD = (SrcAD != SrcBD) ? 1'b1 : 1'b0;
        end
    end
end

endmodule