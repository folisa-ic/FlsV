# FlsV by Folisa

目前完成的功能：
1. 五级流水线正常运行
2. 数据前推（from M/W）
3. 流水线阻塞/清空
   Load 指令后的第一条指令造成数据冒险时，将阻塞 pc / F->D 一个周期，清空 D->E
   branch 分支预测失败或 jal/jalr 指令，清空 D->E
4. 动态分支预测，分支历史记录表 + 分支预测状态机
   稳定性通过了简单测试，不确保其完备性，可以通过 `define 语句开启或解除动态分支预测的功能

考虑将 branch 指令中的计算部分并入 ALU 中，节省硬件资源
会继续更新和完善新的功能  
  
本设计参考了 https://github.com/lvyufeng/step_into_mips 中的基本架构，在此表达感谢！
