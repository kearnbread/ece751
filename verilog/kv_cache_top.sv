module kv_cache_top #(
    parameter int HEADS        = 8,
    parameter int HEAD_DIM     = 64,
    parameter int SEQ_LEN      = 1024,
    parameter int MAX_WIDTH    = 16   // maximum input width (FP16)
)(
    input  logic clk,
    input  logic rst_n,

    // Incoming pre-quantized stream
    input  logic        in_valid,
    input  logic [15:0] in_data,        // supports FP16/INT8/INT4 packed
    input  logic [1:0]  format_mode,    // 0=FP16,1=INT8,2=INT4

    input  logic [$clog2(SEQ_LEN)-1:0] token,
    input  logic [$clog2(HEADS)-1:0]   head,

    // Metadata input (scale etc.)
    input  logic [15:0] scale_in,

    // Read side
    input  logic        rd_en,
    output logic [15:0] rd_data
);

    logic [31:0] wr_addr;
    logic [31:0] rd_addr;

    // Address generation
    kv_addr_gen #(
        .HEADS(HEADS),
        .HEAD_DIM(HEAD_DIM)
    ) addr_gen (
        .token(token),
        .head(head),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr)
    );

    // Format adapter (handles packing differences)
    logic [15:0] formatted_data;

    kv_format_adapter fmt (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .format_mode(format_mode),
        .out_data(formatted_data)
    );

    // SRAM model
    kv_sram_model mem (
        .clk(clk),
        .wr_en(in_valid),
        .wr_addr(wr_addr),
        .wr_data(formatted_data),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    // Metadata storage (separate memory)
    kv_metadata_store meta (
        .clk(clk),
        .wr_en(in_valid),
        .addr(wr_addr),
        .scale_in(scale_in)
    );

    // Performance counters
    kv_perf_counters perf (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(in_valid),
        .rd_en(rd_en),
        .format_mode(format_mode)
    );

endmodule
