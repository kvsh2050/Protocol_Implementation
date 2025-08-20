
MODULE=alu

.PHONY:sim
sim: waveform.vcd

.PHONY:verilate
verilate: .stamp.verilate

.PHONY:build
build: obj_dir/Valu

.PHONY:waves
waves: waveform.vcd
	@echo
	@echo "### WAVES ###"
	gtkwave waveform.vcd

waveform.vcd: ./obj_dir/V$(MODULE)
	@echo
	@echo "### SIMULATING ###"
	@./obj_dir/V$(MODULE)

./obj_dir/V$(MODULE): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$(MODULE).mk V$(MODULE)

.stamp.verilate: $(MODULE).sv tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace -cc $(MODULE).sv --exe tb_$(MODULE).cpp
	@touch .stamp.verilate

.PHONY:lint
lint: $(MODULE).sv
	verilator --lint-only $(MODULE).sv

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd



#.PHONY: all install verilator clean

#install:
#	@echo "Installing Verilator..."
#	@sudo apt-get install verilator

#verilator: alu.sv
#	verilator --cc alu.sv
#For system C -sc, CPP - verilator --sc alu.sv
#	verilator -Wall --trace -cc alu.sv --exe tb_alu.cpp
#	make -C obj_dir -f Valu.mk 
#	./obj_dir/Valu
#	gtkwave waveform.vcd

#clean:
#	rm -rf obj_dir
#	rm -f Valu
#	rm -f waveform.vcd
#	rm -f Valu.mk
#	rm -f Valu.h
#	rm -f Valu__ALL.a
#	rm -f Valu__Syms.h
#	rm -f Valu__Syms.cpp
#	rm -f VerilatedVcdC.h
#	rm -f VerilatedVcdC.cpp
#	rm -f Verilated.h
#	rm -f Verilated.cpp
#	rm -f verilated.mk
#	rm -f verilated.h		
