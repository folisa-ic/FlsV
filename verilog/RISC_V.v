//=====================================================================
// Designer: Folisa Zhang
//
// Description:
// top module of rv_core (datapath + controller, without ITCM/DTCM) 
// 20220403: set inst_ram_ena_F = 1'b1
//=====================================================================

module RISC_V(
    input           clk,
    input           rst_n,
    input  [31:0]   instr_D,        
    input  [31:0]   mem_rdata_W,  
    output          inst_ram_ena_F,
    output          data_ram_ena_M,     // 对应 memen
    output          data_ram_wea_M,     // 对应 memwrite
    output [31:0]   pc_inst_ram_F,
    output [31:0]   alu_result_M,  
    output [31:0]   mem_wdata_M,  
    output          loadstall  
    );

    // 考虑程序一直处于运行状态，inst_ram 使能信号始终为 1，但是初始化时为了不传递未知的地址信号到 inst_ram，需设置复位
    // always @(posedge clk or negedge rst_n)
    // begin
    //     if(!rst_n)
    //         inst_ram_ena_F <= 0;
    //     else
    //         inst_ram_ena_F <= 1;
    // end
    assign inst_ram_ena_F = 1'b1;

    // datapath 和 controller 之间的连线，memwrite/memen 不送入 datapath
    wire j_E;
    wire jr_E;
    wire regwrite_W;
    wire regwrite_M;    // 用于ALU计算的数据前推
    wire regwrite_E;    // 用于判断分支的数据前推
    wire load_imm_E;
    wire alusrc_E; 
    wire branch_E; 
    wire memtoreg_W;
    wire memtoreg_M;
    wire memtoreg_E;  
    wire [2:0] funct_3_D;
    wire [2:0] alucontrol_E;
    wire [2:0] immcontrol_D;
    wire flush_D_to_E;

    datapath              uut_datapath(
      .clk                (clk),
      .rst_n              (rst_n),
      .j_E                (j_E),
      .jr_E               (jr_E),
      .regwrite_W         (regwrite_W), 
      .regwrite_M         (regwrite_M),
      .regwrite_E         (regwrite_E),
      .load_imm_E         (load_imm_E), 
      .alusrc_E           (alusrc_E), 
      .branch_E           (branch_E), 
      .memtoreg_W         (memtoreg_W),
      .memtoreg_M         (memtoreg_M),
      .memtoreg_E         (memtoreg_E),
      .funct_3_D          (funct_3_D),
      .alucontrol_E       (alucontrol_E),
      .immcontrol_D       (immcontrol_D),
      .instr_D            (instr_D),
      .mem_rdata_W        (mem_rdata_W),
      .pc_inst_ram_F      (pc_inst_ram_F),
      .alu_result_M       (alu_result_M),  
      .mem_wdata_M        (mem_wdata_M),
      .loadstall          (loadstall),
      .flush_D_to_E       (flush_D_to_E)
    );

    controller        uut_controller(
      .clk            (clk),
      .rst_n          (rst_n),
      .instr_D        (instr_D),
      .j_E            (j_E), 
      .jr_E           (jr_E),
      .regwrite_W     (regwrite_W), 
      .regwrite_M     (regwrite_M),
      .regwrite_E     (regwrite_E),
      .load_imm_E     (load_imm_E), 
      .alusrc_E       (alusrc_E), 
      .branch_E       (branch_E), 
      .memwrite       (data_ram_wea_M),   // 此项不送入 datapath，而直接作为输出送入 data_ram Memory
      .memtoreg_W     (memtoreg_W),
      .memtoreg_M     (memtoreg_M),
      .memtoreg_E     (memtoreg_E),
      .memen          (data_ram_ena_M),   // 此项不送入 datapath，而直接作为输出送入 data_ram Memory
      .funct_3_D      (funct_3_D),
      .alucontrol_E   (alucontrol_E),
      .immcontrol_D   (immcontrol_D),
      .flush_D_to_E   (flush_D_to_E)      // 和 datapath 一致，在暂停流水线时清空 D/E 之间的 pipeline_reg
    );

endmodule
