RTL        := $(PWD)/RTL
DRIVER     := $(PWD)/Driver
APPLICATION:= $(PWD)/Application
BUILD      := $(PWD)/build


all : uart_rtl

uart_rtl: $(RTL)/uart_rx.v $(RTL)/uart_tx.v $(RTL)/uart_tb.sv
	iverilog -o $(BUILD)/uart_tb.vvp $(RTL)/uart_tb.sv $(RTL)/uart_rx.v $(RTL)/uart_tx.v 
	vvp $(BUILD)/uart_tb.vvp
	gtkwave $(BUILD)/uart.vcd



clean: 
	rm -rf $(BUILD)/*.vvp $(BUILD)/*.vcd

git:
	git add .
	git commit -m "Update Verilator"
	git push origin main