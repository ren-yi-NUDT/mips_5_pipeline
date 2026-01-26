module DataMemory(
    input  logic        CLK,
    input  logic        WE,
    input  logic [31:0] A,
    input  logic [31:0] WD,
    output logic [31:0] RD
);

logic [31:0] mem [0:63]; // 64个字（256字节）

initial for (int i=0; i<64; i++) mem[i] = 32'b0;

always_ff @(posedge CLK) begin
    if (WE) mem[A[31:2]] <= WD; 
end

assign RD = mem[A[31:2]];

endmodule