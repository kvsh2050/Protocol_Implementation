///*
//    UART TX
//    TOTAL : 10 bits
//    start bit, data bits (8), stop bit 
//    The data bit is converted from LSB to MSB and sent bit by bit 
//    Parity is added on the go 
//*/

module uart_tx#(parameter BAUD_RATE = 9600, CLOCK_MHZ = 10_000_000)(
    input  clk,
    input  rst,
    output bits,
    input  [7:0] data_in, // Data to be sent
    input  data_valid, // Data valid signal from CPU
    output data_ready_o // Data ready signal to CPU
);

    localparam CLOCKS_PER_BIT = CLOCK_MHZ/BAUD_RATE;
    localparam IDLE = 0, START=1, DATA =2, STOP =3;

    reg [1:0] state;
    reg [7:0] data_bit;     //LITTLE ENDIAN FORMAT or MSB-LSB FORMAT
    reg bit_out;
    reg [10:0] counter_1 = 0; // Counter for clock cycles
    reg [2:0] counter_2 = 0; // Counter for data bits
    reg data_ready;

    //FSM
    always@(posedge clk) begin
        if(rst) begin
            bit_out <= 1'b1; // Idle state is high
            state <= IDLE; // Reset state to IDLE
            counter_1 <= 0; // Reset clock cycle counter
            counter_2 <= 0; // Reset data bit counter
        end else begin
            //default
            case(state) 
                IDLE: begin
                    //Maintaining high state is not part of the protocol, if no data is got via peripheral it stays high. But in this code, we just provide hardcoded data to be sent. so it maintains high line for some time, till i get the data from the cpu or higher modules 
                    bit_out <= 1'b1; // Idle state is high
                    data_ready <= 1'b1;
                    if(data_valid && data_ready) begin 
                        data_bit <= data_in; // Load data to be sent
                        counter_1 <= 0; // Reset clock cycle counter
                        state <= START; // Move to START state
                    end else begin 
                        counter_1 <= 0; // Reset counter
                        state <= IDLE; // Stay in IDLE state
                    end 
                end
                START: begin
                    bit_out <= 1'b0;
                    data_ready <= 1'b0; // Reset data ready signal
                    //Maintain it till 1 clock per bit 
                    if(counter_1 < CLOCKS_PER_BIT - 1) begin
                        counter_1 <= counter_1 + 1; // Increment counter
                        state <= START; // Stay in START state
                    end else begin
                        counter_1 <= 0; // Reset counter
                        state <= DATA; // Move to DATA state
                    end
                end
                DATA: begin
                    bit_out <= data_bit[counter_2]; // Send the current data bit
                    data_ready <= 1'b0; // Reset data ready signal
                    if(counter_1 < CLOCKS_PER_BIT - 1) begin
                        counter_1 <= counter_1 + 1; // Increment counter
                        state <= DATA; // Stay in DATA state
                    end else begin
                        counter_1 <= 0; // Reset counter
                        if(counter_2 < 7) begin
                            counter_2 <= counter_2 + 1; // Move to next data bit
                            state <= DATA; // Stay in DATA state
                        end else begin
                            counter_2 <= 0; // Reset data bit counter
                            state <= STOP; // Move to STOP state after sending all data bits
                        end
                    end
                end 
                STOP: begin
                    bit_out <= 1'b1; // Stop bit is high
                    data_ready <= 1'b0; // Reset data ready signal
                    if(counter_1 < CLOCKS_PER_BIT - 1) begin
                        counter_1 <= counter_1 + 1; // Increment counter
                        state <= STOP; // Stay in STOP state
                    end else begin
                        counter_1 <= 0; // Reset counter
                        state <= IDLE; // Return to IDLE state after stop bit
                    end
                end 
            endcase
        end 
    end
    assign bits = bit_out;
    assign data_ready_o = data_ready; // Output data ready signal

endmodule