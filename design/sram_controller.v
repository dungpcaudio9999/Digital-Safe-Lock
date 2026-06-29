module sram_controller (
    input  wire i_clk,            // System clock (50MHz)
    input  wire i_rst_n,          // Active-low asynchronous reset
    
    // User interface (Internal connections to the FSM)
    input  wire i_rd_en,          // Read enable signal from FSM
    input  wire i_wr_en,          // Write enable signal from FSM
    input  wire [18:0] i_addr,    // Memory address to read/write
    input  wire [15:0] i_data,    // Data to be written into SRAM
    output reg  [15:0] o_data,    // Data read from SRAM
    output reg  o_ready,          // High when the read/write operation is complete
    
    // SRAM physical interface (External connections to the SRAM chip)
    inout  wire [15:0] io_sram_dq, // Bi-directional data bus 
    output reg  [18:0] o_sram_addr,// Physical address bus
    output reg  o_sram_ce_n,       // Chip Enable (Active Low)
    output reg  o_sram_we_n,       // Write Enable (Active Low)
    output reg  o_sram_oe_n,       // Output Enable (Active Low)
    output wire o_sram_ub_n,       // Upper Byte Enable (Active Low)
    output wire o_sram_lb_n        // Lower Byte Enable (Active Low)
);

    // Byte enables are always tied low (active) because we are always reading/writing full 16-bit words.
    assign o_sram_ub_n = 1'b0;
    assign o_sram_lb_n = 1'b0;

    // FSM States for the SRAM controller
    localparam IDLE    = 3'd0; // Waiting for read/write requests
    localparam R_WAIT  = 3'd1; // Wait state for read data to propagate
    localparam R_DONE  = 3'd2; // Read operation completed
    localparam W_SETUP = 3'd3; // Address and data setup phase for write
    localparam W_WAIT  = 3'd4; // Asserting Write Enable pulse
    localparam W_DONE  = 3'd5; // Write operation completed

    reg [2:0] state; // Current state of the controller
    
    // Control registers for the bi-directional data bus (io_sram_dq)
    reg drive_data;             // When High, the FPGA drives data onto the bus. When Low, bus is High-Z.
    reg [15:0] data_to_write;   // Internal buffer holding the data to be written
    
    // Tri-state buffer assignment for the physical data bus.
    // If we are writing (drive_data=1), output the buffered data. 
    // Otherwise, release the bus (High-Z) so the SRAM chip can send data to us.
    assign io_sram_dq = drive_data ? data_to_write : 16'hzzzz;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Reset all outputs and internal states to safe, inactive defaults
            state <= IDLE;
            o_ready <= 1'b0;
            o_data <= 16'd0;
            o_sram_addr <= 19'd0;
            o_sram_ce_n <= 1'b1;  // Chip disabled
            o_sram_we_n <= 1'b1;  // Write disabled
            o_sram_oe_n <= 1'b1;  // Output disabled
            drive_data <= 1'b0;   // Do not drive data bus
            data_to_write <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear ready flag and ensure physical control pins are inactive
                    o_ready <= 1'b0;
                    o_sram_ce_n <= 1'b1;
                    o_sram_we_n <= 1'b1;
                    o_sram_oe_n <= 1'b1;
                    drive_data <= 1'b0;
                    
                    if (i_wr_en) begin
                        // A write request is received. Latch the address and data.
                        o_sram_addr <= i_addr;
                        data_to_write <= i_data;
                        state <= W_SETUP;
                    end else if (i_rd_en) begin
                        // A read request is received. Latch the address.
                        o_sram_addr <= i_addr;
                        state <= R_WAIT;
                        // Assert Chip Enable and Output Enable to instruct SRAM to output data
                        o_sram_ce_n <= 1'b0;
                        o_sram_oe_n <= 1'b0;
                    end
                end
                
                R_WAIT: begin
                    // One clock cycle wait allows the SRAM chip enough time to fetch the data.
                    // (SRAM access time is ~10ns, our clock period is 20ns, so 1 cycle is sufficient).
                    // Capture the data currently on the physical bus into our output register.
                    o_data <= io_sram_dq;
                    o_ready <= 1'b1; // Signal the parent FSM that data is ready
                    state <= R_DONE;
                end
                
                R_DONE: begin
                    // Hold the ready signal until the parent FSM de-asserts the read enable request
                    if (!i_rd_en) begin
                        state <= IDLE;
                        o_sram_ce_n <= 1'b1; // De-assert Chip Enable
                        o_sram_oe_n <= 1'b1; // De-assert Output Enable
                        o_ready <= 1'b0;
                    end
                end
                
                W_SETUP: begin
                    // Write sequence: The address is already stable on the bus.
                    // Now, assert Chip Enable, Write Enable, and start driving the Data bus.
                    o_sram_ce_n <= 1'b0;
                    o_sram_we_n <= 1'b0;
                    drive_data <= 1'b1;
                    state <= W_WAIT;
                end
                
                W_WAIT: begin
                    // Hold Write Enable low for 1 clock cycle to satisfy SRAM write pulse width requirements.
                    // Then, de-assert Write Enable to finalize the write operation inside the SRAM.
                    o_sram_we_n <= 1'b1;
                    o_ready <= 1'b1; // Signal parent FSM that the write is complete
                    state <= W_DONE;
                end
                
                W_DONE: begin
                    // Hold the ready signal until the parent FSM de-asserts the write enable request
                    if (!i_wr_en) begin
                        state <= IDLE;
                        o_sram_ce_n <= 1'b1; // De-assert Chip Enable
                        drive_data <= 1'b0;  // Stop driving the data bus (return to High-Z)
                        o_ready <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
