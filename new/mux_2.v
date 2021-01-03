`timescale 1ns / 1ps

//注意信号1:a; 0:b
module mux_2 #(parameter WIDTH = 32)(
    input   [WIDTH - 1:0] a,
    input   [WIDTH - 1:0] b,
    input   s,
    output  [WIDTH - 1:0] y
    );

    assign y = s ? a : b;

endmodule
