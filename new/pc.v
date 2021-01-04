`timescale 1ns / 1ps

//本质上是一个同步复位的D触发器
module pc(
    input clk,
    input rst,
    input en,
    input [31:0] din,
    output reg [31:0] q
    );

    reg cnt;
    always@(posedge clk)
    begin
        if(rst) 
            q <= 32'b0;
        else if(en)
            q <= din;
        else ;              
    end
endmodule
