`timescale 1ns / 1ps

module testbench();

    reg clk;
    reg rst;

    `define CLK_PERIORD		20
    always #(`CLK_PERIORD/2) clk = ~clk;	

    top         uut_top(
      .clk      (clk),
      .rst      (rst)
    );

    initial begin
	    clk <= 0;
	    rst <= 1;
	    #20;
	    rst <= 0;
    end

    initial begin
	    #600;
	    $stop;
    end


endmodule
