`timescale 1ns / 1ps

//视频中的alucontrol疑似有误，本文件依照正常alu结构完成
module alu(
    input   [31:0] a,
    input   [31:0] b,
    input   [2:0]  alucontrol,
    output reg[31:0] s,
    output zero,
    output overflow
    );
    
    always@(*)
    begin
        case (alucontrol)
            3'b000: s = a & b;      //AND
            3'b001: s = a | b;      //OR
            3'b010: s = a + b;      //ADD
            3'b011: s = a ^ b;      //XOR
            3'b110: s = a - b;      //SUB
            3'b111: s = (a<b);      //SLT
            default: s = 32'b0;
        endcase
    end

    assign zero = (s == 32'b0);
    assign overflow = 1'b0;     //待后续判断是否溢出

endmodule
