module aludec(
    input  logic[5:0] opcode,  
    input  logic[5:0] funct,   
    output logic[2:0] alucontrol // ALU控制信号（3位）
);

    // ALU控制信号编码定义：
    // 010 = ADD, 110 = SUB, 000 = AND, 001 = OR, 011 = XOR, 111 = SLT
    always_comb
        case(opcode)
            // -------------------- I型指令（直接通过opcode判断） --------------------
            6'b100011: alucontrol = 3'b010;  // lw - 加法（地址计算）
            6'b101011: alucontrol = 3'b010;  // sw - 加法（地址计算）
            6'b001000: alucontrol = 3'b010;  // addi - 加法（立即数）
            6'b000100: alucontrol = 3'b110;  // beq - 减法（比较相等）
            6'b000101: alucontrol = 3'b110;  // bne - 减法（比较不等，ALU操作同beq）
            6'b001100: alucontrol = 3'b000;  // andi - 与运算（立即数）
            6'b001101: alucontrol = 3'b001;  // ori - 或运算（立即数）
            
            // -------------------- R型指令（opcode=000000，需结合funct判断） --------------------
            6'b000000: 
                case(funct)
                    6'b100000: alucontrol = 3'b010; // add - R型加法
                    6'b100010: alucontrol = 3'b110; // sub - R型减法
                    6'b100100: alucontrol = 3'b000; // and - R型与运算
                    6'b100101: alucontrol = 3'b001; // or - R型或运算
                    6'b100110: alucontrol = 3'b011; // xor - R型异或运算
                    6'b101010: alucontrol = 3'b111; // slt - 小于则置位
                    6'b001000: alucontrol = 3'b000; // jr - 无需ALU运算，设为000（避免不定态）
                    default:   alucontrol = 3'bxxx; // 无效R型功能码
                endcase
            
            // -------------------- 无效/未定义指令 --------------------
            default: alucontrol = 3'bxxx;      // 非目标指令，输出未知态
        endcase
endmodule