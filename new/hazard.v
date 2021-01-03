`timescale 1ns / 1ps

module hazard(
    input   [4:0] rs1_E,
    input   [4:0] rs2_E,
    input   [4:0] rs1_D,
    input   [4:0] rs2_D,
    input   [4:0] rd_M,
    input   [4:0] rd_W,
    input   [4:0] rd_E,
    input   regwrite_W,
    input   regwrite_M,
    input   regwrite_E,
    input   memtoreg_E,
    input   memtoreg_M,
    input   memtoreg_W,
    input   branch_D,
    
    //ALU计算时数据冒险前推
    output  [1:0] forwardA_E,      
    output  [1:0] forwardB_E,

    //分支跳转计算时的数据冒险前推
    output  [1:0] forwardA_D,
    output  [1:0] forwardB_D,

    output  stall_instr_F,
    output  stall_PC,
    output  stall_F_to_D,
    output  flush_D_to_E
    );
    
    // ALU数据前推，检测当前执行指令（E阶段）的 alu_srcA_E 和 rd2_sel_E 是否依赖之前指令的数据（alu_srcB_E 实际上是通过 rd2_sel_E 和 imm 选择得到，imm 不需要前推）
    // 如果之前指令为load指令，可能需要阻塞流水线而无法在此处前推），改变ALU输入前面MUX的输入值
    assign  forwardA_E = ((rs1_E != 5'b0) & (rs1_E == rd_M) & regwrite_M) ? 2'b10:
                        ((rs1_E != 5'b0) & (rs1_E == rd_W) & regwrite_W) ? 2'b01:
                        2'b00;
    assign  forwardB_E = ((rs2_E != 5'b0) & (rs2_E == rd_M) & regwrite_M) ? 2'b10:
                        ((rs2_E != 5'b0) & (rs2_E == rd_W) & regwrite_W) ? 2'b01:
                        2'b00;
    // 分支判断数据前推，检测当前执行指令（D阶段）的两个寄存器读取值是否依赖之前指令的数据（如果之前指令为load指令，需要阻塞流水线而无法在此处前推），改变参与MUX的输入值，由于regfile在clk↓写，故不需要推W阶段
    assign  forwardA_D = (rs1_D != 5'b0) & ((rs1_D == rd_E) & regwrite_E) ? 2'b10:
                        (rs1_D != 5'b0) & ((rs1_D == rd_M) & regwrite_M) ? 2'b01:
                        2'b00;
    assign  forwardB_D =(rs2_D != 5'b0) & ((rs2_D == rd_E) & regwrite_E) ? 2'b10:
                        (rs2_D != 5'b0) & ((rs2_D == rd_M) & regwrite_M) ? 2'b01:
                        2'b00;

    // 前一条指令（E阶段）为load指令时且要写回的reg（rd_E）与下一条指令要参与ALU运算的reg（rs1_D/rs2_D）相同时，暂停流水线，同时还需要将 wd3_W（其实就是经过阻塞一周期后的 mem_rdata_M）前推
    wire    loadstall; 
    assign  loadstall = (((rs1_D == rd_E) | (rs2_D == rd_E)) & memtoreg_E);  

    // 上上条（M阶段）存储器要写回reg的值是分支判断指令的操作数之一时
    // 需要暂停流水线，待下个周期得出结果后再执行分支
    wire    branch_stall;
    assign  branch_stall = (branch_D & memtoreg_M & ((rd_M == rs1_D) | (rd_M == rs2_D)));

    // 上一条（E阶段）存储器要写回reg的值是分支判断指令的操作数之一时
    // 需要暂停流水线两个周期（本设计未考虑这种情况）
    // 编译器需避免出现这样的指令序列或直接插入nop指令
    
    assign  stall_instr_F = loadstall | branch_stall; 
    assign  stall_PC = loadstall | branch_stall;        // 暂停PC   
    assign  stall_F_to_D = loadstall | branch_stall;    // 暂停F/D之间的pipeline_reg     
    assign  flush_D_to_E = loadstall | branch_stall;    // 清空D/E之间的pipeline_reg                      

endmodule
