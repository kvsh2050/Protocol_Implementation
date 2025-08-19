///*
//    UART :
//    Start Bit : 1
//    Data Bit  : 7
//    Parity    : 1
//    Stop Bit  : 1
//    Total     : 10
//*/

//Wrong in state logic. i might need to use the edge based method tmr @edge based method 

module uart_rx(
    input clk,
    input rst,      // Active high reset
    input bits      // Serial data in (LSB first)
);

reg [6:0] bits_reg;          // store 7-bit data
reg [2:0] i;                 // bit counter
reg parity_adder;
reg correct_frame;

localparam START_BIT  = 0,
           DATA_BITS  = 1,
           PARITY_BIT = 2,
           STOP_BIT   = 3;

reg [1:0] state, next_state;

// SEQUENTIAL: state update
always @(posedge clk) begin
    if (rst)
        state <= START_BIT;
    else
        state <= next_state;
end

// COMBINATIONAL: next state logic
always @(*) begin
    case (state)
        START_BIT  : next_state = (!bits) ? DATA_BITS : START_BIT; // wait for start bit = 0
        DATA_BITS  : next_state = (i == 6) ? PARITY_BIT : DATA_BITS;
        PARITY_BIT : next_state = STOP_BIT;
        STOP_BIT   : next_state = START_BIT;
        default    : next_state = START_BIT;
    endcase
end

// SEQUENTIAL: outputs + counters
always @(posedge clk) begin
    if (rst) begin
        bits_reg      <= 0;
        i             <= 0;
        parity_adder  <= 0;
        correct_frame <= 0;
    end else begin
        case (state)
            START_BIT: begin
                i <= 0;
                parity_adder <= 0;
                correct_frame <= 0;
            end

            DATA_BITS: begin
                bits_reg[i] <= bits;              // shift in data bit
                parity_adder <= parity_adder + bits;
                i <= i + 1;
            end

            PARITY_BIT: begin
                // simple parity check (even parity assumed)
                correct_frame <= (parity_adder == bits);
            end

            STOP_BIT: begin
                // could check stop bit == 1 here if desired
                i <= 0;
            end
        endcase
    end
end

endmodule

