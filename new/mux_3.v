`timescale 1ns / 1ps

module mux_3 #(parameter WIDTH = 8)(
	input   [WIDTH-1:0] d0,
	input   [WIDTH-1:0] d1,
	input   [WIDTH-1:0] d2,
	input   [1:0] 		s,
	output  [WIDTH-1:0] y
    );

	assign y = (s == 2'b00) ? d0 :
			    (s == 2'b01) ? d1:
				(s == 2'b10) ? d2: d0;
endmodule