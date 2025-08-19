
install:
	@echo "Installing Verilator..."
	@sudo apt-get install verilator

verilator: alu.sv
	verilator --cc alu.sv
#For system C -sc, CPP - verilator --sc alu.sv
	verilator -Wall --trace -cc alu.sv --exe tb_alu.cpp
	make -C obj_dir -f Valu.mk 
	./obj_dir/Valu
	gtkwave waveform.vcd

clean:
	rm -rf obj_dir
	rm -f Valu
	rm -f waveform.vcd
	rm -f Valu.mk
	rm -f Valu.h
	rm -f Valu__ALL.a
	rm -f Valu__Syms.h
	rm -f Valu__Syms.cpp
	rm -f VerilatedVcdC.h
	rm -f VerilatedVcdC.cpp
	rm -f Verilated.h
	rm -f Verilated.cpp
	rm -f verilated.mk
	rm -f verilated.h		
