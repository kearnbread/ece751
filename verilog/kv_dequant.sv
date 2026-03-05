module kv_dequant #(
    parameter HEAD_DIM = 64
)(
    input  logic [HEAD_DIM*16-1:0] in_vector,
    input  logic [1:0] precision,

    output logic [HEAD_DIM*16-1:0] out_vector
);

integer i;

always_comb begin

    out_vector = '0;

    case (precision)

        // -----------------------
        // FP16 (no change)
        // -----------------------
        2'd0: begin
            out_vector = in_vector;
        end


        // -----------------------
        // INT8 → sign extend to 16
        // -----------------------
        2'd1: begin
            for (i = 0; i < HEAD_DIM; i++) begin
                out_vector[i*16 +: 16] =
                    {{8{in_vector[i*8 + 7]}}, in_vector[i*8 +: 8]};
            end
        end


        // -----------------------
        // INT4 → sign extend to 16
        // -----------------------
        2'd2: begin
            for (i = 0; i < HEAD_DIM; i++) begin
                out_vector[i*16 +: 16] =
                    {{12{in_vector[i*4 + 3]}}, in_vector[i*4 +: 4]};
            end
        end


        default: begin
            out_vector = in_vector;
        end

    endcase

end

endmodule