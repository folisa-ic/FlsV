//=====================================================================
// Designer: Folisa Zhang
//
// Description:
// 5-stage pipeline data path
//=====================================================================

module datapath(
    input           clk,
    input           rst_n,
    input           j_E, jr_E, regwrite_W, regwrite_M, regwrite_E, load_imm_E, alusrc_E, branch_E, memtoreg_W, memtoreg_M, memtoreg_E,
    input   [2:0]   funct_3_D,
    input   [2:0]   alucontrol_E,
    input   [2:0]   immcontrol_D,
    input   [31:0]  instr_D,         
    input   [31:0]  mem_rdata_W,      
    output  [31:0]  pc_inst_ram_F, 
    output  [31:0]  alu_result_M,   
    output  [31:0]  mem_wdata_M,
    output          loadstall,
    output          flush_D_to_E
);
   
    wire [4:0]  rd_W;
    wire [31:0] wd3_W;                // 从 mem_rdata 和 alu_result 中选出作为写回 regfile 的数据

    wire        jump_E;               // 是否为跳转指令，用于确定 pcsrc_E 选择 pc 以及 wd3_src 选择 wd3
    wire [31:0] pc_inst_ram_plus4_E;
    wire [31:0] pc_branch_E;
    wire [31:0] pc_jump_E;

    //////////////////////////////////////////////////////////////////////////
    // Fetch
    //////////////////////////////////////////////////////////////////////////

    wire [31:0] pc_F;               // 顺序读取的指令地址
    wire [31:0] pc_plus4_F;         // inst_ram 中的下一条指令地址
    wire [31:0] pc_b_j_p_F;         // 和 pc_branch_D 再次选出最终的 pc_inst_ram_F
    wire [1:0]  pcsrc_E;            // pc_b_j_p_F 选择信号

    wire [31:0] pc_branch_D;        
    wire        next_branch_h_D;      // 预测分支是否发生
    wire        branch_h_E;         // 表示分支指令存在并分支发生（在 E 阶段可知，提前声明）
    wire        predict_en_D;       // 表示在 Decode 阶段的 instr_D 为分支指令且预测分支发生

    pc              uut_pc(       
      .clk          (clk),
      .rst_n        (rst_n),
      .en           (~loadstall),    // 暂停流水线信号，高电平有效故取反
      .din          (pc_plus4_F),
      .q            (pc_F)
    );

    adder           uut_pc_plus4_F(
      .a            (pc_inst_ram_F), 
      .b            (32'd4),             
      .y            (pc_plus4_F)
    );

    mux_4 #(32)     uut_mux_4_next_instr(
      .d0           (pc_F),                 // 正常执行（包含预测成功、非分支跳转指令）
      .d1           (pc_inst_ram_plus4_E),  // 预测分支发生但未发生
      .d2           (pc_branch_E),          // 预测分支不发生但发生
      .d3           (pc_jump_E),            // 跳转
      .s            (pcsrc_E),      
      .y            (pc_b_j_p_F)        
    );

    // 在 Decode 阶段对 instr_D 判断，若为分支指令，且分支预测机预测为分支发生，则直接将 pc_branch_D 赋值给 pc_inst_ram_F
    // 在 E 阶段分支预测失败或跳转时，D 阶段的指令将不执行，此时直接将 pc_b_j_p_F 赋值给 pc_inst_ram_F
    assign branch_D = (instr_D[6:0] == 7'b1100011);
    assign predict_en_D = branch_D & next_branch_h_D;
    assign pc_inst_ram_F = ((predict_en_D == 1'b1) & !flush_D_to_E) ? pc_branch_D : pc_b_j_p_F;
    

    //////////////////////////////////////////////////////////////////////////
    // Decode    
    //////////////////////////////////////////////////////////////////////////

    wire        predict_en_E;             // 若 D 阶段预测分支发生，则需要传递至 E 阶段修正 pcsrc_E
    wire [31:0] pc_inst_ram_D; 
    wire [4:0]  rs1_D, rs2_D, rd_D;
    wire [31:0] rd1_D;                    // 从regfile读取的rs1
    wire [31:0] rd2_D;                    // 从regfile读取的rs2
    wire [31:0] imm_extend_Itype_D;       // Itype指令中被扩展后的imm
    wire [31:0] imm_extend_Stype_D;       // Stype指令中被扩展后的imm
    wire [31:0] imm_extend_Btype_D;       // Btype指令中被扩展后的imm
    wire [31:0] imm_extend_Utype_D;       // Utype指令中被扩展后的imm
    wire [31:0] imm_extend_Jtype_D;       // jal指令中被扩展后的imm
    wire [31:0] imm_extend_JRtype_D;      // jalr指令中被扩展后的imm

    assign rs1_D = instr_D[19:15];
    assign rs2_D = instr_D[24:20];
    assign rd_D = instr_D[11:7];

    flopenrc #(32)     uut_pc_inst_ram_D(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (~loadstall),
      .d               (pc_inst_ram_F),
      .q               (pc_inst_ram_D)
    );

    // 仅是放在了Decode阶段，实际上写回阶段也是在这里发生的
    regfile            uut_regfile(
      .clk             (clk),
      .rst_n           (rst_n),
      .we3             (regwrite_W),          
      .ra1             (instr_D[19:15]),      // rs1地址
      .ra2             (instr_D[24:20]),      // rs2地址            
      .wa3             (rd_W),         
      .wd3             (wd3_W),               // 写回regfile的数据
      .rd1             (rd1_D),               // 读出的rs1数据
      .rd2             (rd2_D)                // 读出的rs2数据   
    );
    
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
    assign imm_extend_Utype_D = {instr_D[31:12], {12{1'b0}}}; // 如果把 {12{1'b0}} 写成 {12{0}} 是错误的，必须写明位数，否则整个 imm_extend_Utype_D 都是0

    //对J-type指令的imm的低位进行补零并符号扩展
    signed_extend #(21)   uut_signed_extend_Jtype_D(
      .a                  ({instr_D[31], instr_D[19:12], instr_D[20], instr_D[30:25], instr_D[24:21], 1'b0}),          // 不需扩展到word寻址，结尾的0已经自动扩展到half_word寻址
      .y                  (imm_extend_Jtype_D)                // 被符号扩展后的 32-bit imm
    );

    assign imm_extend_JRtype_D = imm_extend_Itype_D;          // jalr 与 Itype 的 imm 格式一致

    // pc_branch_D (as branch_predict input)
    adder             uut_pc_branch_D(
      .a              (pc_inst_ram_D),
      .b              (imm_extend_Btype_D),       
      .y              (pc_branch_D)
    );

    //////////////////////////////////////////////////////////////////////////
    // Execute
    //////////////////////////////////////////////////////////////////////////

    wire [31:0] pc_inst_ram_E;
    wire [31:0] rd1_E;
    wire [31:0] rd2_E;
    wire [4:0]  rs1_E, rs2_E, rd_E;  
    wire [4:0]  rd_M;                 // hazard需使用，故将声明移到Execute阶段
    wire [2:0]  funct_3_E;
    wire [2:0]  immcontrol_E; 
    wire [31:0] imm_extend_Itype_E;
    wire [31:0] imm_extend_Stype_E;  
    wire [31:0] imm_extend_Btype_E;   // 直接传递 pc_branch_D 至 pc_branch_E ，不再需要此值
    wire [31:0] imm_extend_Utype_E;  
    wire [31:0] imm_extend_Jtype_E; 
    wire [31:0] imm_extend_JRtype_E;  
    wire [31:0] imm_extend_E;
    wire [31:0] alu_srcB_E;           // 从 Imm 和 rd2 中选出作为 alu_srcB 的输入

    wire [31:0] alu_result_E;
    wire [31:0] pc_j_E;
    wire [31:0] pc_jr_E;
    
    wire        equal_E;                // BEQ
    wire        not_equal_E;            // BNE
    wire        less_E;                 // BLT
    wire        less_u_E;               // BLTU
    wire        greater_E;              // BGT
    wire        greater_u_E;            // BGTU
    
    flopenrc #(32)    uut_rd1_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd1_D),
      .q              (rd1_E)
    );
    flopenrc #(32)    uut_rd2_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd2_D),
      .q              (rd2_E)
    );
    flopenrc #(5)     uut_rs1_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rs1_D),
      .q              (rs1_E)
    );
    flopenrc #(5)     uut_rs2_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rs2_D),
      .q              (rs2_E)
    );
    flopenrc #(5)     uut_rd_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (rd_D),
      .q              (rd_E)
    );
    flopenrc #(3)     uut_immcontrol_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (immcontrol_D),
      .q              (immcontrol_E)
    );
    flopenrc #(3)     uut_funct_3_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (funct_3_D),
      .q              (funct_3_E)
    );
    flopenrc #(32)    uut_signed_extend_Itype_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Itype_D),
      .q              (imm_extend_Itype_E)
    );
    flopenrc #(32)    uut_signed_extend_Stype_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Stype_D),
      .q              (imm_extend_Stype_E)
    );
    flopenrc #(32)    uut_signed_extend_Utype_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Utype_D),
      .q              (imm_extend_Utype_E)
    );
    flopenrc #(32)    uut_signed_extend_Jtype_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_Jtype_D),
      .q              (imm_extend_Jtype_E)
    );
    flopenrc #(32)    uut_signed_extend_JRtype_E(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (imm_extend_JRtype_D),
      .q              (imm_extend_JRtype_E)
    );
    flopenrc #(32)     uut_pc_branch_E(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (flush_D_to_E),
      .en              (1'b1),
      .d               (pc_branch_D),
      .q               (pc_branch_E)
    );
    flopenrc #(32)     uut_pc_inst_ram_E(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (flush_D_to_E),
      .en              (1'b1),
      .d               (pc_inst_ram_D),
      .q               (pc_inst_ram_E)
    );
    flopenrc #(1)      uut_predict_en_E(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (flush_D_to_E),
      .en              (1'b1),
      .d               (predict_en_D),
      .q               (predict_en_E)
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

      .jump_E         (jump_E),
      .branch_E       (branch_E),
      .predict_en_E   (predict_en_E),
      .branch_h_E     (branch_h_E),

      .forwardA_E     (forwardA_E),
      .forwardB_E     (forwardB_E),
      // .forwardA_D     (forwardA_D),
      // .forwardB_D     (forwardB_D),

      .loadstall      (loadstall),
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

    // for jump
    adder             uut_pc_jump_E(
      .a              (pc_inst_ram_E),
      .b              (imm_extend_Jtype_E),       
      .y              (pc_j_E)
    );

    assign jump_E = j_E | jr_E;
    assign pc_jr_E = alu_result_E;
    assign pc_jump_E = (j_E == 1'b1) ? pc_j_E : (jr_E == 1'b1) ? pc_jr_E : 32'b0;
    
    // J 指令 JAL/JALR 需要将 pc + 4 赋值给 rd ，所以需要获得当前指令的 pc 值（即 pc_inst_ram_E ）+4 传递至 W 阶段
    // B 指令预测失败后，需要将 pc +4 重新赋值给 pc_inst_ram_F
    adder             uut_pc_inst_ram_plus4_E(
      .a              (pc_inst_ram_E),         
      .b              (32'd4),       
      .y              (pc_inst_ram_plus4_E)
    );

    // for branch
    assign equal_E = (alu_srcA_E == rd2_sel_E) & (funct_3_E == 3'b000);
    assign not_equal_E = (alu_srcA_E != rd2_sel_E) & (funct_3_E == 3'b001);
    // assign less_E = ( < ) & (funct_3_E == 3'b100);
    // assign greater_E = ( >= ) & (funct_3_E == 3'b101);
    assign less_u_E = (alu_srcA_E < rd2_sel_E) & (funct_3_E == 3'b110);
    assign greater_u_E = (alu_srcA_E >= rd2_sel_E) & (funct_3_E == 3'b111);
    assign branch_h_E = (equal_E | not_equal_E | less_u_E | greater_u_E) & branch_E;
    
    assign pcsrc_E = ((predict_en_E == 1'b1) & (branch_h_E == 1'b1)) ? 2'b00 :      // 预测分支发生且发生（正常执行）
                      ((predict_en_E == 1'b1) & (branch_h_E == 1'b0)) ? 2'b01 :     // 预测分支发生但未发生
                      ((predict_en_E == 1'b0) & (branch_h_E == 1'b1)) ? 2'b10 :     // 预测分支不发生但发生
                      (jump_E == 1'b1) ? 2'b11 :                                    // 跳转
                      2'b00;                                                        // 预测分支不发生且未发生，或非 branch/jal/jalr 指令（正常执行）       

    // 选择需要的imm    
    mux_5 #(32)       uut_mux_5_imm_extend_E(
      .d0             (imm_extend_Itype_E),        
      .d1             (imm_extend_Stype_E),
      .d2             (imm_extend_Btype_E),
      .d3             (imm_extend_Utype_E),
      .d4             (imm_extend_JRtype_E),
      .s              (immcontrol_E),                   
      .y              (imm_extend_E)
    );
    
    //从被扩展的 Imm 和 rd2 中选择一个作为 alu_srcB 的输入
    mux_2 #(32)       uut_mux_2_alu_srcB(
      .a              (imm_extend_E),        
      .b              (rd2_sel_E),
      .s              (alusrc_E),        
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

    //////////////////////////////////////////////////////////////////////////
    // Memory
    //////////////////////////////////////////////////////////////////////////

    wire        load_imm_M;
    wire        jump_M;   
    wire [31:0] pc_inst_ram_plus4_M;
    wire [31:0] imm_extend_Utype_M;

    flopenrc #(32)    uut_alu_result_M(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (alu_result_E),
      .q              (alu_result_M)       // 本项直接作为datapath的输出，不重复声明
    );
    flopenrc #(32)    uut_mem_wdata_M(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd2_sel_E),         // 注意这里不是rd2_E，可能需要数据前推
      .q              (mem_wdata_M)        // 本项直接作为datapath的输出，不重复声明
    );
    flopenrc #(5)     uut_rd_M(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd_E),
      .q              (rd_M)
    );
    flopenrc #(32)     uut_pc_inst_ram_plus4_M(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (pc_inst_ram_plus4_E),
      .q               (pc_inst_ram_plus4_M)
    );
    flopenrc #(1)      uut_jump_M(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (jump_E),
      .q               (jump_M)
    );
    flopenrc #(1)      uut_load_imm_M(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (load_imm_E),
      .q               (load_imm_M)
    );
    flopenrc #(32)    uut_signed_extend_Utype_M(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (imm_extend_Utype_E),
      .q              (imm_extend_Utype_M)
    );

    //////////////////////////////////////////////////////////////////////////
    // Writeback
    //////////////////////////////////////////////////////////////////////////
  
    wire [31:0] alu_result_W;
    wire [31:0] pc_inst_ram_plus4_W;
    wire [31:0] imm_extend_Utype_W;
    wire        jump_W;
    wire        load_imm_W;
    wire [1:0]  wd3_src;

    flopenrc #(32)    uut_alu_result_W(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (alu_result_M),
      .q              (alu_result_W)
    );
    flopenrc #(5)     uut_rd_W(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (rd_M),
      .q              (rd_W)
    );
    flopenrc #(32)     uut_pc_inst_ram_plus4_W(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (pc_inst_ram_plus4_M),
      .q               (pc_inst_ram_plus4_W)
    );
    flopenrc #(1)      uut_jump_W(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (jump_M),
      .q               (jump_W)
    );
    flopenrc #(1)      uut_load_imm_W(
      .clk             (clk),
      .rst_n           (rst_n),
      .clear           (1'b0),
      .en              (1'b1),
      .d               (load_imm_M),
      .q               (load_imm_W)
    );
    flopenrc #(32)    uut_signed_extend_Utype_W(
      .clk            (clk),
      .rst_n          (rst_n),
      .clear          (1'b0),
      .en             (1'b1),
      .d              (imm_extend_Utype_M),
      .q              (imm_extend_Utype_W)
    );

    //mux_2 for regfile_wd3
    //从 mem_rdata 和 alu_result 中选择一个作为写回 regfile 的数据

    // wd3_W的可能来源
    // mem_rdata_W          (memtoreg_W)
    // pc_inst_ram_plus4_W  (jump_W)
    // imm_extend_Utype_W   (load_imm_W)
    // alu_result_W         ()

    assign wd3_src = (memtoreg_W == 1'b1) ? 2'b00 : 
                      (jump_W == 1'b1) ? 2'b01:
                      (load_imm_W == 1'b1) ? 2'b10 : 2'b11;
    
    mux_4 #(32)     uut_mux_4_regfile_wd3(
      .d0           (mem_rdata_W),     
      .d1           (pc_inst_ram_plus4_W),
      .d2           (imm_extend_Utype_W),
      .d3           (alu_result_W),
      .s            (wd3_src),     
      .y            (wd3_W)
    );


    //////////////////////////////////////////////////////////////////////////
    // 动态分支预测模块
    
    branch_predict          uut_branch_predict(
      .clk                  (clk),
      .rst_n                (rst_n),
      .branch_E             (branch_E),
      .branch_h_E           (branch_h_E),
      .pc_branch_E          (pc_branch_E),
      .next_branch_h_D      (next_branch_h_D)
    );


endmodule
