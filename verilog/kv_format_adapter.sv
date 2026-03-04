module kv_format_adapter (
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    input  logic [15:0] in_data,
    input  logic [1:0]  format_mode,
    output logic [15:0] out_data
);

    /*
      format_mode:
      0 = FP16  (store as-is)
      1 = INT8  (2 per 16-bit word)
      2 = INT4  (4 per 16-bit word)
    */

    always_ff @(posedge clk) begin
        if (!rst_n)
            out_data <= 16'd0;
        else if (in_valid) begin
            case (format_mode)
                2'd0: out_data <= in_data;      // FP16 passthrough
                2'd1: out_data <= in_data;      // assume pre-packed INT8
                2'd2: out_data <= in_data;      // assume pre-packed INT4
                default: out_data <= in_data;
            endcase
        end
    end

endmodule
