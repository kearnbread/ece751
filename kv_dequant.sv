module kv_dequant #(
    parameter NUM_HEADS  = 8,
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024,

    // Precision per head: 0=FP16, 1=INT8, 2=INT4
    parameter int PRECISION [0:NUM_HEADS-1] = '{default:0}
)(
    input  logic clk,
    input  logic rst_n,

    // Inputs from KV cache
    input  logic [HEAD_DIM*16-1:0] rd_vector [0:NUM_HEADS-1],
    input  logic [15:0]            rd_scale  [0:NUM_HEADS-1],

    output logic [HEAD_DIM*16-1:0] dequant_vector [0:NUM_HEADS-1],
    output logic [15:0]            dequant_scale  [0:NUM_HEADS-1]
);

    // ---------------------------------------------------------
    // Helper functions: multiply int value by scale → FP16
    // ---------------------------------------------------------
    function logic [15:0] int8_to_fp16(input logic [15:0] val16, input logic [15:0] scale);
        logic signed [7:0] v;
        logic [15:0] result;
        begin
            v = val16[7:0]; // lower 8 bits
            // simple model: cast to FP16 = val * scale
            // here we just store val*scale in 16-bit for abstraction
            // replace with actual FP16 multiplication for real hw
            result = scale * v;
            int8_to_fp16 = result;
        end
    endfunction

    function logic [15:0] int4_to_fp16(input logic [15:0] val16, input logic [15:0] scale);
        logic signed [3:0] v;
        logic [15:0] result;
        begin
            v = val16[3:0];
            result = scale * v;
            int4_to_fp16 = result;
        end
    endfunction

    // ---------------------------------------------------------
    // Dequant pipeline per head
    // ---------------------------------------------------------
    generate
    for (genvar h = 0; h < NUM_HEADS; h++) begin : dequant_heads
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                dequant_vector[h] <= '0;
                dequant_scale[h]  <= '0;
            end else begin
                case (PRECISION[h])
                    0: dequant_vector[h] <= rd_vector[h]; // FP16 pass-through
                    1: begin // INT8 → FP16
                        for (int j = 0; j < HEAD_DIM; j++) begin
                            dequant_vector[h][j*16 +:16] <=
                                int8_to_fp16(rd_vector[h][j*16 +:16], rd_scale[h]);
                        end
                    end
                    2: begin // INT4 → FP16
                        for (int j = 0; j < HEAD_DIM; j++) begin
                            dequant_vector[h][j*16 +:16] <=
                                int4_to_fp16(rd_vector[h][j*16 +:16], rd_scale[h]);
                        end
                    end
                    default: dequant_vector[h] <= rd_vector[h];
                endcase
                dequant_scale[h] <= rd_scale[h];
            end
        end
    end
    endgenerate

endmodule

function logic [15:0] int_to_fp16(input logic signed [15:0] val);
    logic sign;
    logic [15:0] abs_val;
    logic [4:0] exponent;   // 5-bit exponent
    logic [9:0] fraction;   // 10-bit fraction
    int msb_pos;
    logic [15:0] fp16_bits;

    begin
        // Step 1: determine the sign
        sign = (val < 0);

        // Step 2: get absolute value
        abs_val = sign ? -val : val;

        // Step 3: find the position of the highest set bit
        // This will determine the exponent
        msb_pos = -1;
        for (int i = 15; i >= 0; i--) begin
            if (abs_val[i]) begin
                msb_pos = i;
                break;
            end
        end

        // Step 4: handle zero
        if (msb_pos == -1) begin
            // value is zero → FP16 zero
            fp16_bits = 16'h0000;
        end else begin
            // Step 5: exponent = msb_pos + bias (15)
            exponent = msb_pos + 15;

            // Step 6: shift abs_val to fill fraction (10 bits)
            // FP16 fraction does NOT include the implicit leading 1
            // So shift left to put MSB at bit 10
            fraction = (abs_val << (10 - msb_pos)) & 10'h3FF;

            // Step 7: assemble FP16 bits
            fp16_bits = {sign, exponent, fraction};
        end

        int_to_fp16 = fp16_bits;
    end
endfunction
