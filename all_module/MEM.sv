module MEM(
    input logic CLK, MemWriteM,
    input logic [31:0] ALUOutM, WriteDataM,
    output logic [31:0] RDM
);

DataMemory Datamem(
    .CLK(CLK),
    .WE(MemWriteM),
    .A(ALUOutM),
    .WD(WriteDataM),
    .RD(RDM)
);

endmodule