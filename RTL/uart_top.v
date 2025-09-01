//UART IP for plug and play with softcore processors or SoC 

//THIS IS THE RTL WRAPEER , WILL ADD THE REG IN OTHER WRAPPER FILE
module uart_top#(BAUD_RATE = 9600, CLOCK_MHZ = 10_00_000)(
    input clk,
    input rst,

    //CPU SIDE PERIPHERALS
    input [7:0] data_cpu_tx,
    input data_cpu_tx_valid,                        // Data valid signal from CPU
    output data_cpu_tx_ready,                       // Data ready signal to CPU
    output [7:0] data_cpu_rx,                       // Data received from UART
    output data_cpu_rx_valid,                       // Data valid signal from UART to CPU
    input data_cpu_rx_ready,                        // Data ready signal from CPU to UART

    //BOARD PERIPERALS
    output tx_out,                                  // Serial data out (LSB first)
    input rx_out                                    // Serial data in (LSB first)
);

wire rx_bits;
wire tx_bits;
wire [7:0] rx_cpu_data;
wire rx_cpu_valid;
wire rx_cpu_ready;
wire tx_cpu_ready;
wire [7:0] tx_cpu_data;
wire tx_cpu_valid;


//Logic 
//UART BOARD CONNECT
assign tx_out =  tx_bits;
assign rx_bits = rx_out; 
//CPU
assign tx_cpu_data = data_cpu_tx;
assign tx_cpu_valid = data_cpu_tx_valid;
assign data_cpu_tx_ready = tx_cpu_ready; // Data ready signal to CPU
assign data_cpu_rx = rx_cpu_data; // Data received from UART
assign data_cpu_rx_valid = rx_cpu_valid; // Data valid signal from UART to CPU
assign rx_cpu_ready = data_cpu_rx_ready; // Data ready signal from CPU to UART

//Module instantiation of the UART core

//Receive and Give to CPU core
uart_rx#(.BAUD_RATE(BAUD_RATE), .CLOCK_MHZ(CLOCK_MHZ))rx(
    .clk(clk),
    .rst(rst),                                     // Active high reset
    .bits(rx_bits),                                 // Serial data in (LSB first)
    .data_out(rx_cpu_data),                            //Output 
    .data_valid(rx_cpu_valid),                          //Output data valid signal
    .data_ready(rx_cpu_ready)                           //Input
);

//take from cpu and transmit it out of fpga board
uart_tx#(.BAUD_RATE(BAUD_RATE), .CLOCK_MHZ(CLOCK_MHZ))tx(
    .clk(clk),
    .rst(rst),
    .bits(tx_bits),
    .data_in(tx_cpu_data),         // Data to be sent - Input
    .data_valid(tx_cpu_valid),      // Data valid signal from CPU - Input 
    .data_ready_o(tx_cpu_ready)     // Data ready signal to CPU - Output
);


endmodule