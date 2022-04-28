`timescale 1ns / 1ps

module tb_top();

		reg clk;
		reg rst_n;

		`define CLK_PERIORD		20
		always #(`CLK_PERIORD/2) clk = ~clk;	

		top         uut_top(
			.clk      (clk),
			.rst_n    (rst_n)
		);

	initial begin
			clk <= 0;
			rst_n <= 0;
			# `CLK_PERIORD;
			rst_n <= 1;
		end

		initial begin
			#(`CLK_PERIORD*300);
			$stop;
		end


endmodule
