`timescale 1ns / 1ps

module flopenrc #(parameter WIDTH = 8)(
	input       clk,
    input       rst_n,
    input       en,
    input       clear,
	input       [WIDTH-1:0] d,
	output reg  [WIDTH-1:0] q
    );

	always @(posedge clk or negedge rst_n) 
    begin
		if(!rst_n) 
			q <= 0;
		else if(clear) 
			q <= 0;
		else if(en) 
			/* code */
			q <= d;
		else ;
	end
    
endmodule 