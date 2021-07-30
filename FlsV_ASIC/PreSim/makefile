.PHONY:com sim clean		 		# .PHONY:不管路径下是否真的存在后面的文件，都执行

OUTPUT = simv

# \ 表示换行，命令过长时使用，与前面的命令之间要有一个空格
# sverilog 表示支持 systemverilog
# +v2k 兼容 verilog 2001 以前的标准
# -debug_access+<option> 用于指定 debug 的模式，具体选项可见：https://blog.csdn.net/zhajio/article/details/88839838
# -debug_access+driver 如果需要 trace driver 的话，需要加这个选项
# -o simv 指定输出文件名为 simv
# -l compile.log 指定输出编译日志文件名
# -full64 支持64位x86处理器，可省略
# -kdb 若想使用 Verdi 查看波形，需要添加此选项
# -Mupdate 增量编译 再次编译时只编译改变的文件    

VCS = vcs -sverilog +v2k              	\
	  -debug_access+r+dmptf+driver 		\
	  -o ${OUTPUT}						\
	  -l compile.log					\
	  -full64                    		\
      -kdb                            	\


# -l run.log 指定输出运行日志文件名
# ./simv -gui=verdi -l run.log 为 Verdi 一种执行命令，但使用此命令后，EDA服务器显示没有 Verdi 的 license
SIM = ./${OUTPUT} -gui -dve_opts "-sx" -l run.log

# vcs sourcefile [compile_time_option]
# -f 表示使用 filelist 来指定源文件
com:
	${VCS} -f filelist		 

sim:
	${SIM}

clean:
	rm -rf ./csrc *.daidir *.log simv* *.key
