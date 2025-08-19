///*
//    UART TX
//    TOTAL : 10 bits
//    start bit, data bits (7) , parity bit, stop bit 
//    The data bit is converted from LSB to MSB and sent bit by bit 
//    Parity is added on the go 
//*/

module uart_tx(
    input clk,
    input rst,
    output bits
);
    reg [6:0] data_bit = 7'b1010101;     //LITTLE ENDIAN FORMAT or MSB-LSB FORMAT
    reg [3:0] i;                          //Counter Variable
    reg bit_out;
    wire pari;
    //Tx FSM
    localparam START=0, CAL_PARITY=1, TRANSMIT=2, BUFF=3;
    reg [1:0]state, next_state;

    //FF
    always@(posedge clk)begin
        if(rst) begin
            state <= 0;
        end else begin
            state <= next_state;
        end 
    end 

    //Next state logic
    always@(*)begin
        case(state)
            START: begin
                next_state = CAL_PARITY;
            end
            CAL_PARITY: begin
                next_state = TRANSMIT;
            end
            TRANSMIT: begin
                next_state = (i <= 'd7) ? BUFF : TRANSMIT;  //need to include parity too so
            end 
            BUFF: begin
                next_state = START;
            end 
        endcase 
    end 

    //Output 
    always@(posedge clk) begin
        if(rst) begin
            i<= 0;
            bit_out <= 1;
        end else begin
            case(state) 
            START: begin
                bit_out <= 1;
                i <= 0;
            end
            CAL_PARITY: begin
                //start of the start bit 
                bit_out <= 0;
                i <= 0;
                //parity 
                //I have used the comb to calculate parity
            end
            TRANSMIT: begin
                if(i < 'd7) begin
                    bit_out <= data_bit[i];  //transmit LSB -> MSB first
                end 
                else if (i == 'd7) begin
                    bit_out <= pari;
                end 
                else begin
                    bit_out <= 0;
                end 
            end 
            BUFF: begin
                i <= 0;
                bit_out <=  1;
            end 
            endcase
        end 
    end
    assign bits = bit_out;
    assign pari = ^data_bit;

endmodule