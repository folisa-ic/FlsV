`timescale 1ns / 1ps

//左移2位，用于PC相对寻址
module left_shift(
    input   [31:0] a,
    output  [31:0] y
    );

    assign y = {a[29:0], 2'b00};

endmodule
