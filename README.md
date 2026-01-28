# mips_5_pipeline

## Overview
 
实现了一个5级流水线的MIPS处理器，可以通过Forwarding-Stall-Flush处理冲突

支持的指令包括： lw、sw、beq、addi、add、sub、and、or、slt、bne、andi、ori、xor、xori、jr

如果需要其他的指令可以自行修改添加

all_module文件夹可直接放入Xilinx Vivado中进行综合、实现、仿真；structure文件夹按逻辑对模块进行了分类，方便查看和修改

注意testbench.sv需设置为simulation only

- 当需要上板验证时，加上top模块，并将IF模块改为无pc限位版

- 当不需要上板验证、只需要仿真波形时，将top模块去掉，将IF模块改为pc限位版


## 结构

参照课本上原图进行设计，另为执行jr添加了新的控制信号，具体改动已做标识

<img width="1595" height="886" alt="流水线mips处理器" src="https://github.com/user-attachments/assets/76924e64-822c-472a-a308-f61fdf745b98" />

注意：设计过程中发现mips流水线的stall/flush逻辑会使得无法用 `beq $0, $0, -1`类似指令实现程序终止，需设置超限返回空指令逻辑


各模块分开设计，共IF、ID、EX、MEM、WB五个模块，使用datapath对各模块进行连接并处理冲突，top上板用，tb仿真用

另外单独设计了寄存器，数据存储器，指令存储器，ALUdec四个子模块，子模块均可复用

## 测试指令集
 ```
    32'h2002000A,  // RAM[0]：addi $2, $0, 10  → $2=10（out[0]）
    32'h20030003,  // RAM[1]：addi $3, $0, 3   → $3=3（out[1]）
    32'h20040000,  // RAM[2]：addi $4, $0, 0   → $4=0（out[2]）
    32'h20050000,  // RAM[3]：addi $5, $0, 0   → $5=0（out[3]）
    32'h20070050,  // RAM[4]：addi $7, $0, 80  → $7=80（jr跳转至RAM[20]，80/4=20）
    32'h00431020,  // RAM[5]：add $2, $2, $3   → $2=10+3=13
    32'h00431822,  // RAM[6]：sub $3, $2, $3   → $3=13-3=10
    32'h00432024,  // RAM[7]：and $4, $2, $3   → $4=13&10=8
    32'h00432825,  // RAM[8]：or  $5, $2, $3   → $5=13|10=15
    32'h00852026,  // RAM[9]：xor $4, $4, $5   → $4=8^15=7
    32'h0043382A,  // RAM[10]：slt $7, $2, $3  → $7=0（13<10不成立）
    32'h3044000F,  // RAM[11]：andi $4, $2, 15 → $4=13&15=13
    32'h3465000F,  // RAM[12]：ori $5, $3, 15  → $5=10|15=15
    32'hAC020000,  // RAM[13]：sw $2, 0($0)    → 存储$2=13到地址0
    32'h8C030000,  // RAM[14]：lw $3, 0($0)    → 加载13到$3
    32'h10430001,  // RAM[15]：beq $2,$3,1     → 偏移量1，跳转至RAM[17]（正确计算）
    32'h14470000,  // RAM[16]：bne $2,$7,0     → $2=13≠$7=0，不跳转
    32'h20420001,  // RAM[17]：addi $2, $2, 1  → $2=14（跳转后执行）
    32'h20070050,  // RAM[18]：addi $7, $0, 80 → $7=80（RAM[20]=80/4=20）
    32'h00E00008,  // RAM[19]：jr $7          → 跳转到RAM[20]（多跳1行，无越界）
    32'h00000000   // RAM[20]：nop            → 程序正常结束
```

## 冲突解决逻辑

#### -- 逻辑推导

这里实现的流水线mips处理器通过重定向（`Forwarding`）解决`RAW`数据冲突，通过`Stall`/`Flush`解决`lw`的周期延迟与分支跳转产生的控制冲突，但是没有做分支预测，导致处理一个lw需要额外1周期/气泡，处理一个分支指令需要额外2周期/气泡，一个jump需要额外1周期/气泡


| 指令组合场景                | 无转发/无预测 气泡数 | 有转发/无预测 气泡数 | 核心判定依据（备注）|
|-----------------------------|----------------------|----------------------|-------------------------------------------|
| lw + 依赖ALU指令            | 1                    | 1                    | lw需M段取数，依赖指令E段需数，转发无解，必插1泡 |
| lw + 依赖branch指令         | 2                    | 2                    | 1泡等lw数据就绪，1泡为branch本身控制冲突，叠加共2泡 |
| lw + 依赖jump指令           | 1                    | 1                    | 仅需1泡等lw数据，jump在D段判定，无额外控制冲突开销 |
| ALU指令 + 依赖ALU指令       | 2                    | 0                    | 无转发数据晚2拍需2泡，有转发直接传E段，无需气泡 |
| ALU指令 + 依赖branch指令    | 2                    | 1                    | 转发消除1个数据冲突泡，保留branch本身1个控制冲突泡 |
| 普通branch指令（无依赖）    | 2                    | 2                    | branch需E段判定，冲刷F/D段预取指令，固定2泡 |
| 普通jump指令（无依赖）      | 1                    | 1                    | jump在D段判定，仅冲刷F段预取指令，固定1泡 |



#### -- 涉及代码

```
always_comb begin
    if ((RsE != 0) && (RsE == WriteRegM) && RegWriteM) ForwardAE = 2'b10;
    else if ((RsE != 0) && (RsE == WriteRegW) && RegWriteW) ForwardAE = 2'b01;
    else ForwardAE = 2'b00;

    if ((RtE != 0) && (RtE == WriteRegM) && RegWriteM) ForwardBE = 2'b10;
    else if ((RtE != 0) && (RtE == WriteRegW) && RegWriteW) ForwardBE = 2'b01;
    else ForwardBE = 2'b00;

    lwstall = ((RsD == RtE) || (RtD == RtE)) && MemtoRegE;

    ForwardAD = (RsD != 0) && (RsD == WriteRegM) && RegWriteM;
    ForwardBD = (RtD != 0) && (RtD == WriteRegM) && RegWriteM;

    branchstall = (BranchEQD | BranchNED) && RegWriteE && (WriteRegE == RsD || WriteRegE == RtD) 
                || (BranchEQD | BranchNED) && MemtoRegM && (WriteRegM == RsD || WriteRegM == RtD);

    StallF = (lwstall | branchstall | JumpRegD);
    StallD = (lwstall | branchstall | JumpRegD);
    FlushE = (lwstall | branchstall | JumpRegD);

    //注意，这里与课本上的不同在于加了Jump判断

end 
```

## 仿真波形解读示例

<img width="1263" height="871" alt="image" src="https://github.com/user-attachments/assets/f4ee48eb-3e20-4d85-b930-832236a4bb88" />

<img width="1263" height="871" alt="波形解读" src="https://github.com/user-attachments/assets/348db039-d0d0-424f-8da9-cdde06ff274e" />








