module hex_display (
    input wire [2:0] state_in,
    output reg [6:0] hex2, // Leftmost of the 3
    output reg [6:0] hex1, // Middle
    output reg [6:0] hex0  // Rightmost
);

    // Active low 7-segment encoding
    localparam CHAR_O = 7'h40;
    localparam CHAR_P = 7'h0C;
    localparam CHAR_n = 7'h2B;
    
    localparam CHAR_E = 7'h06;
    localparam CHAR_r = 7'h2F;
    
    localparam CHAR_C = 7'h46;
    localparam CHAR_h = 7'h0B;
    localparam CHAR_g = 7'h10;
    
    localparam CHAR_DASH = 7'h3F;

    always @(*) begin
        case (state_in)
            3'd0: begin // IDLE
                hex2 = CHAR_DASH;
                hex1 = CHAR_DASH;
                hex0 = CHAR_DASH;
            end
            3'd1: begin // OPN
                hex2 = CHAR_O;
                hex1 = CHAR_P;
                hex0 = CHAR_n;
            end
            3'd2: begin // ERR
                hex2 = CHAR_E;
                hex1 = CHAR_r;
                hex0 = CHAR_r;
            end
            3'd3: begin // CHG
                hex2 = CHAR_C;
                hex1 = CHAR_h;
                hex0 = CHAR_g;
            end
            default: begin
                hex2 = CHAR_DASH;
                hex1 = CHAR_DASH;
                hex0 = CHAR_DASH;
            end
        endcase
    end

endmodule
