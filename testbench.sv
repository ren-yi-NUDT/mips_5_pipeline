`timescale 1ns / 1ps

// testbench完全是ai产出的 () 确实比人写的好用一点

module tb_cpu_datapath;
    // ====================== 1. Clock/Reset/Core Signals ======================
    logic         CLK          = 1'b0;
    logic         reset        = 1'b0;
    logic [31:0]  out[4:0];
    // Debug observation signals
    logic [31:0]  PCPlus4F;
    logic [31:0]  InstrD;
    logic [31:0]  PCBranchD;
    logic [31:0]  SrcAD;
    logic [31:0]  SrcBD;
    logic         StallF;
    logic         StallD;
    logic         FlushE;
    logic         ForwardAD;
    logic         ForwardBD;
    logic         BranchD;
    logic         PCSrcD;

    // ====================== 2. Parameter Configuration ======================
    parameter     CLK_PERIOD   = 10;
    parameter     RESET_DUR    = 20;
    parameter     SIM_DUR      = 1000;
    parameter     REG_NUM      = 5;
    // Expected output values
    logic [31:0]  EXPECTED_OUT[0:4] = '{14, 13, 13, 15, 80};

    // ====================== 3. DUT Instantiation ======================
    datapath dp (
        .CLK        (CLK),
        .reset      (reset),
        .out        (out),
        .InstrD     (InstrD),
        .PCPlus4F   (PCPlus4F),
        .StallF     (StallF),
        .StallD     (StallD),
        .FlushE     (FlushE),
        .ForwardAD  (ForwardAD),
        .ForwardBD  (ForwardBD),
        .BranchD    (BranchD),
        .PCSrcD     (PCSrcD),
        .PCBranchD  (PCBranchD),
        .SrcAD      (SrcAD),
        .SrcBD      (SrcBD)
    );

    // ====================== 4. Clock Generation ======================
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // ====================== 5. Reset Sequence ======================
    initial begin
        reset = 1'b1;
        $display("[%0t ns] Starting reset...", $time);
        #RESET_DUR;
        reset = 1'b0;
        $display("[%0t ns] Reset complete, CPU begins execution", $time);
    end


    // ====================== 7. Result Verification & Simulation Termination ======================
    logic test_pass = 1'b1;
    initial begin
        
        #SIM_DUR;

        // 7.1 Print final output results
        $display("\n=====================================");
        $display("CPU Execution Complete - Final Register Output");
        $display("=====================================");
        for(int i=0; i<REG_NUM; i++) begin
            $display("out[%0d] (rf[%0d]) = %h (decimal: %0d) | Expected: %h (decimal: %0d)",
                i, (i==4 ? 7 : i+2), out[i], out[i], EXPECTED_OUT[i], EXPECTED_OUT[i]);
        end

        // 7.2 Automated result check
        for(int i=0; i<REG_NUM; i++) begin
            if(out[i] !== EXPECTED_OUT[i]) begin
                test_pass = 1'b0;
                $error("out[%0d] verification failed! Actual: %0d, Expected: %0d", i, out[i], EXPECTED_OUT[i]);
            end
        end

        // 7.3 Test result summary
        if(test_pass) begin
            $display("\n✅ All tests passed! CPU functional verification successful");
        end else begin
            $display("\n❌ Test failed! Please check datapath/forwarding logic/instruction machine code");
        end

        // 7.4 Terminate simulation
        $display("\n[%0t ns] Simulation ended", $time);
        $finish;
    end

    // ====================== 8. Exception Monitoring ======================
    initial begin
        @(negedge reset);
        forever begin
            @(posedge CLK);
            // Check PC out-of-bounds (RAM max address 28*4=112)
            if(PCPlus4F > 32'h00000070) begin
                $warning("[%0t ns] Warning: PC out-of-bounds! PC+4F = %h", $time, PCPlus4F);
            end
            // Check long stall (possible deadlock)
            if(StallF && StallD) begin
                static int stall_cnt = 0;
                stall_cnt++;
                if(stall_cnt > 10) begin
                    $error("[%0t ns] Error: Stall persists for >10 cycles, CPU deadlock!", $time);
                    $finish;
                end
            end
        end
    end

endmodule


// 自己看仿真用注释的一版，自己写的不心疼，给助教看用上面ai写的就行
// module tb();

// logic CLK=0, reset=0;
// logic[31:0]out[4:0];
// logic [31:0] PCPlus4F = 32'b0, InstrD = 32'b0, PCBranchD, SrcAD, SrcBD;
// logic StallF, StallD, FlushE, ForwardAD, ForwardBD, BranchD, PCSrcD;
// datapath dp(.CLK(CLK), .reset(reset), .out(out), .InstrD(InstrD), .PCPlus4F(PCPlus4F), .StallF(StallF), .StallD(StallD), .FlushE(FlushE), .ForwardAD(ForwardAD), .ForwardBD(ForwardBD), .BranchD(BranchD), .PCSrcD(PCSrcD), .PCBranchD(PCBranchD),
// .SrcAD(SrcAD), .SrcBD(SrcBD)
// );

// initial begin
//     reset = 1;
//     #20;
//     reset = 0;
//     #10;
// end

// always begin
//     CLK = 1; #5;
//     CLK = 0; #5;
// end

// endmodule





