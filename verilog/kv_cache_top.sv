module kv_cache_top #(
    parameter NUM_HEADS  = 8,
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024,

    // Precision per head
    parameter int PRECISION [0:NUM_HEADS-1] = '{default:0}
)(
    input  logic clk,
    input  logic rst_n,

    // WRITE
    input  logic wr_valid,
    input  logic wr_is_value,   // 0 = write K, 1 = write V
    input  logic [$clog2(MAX_TOKENS)-1:0] wr_token,

    input  logic [HEAD_DIM*16-1:0] wr_vector [0:NUM_HEADS-1],
    input  logic [15:0]            wr_scale  [0:NUM_HEADS-1],

    // READ STREAM
    input  logic rd_req,
    input  logic [$clog2(MAX_TOKENS)-1:0] rd_start_token,
    input  logic [15:0] rd_len,

    output logic rd_valid,

    // READ OUTPUTS
    output logic [HEAD_DIM*16-1:0] rd_K [0:NUM_HEADS-1],
    output logic [HEAD_DIM*16-1:0] rd_V [0:NUM_HEADS-1],

    output logic [15:0] rd_K_scale [0:NUM_HEADS-1],
    output logic [15:0] rd_V_scale [0:NUM_HEADS-1]
);

    // ---------------------------------------------------
    // Write routing
    // ---------------------------------------------------

    logic K_wr_valid;
    logic V_wr_valid;

    assign K_wr_valid = wr_valid & ~wr_is_value;
    assign V_wr_valid = wr_valid &  wr_is_value;

    // ---------------------------------------------------
    // K CACHE
    // ---------------------------------------------------

    kv_cache #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
    ) K_cache (

        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(K_wr_valid),
        .wr_token(wr_token),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),

        .rd_req(rd_req),
        .rd_start_token(rd_start_token),
        .rd_len(rd_len),

        .rd_valid(),  // not used here

        .rd_vector(rd_K),
        .rd_scale(rd_K_scale)
    );

    // ---------------------------------------------------
    // V CACHE
    // ---------------------------------------------------

    kv_cache #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
    ) V_cache (

        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(V_wr_valid),
        .wr_token(wr_token),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),

        .rd_req(rd_req),
        .rd_start_token(rd_start_token),
        .rd_len(rd_len),

        .rd_valid(rd_valid),

        .rd_vector(rd_V),
        .rd_scale(rd_V_scale)
    );

endmodule
