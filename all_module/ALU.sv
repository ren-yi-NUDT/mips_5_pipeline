module ALU(
    input  logic [2:0]  Control,  // ALU控制信号（来自ALUControlD）
    input  logic [31:0] A, B,     // 两个操作数
    output logic [31:0] ALUOut    // ALU运算结果
);
always_comb begin
    case (Control)
        3'b000: ALUOut = A & B;    // and（and/andi）
        3'b001: ALUOut = A | B;    // or（or/ori）
        3'b010: ALUOut = A + B;    // add（add/addi/lw/sw）
        3'b011: ALUOut = A ^ B;    // xor（xor/xori，新增指令映射）
        3'b100: ALUOut = A & ~B;   // nand（预留）
        3'b101: ALUOut = A | ~B;   // nor（预留）
        3'b110: ALUOut = A - B;    // sub（sub/subi/beq/bne）
        3'b111: ALUOut = {31'b0, A < B}; // slt（slt/slti）
    endcase
end
endmodule