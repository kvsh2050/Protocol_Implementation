`timescale 1ns/1ps

// Clock at receiver is 10 MHz
// Time period = 100 ns
// Baud rate = 9600
// => CLKS_PER_BIT = 10000000 / 9600 ≈ 1042

module uart_tb;

    // Parameters
    parameter CLOCK_PERIOD_NS = 100;          // 10 MHz clock
    parameter CLKS_PER_BIT    = 1042;         // Baud 9600
    parameter BIT_PERIOD      = CLOCK_PERIOD_NS * CLKS_PER_BIT; // ns

    // REGISTERS
    reg clk;
    reg rst;
    reg rx_bit;          // Drives uart_rx serial input
    wire tx_bit;         // Output of uart_tx
    wire [7:0] data_out; // Parallel output from uart_rx

    // ---------------- RESET ----------------
    initial begin
        clk = 0;
        rst = 0;
        rx_bit = 1;      // idle line is high
        #200 rst = 1;    // assert reset
        #200 rst = 0;    // deassert reset
    end 

    // CLOCK GENERATION (10 MHz)
    always #(CLOCK_PERIOD_NS/2) clk = ~clk;

    // ---------------- TASK: Drive RX directly ----------------
    task UART_WRITE_BYTE;
        input [7:0] i_Data;
        integer ii;
        begin
            // Start bit
            rx_bit <= 1'b0;
            #(BIT_PERIOD);

            // Data bits (LSB first)
            for (ii = 0; ii < 8; ii = ii + 1) begin
                rx_bit <= i_Data[ii];
                #(BIT_PERIOD);
            end

            // Stop bit
            rx_bit <= 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    // ---------------- TEST CASE ----------------
    initial begin
        // wait until reset is released
        @(negedge rst);  
        @(posedge clk);

        // ---- Test 1: Directly stimulate RX ----
        $display("Sending 0x3F directly into RX...");
        UART_WRITE_BYTE(8'h3F);

        #(BIT_PERIOD*2);

        if (data_out == 8'h3F)
            $display("Test 1 Passed - RX received %h", data_out);
        else
            $display("Test 1 Failed - RX got %h", data_out);

        // ---- Test 2: TX→RX loopback ----
        $display("Testing TX→RX loopback...");

        // Connect TX output to RX input
        force rx_bit = tx_bit;

        // Wait long enough for TX to finish sending its hardcoded byte
        #(BIT_PERIOD*12);

        release rx_bit; // restore control if needed

        #(BIT_PERIOD*2);

        $display("Loopback RX got = %h", data_out);

        $finish;
    end 

  

    // ---------------- MODULE INSTANTIATION ----------------
    uart_rx rx (
        .clk(clk),
        .rst(rst),
        .bits(rx_bit),     // serial in
        .data_out(data_out)
    );

    uart_tx tx (
        .clk(clk),
        .rst(rst),
        .bits(tx_bit)      // serial out
    );

    // ---------------- WAVEFORM ----------------
    initial begin
        $dumpfile("build/uart.vcd");   
        $dumpvars(0, uart_tb);   
    end

endmodule
