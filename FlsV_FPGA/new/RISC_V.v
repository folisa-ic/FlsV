`timescale 1ns / 1ps

//RISC_V_core = datapath + controller

module RISC_V(
    input           clk,
    input           rst,
    input  [31:0]   instr_F,        
    input  [31:0]   mem_rdata_M,  
    output reg      inst_ram_ena_F,
    output          data_ram_ena_M,     // 对应memen
    output          data_ram_wea_M,     // 对应memwrite
    output [31:0]   pc_inst_ram_F,
    output [31:0]   alu_result_M,  
    output [31:0]   mem_wdata_M,  
    output          stall_instr_F  
    );

    //考虑程序一直处于运行状态，inst_ram使能信号始终为1，但是初始化时为了不传递未知的地址信号到inst_ram，需设置复位
    always@(posedge clk or posedge rst)
    begin
        if(rst)
            inst_ram_ena_F <= 0;
        else
            inst_ram_ena_F <= 1;
    end

    //datapath和controller之间的连线，memwrite/memen不送入datapath
    wire jump_D;
    wire regwrite_W;
    wire regwrite_M;    // 用于ALU计算的数据前推
    wire regwrite_E;    // 用于判断分支的数据前推
    wire load_imm_E;
    wire alusrc; 
    wire branch_D; 
    wire memtoreg_W;
    wire memtoreg_M;
    wire memtoreg_E;  
    wire [31:0] instr_D;
    wire [2:0] alucontrol_E;
    wire [2:0] immcontrol_D;
    wire stall_PC;
    wire stall_F_to_D; 
    wire flush_D_to_E;
    wire [1:0]pcsrc_D;
    
    //目的是将instr_D传入controller模块，其实也可以将instr_F传入后在模块内自行加入流水线reg
    flopenrc #(32)    uut_instr_D(
      .clk            (clk),
      .rst            (rst),
      .clear          (~pcsrc_D[1]),
      .en             (~stall_F_to_D),
      .d              (instr_F),
      .q              (instr_D)
    );

    datapath              uut_datapath(
      .clk                (clk),
      .rst                (rst),
      .instr_F            (instr_F),
      .mem_rdata_M        (mem_rdata_M),
      .pc_inst_ram_F      (pc_inst_ram_F),
      .alu_result_M       (alu_result_M),  
      .mem_wdata_M        (mem_wdata_M),
      .jump_D             (jump_D), 
      .regwrite_W         (regwrite_W), 
      .regwrite_M         (regwrite_M),
      .regwrite_E         (regwrite_E),
      .load_imm_E         (load_imm_E), 
      .alusrc             (alusrc), 
      .branch_D           (branch_D), 
      .memtoreg_W         (memtoreg_W),
      .memtoreg_M         (memtoreg_M),
      .memtoreg_E         (memtoreg_E),
      .alucontrol_E       (alucontrol_E),
      .immcontrol_D       (immcontrol_D),
      .stall_instr_F      (stall_instr_F),
      .stall_PC           (stall_PC),
      .stall_F_to_D       (stall_F_to_D),
      .flush_D_to_E       (flush_D_to_E),
      .pcsrc_D            (pcsrc_D)
    );

    controller        uut_controller(
      .clk            (clk),
      .rst            (rst),
      .instr_D        (instr_D),
      .jump_D         (jump_D), 
      .regwrite_W     (regwrite_W), 
      .regwrite_M     (regwrite_M),
      .regwrite_E     (regwrite_E),
      .load_imm_E     (load_imm_E), 
      .alusrc         (alusrc), 
      .branch_D       (branch_D), 
      .memwrite       (data_ram_wea_M),   // 此项不送入datapath，而直接作为输出送入data_ram Memory
      .memtoreg_W     (memtoreg_W),
      .memtoreg_M     (memtoreg_M),
      .memtoreg_E     (memtoreg_E),
      .memen          (data_ram_ena_M),   // 此项不送入datapath，而直接作为输出送入data_ram Memory
      .alucontrol_E   (alucontrol_E),
      .immcontrol_D   (immcontrol_D),
      .flush_D_to_E   (flush_D_to_E)      // 和datapath一致，在暂停流水线时清空D/E之间的pipeline_reg
    );

endmodule
