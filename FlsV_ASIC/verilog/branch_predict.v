`timescale 1ns / 1ps
`define BRANCH_PREDICT

module branch_predict(
    input 			clk,
    input 			rst,
    input 			branch_inst,
	input			branch_h,
    input 	[31:0] 	pc_branch,
	output	[31:0]	pc_branch_predict,
    output 			next_branch_h
    );

    reg 			next_branch_h_reg;
	reg 	[31:0] 	pc_branch_reg;

    //////////////////////////////////////////////////////////////////////////
    // 动态分支预测状态机，包含三种有效状态
	localparam B_N_H_STRONG = 0;
	localparam B_N_H_WEAK   = 1;
	localparam B_H          = 2;

	reg[1:0] state_now;
	reg[1:0] state_next;
	
   // 第一阶段：时序逻辑对状态锁存  
	always@(posedge clk)
	begin
		if(rst) state_now <= B_N_H_STRONG;
		else state_now <= state_next;
	end
    
    // 第二阶段：组合逻辑状态变迁（注意变更的是state_next） 
	always@(*)
	begin
		case(state_now)

			// 初始状态即为 B_N_H_STRONG，在 B_N_H_STRONG 下发生分支，进入 B_N_H_WEAK
            B_N_H_STRONG:
				if(branch_h == 1) state_next = B_N_H_WEAK;
				else state_next = B_N_H_STRONG;
			
            // B_N_H_WEAK 下分支发生（且分支地址相同），则进入 B_H 状态，不发生则恢复 B_N_H_STRONG
            B_N_H_WEAK:
				if((branch_inst == 1) & (branch_h == 1) & (pc_branch == pc_branch_reg)) state_next = B_H;
				else if(branch_inst == 1) state_next = B_N_H_STRONG;
				else state_next = B_N_H_WEAK;
			
            // B_H 下发生分支则维持 B_H 状态，不发生分支（或发生分支但分支地址改变）则回到 B_N_H_STRONG 
            B_H:
				if((branch_inst == 1) & (branch_h == 0)) state_next = B_N_H_STRONG;
				else if((branch_inst == 1) & (branch_h == 1) & (pc_branch != pc_branch_reg)) state_next = B_N_H_STRONG;
				else state_next = B_H;
            
			default: ;
		endcase
	end
 
	// 第三阶段：组合或时序逻辑根据状态对输出赋值 
	`ifdef BRANCH_PREDICT
		assign next_branch_h = (state_now == B_H)? 1 : 0;
	`endif 

	`ifndef BRANCH_PREDICT
		assign next_branch_h = 1'b0;
	`endif 

	always @(posedge clk) begin
		if(rst) pc_branch_reg <= 32'b0;
		else if((branch_inst == 1) & (branch_h == 1)) pc_branch_reg <= pc_branch;
		else pc_branch_reg <= pc_branch_reg;
	end

	assign pc_branch_predict = pc_branch_reg;

endmodule
