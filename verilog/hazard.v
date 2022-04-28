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

    input   jump_E,
    input   branch_E,           
    input   predict_en_E,
    input   branch_h_E,
    
    // ALU 计算时数据冒险前推
    output  [1:0] forwardA_E,      
    output  [1:0] forwardB_E,

    // stall & flush
    output  loadstall,
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
    // // 分支判断数据前推，检测当前执行指令（D阶段）的两个寄存器读取值是否依赖之前指令的数据（如果之前指令为load指令，需要阻塞流水线而无法在此处前推），改变参与MUX的输入值，由于regfile在clk↓写，故不需要推W阶段
    // assign  forwardA_D = (rs1_D != 5'b0) & ((rs1_D == rd_E) & regwrite_E) ? 2'b10:
    //                     (rs1_D != 5'b0) & ((rs1_D == rd_M) & regwrite_M) ? 2'b01:
    //                     2'b00;
    // assign  forwardB_D =(rs2_D != 5'b0) & ((rs2_D == rd_E) & regwrite_E) ? 2'b10:
    //                     (rs2_D != 5'b0) & ((rs2_D == rd_M) & regwrite_M) ? 2'b01:
    //                     2'b00;

    // 前一条指令（E阶段）为 load 指令时且要写回的 reg (rd_E) 与下一条指令所需 reg (rs1_D/rs2_D) 相同时，暂停流水线，同时还需要将 wd3_W (mem_rdata_W) 前推
    // 需要 stall 的流水线为 pc / F->D
    // 因为阻塞了 F/D 流水线，导致 E 被空出来，故需要 flush 的流水线为 D->E
    wire    flush_load;
    assign  loadstall = (((rs1_D == rd_E) | (rs2_D == rd_E)) & memtoreg_E);  
    assign  flush_load = (((rs1_D == rd_E) | (rs2_D == rd_E)) & memtoreg_E);

    // 前一条指令（E阶段）为 branch 指令，预测分支不发生但发生，或预测发生但分支但未发生，或为 jal/jalr 指令跳转，
    // 需通过 pcsrc_E 修正 pc_inst_ram_F，并清空此刻 D 阶段的错误指令
    // 需要 flush 的流水线为 D->E
    wire    predict_error_E;
    wire    flush_b_j;
    assign  predict_error_E = ((predict_en_E == 1'b0) & (branch_h_E == 1'b1)) | ((predict_en_E == 1'b1) & (branch_h_E == 1'b0));
    assign  flush_b_j = (branch_E & predict_error_E) | jump_E;

    assign  flush_D_to_E = flush_load | flush_b_j;

endmodule
