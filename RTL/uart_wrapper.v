// -----------------------------------------------------------------------------
// uart_ip.v
// UART wrapper with AXI4-Lite register bank and mapping logic
//
// - Single-clock AXI4-Lite slave on ACLK / ARESETN (active-low reset).
// - Register map (word offsets):
//     0x00 : ENABLE_REG   (R/W)  bit0 = 1 -> UART enabled (default = 1)
//     0x04 : BAUD_REG     (R/W)  UART baud configuration (platform-specific)
//     0x08 : DATA_TX_REG  (W)    Write: CPU writes byte to transmit (byte lanes used)
//     0x0C : DATA_RX_REG  (R)    Read: CPU reads last received byte (LSB valid)
//     0x10 : STATUS_REG   (R)    [1:0] status: 00=idle, 01=RX valid, 10=TX ready
//
// - AXI4-Lite behavior:
//     * Accepts AW and W in any order and responds with BVALID when both captured.
//     * Byte-strobe (WSTRB) merges with existing register contents for writes.
//     * Read channel responds after AR handshake; RVALID held until RREADY.
// - Ports to uart_top are local wires/regs named cpu_* to mirror the UART core API.
// - This module assumes the UART core uses ACLK domain as well. If your uart_top
//   runs in a different clock domain, add CDC synchronizers.
//
// -----------------------------------------------------------------------------


module uart_ip #(
    parameter integer CLOCK_MHZ = 10_000_000
)(
    // Single global clock/reset for this IP (ACLK/ARESETN)
    input  wire         ACLK,
    input  wire         ARESETN,    // active-low reset

    // AXI4-Lite Write Address Channel
    input  wire [31:0]  AWADDR,
    input  wire         AWVALID,
    output reg          AWREADY,

    // AXI4-Lite Write Data Channel
    input  wire [31:0]  WDATA,
    input  wire [3:0]   WSTRB,
    input  wire         WVALID,
    output reg          WREADY,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]   BRESP,
    output reg          BVALID,
    input  wire         BREADY,

    // AXI4-Lite Read Address Channel
    input  wire [31:0]  ARADDR,
    input  wire         ARVALID,
    output reg          ARREADY,

    // AXI4-Lite Read Data Channel
    output reg  [31:0]  RDATA,
    output reg  [1:0]   RRESP,
    output reg          RVALID,
    input  wire         RREADY,

    // Board-level UART pins
    output wire         uart_tx_pin,  // TX to board (driven by uart_top)
    input  wire         uart_rx_pin   // RX from board (input to uart_top)
);

// -----------------------------------------------------------------------------
// Register bank (ACLK domain)
// -----------------------------------------------------------------------------
reg [31:0] ENABLE_REG;    // 0x00 - bit0: enable(1)/disable(0)
reg [31:0] BAUD_REG;      // 0x04 - baud or divider value
reg [31:0] DATA_TX_REG;   // 0x08 - write-only by CPU (LSB is data byte)
reg [31:0] DATA_RX_REG;   // 0x0C - read-only by CPU (LSB is received byte)
reg [31:0] STATUS_REG;    // 0x10 - read-only status register (we use bits[1:0])

// STATUS_REG bits meaning (LSB..):
//   [1:0] = 2'b00 => idle / no-op
//           2'b01 => RX data valid (CPU should read DATA_RX_REG)
//           2'b10 => TX ready (UART can accept new byte from CPU)
// other bits reserved for future use

// -----------------------------------------------------------------------------
// Internal signals connecting to uart_top (ACLK domain)
// -----------------------------------------------------------------------------
reg         cpu_tx_valid;    // asserted by software write to DATA_TX_REG, cleared when uart accepts
wire        cpu_tx_ready;    // asserted by uart_top when ready to accept new TX byte
wire [7:0]  cpu_tx_data;     // DATA_TX_REG[7:0]
wire [7:0]  cpu_rx_data;     // data from uart_top
wire        cpu_rx_valid;    // asserted by uart_top when a received byte is available
reg         cpu_rx_ack;      // pulse: CPU (IP) acknowledges the read of DATA_RX_REG

assign cpu_tx_data = DATA_TX_REG[7:0];

