`timescale 1ns/1ps

module uart_tb;

// REGISTERS
reg clk;
reg rst;
reg rx_bit;
wire tx_bit;
reg [9:0] data = 10'b1110010010; //  0101010101;
integer i;

// INITIAL RESET
initial begin
    clk = 0;
    rst = 0;
    #5 rst = 1;
    #5 rst = 0;
end 

// CLOCK GENERATION
always #5 clk = ~clk;

// TEST CASE TX to RX
initial begin 
    i = 0;
    @(negedge rst);   // wait until reset is released
    @(posedge clk);
    for (i = 0; i < 10; i = i + 1) begin
        rx_bit = data[i];   // drive next bit
        @(posedge clk);     // wait 1 cycle
    end
    #20;   // wait a little more
    $finish; // stop simulation
end 

// TEST CASE TX to DISPLAY
always @(posedge clk) begin
    $display("Time=%0t TX Data=%b", $time, tx_bit);
end 

// MODULE INSTANTIATION
uart_rx rx (
    .clk(clk),
    .rst(rst),
    .bits(rx_bit)
);

uart_tx tx (
    .clk(clk),
    .rst(rst),
    .bits(tx_bit)
);
//FOR GTKWAVE
initial begin
    $dumpfile("build/uart.vcd");   // create VCD file
    $dumpvars(0, uart_tb);   // dump all signals in uart_tb
end

endmodule
