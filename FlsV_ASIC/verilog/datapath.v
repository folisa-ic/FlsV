`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////
// MIPS基本指令分类

// 1. I-Type
// opcode[31:26] rs[25:21] rt[20:16] Imm[15:0]
// 在load&store指令中rs作为地址基址reg，rt作为写回/读取reg，Imm作为offset
// 在Imm运算指令中，将rs与Imm（符号扩展后）进行运算，结果写回rt

// 2. J-Type
// opcode[31:26] Imm[25:0]

// 3. R-Type
// opcode[31:26] rs[25:21] rt[20:16] rd[15:11] sa[10:6] funct[5:0]



//////////////////////////////////////////////////////////////////////////
// RISCV基本指令集分类

// 1. I-Type
// Imm[31:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]
// 立即数与rs1寄存器内的值做算术运算 & load指令；

// 2. R-Type
// funct7[31:25] rs2[24:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]

// 3. S-Type
// Imm[31:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[11:7] opcode[6:0]
// store指令

// 4. B-Type
// Imm[31:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[11:7] opcode[6:0]
// 分支跳转指令

// 5. U-Type
// imm[31:12] rd[11:7] opcode[6:0]
// 长立即数指令

// 6. J-Type
// imm[31:12] rd[11:7] opcode[6:0]
// 无条件分支跳转


// 注意：RISCV指令集的imm构成较为复杂，具体请对照imm.png
// 全部的reg操作数顺序及名字都需要替换，工作量较大且容易出错

module datapath(
    input   clk,
    input   rst,
    input   jump_D, regwrite_W, regwrite_M, regwrite_E, load_imm_E, alusrc, branch_D, memtoreg_W, memtoreg_M, memtoreg_E,
    input   [2:0]   sub_control_D,
    input   [2:0]   alucontrol_E,
    input   [2:0]   immcontrol_D,
    input   [31:0]  instr_F,         
    input   [31:0]  mem_rdata_M,      
    output  [31:0]  pc_inst_ram_F, 
    output  [31:0]  alu_result_M,   
    output  [31:0]  mem_wdata_M,
    output  stall_instr_F,
    output  stall_PC,
    output  stall_F_to_D,
    output  flush_D_to_E,
    output  flush_F_to_D
    );

    // 在Execute阶段生成的信号，作为Decode阶段的输入，需要声明在Decode模块之前
    wire [31:0]  alu_result_E;
    
    // Decode 阶段需要使用到 pc_inst_ram_E，提前声明
    wire [31:0]  pc_inst_ram_E;            // branch 和 jump 指令需要用到 

    // 在Writeback阶段生成的信号，作为Decode阶段的输入，需要声明在Decode模块之前
    wire [4:0]  rd_W;
    wire [31:0] wd3_W;              // 从mem_rdata和alu_result中选出作为写回regfile的数据
    wire [31:0] pc_branch_D;
    wire [31:0] pc_jump_D;

    //////////////////////////////////////////////////////////////////////////
    // Fetch
    wire [31:0] pc_F;               // 顺序读取的指令地址
    wire [31:0] pc_plus4_F;         // inst_ram中的下一条指令地址
    wire [31:0] pc_branch_predict_F;// 分支预测指令地址
    wire [31:0] pc_b_j_p_F;         // 和 pc_branch_predict_F 再次选出最终的 pc_inst_ram_F
    wire [1:0]  pcsrc_D;            // pc_b_j_p_F 选择信号

    wire        next_branch_h;      // 预测分支是否发生
    wire        branch_F;           // 动态分支预测需要在 Fetch 阶段判断出该指令是否为分支指令
    wire        branch_h_D;         // 表示分支指令存在并分支发生（在 D 阶段被译码后可知，提前声明）
    wire        predict_en_F;       // 表示在 Fetch 阶段的 instr_F 为分支指令且预测分支发生


    reg  [31:0] pc_branch_plus_4;   // 分支预测指令的下一条指令，当分支预测失败时赋值给 pc_inst_ram_F 
    always @(posedge clk) begin
      if(rst) pc_branch_plus_4 <= 32'b0;
      else if(branch_h_D) pc_branch_plus_4 <= pc_inst_ram_E + 32'd4;
      else pc_branch_plus_4 <= pc_branch_plus_4;
    end

    pc              uut_pc(       
      .clk          (clk),
      .rst          (rst),
      .en           (~stall_PC),    // 暂停流水线信号，高电平有效故取反
      .din          (pc_plus4_F),
      .q            (pc_F)
    );

    adder           uut_pc_plus4_F(
      .a            (pc_inst_ram_F), 
      .b            (32'd4),             
      .y            (pc_plus4_F)
    );

    // mux_3 for next instruction
    mux_4 #(32)     uut_mux_4_next_instr(
      .d0           (pc_branch_D),      // 2'b00  
      .d1           (pc_jump_D),        // 2'b01
      .d2           (pc_F),             // 2'b10
      .d3           (pc_branch_plus_4), // 2'b11
      .s            (pcsrc_D),      
      .y            (pc_b_j_p_F)        
    );

    // 在 Fetch 阶段对 instr_F 判断，若为分支指令，且分支预测机预测为分支发生，则直接将 pc_branch_predict_F 赋值给 pc_inst_ram_F
    // 故需要在 Fetch 阶段对 instr_F 进行简单的初步译码
    assign branch_F = (instr_F[6:0] == 7'b1100011);
    assign predict_en_F = branch_F & next_branch_h;
    assign pc_inst_ram_F = (predict_en_F == 1'b1) ? pc_branch_predict_F : pc_b_j_p_F;
    

    //////////////////////////////////////////////////////////////////////////
    // Decode    

    wire        predict_en_D;             // 若 F 阶段预测分支发生，则需要传递至 D 阶段挡住 pcsrc_D 的作用
    wire        predict_correct_D;        // 当分支指令预测发生且实际上分支发生时，置 1
    wire        predict_error_D;          // 当分支指令预测发生且实际上分支不发生时，置 1
    wire [31:0] instr_D;
    wire [31:0] pc_inst_ram_D; 
    wire [31:0] pc_inst_ram_plus4_D;      // JAL指令需要用到 
    wire [4:0]  rs1_D, rs2_D, rd_D;
    wire [31:0] rd1_D;                    // 从regfile读取的rs1
    wire [31:0] rd2_D;                    // 从regfile读取的rs2
    wire [31:0] imm_extend_Itype_D;       // Itype指令中被扩展后的imm
    wire [31:0] imm_extend_Stype_D;       // Stype指令中被扩展后的imm
    wire [31:0] imm_extend_Btype_D;       // Btype指令中被扩展后的imm
    wire [31:0] imm_extend_Utype_D;       // Utype指令中被扩展后的imm
    wire [31:0] imm_extend_Jtype_D;       // Jtype指令中被扩展后的imm

    // wire [31:0] imm_extend_ls2_D;      // 被扩展后并左移2位的imm，通常用于branch指令
    wire [31:0] eq_srcA_D;
    wire [31:0] eq_srcB_D;
    wire        equal_D;                  // 判断 BEQ 条件分支跳转指令是否发生
    wire        not_equal_D;              // 判断 BNE 条件分支跳转指令是否发生
    wire [1:0]  forwardA_D;
    wire [1:0]  forwardB_D;

    assign rs1_D = instr_D[19:15];
    assign rs2_D = instr_D[24:20];
    assign rd_D = instr_D[11:7];

    flopenrc #(1)      uut_predict_en_D(
      .clk             (clk),
      .rst             (rst),
      .clear           (flush_F_to_D),
      .en              (~stall_F_to_D),
      .d               (predict_en_F),
      .q               (predict_en_D)
    );   
    flopenrc #(32)     uut_instr_D(
      .clk             (clk),
      .rst             (rst),
      .clear           (flush_F_to_D),
      .en              (~stall_F_to_D),
      .d               (instr_F),
      .q               (instr_D)
    );    
    flopenrc #(32)     uut_pc_inst_ram_D(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (pc_inst_ram_F),
      .q               (pc_inst_ram_D)
    );

    // 仅是放在了Decode阶段，实际上写回阶段也是在这里发生的
    regfile            uut_regfile(
      .clk             (clk),
      .rst             (rst),
      .we3             (regwrite_W),          
      .ra1             (instr_D[19:15]),      // rs1地址
      .ra2             (instr_D[24:20]),      // rs2地址            
      .wa3             (rd_W),         
      .wd3             (wd3_W),               // 写回regfile的数据
      .rd1             (rd1_D),               // 读出的rs1数据
      .rd2             (rd2_D)                // 读出的rs2数据   
    );
  
    mux_3 #(32)       uut_mux_3_eq_srcA(
	    .d0             (rd1_D),
	    .d1             (alu_result_M),
	    .d2             (alu_result_E),
	    .s              (forwardA_D),
	    .y              (eq_srcA_D)
    );

    mux_3 #(32)       uut_mux_3_eq_srcB(
	    .d0             (rd2_D),
	    .d1             (alu_result_M),
	    .d2             (alu_result_E),
	    .s              (forwardB_D),
	    .y              (eq_srcB_D)
    );
    
    assign equal_D = (eq_srcA_D == eq_srcB_D) & (sub_control_D == 3'b000);
    assign not_equal_D = (eq_srcA_D != eq_srcB_D) & (sub_control_D == 3'b001);
    assign branch_h_D = (equal_D | not_equal_D) & branch_D;
    assign predict_error_D = (branch_h_D == 1'b0) & (predict_en_D == 1'b1);
    assign predict_correct_D = (branch_h_D == 1'b1) & (predict_en_D == 1'b1);
    
    assign pcsrc_D = (predict_error_D == 1'b1) ? 2'b11 : (predict_correct_D == 1'b1) ? 2'b10 : (jump_D == 1'b1) ? 2'b01 : (branch_h_D == 1'b1) ? 2'b00 : 2'b10;
    assign flush_F_to_D = ((pcsrc_D[1] == 1'b0) | (predict_error_D == 1'b1));

    // 当进入 B_H 状态时，分支将一直发生，直到分支预测失败，此时需要仿照静态分支预测去清空流水线

    //对I-type指令的imm进行符号扩展
    signed_extend #(12)   uut_signed_extend_Itype_D(
      .a                  (instr_D[31:20]),                   // imm
      .y                  (imm_extend_Itype_D)                // 被符号扩展后的32-bit imm
    );

    //对S-type指令的imm进行符号扩展
    signed_extend #(12)   uut_signed_extend_Stype_D(
      .a                  ({instr_D[31:25], instr_D[11:7]}),  // imm
      .y                  (imm_extend_Stype_D)                // 被符号扩展后的32-bit imm
    );

    //对B-type指令的imm进行符号扩展
    signed_extend #(13)   uut_signed_extend_Btype_D(
      .a                  ({instr_D[31], instr_D[7], instr_D[30:25], instr_D[11:8], 1'b0}),          // 不需扩展到word寻址，结尾的0已经自动扩展到half_word寻址
      .y                  (imm_extend_Btype_D)                // 被符号扩展后的32-bit imm
    );

    //对U-type指令的imm的低位进行补零
    assign imm_extend_Utype_D = {instr_D[31:12], {12{1'b0}}}; // 注意：如果把 {12{1'b0}} 写成 {12{0}} 是错误的，必须写明位数，否则整个 imm_extend_Utype_D 都是0

    //对J-type指令的imm的低位进行补零并符号扩展
    signed_extend #(21)   uut_signed_extend_Jtype_D(
      .a                  ({instr_D[31], instr_D[19:12], instr_D[20], instr_D[30:25], instr_D[24:21], 1'b0}),          // 不需扩展到word寻址，结尾的0已经自动扩展到half_word寻址
      .y                  (imm_extend_Jtype_D)                // 被符号扩展后的32-bit imm
    );

    //pc_branch_D
    adder             uut_pc_branch_D(
      .a              (pc_inst_ram_E),          // 注意是pc_inst_ram_E
      .b              (imm_extend_Btype_D),       
      .y              (pc_branch_D)
    );

    //pc_jump_D
    adder             uut_pc_jump_D(
      .a              (pc_inst_ram_E),          // 注意是pc_inst_ram_E
      .b              (imm_extend_Jtype_D),       
      .y              (pc_jump_D)
    );

    //J型指令中的JAL需要将pc+4赋值给rd，所以需要获得当前指令的pc值（即pc_inst_ram_E）并+4传递至W阶段
    adder             uut_pc_inst_ram_plus4_D(
      .a              (pc_inst_ram_E),         
      .b              (32'd4),       
      .y              (pc_inst_ram_plus4_D)
    );

    //////////////////////////////////////////////////////////////////////////
    // Execute

    wire [31:0] rd1_E;
    wire [31:0] rd2_E;
    wire [4:0]  rs1_E, rs2_E, rd_E;  
    wire [4:0]  rd_M;                 // hazard需使用，故将声明移到Execute阶段
    wire [31:0] pc_inst_ram_plus4_E;
    wire        jump_E;
    wire [2:0]  immcontrol_E; 
    wire [31:0] imm_extend_Itype_E;
    wire [31:0] imm_extend_Stype_E;  
    wire [31:0] imm_extend_Btype_E;  
    wire [31:0] imm_extend_Utype_E;  
    wire [31:0] imm_extend_Jtype_E;   
    wire [31:0] imm_extend_E;
    wire [31:0] alu_srcB_E;           // 从Imm和rd2(rs2的数据)中选出作为alu_srcB的输入
    
    flopenrc #(32)    uut_rd1_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd1_D),
      .q              (rd1_E)
    );
    flopenrc #(32)    uut_rd2_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd2_D),
      .q              (rd2_E)
    );
    flopenrc #(5)     uut_rs1_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rs1_D),
      .q              (rs1_E)
    );
    flopenrc #(5)     uut_rs2_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rs2_D),
      .q              (rs2_E)
    );
    flopenrc #(5)     uut_rd_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd_D),
      .q              (rd_E)
    );
    flopenrc #(3)     uut_immcontrol_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (immcontrol_D),
      .q              (immcontrol_E)
    );
    flopenrc #(32)    uut_signed_extend_Itype_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Itype_D),
      .q              (imm_extend_Itype_E)
    );
    flopenrc #(32)    uut_signed_extend_Stype_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Stype_D),
      .q              (imm_extend_Stype_E)
    );
    flopenrc #(32)    uut_signed_extend_Btype_E(    // Execute阶段已不需要，为整齐而保留
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Btype_D),
      .q              (imm_extend_Btype_E)
    );
    flopenrc #(32)    uut_signed_extend_Utype_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Utype_D),
      .q              (imm_extend_Utype_E)
    );
    flopenrc #(32)    uut_signed_extend_Jtype_E(    // Execute阶段已不需要，为整齐而保留
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Jtype_D),
      .q              (imm_extend_Jtype_E)
    );
    flopenrc #(32)     uut_pc_inst_ram_E(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (pc_inst_ram_D),
      .q               (pc_inst_ram_E)
    );
    flopenrc #(32)     uut_pc_inst_ram_plus4_E(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (pc_inst_ram_plus4_D),
      .q               (pc_inst_ram_plus4_E)
    );
    flopenrc #(1)      uut_jump_E(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (jump_D),
      .q               (jump_E)
    );

    wire [31:0] alu_srcA_E;
    wire [31:0] rd2_sel_E;
    wire [1:0]  forwardA_E;
    wire [1:0]  forwardB_E;

    //数据冲突检测，原则上独立于数据通路，写在Execute仅表示关系较大
    hazard            uut_hazard_unit(
      .rs1_E          (rs1_E),
      .rs2_E          (rs2_E),
      .rs1_D          (rs1_D),
      .rs2_D          (rs2_D),
      .rd_M           (rd_M),
      .rd_W           (rd_W),
      .rd_E           (rd_E),
      .regwrite_W     (regwrite_W),
      .regwrite_M     (regwrite_M),
      .regwrite_E     (regwrite_E),
      .memtoreg_E     (memtoreg_E),
      .memtoreg_M     (memtoreg_M),
      .memtoreg_W     (memtoreg_W),
      .branch_D       (branch_D),
      .forwardA_E     (forwardA_E),
      .forwardB_E     (forwardB_E),
      .forwardA_D     (forwardA_D),
      .forwardB_D     (forwardB_D),
      .stall_instr_F  (stall_instr_F),
      .stall_PC       (stall_PC),
      .stall_F_to_D   (stall_F_to_D),
      .flush_D_to_E   (flush_D_to_E)
    );

    //前推3*1MUX
    mux_3 #(32)       uut_mux_3_srcA(
	    .d0             (rd1_E),
	    .d1             (wd3_W),
	    .d2             (alu_result_M),
	    .s              (forwardA_E),
	    .y              (alu_srcA_E)
    );

    mux_3 #(32)       uut_mux_3_srcB(
	    .d0             (rd2_E),
	    .d1             (wd3_W),
	    .d2             (alu_result_M),
	    .s              (forwardB_E),
	    .y              (rd2_sel_E)
    );

    //mux_5 for imm_extend_E
    //从  imm_extend_Itype_D
    //    imm_extend_Stype_D
    //    imm_extend_Btype_D
    //    imm_extend_Utype_D
    //    imm_extend_Jtype_D
    //中选择需要的imm    
    mux_5 #(32)       uut_mux_5_imm_extend_E(
      .d0             (imm_extend_Itype_E),        
      .d1             (imm_extend_Stype_E),
      .d2             (imm_extend_Btype_E),
      .d3             (imm_extend_Utype_E),
      .d4             (imm_extend_Jtype_E),
      .s              (immcontrol_E),                   
      .y              (imm_extend_E)
    );
    
    
    //mux_2 for alu_srcB
    //从被扩展的Imm和rd2(rs2的数据)中选择一个作为alu_srcB的输入
    mux_2 #(32)       uut_mux_2_alu_srcB(
      .a              (imm_extend_E),        
      .b              (rd2_sel_E),
      .s              (alusrc),        
      .y              (alu_srcB_E)
    );

    alu               uut_alu(
      .a              (alu_srcA_E),               
      .b              (alu_srcB_E),
      .alucontrol     (alucontrol_E),                  
      .s              (alu_result_E),
      .zero           (),
      .overflow       ()
    );

    /*
    //mux_2 for regfile_wa3
    //从rt_E和rd_E中选择一个作为写回regfile的地址，注意区分rd/rt是地址，rd1/rd2是数据
    mux_2 #(5)        uut_mux_2_regfile_wa3(
      .a              (rd_E),         // rd for R-Type，待后续更换为instr_D
      .b              (rt_E),         // rt for I-Type，待后续更换为instr_D
      .s              (load_imm_E),   
      .y              (write2reg_E)
    );
    // 本段代码无意义故注释，RISCV不需要选择rt/rd作为写回reg，rd是固定的写回reg
    */

    //////////////////////////////////////////////////////////////////////////
    // Memory

    wire        load_imm_M;
    wire        jump_M;   
    wire [31:0] pc_inst_ram_plus4_M;
    wire [31:0] imm_extend_Utype_M;

    flopenrc #(32)    uut_alu_result_M(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (alu_result_E),
      .q              (alu_result_M)       // 本项直接作为datapath的输出，不重复声明
    );
    flopenrc #(32)    uut_mem_wdata_M(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd2_sel_E),         // 注意这里不是rd2_E，可能需要数据前推
      .q              (mem_wdata_M)        // 本项直接作为datapath的输出，不重复声明
    );
    flopenrc #(5)     uut_rd_M(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd_E),
      .q              (rd_M)
    );
    flopenrc #(32)     uut_pc_inst_ram_plus4_M(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (pc_inst_ram_plus4_E),
      .q               (pc_inst_ram_plus4_M)
    );
    flopenrc #(1)      uut_jump_M(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (jump_E),
      .q               (jump_M)
    );
    flopenrc #(1)      uut_load_imm_M(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (load_imm_E),
      .q               (load_imm_M)
    );
    flopenrc #(32)    uut_signed_extend_Utype_M(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Utype_E),
      .q              (imm_extend_Utype_M)
    );

    //////////////////////////////////////////////////////////////////////////
    // Writeback
  
    wire [31:0] alu_result_W;
    wire [31:0] pc_inst_ram_plus4_W;
    wire [31:0] imm_extend_Utype_W;
    wire        jump_W;
    wire        load_imm_W;
    wire [1:0]  wd3_src;

    flopenrc #(32)    uut_alu_result_W(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (alu_result_M),
      .q              (alu_result_W)
    );
    flopenrc #(5)     uut_rd_W(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd_M),
      .q              (rd_W)
    );
    flopenrc #(32)     uut_pc_inst_ram_plus4_W(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (pc_inst_ram_plus4_M),
      .q               (pc_inst_ram_plus4_W)
    );
    flopenrc #(1)      uut_jump_W(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (jump_M),
      .q               (jump_W)
    );
    flopenrc #(1)      uut_load_imm_W(
      .clk             (clk),
      .rst             (rst),
      .clear           (1'b0),
      .en              (~stall_F_to_D),
      .d               (load_imm_M),
      .q               (load_imm_W)
    );
    flopenrc #(32)    uut_signed_extend_Utype_W(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Utype_M),
      .q              (imm_extend_Utype_W)
    );

    //mux_2 for regfile_wd3
    //从mem_rdata和alu_result中选择一个作为写回regfile的数据
    //重大改动，这里不是 mem_rdata_W 而是 mem_rdata_M 
    //因为mem读有效数据必须在读信号有效的下一个clk才有效，所以实际上在W阶段时mem的读取数据才正确
    //故不需要传递 mem_rdata_W ，直接把在W阶段有效的 mem_rdata_M 拉过来即可

    // wd3_W的可能来源
    // mem_rdata_M          (memtoreg_W)
    // pc_inst_ram_plus4_W  (jump_W)
    // imm_extend_Utype_W   (load_imm_W)
    // alu_result_W         ()

    assign wd3_src = (memtoreg_W == 1'b1) ? 2'b00 : 
                      (jump_W == 1'b1) ? 2'b01:
                      (load_imm_W == 1'b1) ? 2'b10 : 2'b11;
    
    mux_4 #(32)     uut_mux_4_regfile_wd3(
      .d0           (mem_rdata_M),     
      .d1           (pc_inst_ram_plus4_W),
      .d2           (imm_extend_Utype_W),
      .d3           (alu_result_W),
      .s            (wd3_src),     
      .y            (wd3_W)
    );


    //////////////////////////////////////////////////////////////////////////
    // 动态分支预测模块
    
    branch_predict        uut_branch_predict(
      .clk                (clk),
      .rst                (rst),
      .branch_inst        (branch_D),
      .branch_h           (branch_h_D),
      .pc_branch          (pc_branch_D),
      .pc_branch_predict  (pc_branch_predict_F),
      .next_branch_h      (next_branch_h)
    );


endmodule
