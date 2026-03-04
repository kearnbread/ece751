module kv_metadata_store #(
    parameter int DEPTH = 65536
)(
    input  logic clk,
    input  logic wr_en,
    input  logic [31:0] addr,
    input  logic [15:0] scale_in
);

    logic [15:0] scale_mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr_en)
            scale_mem[addr] <= scale_in;
    end

endmodule
