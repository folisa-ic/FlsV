`timescale 1ns / 1ps

// 通常针对Imm计算时的符号扩展
module signed_extend #(parameter WIDTH = 16)(
    input   [WIDTH-1:0] a,
    output  [31:0]      y
    );

    assign y = {{(32-WIDTH){a[WIDTH-1]}}, a};

endmodule
