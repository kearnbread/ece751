module kv_perf_counters (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic rd_en,
    input logic [1:0] format_mode
);

    logic [63:0] cycle_count;
    logic [63:0] bits_written;
    logic [63:0] bits_read;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
            bits_written <= 0;
            bits_read <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (wr_en) begin
                case(format_mode)
                    2'd0: bits_written <= bits_written + 16;
                    2'd1: bits_written <= bits_written + 16;
                    2'd2: bits_written <= bits_written + 16;
                endcase
            end

            if (rd_en)
                bits_read <= bits_read + 16;
        end
    end

endmodule
