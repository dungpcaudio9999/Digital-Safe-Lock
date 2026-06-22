module sram_controller (
    input wire clk,
    input wire rst_n,
    
    // User interface
    input wire rd_en,
    input wire wr_en,
    input wire [18:0] addr_in,
    input wire [15:0] data_in,
    output reg [15:0] data_out,
    output reg ready,
    
    // SRAM physical interface
    inout wire [15:0] SRAM_DQ,
    output reg [18:0] SRAM_ADDR,
    output reg SRAM_CE_N,
    output reg SRAM_WE_N,
    output reg SRAM_OE_N,
    output wire SRAM_UB_N,
    output wire SRAM_LB_N
);

    // Byte enables always active (we use 16-bit words)
    assign SRAM_UB_N = 1'b0;
    assign SRAM_LB_N = 1'b0;

    localparam IDLE    = 3'd0;
    localparam R_WAIT  = 3'd1;
    localparam R_DONE  = 3'd2;
    localparam W_SETUP = 3'd3;
    localparam W_WAIT  = 3'd4;
    localparam W_DONE  = 3'd5;

    reg [2:0] state;
    
    // Control bus tri-state
    reg drive_data;
    reg [15:0] data_to_write;
    
    assign SRAM_DQ = drive_data ? data_to_write : 16'hzzzz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            data_out <= 16'd0;
            SRAM_ADDR <= 19'd0;
            SRAM_CE_N <= 1'b1;
            SRAM_WE_N <= 1'b1;
            SRAM_OE_N <= 1'b1;
            drive_data <= 1'b0;
            data_to_write <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    SRAM_CE_N <= 1'b1;
                    SRAM_WE_N <= 1'b1;
                    SRAM_OE_N <= 1'b1;
                    drive_data <= 1'b0;
                    
                    if (wr_en) begin
                        SRAM_ADDR <= addr_in;
                        data_to_write <= data_in;
                        state <= W_SETUP;
                    end else if (rd_en) begin
                        SRAM_ADDR <= addr_in;
                        state <= R_WAIT;
                        SRAM_CE_N <= 1'b0;
                        SRAM_OE_N <= 1'b0;
                    end
                end
                
                R_WAIT: begin
                    // One cycle wait for data to be valid from SRAM
                    // SRAM guarantees 10ns, clk is 20ns, so it's ready now
                    data_out <= SRAM_DQ;
                    ready <= 1'b1;
                    state <= R_DONE;
                end
                
                R_DONE: begin
                    // Wait for rd_en to go low before returning to IDLE
                    if (!rd_en) begin
                        state <= IDLE;
                        SRAM_CE_N <= 1'b1;
                        SRAM_OE_N <= 1'b1;
                        ready <= 1'b0;
                    end
                end
                
                W_SETUP: begin
                    // Address is stable, now assert CE, WE, and drive Data
                    SRAM_CE_N <= 1'b0;
                    SRAM_WE_N <= 1'b0;
                    drive_data <= 1'b1;
                    state <= W_WAIT;
                end
                
                W_WAIT: begin
                    // Hold WE low for 1 cycle, then deassert
                    SRAM_WE_N <= 1'b1;
                    ready <= 1'b1;
                    state <= W_DONE;
                end
                
                W_DONE: begin
                    // Wait for wr_en to go low
                    if (!wr_en) begin
                        state <= IDLE;
                        SRAM_CE_N <= 1'b1;
                        drive_data <= 1'b0;
                        ready <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
