`timescale 1ns / 1ps

module mux_5 #(parameter WIDTH = 32)(
    input   [WIDTH-1:0] d0,       
    input   [WIDTH-1:0] d1,
    input   [WIDTH-1:0] d2,
    input   [WIDTH-1:0] d3,
    input   [WIDTH-1:0] d4,
    input   [2:0] 		s,
    output  [WIDTH-1:0] y
    );

    assign y = (s == 3'b000) ? d0 :
			    (s == 3'b001) ? d1 :
				(s == 3'b010) ? d2 : 
                (s == 3'b011) ? d3 : d4;
endmodule
