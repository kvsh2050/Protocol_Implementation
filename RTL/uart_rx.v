///*
//    UART :
//    Start Bit : 1
//    Data Bit  : 8
//    Stop Bit  : 1
//    Total     : 10
//    Transmit config = 8N1
//    Receive config  = 8N1
//*/

//Wrong in state logic. i might need to use the edge based method tmr @edge based method 
//BAUD RATE in ns ?

module uart_rx#(parameter BAUD_RATE = 9600, CLOCK_MHZ = 10_000_000)(
    input clk,
    input rst,                                  // Active high reset
    input bits,                                 // Serial data in (LSB first)
    output [7:0] data_out                       //Parallel data
);

localparam CLOCKS_PER_BIT= CLOCK_MHZ/BAUD_RATE;
localparam IDLE      = 'd0,
           START     = 'd1,
           DATA_BITS = 'd2,
           STOP_BIT  = 'd3;

reg [7:0] bits_reg;          
reg [10:0] counter_1;
reg [2:0] counter_2; 
reg [2:0] state;
reg done_flag;

//LOGIC 
always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        bits_reg <= 8'b0;
        counter_1 <= 8'b0;
        counter_2 <= 8'b0; // Reset counters and state on reset
        done_flag <= 1'b0; // Reset done flag
    end else begin
        done_flag <= 1'b0; // Reset done flag on each clock cycle
        case (state)
            IDLE: begin
                counter_1 <= 0;
                bits_reg <= 8'b0; // Clear bits register
                if (bits == 0) begin // Start bit detected
                    state <= START;
                end
                else begin
                    state <= IDLE; // Stay in IDLE if no start bit
                end
            end
            
            START: begin
                if (counter_1 == (CLOCKS_PER_BIT - 1)/2) begin
                    //check if it is still 0?
                    if(bits == 0) begin
                        counter_1 <= 0; // Reset counter for data bits
                        state <= DATA_BITS; // Move to DATA_BITS state
                    end else begin
                        state <= IDLE; // If not 0, return to IDLE
                    end
                end
                else begin
                    counter_1 <= counter_1 + 1; // Increment counter until we reach the middle of the start bit
                    state <= START; // Stay in START state until the middle of the start bit is reached
                end 
            end
            
            DATA_BITS: begin
                //the next middle of the bit is clocks_per_bit apart from the middle of the start bits
                if (counter_1 < CLOCKS_PER_BIT - 1) begin
                    counter_1 <= counter_1 + 1;
                    state <= DATA_BITS; // Stay in DATA_BITS state
                end else begin
                    counter_1 <= 0; // Reset counter for next bit
                    bits_reg[counter_2] <= bits; // Store the received bit in the bits register sample at middle and go to next state if the condifiton is satisfied
                    if (counter_2 < 7) begin
                        counter_2 <= counter_2 + 1; // Move to the next bit
                        state <= DATA_BITS; // Stay in DATA_BITS state
                    end else begin
                        state <= STOP_BIT; // Move to STOP_BIT state after receiving all data bits
                        counter_2 <= 0; // Reset bit counter for next byte
                    end
                end
            end
            
            STOP_BIT: begin
                if (counter_1 < CLOCKS_PER_BIT - 1) begin
                    counter_1 <= counter_1 + 1;
                    state <= STOP_BIT; // Stay in STOP_BIT state
                end else begin
                    state <= IDLE; // Return to idle after stop bit
                    done_flag <= 1'b1; // Set done flag to indicate data reception is complete
                end
            end
            
            default: state <= IDLE; // Reset to idle on unexpected state
        endcase
    end
end

assign data_out = (done_flag)? bits_reg : 8'b0; // Output data only when in STOP_BIT state

endmodule

