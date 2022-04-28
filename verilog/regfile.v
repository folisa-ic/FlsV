
module regfile(
    input clk,
    input rst_n,
    input we3,                  //reg写使能
    input [4:0] ra1,            //rs地址
    input [4:0] ra2,            //rt地址
    input [4:0] wa3,            //写回regfile的地址
    input [31:0] wd3,           //写回regfile的数据
    output[31:0] rd1, rd2       //读出源操作数reg的数据
    );
    
    reg [31:0] rf[31:0];        //32维寄存器数组模拟寄存器文件
    integer i;

    always @(negedge clk or negedge rst_n)        //测试下降沿写入，调整时序，避免数据冒险
    begin
        if(!rst_n)
        begin
            //寄存器数组在仿真时若不初始化，则数值为未知X
            for(i = 0; i <= 31; i = i + 1)
            begin
                rf[i] <= 32'b0;
            end
        end
        else if(we3)
            rf[wa3] <= (wa3 != 0) ? wd3 : 0;
        else ;
    end

    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;      //判断是否为0号reg，若是则输出0
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;

endmodule
