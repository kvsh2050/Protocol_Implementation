//UART wrapper with register bank and mapping logic 

module uart_ip(
    input clk,
    input rst,

    //AXI-4 INTERFACE 


);

//REGISTER BANK 

/*
    ADDRESS(OFFSET)    |   NAME-REGISTER      |  ACCESS TYPE    |   DESCRIPTION   
    ------------------------------------------------------------------------------
    0x00               |   ENABLE /DISABLE    |   R/W           | Enable/Disable UART
    0x04               |   BAUD RATE          |   R/W           | Set Baud Rate
    0x08               |   DATA               |   R/W           | Data Register
    0x0C               |   STATUS             |   R             | Status Register
    ------------------------------------------------------------------------------
*/



    

//MAPPING LOGIC 


//INSTANTIATION

endmodule 