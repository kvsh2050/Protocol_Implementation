//UART wrapper with register bank and mapping logic 
//NOTE : Here the master is CPU and slave is UART. CPU initiates the transaction both read and writes.it initiates both read and write transactions.

module uart_ip#(CLOCK_MHZ= 10_000_000)(
    input wire          clk,
    input wire          rst_w,  //active high reset from outside

    //AXI-4 INTERFACE 
    // Global
    input  wire        ACLK,
    input  wire        ARESETN,

    // Write Address Channel
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output reg        AWREADY,

    // Write Data Channel
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output reg        WREADY,

    // Write Response Channel
    output reg [1:0]  BRESP,
    output reg        BVALID,
    input  wire        BREADY,

    // Read Address Channel
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output reg        ARREADY,

    // Read Data Channel
    output reg [31:0] RDATA,
    output reg [1:0]  RRESP,
    output reg        RVALID,
    input  wire       RREADY,

    //Output pins to the board 
    output wire  uart_tx_pin,
    input wire   uart_rx_pin

);

//REGISTER BANK : 32 bit REGISTER for 32 bit CPU : totally 5 registers * 4 bytes = 20 bytes = log2(20) = 5 bits to address the registers 
//It is okay to use 5 bits for addressing, but i am taking 8 bits here for future expansion

/*
    ADDRESS(OFFSET)    |   NAME-REGISTER      |  ACCESS TYPE    |   DESCRIPTION   
    ------------------------------------------------------------------------------
    0x00               |   ENABLE /DISABLE    |   R/W           | Enable/Disable UART
    0x04               |   BAUD RATE          |   R/W           | Set Baud Rate
    0x08               |   DATA_TX            |   R/W           | Data tx from the cpu to UART
    0x0C               |   DATA_RX            |   R             | Data rx from cpu to uart
    0x10               |   STATUS             |   R             | Status Register
    ------------------------------------------------------------------------------
*/
//STATUS REGISTER BITS 
// 00 : no ops 
// 01 : valid signal rx data from uart READ
// 10 : ready signal to give the data from cpu to the uart WRITE
// others : reserved for now.



//4 bytes * 8 = 32 bits 

//REGISTER DECLARATION
reg [31:0] ENABLE_REG;          //0x00
reg [31:0] BAUD;                //0x04
reg [31:0] DATA_TX;             //0x08
reg [31:0] DATA_RX;             //0x0C
reg [31:0] STATUS;              //0x10


//AXI LITE LOGIC 
reg [7:0] wa_addr;

