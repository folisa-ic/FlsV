`timescale 1ns / 1ps



module sram_code #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
    )(
    input                           clk,
    input                           en,
    input   [ADDR_WIDTH-1:0]        addr,
    output  [DATA_WIDTH-1:0]        dout
    );

    localparam SRAM_SIZE = (1 << (ADDR_WIDTH-1));
    reg [DATA_WIDTH-1:0] sram [SRAM_SIZE-1:0];
    reg [DATA_WIDTH-1:0] dout_reg;

    initial begin
        $readmemh("code.txt", sram);
    end
    
    always @(posedge clk) begin
        if(!en) dout_reg <= 0;
        else begin
            dout_reg <= sram[addr];
        end
    end

    assign dout = dout_reg;
    

endmodule
