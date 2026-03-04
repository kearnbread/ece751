module kv_addr_gen #(
    parameter int HEADS    = 8,
    parameter int HEAD_DIM = 64
)(
    input  logic [15:0] token,
    input  logic [7:0]  head,

    output logic [31:0] wr_addr,
    output logic [31:0] rd_addr
);

    // Flattened addressing
    // addr = token * (HEADS*HEAD_DIM) + head * HEAD_DIM
    always_comb begin
        wr_addr = token * (HEADS * HEAD_DIM) +
                  head  * HEAD_DIM;

        rd_addr = wr_addr; // symmetric for now
    end

endmodule
