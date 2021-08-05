# FlsV by Folisa

一个基于RV32I指令集的五级流水线CPU核，目前实现：
1. 五级流水线正常运行
2. R/I型指令之间的数据前推（from M/W）
3. B型指令数据前推（from E/M）
4. 当Load指令后的第一条指令为R/I型指令并造成数据冒险时，将暂停流水线一个周期
5. 当Laod指令后的第二条指令为B型指令并造成数据冒险时，将暂停流水线一个周期
6. 建议编译器通过调整指令顺序或插入nop指令，避免Laod指令后的第一条指令为B型指令，本设计未考虑这种情况
7. 当J/B型指令发生跳转时将清空D阶段之前的流水线 
8. 加入动态分支预测功能，通过简单的测试，但不确保其完备性


提供 ASIC 和 FPGA 两种版本，其中 FlsV_ASIC 使用 SRAM 作为存储，FlsV_FPGA 使用 BRAM 作为存储  
FlsV_ASIC 加入了动态分支预测的功能，可以在 branch_predict.v 中通过 `define 语句开启或关闭该功能，FlsV_FPGA 并未加入此功能  
  
会继续更新和完善新的功能  
  
本设计参考了 https://github.com/lvyufeng/step_into_mips 中的基本架构，在此表达感谢！
