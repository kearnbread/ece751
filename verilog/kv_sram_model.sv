module kv_sram_model #(
    parameter int DEPTH = 65536
)(
    input  logic clk,
    input  logic wr_en,
    input  logic [31:0] wr_addr,
    input  logic [15:0] wr_data,

    input  logic rd_en,
    input  logic [31:0] rd_addr,
    output logic [15:0] rd_data
);

    logic [15:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;

        if (rd_en)
            rd_data <= mem[rd_addr];
    end

endmodule
