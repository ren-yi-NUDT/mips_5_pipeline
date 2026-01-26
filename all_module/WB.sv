module WB(
    input logic MemtoRegW,
    input logic [31:0] ReadDataW, ALUOutW,
    output logic [31:0] ResultW
);

assign ResultW = MemtoRegW ? ReadDataW : ALUOutW;

endmodule