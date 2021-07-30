`timescale 1ns / 1ps

// top = RISCV_core + inst_ram + data_ram
// Vivado 2019.1

// 目前完成的功能：
// 五级流水线正常运行
// R/I型指令之间的数据前推（from M/W）
// B型指令数据前推（from E/M）
// 当Load指令后的第一条指令为R/I型指令并造成数据冒险时，将暂停流水线一个周期
// 当Laod指令后的第二条指令为B型指令并造成数据冒险时，将暂停流水线一个周期
// 建议编译器通过调整指令顺序或插入nop指令，避免Laod指令后的第一条指令为B型指令，本设计未考虑这种情况
// 当J/B型指令发生跳转时将清空D阶段之前的流水线



module top(
    input clk,
    input rst
    );

    wire inst_ram_ena_F;                        // inst_ram使能 Fetch
    wire data_ram_ena_M;                        // data_ram使能 Memory
    wire data_ram_wea_M;                        // data_ram写使能 Memory
    wire [31:0] pc_inst_ram_F;                  // 
    wire [31:0] pc_word_F;                      // inst_ram地址输入 Fetch
    wire [31:0] instr_F;                        // inst_ram指令输出 Fetch
    wire [31:0] instr_F_initial;                // 最初的inst_ram指令输出
    reg  [31:0] instr_F_delay;                  // instr_F_initial延迟一拍
    wire [31:0] alu_result_M;                   // data_ram取其低位部分作为地址输入 Memory
    wire [31:0] mem_wdata_M;                    // data_ram写输入Memory
    wire [31:0] mem_rdata_M;                    // data_ram读输入Memory 
  
    wire stall_instr_F;
    assign pc_word_F = {2'b0, pc_inst_ram_F[31:2]};      // 由于inst_ram按word寻址，故需要将最终结果右移


    //RV_core
    RISC_V              uut_RISC_V(
      .clk              (clk),
      .rst              (rst),
      .inst_ram_ena_F   (inst_ram_ena_F),
      .data_ram_ena_M   (data_ram_ena_M),
      .data_ram_wea_M   (data_ram_wea_M),
      .pc_inst_ram_F    (pc_inst_ram_F),
      .instr_F          (instr_F),
      .alu_result_M     (alu_result_M),
      .mem_wdata_M      (mem_wdata_M),              
      .mem_rdata_M      (mem_rdata_M),
      .stall_instr_F    (stall_instr_F)    
    );

    //inst_ram
    /*
    inst_ram            uut_inst_ram (
      .clka             (clk),      
      .ena              (inst_ram_ena_F),         
      .wea              (4'b0),                 // inst_ram只读不写，写使能置零  
      .addra            (pc_word_F[7:0]),       // 取pc_word_F的低8位作为指令地址
      .dina             (32'b0),                // inst_ram只读不写，写入数据无效    
      .douta            (instr_F_initial)       // 指令ram输出32-bit指令
    );
    */

    
    sram_code #(
      .DATA_WIDTH       (32),
      .ADDR_WIDTH       (8)
    ) uut_sram_code_test (
      .clk              (clk),    
      .en               (inst_ram_ena_F),      
      .addr             (pc_word_F[7:0]),            
      .dout             (instr_F_initial)           
    );
    

    

    // 非常奇幻的设计，由于instr_F和前面不存在流水线reg所以通过常规的 flopenrc 阻塞
    // 当我们需要阻塞流水线时（目前仅在load指令后的数据冒险时需要），instr_F也需要暂停，所以引入了 instr_F_initial、instr_F_delay、hold_on_instr_F
    // 让 stall_instr_F 到来后 instr_F 保持不变一个周期，是非常重要的操作
    always@(posedge clk)
    begin
    	instr_F_delay <= instr_F_initial;
    end

    reg hold_on_instr_F;
    always@(posedge clk)
    begin
      if(stall_instr_F) hold_on_instr_F <= 1'b1;
      else hold_on_instr_F <= 1'b0;
    end

    assign instr_F = (hold_on_instr_F == 1) ? instr_F_delay : instr_F_initial;

    //data_ram
    //write first模式中，读数据为当前地址最新的写数据，read first模式中，读数据为当前地址旧的数据（即这个clk刚刚写入的数据不会被读出）
    //本设计的 data_ram 为 write first
    //但无论如何，真正有效的读数据只会在读地址有效后的下一个clk上升沿出现，例如：
    //当出现写addr1后写addr2再读addr1的连续指令时，两个模式都会读到addr2的值（只不过是新旧区别，但均不是想要的addr1的值）
    //对于write first模式，在写addr1后马上读addr1可以恰好读到正确的值
    //不过我们的设计会统一往后延一拍，保证读取可以得到正确的值
    
    /*
    data_ram            uut_data_ram (
      .clka             (clk),    
      .ena              (data_ram_ena_M),      
      .wea              ({4{data_ram_wea_M}}),  // 4-bit对应4个byte的输入写使能，均为1可写4个word
      .addra            (alu_result_M[9:0]),    // alu_result[9:0]作为MEM地址
      .dina             (mem_wdata_M),          // 作为store指令写入MEM中的数据
      .douta            (mem_rdata_M)           // 作为load指令读取的MEM中的数据
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
      .dout             (mem_rdata_M)           
    );



endmodule
