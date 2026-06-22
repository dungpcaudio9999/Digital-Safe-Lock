module digital_safe_lock (
    input wire CLOCK_50,
    input wire [7:0] SW,
    input wire [2:0] KEY, // KEY[0]: rst_n, KEY[1]: Enter, KEY[2]: Change Pass
    
    output wire [0:0] LEDR, // Red LED for locked/error
    output wire [0:0] LEDG, // Green LED for unlocked
    
    output wire [6:0] HEX2,
    output wire [6:0] HEX1,
    output wire [6:0] HEX0,
    
    // SRAM interface
    inout wire [15:0] SRAM_DQ,
    output wire [18:0] SRAM_ADDR,
    output wire SRAM_CE_N,
    output wire SRAM_WE_N,
    output wire SRAM_OE_N,
    output wire SRAM_UB_N,
    output wire SRAM_LB_N
);

    wire rst_n = KEY[0];
    
    // Debounce buttons
    wire enter_btn_db;
    wire change_btn_db;
    
    button_debounce db_enter (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .btn_in(KEY[1]),
        .btn_out(enter_btn_db)
    );
    
    button_debounce db_change (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .btn_in(KEY[2]),
        .btn_out(change_btn_db)
    );
    
    // Edge detection for debounced buttons (active low -> detect falling edge)
    reg enter_btn_db_reg;
    reg change_btn_db_reg;
    
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            enter_btn_db_reg <= 1'b1;
            change_btn_db_reg <= 1'b1;
        end else begin
            enter_btn_db_reg <= enter_btn_db;
            change_btn_db_reg <= change_btn_db;
        end
    end
    
    wire enter_tick = (enter_btn_db_reg == 1'b1) && (enter_btn_db == 1'b0);
    wire change_tick = (change_btn_db_reg == 1'b1) && (change_btn_db == 1'b0);
    
    // SRAM Controller connections
    wire sram_rd_en;
    wire sram_wr_en;
    wire [18:0] sram_addr;
    wire [15:0] sram_data_in;
    wire [15:0] sram_data_out;
    wire sram_ready;
    
    sram_controller sram_ctrl (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .rd_en(sram_rd_en),
        .wr_en(sram_wr_en),
        .addr_in(sram_addr),
        .data_in(sram_data_in),
        .data_out(sram_data_out),
        .ready(sram_ready),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_CE_N(SRAM_CE_N),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_OE_N(SRAM_OE_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_LB_N(SRAM_LB_N)
    );
    
    // Lock FSM connections
    wire [2:0] display_state;
    
    lock_fsm fsm_inst (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW),
        .enter_btn_tick(enter_tick),
        .change_btn_tick(change_tick),
        .sram_rd_en(sram_rd_en),
        .sram_wr_en(sram_wr_en),
        .sram_addr(sram_addr),
        .sram_data_in(sram_data_in),
        .sram_data_out(sram_data_out),
        .sram_ready(sram_ready),
        .led_red(LEDR[0]),
        .led_green(LEDG[0]),
        .display_state(display_state)
    );
    
    // HEX Display connections
    hex_display hex_inst (
        .state_in(display_state),
        .hex2(HEX2),
        .hex1(HEX1),
        .hex0(HEX0)
    );

endmodule
