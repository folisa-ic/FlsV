`timescale 1ns / 1ps

//jump_D            是否为jump指令
//regwrite          是否需要写寄存器文件
//load_imm_E        是否为U-type
//alusrc            ALU的B端口选择Imm(1) or Regfile(0)
//branch_D          是否为branch指令，且满足branch条件
//memwrite          是否要写数据存储器
//memtoreg          回写数字是否来自MEM(1) or ALU(0)
//memen             data_ram使能

//如果要从MIPS迁移至RISCV则本模块需要大改
//对指令的操作要从原本的op+funct改为op+funct7+funct3的模式，操作位也需要变化
//需要注意的是RISCV的指令的操作数不再分为rs/rt/rd，而是改为rd/rs1/rs2，也就不存在选择rs/rd的问题（基本上都是rd），更加清楚简明
//所以将原本用于选择rt/rd的regdst替换成区分指令是否为U-type的load_imm_D

//main_dec和alu_dec模块可直接复用，但controller内部信号线需按照流水线阶段重新命名
//直接将sigs和alucontrol信号在pipeline_reg之间传递，在不同阶段取其某一位作为相应的控制信号

module controller(
    input   clk,
    input   rst,
    input   [31:0] instr_D,
    input   flush_D_to_E,
    output  jump_D, regwrite_W, regwrite_M, regwrite_E, load_imm_E, alusrc, branch_D, memwrite, memtoreg_W, memtoreg_M, memtoreg_E, memen,
    output  [2:0] alucontrol_E,             // 用于Execute阶段的输出
    output  [2:0] immcontrol_D              // 用于选择imm的类型，RISCV新添加
    );

    wire [1:0] aluop_D;

    wire [7:0] sigs_D;
    wire [2:0] alucontrol_D;

    wire [6:0] sigs_E;

    wire [4:0] sigs_M;
    wire [1:0] sigs_W;

    main_dec            uut_main_dec(
        .op             (instr_D[6:0]),     // main_dec输入 Decode
        .sigs           (sigs_D),           // main_dec输出，各级控制信号 Decode
        .immcontrol     (immcontrol_D)
    );

    alu_dec             uut_alu_dec(
        .op             (instr_D[6:0]),  
        .funct_7        (instr_D[31:25]),   // alu_dec输入 Decode
        .funct_3        (instr_D[14:12]),   // alu_dec输入 Decode
        .alucontrol     (alucontrol_D)      // alu_dec输出 ALU控制信号 Decode
    );
    
    //////////////////////////////////////////////////////////////////////////
    // Decode
    // jump_D, regwrite, load_imm_E, alusrc, branch_D, memwrite, memtoreg, memen
    assign jump_D = sigs_D[7];                
    assign branch_D = sigs_D[3];                          

    //////////////////////////////////////////////////////////////////////////
    // Execute
    // regwrite, load_imm_E, alusrc, branch_D, memwrite, memtoreg, memen
    // branch_D多于，待删掉
    flopenrc #(7)     uut_sigs_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (sigs_D[6:0]),
      .q              (sigs_E)
    );
    flopenrc #(3)     uut_alucontrol_E(
      .clk            (clk),
      .rst            (rst),
      .clear          (flush_D_to_E),
      .en             (1'b1),
      .d              (alucontrol_D),
      .q              (alucontrol_E)
    );

    assign load_imm_E = sigs_E[5];          
    assign alusrc = sigs_E[4];
    assign memtoreg_E = sigs_E[1];
    assign regwrite_E = sigs_E[6];

    //////////////////////////////////////////////////////////////////////////
    // Memory
    // regwrite, branch_D, memwrite, memtoreg, memen
    flopenrc #(5)     uut_sigs_M(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              ({sigs_E[6],sigs_E[3:0]}),
      .q              (sigs_M)
    );

    assign memwrite = sigs_M[2];
    assign memen = sigs_M[0];
    assign regwrite_M = sigs_M[4];      // 用于数据前推
    assign memtoreg_M = sigs_M[1];

    //////////////////////////////////////////////////////////////////////////
    // Writeback
    // regwrite, memtoreg
    flopenrc #(2)     uut_sigs_W(
      .clk            (clk),
      .rst            (rst),
      .clear          (1'b0),
      .en             (1'b1),
      .d              ({sigs_M[4],sigs_M[1]}),
      .q              (sigs_W)
    );

    assign regwrite_W = sigs_W[1];
    assign memtoreg_W = sigs_W[0];

endmodule

module main_dec(
    input   [6:0] op,
    output reg [7:0] sigs,
    output reg [2:0] immcontrol
    );

    // immcontrol = 000: I-type
    // immcontrol = 001: S-type
    // immcontrol = 010: B-type
    // immcontrol = 011: U-type
    // immcontrol = 100: J-type
    
    //jump_D, regwrite, load_imm_E, alusrc, branch_D, memwrite, memtoreg, memen
    //jump_D            是否为jump指令
    //regwrite          是否需要写寄存器文件
    //load_imm_E        是否为U型指令
    //alusrc            ALU的B端口选择Imm(1) or Regfile(0)
    //branch_D          是否为branch指令，且满足branch条件
    //memwrite          是否要写数据存储器
    //memtoreg          回写数字是否来自MEM(1) or ALU(0)
    //memen             data_ram使能
    always@(*)
    begin
        case (op)
            7'b0110111: begin               //LUI
                sigs  = 8'b01100000;
                immcontrol = 3'b011;        
            end
            7'b0010111: begin               //AUIPC
                sigs  = 8'b01100000;
                immcontrol = 3'b011;
            end
            7'b1101111: begin               //JAL
                sigs  = 8'b11000000;
                immcontrol = 3'b100;
            end
            7'b1100111: begin               //JALR
                sigs  = 8'b11000000;
                immcontrol = 3'b100;
            end
            7'b1100011: begin               //B-type
                sigs  = 8'b00001000;
                immcontrol = 3'b010;
            end
            7'b0000011: begin               //Load(I-type)
                sigs  = 8'b01010011;
                immcontrol = 3'b000;
            end
            7'b0100011: begin               //Store
                sigs  = 8'b00010101;
                immcontrol = 3'b001;
            end
            7'b0010011: begin               //I-type
                sigs  = 8'b01010000;
                immcontrol = 3'b000;
            end
            7'b0110011: begin               //R-type
                sigs  = 8'b01000000;
                immcontrol = 3'b000;        //默认无意义   
            end
            default: begin
                sigs  = 8'b00000000;
            end
        endcase
    end

endmodule

module alu_dec(
    input   [6:0] op,
    input   [6:0] funct_7,
    input   [2:0] funct_3,
    output  [2:0] alucontrol
    );

    reg[2:0] alucontrol_reg;
    assign alucontrol = alucontrol_reg;

    always@(*)
    begin    
        if(op == 7'b0110011 | op == 7'b0010011)                                 //面向R/I-type指令
        begin
            case (funct_3)                                                    
                3'b000: begin
                if      (funct_7 == 7'b0000000) alucontrol_reg = 3'b010;        //ADD
                else if (funct_7 == 7'b0100000) alucontrol_reg = 3'b110;        //SUB
                end
                3'b010: alucontrol_reg = 3'b111;                                //SLT
                3'b100: alucontrol_reg = 3'b011;                                //XOR
                3'b110: alucontrol_reg = 3'b001;                                //OR
                3'b111: alucontrol_reg = 3'b000;                                //AND
                default: alucontrol_reg = 3'b010;                               //默认为ADD    
            endcase
        end

        else alucontrol_reg = 3'b010;                                           //对Load/Store指令均为ADD
    end

endmodule
