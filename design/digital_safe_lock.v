module digital_safe_lock #(
    parameter DB_DELAY = 20'd1_000_000,         // Configurable debounce delay (1 million clock cycles at 50MHz ~ 20ms). Set to 1 for simulations.
    parameter TIMER_CYCLES = 28'd100_000_000    // Configurable 2-second timer (100 million clock cycles at 50MHz).
)(
    input  wire i_clk,          // System clock input (50MHz)
    input  wire [7:0] i_sw,     // 8 toggle switches for password input
    input  wire [2:0] i_key,    // 3 push buttons. i_key[0]: Reset, i_key[1]: Enter, i_key[2]: Change Pass. (Active Low)
    
    output wire [0:0] o_ledr,   // Red LED indicating the safe is Locked or an Error occurred
    output wire [0:0] o_ledg,   // Green LED indicating the safe is Unlocked
    
    output wire [6:0] o_hex2,   // Leftmost 7-segment display
    output wire [6:0] o_hex1,   // Middle 7-segment display
    output wire [6:0] o_hex0,   // Rightmost 7-segment display
    
    // SRAM physical interface pins routed directly to the external SRAM chip on the board
    inout  wire [15:0] io_sram_dq, // 16-bit Bi-directional Data bus
    output wire [18:0] o_sram_addr,// 19-bit Address bus
    output wire o_sram_ce_n,       // Chip Enable (Active Low)
    output wire o_sram_we_n,       // Write Enable (Active Low)
    output wire o_sram_oe_n,       // Output Enable (Active Low)
    output wire o_sram_ub_n,       // Upper Byte Enable (Active Low)
    output wire o_sram_lb_n        // Lower Byte Enable (Active Low)
);

    // Map the reset button to a dedicated wire for clarity
    wire rst_n = i_key[0];
    
    // --- Debouncer Instantiations ---
    // Physical buttons bounce, creating rapid false signals. We must filter these.
    
    wire enter_btn_state; // The stable state of the Enter button
    wire enter_tick;      // A clean 1-clock-cycle pulse when Enter is pressed
    
    button_debounce #(
        .DELAY_CYCLES(DB_DELAY) // Pass down the configurable delay
    ) db_enter (
        .i_clk(i_clk),
        .i_rst_n(rst_n),
        .i_btn(i_key[1]),             // Connect physical KEY[1] (Enter)
        .o_btn_state(enter_btn_state),
        .o_btn_tick(enter_tick)       // Retrieve the clean pulse
    );
    
    wire change_btn_state; // The stable state of the Change button
    wire change_tick;      // A clean 1-clock-cycle pulse when Change is pressed
    
    button_debounce #(
        .DELAY_CYCLES(DB_DELAY) // Pass down the configurable delay
    ) db_change (
        .i_clk(i_clk),
        .i_rst_n(rst_n),
        .i_btn(i_key[2]),             // Connect physical KEY[2] (Change Password)
        .o_btn_state(change_btn_state),
        .o_btn_tick(change_tick)      // Retrieve the clean pulse
    );
    
    // --- SRAM Controller Instantiation ---
    // This module handles the low-level timing requirements of the external memory chip
    
    wire sram_rd_en;                  // Internal read request signal
    wire sram_wr_en;                  // Internal write request signal
    wire [18:0] sram_addr_internal;   // Internal address bus
    wire [15:0] sram_data_to_ctrl;    // Data flowing from FSM into SRAM Controller
    wire [15:0] sram_data_from_ctrl;  // Data flowing from SRAM Controller into FSM
    wire sram_ready;                  // Handshake signal indicating memory operation is done
    
    sram_controller sram_ctrl (
        .i_clk(i_clk),
        .i_rst_n(rst_n),
        
        // FSM Interface
        .i_rd_en(sram_rd_en),
        .i_wr_en(sram_wr_en),
        .i_addr(sram_addr_internal),
        .i_data(sram_data_to_ctrl),
        .o_data(sram_data_from_ctrl),
        .o_ready(sram_ready),
        
        // Physical Pins
        .io_sram_dq(io_sram_dq),
        .o_sram_addr(o_sram_addr),
        .o_sram_ce_n(o_sram_ce_n),
        .o_sram_we_n(o_sram_we_n),
        .o_sram_oe_n(o_sram_oe_n),
        .o_sram_ub_n(o_sram_ub_n),
        .o_sram_lb_n(o_sram_lb_n)
    );
    
    // --- Central Lock FSM Instantiation ---
    // The "Brain" of the digital safe, managing states and password verification
    
    wire [2:0] display_state; // Internal bus carrying the current display code to the HEX display module
    
    lock_fsm #(
        .TIMER_CYCLES(TIMER_CYCLES) // Pass down the configurable timer length
    ) fsm_inst (
        .i_clk(i_clk),
        .i_rst_n(rst_n),
        
        // UI Inputs
        .i_sw(i_sw),
        .i_enter_tick(enter_tick),
        .i_change_tick(change_tick),
        
        // Communication with the SRAM controller
        .o_sram_rd_en(sram_rd_en),
        .o_sram_wr_en(sram_wr_en),
        .o_sram_addr(sram_addr_internal),
        .o_sram_data_out(sram_data_to_ctrl),
        .i_sram_data(sram_data_from_ctrl),
        .i_sram_ready(sram_ready),
        
        // UI Outputs
        .o_ledr(o_ledr[0]),
        .o_ledg(o_ledg[0]),
        .o_display_state(display_state)
    );
    
    // --- HEX Display Instantiation ---
    // Translates the FSM's state codes into physical 7-segment LED patterns
    
    hex_display hex_inst (
        .i_state(display_state), // Receives the display code from the FSM
        .o_hex2(o_hex2),
        .o_hex1(o_hex1),
        .o_hex0(o_hex0)
    );

endmodule