//axi write address channel : as a slave device it controls the ready signal
always@(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
        AWREADY <= 0;
    end else begin
        if(AWVALID && !AWREADY) begin
            //get the output in that address
            AWREADY <= 1;
            wa_addr <= AWADDR[7:0];  //note put offset address
        end 
        else begin
            AWREADY <= 0;
        end
    end
end


//axi write data channel 
always@(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
        WREADY <= 0;
    end else begin
        if(WVALID && !WREADY) begin
            WREADY <= 1;
            //write the data to the register based on the address
            case(wa_addr)
                8'h00: ENABLE_REG <= {WSTRB[3] ? WDATA[31:24] : 0, WSTRB[2] ? WDATA[23:16] : 0, WSTRB[1] ? WDATA[15:8] : 0, WSTRB[0] ? WDATA[7:0] : 0 }; //enable/disable register
                8'h04: BAUD <= {WSTRB[3] ? WDATA[31:24] : 0, WSTRB[2] ? WDATA[23:16] : 0, WSTRB[1] ? WDATA[15:8] : 0, WSTRB[0] ? WDATA[7:0] : 0 };  //baud rate register
                8'h08: DATA_TX <= {WSTRB[3] ? WDATA[31:24] : 0, WSTRB[2] ? WDATA[23:16] : 0, WSTRB[1] ? WDATA[15:8] : 0, WSTRB[0] ? WDATA[7:0] : 0 };;    //data tx register
                default: ; ;
                //note cannot write the read only registers, need to handle those 
            endcase
        end 
        else begin
            WREADY <= 0;
        end
    end
end

//axi write response channel
always@(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
        BRESP <= 0;
        BVALID <= 0;
    end 
    else begin
        if(WREADY && WVALID && !BVALID) begin
            BVALID <= 1;
            BRESP <= 2'b00; //OKAY response
        end 
        else if(BVALID && BREADY) begin
            BVALID <= 0;
        end
    end 
end 

//Rx data initiation from the CPU 
//Read Address Channel
reg [7:0] ra_addr;

always@(posedge ACLK or negedge ARESETN) begin //as the reset is asynchronous active low
    if(!ARESETN) begin
        ARREADY <= 0;
        ra_addr <= 0;
    end
    else begin
        if(!ARREADY && ARVALID) begin
            ARREADY <= 1;
            ra_addr <= ARADDR[7:0];
        end 
        else begin
            ARREADY <= 0;
        end  
    end 
end 

//Read data channel -> need to add the status too.
always@(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
        RVALID <= 0;
        RRESP <= 0;
        RDATA <= 0;
    end 
    else begin
        if(ARREADY && ARVALID && !RVALID) begin
            RVALID <= 1;
            RRESP <= 2'b00; //OKAY response
            case(ra_addr)
                8'h00: RDATA <= ENABLE_REG;
                8'h04: RDATA <= BAUD_RATE;
                8'h0C: RDATA <= DATA_RX; //data rx register
                8'h10: RDATA <= STATUS;  //status register
                default: RDATA <= 32'b0;
            endcase
        end 
        else if(RVALID && RREADY) begin
            RVALID <= 0;
        end
    end
end 

//MAPPING LOGIC 
//Now the data is stored in the resisiter block now need to map it to the rtl signals
//Write reg
assign rst = ENABLE_REG[0] ? 1'b0 : ((rst_w)? 1 : 0 ); // Active high reset when UART is disabled
assign cpu_tx_data =  DATA_TX[7:0];
//Read reg
assign  DATA_RX[7:0] = cpu_rx_data; 
//Baud rate only write reg 
localparam BAUD = BAUD_RATE;
//if data out is valid then you must set the status register to 1. else dont care.

//----------------------------
//SEPERATE LOGIC FOR STATUS REGISTER
//-------------------------------
always@(posedge clk) begin
    if(rst) begin
        STATUS <= 32'b0;
    end 
    else begin
        if(cpu_rx_valid && ! cpu_rx_ready) begin // read the data from uart
            cpu_rx_ready <= 1'b1;
            STATUS <= 2'b01;
        end 
    end 
end 

always@(posedge clk) begin
    if(rst) begin
        STATUS <= 32'b0; //no ops
    end 
    else begin
        if(cpu_tx_ready) begin // read the data from uart
            cpu_tx_valid <= 1'b1;
            STATUS <= 2'b10;
        end 
    end 
end 

//--------------------------------------
// UART TOP Instantiation
//--------------------------------------
uart_top #(
    .BAUD_RATE (BAUD),          // UART baud rate
    .CLOCK_MHZ (CLOCK_MHZ)     // System clock frequency in Hz
) uart_top_inst (
    // Global
    .clk              (clk),               // System clock
    .rst              (rst),               // Active-high reset

    // CPU <-> UART interface
    .data_cpu_tx       (cpu_tx_data),      // 8-bit data from CPU to UART
    .data_cpu_tx_valid (cpu_tx_valid),     // CPU asserts when data is valid
    .data_cpu_tx_ready (cpu_tx_ready),     // UART signals ready for next byte
    .data_cpu_rx       (cpu_rx_data),      // Data received by UART
    .data_cpu_rx_valid (cpu_rx_valid),     // UART asserts when RX data is valid
    .data_cpu_rx_ready (cpu_rx_ready),     // CPU asserts when it consumes RX data

    // Board-level pins
    .tx_out           (uart_tx_pin),       // UART TX -> goes to board connector
    .rx_out           (uart_rx_pin)        // UART RX <- comes from board connector
);


endmodule 