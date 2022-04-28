`timescale 1ns / 1ps


module sram_data #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
    )(
    input                           clk,
    input                           en,
    input   [3:0]                   we,
    input   [ADDR_WIDTH-1:0]        addr,
    input   [DATA_WIDTH-1:0]        din,
    output  [DATA_WIDTH-1:0]        dout
    );

    localparam SRAM_SIZE = (1 << (ADDR_WIDTH-1));
    reg [DATA_WIDTH-1:0] sram [SRAM_SIZE-1:0];
    reg [DATA_WIDTH-1:0] dout_reg;

    always @(posedge clk) begin
        if(!en) dout_reg <= 0;
        else begin
            dout_reg <= sram[addr];
            sram[addr][7:0]     <= we[0] ? din[7:0]     : sram[addr][7:0];
            sram[addr][15:8]    <= we[1] ? din[15:8]    : sram[addr][15:8];
            sram[addr][23:16]   <= we[2] ? din[23:16]   : sram[addr][23:16];
            sram[addr][31:24]   <= we[3] ? din[31:24]   : sram[addr][31:24];
        end
    end

    assign dout = dout_reg;


    

endmodule
