`timescale 1ns / 1ps

// top = RISC_V + sram_code + sram_data
// VCS & Verdi/DVE  Modelsim  Vivado

// RV32I 寄存器/寻址空间数据位宽为 32-bit（XLEN = 32），共 32 个通用寄存器
// RV32E 寄存器/寻址空间数据位宽为 32-bit（XLEN = 32），共 16 个通用寄存器
// RV64I 寄存器/寻址空间数据位宽为 64-bit（XLEN = 64），共 32 个通用寄存器

// four core instruction formats (R/I/S/U)
// further two formats for immediates (B/J) 

// 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
// {      funct7      } {    rs2     } {    rs1     } {funct3} {     rd     } {      opcode      } for R-type
// {           imm[11:0]             } {    rs1     } {funct3} {     rd     } {      opcode      } for I-type 
// {     imm[11:5]    } {    rs2     } {    rs1     } {funct3} {  imm[4:0]  } {      opcode      } for S-type
// {                       imm[31:12]                        } {     rd     } {      opcode      } for U-type 
// {   imm[12,10:5]   } {    rs2     } {    rs1     } {funct3} { imm[4:1,11]} {      opcode      } for B-type
// {                  imm[20,10:1,11,19:12]                  } {     rd     } {      opcode      } for J-type 

///////////////////////////////////////////////////////
// RV32I 47 INSTRUCTIONS 
///////////////////////////////////////////////////////

// LOAD: lb/lh/lw/lbu/lhu
// STORE: sb/sh/sw
// ARITHMETIC: add/addi/sub/lui/auipc
// LOGIC: xor/xori/or/ori/and/andi
// SHIFT: sll/slli/srl/srli/sra/srai
// COMPARE: slt/slti/sltu/sltiu
// BRANCH: beq/bne/blt/bge/bltu/bgeu
// JUMP: jal/jalr

// SYNC: fence/fence.i
// CSR: csrrw/csrrs/csrrc/csrrwi/csrrsi/csrrci
// SYSTEM: ecall/ebreak


// 目前完成的功能：
// 五级流水线正常运行
// 数据前推（from M/W）
// 流水线阻塞/清空
//    Load 指令后的第一条指令造成数据冒险时，将阻塞 pc / F->D 一个周期，清空 D->E
//    branch 分支预测失败或 jal/jalr 指令，清空 D->E
// 动态分支预测，分支历史记录表 + 分支预测状态机
//    稳定性通过了简单测试，不确保其完备性，可以通过 `define 语句开启或解除动态分支预测的功能
// 考虑将 branch 指令中的计算部分并入 ALU 中，节省硬件资源



module top(
    input clk,
    input rst_n
    );

    wire inst_ram_ena_F;                        // inst_ram 使能 Fetch
    wire data_ram_ena_M;                        // data_ram 使能 Memory
    wire data_ram_wea_M;                        // data_ram 写使能 Memory
    wire [31:0] pc_inst_ram_F;                  // 
    wire [31:0] pc_word_F;                      // inst_ram 地址输入 Fetch
    wire [31:0] instr_D;                        // inst_ram 指令输出 Fetch
    wire [31:0] instr_D_initial;                // 最初的 inst_ram 指令输出
    reg  [31:0] instr_D_delay;                  // instr_D_initial 延迟一拍
    wire [31:0] alu_result_M;                   // data_ram 取其低位部分作为地址输入 Memory
    wire [31:0] mem_wdata_M;                    // data_ram 写输入 Memory
    wire [31:0] mem_rdata_W;                    // data_ram 读输入 Memory 
  
    wire loadstall;
    assign pc_word_F = {2'b0, pc_inst_ram_F[31:2]};      // 由于 inst_ram 按 word 寻址，故需要将最终结果右移


    //RV_core
    RISC_V              uut_RISC_V(
      .clk              (clk),
      .rst_n            (rst_n),
      .inst_ram_ena_F   (inst_ram_ena_F),
      .data_ram_ena_M   (data_ram_ena_M),
      .data_ram_wea_M   (data_ram_wea_M),
      .pc_inst_ram_F    (pc_inst_ram_F),
      .instr_D          (instr_D),
      .alu_result_M     (alu_result_M),
      .mem_wdata_M      (mem_wdata_M),              
      .mem_rdata_W      (mem_rdata_W),
      .loadstall        (loadstall)    
    );

    sram_code #(
      .DATA_WIDTH       (32),
      .ADDR_WIDTH       (8)
    ) uut_sram_code_test (
      .clk              (clk),    
      .en               (inst_ram_ena_F),      
      .addr             (pc_word_F[7:0]),            
      .dout             (instr_D_initial)           
    );

    
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) instr_D_delay <= 'b0;
    	else instr_D_delay <= instr_D_initial;
    end

    reg hold_on_instr_F;
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) hold_on_instr_F <= 1'b0;
      else if(loadstall) hold_on_instr_F <= 1'b1;
      else hold_on_instr_F <= 1'b0;
    end

    assign instr_D = (hold_on_instr_F == 1) ? instr_D_delay : instr_D_initial;

    // data_ram
    // write first 模式中，读数据为当前地址最新的写数据，read first 模式中，读数据为当前地址旧的数据（即这个 clk 刚刚写入的数据不会被读出）
    // 本设计的 data_ram 为 write first
    // 但无论如何，真正有效的读数据只会在读地址有效后的下一个 clk 上升沿出现，例如：
    // 当出现写 addr1 后写 addr2 再读 addr1 的连续指令时，两个模式都会读到 addr2 的值（只不过是新旧区别，但均不是想要的 addr1 的值）
    // 对于 write first 模式，在写 addr1 后马上读 addr1 可以恰好读到正确的值
    // 不过我们的设计会统一往后延一拍，保证读取可以得到正确的值
    
    /*
    data_ram            uut_data_ram (
      .clka             (clk),    
      .ena              (data_ram_ena_M),      
      .wea              ({4{data_ram_wea_M}}),  // 4-bit对应4个byte的输入写使能，均为1可写4个word
      .addra            (alu_result_M[9:0]),    // alu_result[9:0]作为MEM地址
      .dina             (mem_wdata_M),          // 作为store指令写入MEM中的数据
      .douta            (mem_rdata_W)           // 作为load指令读取的MEM中的数据
    );
    */

    sram_data #(
      .DATA_WIDTH       (32),
      .ADDR_WIDTH       (8)
    ) uut_sram_data_test (
      .clk              (clk),    
      .en               (data_ram_ena_M),      
      .we               ({4{data_ram_wea_M}}),  
      .addr             (alu_result_M[7:0]),    
      .din              (mem_wdata_M),          
      .dout             (mem_rdata_W)           
    );



endmodule
