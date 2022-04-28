`timescale 1ns / 1ps
`define BRANCH_PREDICT

module branch_predict(
    input 			clk,
    input 			rst_n,
    input 			branch_E,
	input			branch_h_E,
    input 	[31:0] 	pc_branch_E,
    output 			next_branch_h_D
    );

	reg 	[31:0] 	pc_branch_reg;

    //////////////////////////////////////////////////////////////////////////
	localparam B_N_H_STRONG = 0;
	localparam B_N_H_WEAK   = 1;
	localparam B_H          = 2;

	reg[1:0] state_now;
	reg[1:0] state_next;
	
	always @(posedge clk or negedge rst_n)
	begin
		if(!rst_n) state_now <= B_N_H_STRONG;
		else state_now <= state_next;
	end
    
	always @(*)
	begin
		case(state_now)

			// 初始状态即为 B_N_H_STRONG，在 B_N_H_STRONG 下发生分支，进入 B_N_H_WEAK
            B_N_H_STRONG:
				if(branch_h_E == 1) state_next = B_N_H_WEAK;
				else state_next = B_N_H_STRONG;
			
            // B_N_H_WEAK 下分支发生（且分支地址相同），则进入 B_H 状态，不发生则恢复 B_N_H_STRONG
            B_N_H_WEAK:
				if((branch_E == 1) & (branch_h_E == 1) & (pc_branch_E == pc_branch_reg)) state_next = B_H;
				else if(branch_E == 1) state_next = B_N_H_STRONG;
				else state_next = B_N_H_WEAK;
			
            // B_H 下发生分支且分支地址不变则维持 B_H 状态，不发生分支（或发生分支但分支地址改变）则回到 B_N_H_STRONG 
            B_H:
				if((branch_E == 1) & (branch_h_E == 0)) state_next = B_N_H_STRONG;
				else if((branch_E == 1) & (branch_h_E == 1) & (pc_branch_E != pc_branch_reg)) state_next = B_N_H_STRONG;
				else state_next = B_H;
            
			default: ;
		endcase
	end
 
	`ifdef BRANCH_PREDICT
		assign next_branch_h_D = (state_now == B_H) ? 1 : 0;
	`endif 

	`ifndef BRANCH_PREDICT
		assign next_branch_h_D = 1'b0;
	`endif 

	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) pc_branch_reg <= 32'b0;
		else if(branch_E == 1) pc_branch_reg <= pc_branch_E;
		else pc_branch_reg <= pc_branch_reg;
	end


endmodule
