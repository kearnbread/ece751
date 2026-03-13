module kv_quant #(
    parameter NUM_HEADS = 8,
    parameter HEAD_DIM  = 64,

    // 0 = FP16
    // 1 = INT8
    // 2 = INT4
    parameter int PRECISION [0:NUM_HEADS-1] = '{default:0}

)(
    input  logic clk,

    // input FP16 vectors
    input  logic [HEAD_DIM*16-1:0] in_vec [0:NUM_HEADS-1],

    // quantized output vectors
    output logic [HEAD_DIM*16-1:0] q_vec [0:NUM_HEADS-1],

    // scale per head
    output logic [15:0] scale [0:NUM_HEADS-1]
);

    genvar h;

    generate
    for (h = 0; h < NUM_HEADS; h++) begin : HEAD_QUANT

        integer j;

        always_comb begin

            // default
            q_vec[h] = '0;

            // placeholder scale
            scale[h] = 16'h0001;

            case (PRECISION[h])

                // -----------------------------
                // FP16 passthrough
                // -----------------------------
                0: begin
                    q_vec[h] = in_vec[h];
                end

                // -----------------------------
                // INT8 quantization
                // take upper 8 bits of FP16
                // -----------------------------
                1: begin
                    for (j = 0; j < HEAD_DIM; j++) begin
                        q_vec[h][j*8 +: 8] =
                            in_vec[h][j*16 + 8 +: 8];
                    end
                end

                // -----------------------------
                // INT4 quantization
                // take upper 4 bits of FP16
                // -----------------------------
                2: begin
                    for (j = 0; j < HEAD_DIM; j++) begin
                        q_vec[h][j*4 +: 4] =
                            in_vec[h][j*16 + 12 +: 4];
                    end
                end

                default: begin
                    q_vec[h] = in_vec[h];
                end

            endcase

        end

    end
    endgenerate

endmodule
