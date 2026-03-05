module kv_cache #(
    parameter NUM_HEADS  = 8,
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024
)(
    input logic clk,
    input logic rst_n,

    // WRITE
    input logic wr_valid,
    input logic wr_is_value,
    input logic [1:0] wr_precision,
    input logic [HEAD_DIM*16-1:0] wr_vector,
    input logic [15:0] wr_scale,
    input logic [$clog2(NUM_HEADS)-1:0] wr_head,
    input logic [$clog2(MAX_TOKENS)-1:0] wr_token,

    // READ STREAM
    input logic rd_req,
    input logic [$clog2(MAX_TOKENS)-1:0] rd_start_token,
    input logic [15:0] rd_len,

    output logic rd_valid,

    output logic [NUM_HEADS-1:0][HEAD_DIM*16-1:0] rd_K,
    output logic [NUM_HEADS-1:0][HEAD_DIM*16-1:0] rd_V
);

logic active;
logic [15:0] burst_cnt;
logic [$clog2(MAX_TOKENS)-1:0] cur_token;

always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        active <= 0;
        burst_cnt <= 0;
    end

    else begin

        if (rd_req) begin
            active <= 1;
            burst_cnt <= rd_len;
            cur_token <= rd_start_token;
        end

        else if (active) begin

            cur_token <= cur_token + 1;
            burst_cnt <= burst_cnt - 1;

            if (burst_cnt == 1)
                active <= 0;

        end

    end

end

assign rd_valid = active;


genvar i;

generate
for (i=0;i<NUM_HEADS;i++) begin : KV_BANKS

    kv_bank #(
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS)
    ) K_bank (

        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(wr_valid && !wr_is_value && wr_head==i),
        .wr_precision(wr_precision),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),
        .wr_token(wr_token),

        .rd_en(active),
        .rd_token(cur_token),

        .rd_vector(rd_K[i]),
        .rd_precision(),
        .rd_scale()
    );


    kv_bank #(
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS)
    ) V_bank (

        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(wr_valid && wr_is_value && wr_head==i),
        .wr_precision(wr_precision),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),
        .wr_token(wr_token),

        .rd_en(active),
        .rd_token(cur_token),

        .rd_vector(rd_V[i]),
        .rd_precision(),
        .rd_scale()
    );

end
endgenerate

endmodule
