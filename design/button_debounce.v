module button_debounce (
    input wire clk,
    input wire rst_n,
    input wire btn_in,
    output reg btn_out
);

    // 20ms debounce at 50MHz is 1,000,000 clock cycles.
    // 20 bits can hold up to 1,048,575
    reg [19:0] counter;
    reg btn_sync_0;
    reg btn_sync_1;

    // Double flip-flop synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b1; // Assuming active low buttons (common on DE boards)
            btn_sync_1 <= 1'b1;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 20'd0;
            btn_out <= 1'b1; // Default unpressed
        end else begin
            if (btn_sync_1 == btn_out) begin
                counter <= 20'd0; // Reset counter if no change
            end else begin
                counter <= counter + 1'b1;
                if (counter == 20'd1_000_000) begin
                    btn_out <= btn_sync_1; // Update output after stable 20ms
                    counter <= 20'd0;
                end
            end
        end
    end

endmodule
