vlib work
vmap work work

#library
#vlog  -work work ../../library/artix7/*.v

#IP
#vlog  -work work ../../../source_code/ROM_IP/rom_controller.v

#SourceCode
vlog  -work work ../../verilog/*.v

#Testbench
vlog  -work work ../../Presim/tb_top.v 


vsim -voptargs=+acc work.tb_top

#Add signal into wave window
do wave.do

#run -all
