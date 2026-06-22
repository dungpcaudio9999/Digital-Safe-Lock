`timescale 1ns/1ps

module tb_digital_safe_lock();

    reg CLOCK_50;
    reg [7:0] SW;
    reg [2:0] KEY;
    
    wire LEDR;
    wire LEDG;
    wire [6:0] HEX2;
    wire [6:0] HEX1;
    wire [6:0] HEX0;
    
    wire [15:0] SRAM_DQ;
    wire [18:0] SRAM_ADDR;
    wire SRAM_CE_N;
    wire SRAM_WE_N;
    wire SRAM_OE_N;
    wire SRAM_UB_N;
    wire SRAM_LB_N;

    // Instantiate Top Module
    digital_safe_lock dut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .KEY(KEY),
        .LEDR(LEDR),
        .LEDG(LEDG),
        .HEX2(HEX2),
        .HEX1(HEX1),
        .HEX0(HEX0),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_CE_N(SRAM_CE_N),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_OE_N(SRAM_OE_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_LB_N(SRAM_LB_N)
    );

    // Simple SRAM Model
    reg [15:0] sram_mem [0:1023]; // Only model first 1024 words
    reg [15:0] sram_data_out;
    reg sram_drive_data;
    
    assign SRAM_DQ = sram_drive_data ? sram_data_out : 16'hzzzz;
    
    always @(*) begin
        sram_drive_data = 1'b0;
        sram_data_out = 16'hxxxx;
        
        if (!SRAM_CE_N) begin
            if (!SRAM_WE_N) begin
                // Write cycle
                // Note: Real SRAM writes when WE or CE goes high, but simplified behavioral here
                sram_mem[SRAM_ADDR] <= SRAM_DQ;
            end else if (!SRAM_OE_N) begin
                // Read cycle
                sram_drive_data = 1'b1;
                sram_data_out = sram_mem[SRAM_ADDR];
            end
        end
    end

    // Clock generation (50MHz = 20ns period)
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;
    end

    // --- Tasks for Modular Testing ---
    
    // Task 1: Reset the system
    task reset_system;
        begin
            KEY[0] = 1'b0;
            #100 KEY[0] = 1'b1;
            // Wait for INIT state to finish (writing 00 to SRAM)
            #200;
        end
    endtask

    // Task 2: Simulate entering a password via switches and pressing a button
    // btn_type: 1 for Enter (KEY[1]), 2 for Change (KEY[2])
    task enter_password(input [7:0] pass, input [1:0] btn_type);
        begin
            SW = pass;
            if (btn_type == 1) begin
                KEY[1] = 1'b0;
                force dut.enter_btn_db = 1'b0; // Bypass debounce
                #100;
                force dut.enter_btn_db = 1'b1;
                KEY[1] = 1'b1;
            end else if (btn_type == 2) begin
                KEY[2] = 1'b0;
                force dut.change_btn_db = 1'b0; // Bypass debounce
                #100;
                force dut.change_btn_db = 1'b1;
                KEY[2] = 1'b1;
            end
            #200; // wait for FSM to process
        end
    endtask

    // Task 3: Bypass the 2-second timer for "CHG" display
    task bypass_display_timer;
        begin
            force dut.fsm_inst.timer = 28'd100_000_000;
            #100;
            release dut.fsm_inst.timer;
            #200;
        end
    endtask

    // Task 4: Force state back to IDLE (alternative to timer bypass for ERR state)
    task force_to_idle;
        begin
            force dut.fsm_inst.state = 4'd2; // S_IDLE
            #100;
            release dut.fsm_inst.state;
            #100;
        end
    endtask

    // Task 5: Self-checking result verifier
    task check_result(input exp_ledg, input exp_ledr, input [7:0] test_id);
        begin
            if (LEDG == exp_ledg && LEDR == exp_ledr) begin
                $display("Pass: Test %0d (LEDG=%b, LEDR=%b)", test_id, LEDG, LEDR);
            end else begin
                $display("Fail: Test %0d - Expected LEDG=%b LEDR=%b, Got LEDG=%b LEDR=%b", 
                         test_id, exp_ledg, exp_ledr, LEDG, LEDR);
                $stop; // Halt simulation if a test fails
            end
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Optional: Generate waveform
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_digital_safe_lock);

        // Initialize inputs
        SW = 8'h00;
        KEY = 3'b111; // KEY is active low
        
        $display("========================================");
        $display("   DIGITAL SAFE LOCK - TESTBENCH START  ");
        $display("========================================");
        
        // 1. Reset
        reset_system();
        
        // Test 1: Unlock with default password 00
        $display("\n[Test 1] Unlock with default password (00)");
        enter_password(8'h00, 1);
        check_result(1'b1, 1'b0, 1);
        
        // Test 2: Change password to A5
        $display("\n[Test 2] Change password to A5");
        enter_password(8'hA5, 2);
        bypass_display_timer();
        $display("Password changed to A5.");
        
        // Lock it back
        $display("\nLocking the safe...");
        enter_password(8'hA5, 1);
        
        // Test 3: Try unlocking with WRONG password 11
        $display("\n[Test 3] Try unlocking with WRONG password (11)");
        enter_password(8'h11, 1);
        check_result(1'b0, 1'b1, 3); // Expect Red LED for wrong pass
        force_to_idle(); // Bypass the 2-second error display
        
        // Test 4: Unlock with NEW password A5
        $display("\n[Test 4] Unlock with NEW password (A5)");
        enter_password(8'hA5, 1);
        check_result(1'b1, 1'b0, 4);
        
        // Lock it back
        $display("\nLocking the safe...");
        enter_password(8'h00, 1); // Password value doesn't matter when locking
        
        // Test 5: Spam Wrong Password
        $display("\n[Test 5] Spam wrong password multiple times");
        enter_password(8'h99, 1);
        check_result(1'b0, 1'b1, 51);
        force_to_idle();
        
        enter_password(8'h88, 1);
        check_result(1'b0, 1'b1, 52);
        force_to_idle();

        // Test 6: Finally unlock it again
        $display("\n[Test 6] Unlock again with correct password (A5)");
        enter_password(8'hA5, 1);
        check_result(1'b1, 1'b0, 6);

        #500;
        $display("========================================");
        $display("          SIMULATION COMPLETE           ");
        $display("========================================");
        $finish;
    end

endmodule
