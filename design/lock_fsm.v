module lock_fsm (
    input wire clk,
    input wire rst_n,
    
    // User interface
    input wire [7:0] sw_in,
    input wire enter_btn_tick,
    input wire change_btn_tick,
    
    // SRAM controller interface
    output reg sram_rd_en,
    output reg sram_wr_en,
    output reg [18:0] sram_addr,
    output reg [15:0] sram_data_in,
    input wire [15:0] sram_data_out,
    input wire sram_ready,
    
    // Outputs
    output reg led_red,
    output reg led_green,
    output reg [2:0] display_state // 0: Blank/Line, 1: OPN, 2: ERR, 3: CHG
);

    localparam S_INIT_WR    = 4'd0;
    localparam S_INIT_WAIT  = 4'd1;
    localparam S_IDLE       = 4'd2;
    localparam S_READ_CHECK = 4'd3;
    localparam S_WAIT_CHECK = 4'd4;
    localparam S_UNLOCKED   = 4'd5;
    localparam S_ERR        = 4'd6;
    localparam S_WRITE_CHG  = 4'd7;
    localparam S_WAIT_CHG   = 4'd8;
    localparam S_CHG_DONE   = 4'd9;

    reg [3:0] state;
    reg [27:0] timer; // 50MHz, 2 seconds = 100,000,000 cycles
    localparam TIMER_2SEC = 28'd100_000_000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_INIT_WR;
            sram_rd_en <= 1'b0;
            sram_wr_en <= 1'b0;
            sram_addr <= 19'd0;
            sram_data_in <= 16'd0;
            led_red <= 1'b1; // Locked by default
            led_green <= 1'b0;
            display_state <= 3'd0;
            timer <= 28'd0;
        end else begin
            case (state)
                S_INIT_WR: begin
                    sram_wr_en <= 1'b1;
                    sram_addr <= 19'd0;
                    sram_data_in <= 16'h0000; // Default password is 00
                    state <= S_INIT_WAIT;
                end
                
                S_INIT_WAIT: begin
                    if (sram_ready) begin
                        sram_wr_en <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                
                S_IDLE: begin
                    led_red <= 1'b1;
                    led_green <= 1'b0;
                    display_state <= 3'd0; // Idle display
                    
                    if (enter_btn_tick) begin
                        sram_rd_en <= 1'b1;
                        sram_addr <= 19'd0;
                        state <= S_READ_CHECK;
                    end
                end
                
                S_READ_CHECK: begin
                    if (sram_ready) begin
                        // Data is available
                        if (sram_data_out[7:0] == sw_in) begin
                            state <= S_UNLOCKED;
                        end else begin
                            state <= S_ERR;
                            timer <= 28'd0;
                        end
                        sram_rd_en <= 1'b0;
                    end
                end
                
                S_UNLOCKED: begin
                    led_red <= 1'b0;
                    led_green <= 1'b1;
                    display_state <= 3'd1; // OPN
                    
                    if (change_btn_tick) begin
                        // Change password
                        sram_wr_en <= 1'b1;
                        sram_addr <= 19'd0;
                        sram_data_in <= {8'h00, sw_in}; // Write new password from SW
                        state <= S_WRITE_CHG;
                    end else if (enter_btn_tick) begin
                        // Lock again
                        state <= S_IDLE;
                    end
                end
                
                S_ERR: begin
                    led_red <= 1'b1;
                    led_green <= 1'b0;
                    display_state <= 3'd2; // ERR
                    
                    if (timer < TIMER_2SEC) begin
                        timer <= timer + 1'b1;
                    end else begin
                        state <= S_IDLE;
                    end
                    
                    // Allow early exit from ERR state if enter is pressed again
                    if (enter_btn_tick) begin
                        state <= S_IDLE;
                    end
                end
                
                S_WRITE_CHG: begin
                    if (sram_ready) begin
                        sram_wr_en <= 1'b0;
                        state <= S_CHG_DONE;
                        timer <= 28'd0;
                    end
                end
                
                S_CHG_DONE: begin
                    led_red <= 1'b0;
                    led_green <= 1'b1; // Still unlocked
                    display_state <= 3'd3; // CHG
                    
                    if (timer < TIMER_2SEC) begin
                        timer <= timer + 1'b1;
                    end else begin
                        state <= S_UNLOCKED; // Go back to unlocked state after showing CHG
                    end
                end
                
                default: state <= S_INIT_WR;
            endcase
        end
    end

endmodule
