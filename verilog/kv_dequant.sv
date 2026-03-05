module kv_dequant #(
    parameter HEAD_DIM = 64
)(
    input  logic [HEAD_DIM*16-1:0] in_vector,
    input  logic [1:0] precision,
    input  logic [15:0] scale,

    output logic [HEAD_DIM*16-1:0] out_vector
);

integer i;

always_comb begin

    case (precision)

        2'd0:
            out_vector = in_vector;

        2'd1: begin
            for (i=0;i<HEAD_DIM;i++)
                out_vector[i*16 +: 16] =
                    {{8{in_vector[i*8+7]}}, in_vector[i*8 +: 8]} * scale;
        end

        2'd2: begin
            for (i=0;i<HEAD_DIM;i++)
                out_vector[i*16 +: 16] =
                    {{12{in_vector[i*4+3]}}, in_vector[i*4 +: 4]} * scale;
        end

        default:
            out_vector = in_vector;

    endcase

end

endmodule