// Map enable/reg to local reset behavior (active-high internal reset):
// If ENABLE_REG[0]==1 -> UART enabled (internal rst_n = ARESETN)
// If ENABLE_REG[0]==0 -> force internal reset (disabled).
wire internal_reset_n = ARESETN & ENABLE_REG[0];

// -----------------------------------------------------------------------------
// AXI4-Lite write address/data decoupling (accept AW and W in any order).
// We implement simple capture flags aw_hs and w_hs and form the write response
// only when both AW and W have been captured for a single-beat write.
// -----------------------------------------------------------------------------
reg aw_hs;                // address handshake captured
reg w_hs;                 // data handshake captured
reg [31:0] awaddr_q;      // captured AWADDR (aligned to word)

wire [31:0] wmask = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };

// AWREADY and capture
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        AWREADY  <= 1'b0;
        aw_hs    <= 1'b0;
        awaddr_q <= 32'd0;
    end else begin
        // Offer AWREADY when we are not currently processing a write response
        AWREADY <= (!BVALID && !aw_hs);

        if (AWREADY && AWVALID) begin
            aw_hs    <= 1'b1;
            awaddr_q <= {AWADDR[31:2], 2'b00}; // word-aligned address (lower 2 bits ignored)
        end

        if (BVALID && BREADY) begin
            // completed last write response -> allow new transactions
            aw_hs <= 1'b0;
        end
    end
end

// WREADY and capture
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        WREADY <= 1'b0;
        w_hs   <= 1'b0;
    end else begin
        // Offer WREADY when we are ready and not currently responding
        WREADY <= (!BVALID && !w_hs);

        if (WREADY && WVALID) begin
            w_hs <= 1'b1;
        end

        if (BVALID && BREADY) begin
            // completed last write response -> allow new data
            w_hs <= 1'b0;
        end
    end
end

// Perform write when both AW and W seen; create BVALID response
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        BVALID <= 1'b0;
        BRESP  <= 2'b00;
        ENABLE_REG  <= 32'h0000_0001; // default enabled
        BAUD_REG    <= 32'd115200;    // default baud (example)
        DATA_TX_REG <= 32'd0;
        DATA_RX_REG <= 32'd0;
        STATUS_REG  <= 32'd0;
        cpu_tx_valid<= 1'b0;
        cpu_rx_ack  <= 1'b0;
    end else begin
        // When both captured and there is no pending response, commit the write
        if (aw_hs && w_hs && !BVALID) begin
            case (awaddr_q[7:0])
                8'h00: begin
                    // Enable register: merge bytes using WSTRB mask
                    ENABLE_REG <= (ENABLE_REG & ~wmask) | (WDATA & wmask);
                end

                8'h04: begin
                    // Baud register
                    BAUD_REG <= (BAUD_REG & ~wmask) | (WDATA & wmask);
                end

                8'h08: begin
                    // Write DATA_TX_REG (software requests transmit)
                    DATA_TX_REG <= (DATA_TX_REG & ~wmask) | (WDATA & wmask);
                    cpu_tx_valid <= 1'b1; // signal uart_top we have data to send
                end

                default: begin
                    // Read-only or reserved space: ignore writes
                end
            endcase

            // issue OKAY response
            BVALID <= 1'b1;
            BRESP  <= 2'b00;
        end

        // Clear BVALID on handshake from master
        if (BVALID && BREADY) begin
            BVALID <= 1'b0;
            BRESP  <= 2'b00;
        end

        // cpu_tx_valid is cleared when uart core accepts the byte (cpu_tx_ready)
        if (cpu_tx_valid && cpu_tx_ready) begin
            cpu_tx_valid <= 1'b0;
        end

        // cpu_rx_ack is a short pulse produced when CPU reads DATA_RX_REG (see read logic)
        if (cpu_rx_ack)
            cpu_rx_ack <= 1'b0;
    end
end


// -----------------------------------------------------------------------------
// AXI4-Lite read channel (AR/R)
// - ARREADY offered when not currently presenting RVALID.
// - After AR handshake, the module places RDATA/RRESP and asserts RVALID.
// - RVALID held until master asserts RREADY.
// -----------------------------------------------------------------------------
reg ar_hs;
reg [31:0] araddr_q;

always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        ARREADY <= 1'b0;
        RVALID  <= 1'b0;
        RRESP   <= 2'b00;
        RDATA   <= 32'd0;
        ar_hs   <= 1'b0;
        araddr_q<= 32'd0;
    end else begin
        ARREADY <= (!RVALID && !ar_hs);

        if (ARREADY && ARVALID) begin
            ar_hs <= 1'b1;
            araddr_q <= {ARADDR[31:2], 2'b00}; // word-aligned
        end

        if (ar_hs && !RVALID) begin
            // On the next cycle after capturing AR, present the read data
            case (araddr_q[7:0])
                8'h00: RDATA <= ENABLE_REG;
                8'h04: RDATA <= BAUD_REG;
                8'h08: RDATA <= DATA_TX_REG;   // optional: readable
                8'h0C: RDATA <= DATA_RX_REG;
                8'h10: RDATA <= STATUS_REG;
                default: RDATA <= 32'd0;
            endcase
            RRESP <= 2'b00;
            RVALID <= 1'b1;

            // If CPU reads DATA_RX_REG and there was valid RX data, acknowledge it
            if (araddr_q[7:0] == 8'h0C && STATUS_REG[1:0] == 2'b01) begin
                cpu_rx_ack <= 1'b1; // clear DATA_RX/STATUS in RX logic
            end

            ar_hs <= 1'b0;
        end

        if (RVALID && RREADY) begin
            RVALID <= 1'b0;
            RRESP  <= 2'b00;
        end
    end
end


// -----------------------------------------------------------------------------
// STATUS / DATA_RX update logic (single writer, ACLK domain).
// - DATA_RX_REG updated when uart asserts cpu_rx_valid.
// - STATUS_REG reflects rx-valid or tx-ready conditions.
// - cpu_rx_ack (pulse produced by read of DATA_RX_REG) clears RX valid.
// -----------------------------------------------------------------------------
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        DATA_RX_REG <= 32'd0;
        STATUS_REG  <= 32'd0;
    end else begin
        // Capture RX byte when UART indicates valid and we haven't acknowledged it.
        if (cpu_rx_valid && STATUS_REG[1:0] != 2'b01) begin
            DATA_RX_REG[7:0] <= cpu_rx_data;
            STATUS_REG[1:0]  <= 2'b01; // RX valid
        end

        // If CPU read acknowledged the RX byte, clear the RX valid bit
        if (cpu_rx_ack) begin
            STATUS_REG[1:0] <= 2'b00;
        end

        // Reflect TX ready as reported by uart_top
        if (cpu_tx_ready) begin
            // only set TX ready if not currently marking RX valid (RX has priority in this encoding)
            STATUS_REG[1:0] <= 2'b10;
        end

        // If neither RX valid nor TX ready, leave as 00 (idle)
        if (!cpu_rx_valid && !cpu_tx_ready && !cpu_rx_ack) begin
            STATUS_REG[1:0] <= 2'b00;
        end
    end
end


// -----------------------------------------------------------------------------
// Instantiate UART core (in the same clock/reset domain).
// - Note: adjust port names and BAUD parameter mapping to match your uart_top.
// - Ensure uart_top has ports: clk, rst_n (or rst), data_cpu_tx, data_cpu_tx_valid,
//   data_cpu_tx_ready, data_cpu_rx, data_cpu_rx_valid, data_cpu_rx_ready, tx_out, rx_in.
// -----------------------------------------------------------------------------
uart_top #(
    .BAUD_RATE (BAUD_REG[31:0]),   // if uart_top accepts a parameter; otherwise wire BAUD_REG to config port
    .CLOCK_MHZ (CLOCK_MHZ)
) uart_top_inst (
    .clk                (ACLK),
    .rst_n              (internal_reset_n),   // prefer active-low reset for cores; adapt if your core uses active-high
    .data_cpu_tx        (cpu_tx_data),
    .data_cpu_tx_valid  (cpu_tx_valid),
    .data_cpu_tx_ready  (cpu_tx_ready),
    .data_cpu_rx        (cpu_rx_data),
    .data_cpu_rx_valid  (cpu_rx_valid),
    .data_cpu_rx_ready  (/* not used - we use internal ack logic */ ),
    .tx_out             (uart_tx_pin),
    .rx_in              (uart_rx_pin)
);

// If your uart_top has active-high reset named "rst" instead of "rst_n", change the connection:
//   .rst ( ~internal_reset_n )

endmodule
