module kv_cache_tb;

    parameter NUM_HEADS  = 1;
    parameter HEAD_DIM   = 2;
    parameter MAX_TOKENS = 8;

    // 0 = FP16, 1 = INT8, 2 = INT4
    parameter int PRECISION [0:NUM_HEADS-1] = '{default:1};

    logic clk;
    logic rst_n;

    // WRITE
    logic wr_valid;
    logic [$clog2(MAX_TOKENS)-1:0] wr_token;
    logic [HEAD_DIM*16-1:0] wr_vector [0:NUM_HEADS-1];
    logic [15:0] wr_scale  [0:NUM_HEADS-1];

    // READ
    logic rd_req;
    logic [$clog2(MAX_TOKENS)-1:0] rd_start_token;
    logic [15:0] rd_len;

    logic rd_valid;
    logic [HEAD_DIM*16-1:0] rd_vector [0:NUM_HEADS-1];
    logic [15:0] rd_scale  [0:NUM_HEADS-1];

    // Reference model (always FP16 expanded)
    logic [HEAD_DIM*16-1:0] ref_vector [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0]            ref_scale  [0:NUM_HEADS-1][0:MAX_TOKENS-1];

    kv_cache #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(wr_valid),
        .wr_token(wr_token),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),

        .rd_req(rd_req),
        .rd_start_token(rd_start_token),
        .rd_len(rd_len),

        .rd_valid(rd_valid),
        .rd_vector(rd_vector),
        .rd_scale(rd_scale)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk;

    int val;

initial begin

    int token_cnt;

    rst_n = 0;
    wr_valid = 0;
    rd_req = 0;

    repeat(2) @(posedge clk);
    rst_n = 1;

    val = 0;

    //---------------------------------------
    // WRITE PHASE
    //---------------------------------------

    for (int t=0; t<MAX_TOKENS; t++) begin

        @(posedge clk);

        wr_token = t;
        wr_valid = 1;

        for (int h=0; h<NUM_HEADS; h++) begin

            int elem_bits;

            case (PRECISION[h])
                0: elem_bits = 16;
                1: elem_bits = 8;
                2: elem_bits = 4;
                default: elem_bits = 16;
            endcase

wr_vector[h] = '0;

for (int j=0; j<HEAD_DIM; j++) begin

    val++;

    case (PRECISION[h])

        // ---------------- FP16 ----------------
        0: begin
            wr_vector[h][j*16 +: 16] = val[15:0];
            ref_vector[h][t][j*16 +: 16] = val[15:0];
        end

        // ---------------- INT8 ----------------
        1: begin
            wr_vector[h][j*8 +: 8] = val[7:0];
            ref_vector[h][t][j*16 +: 16] =
                {{8{val[7]}}, val[7:0]};
        end

        // ---------------- INT4 ----------------
        2: begin
            wr_vector[h][j*4 +: 4] = val[3:0];
            ref_vector[h][t][j*16 +: 16] =
                {{12{val[3]}}, val[3:0]};
        end

    endcase

end

            wr_scale[h] = t*2 + h;
            ref_scale[h][t] = wr_scale[h];

        end
    end

    @(posedge clk);
    wr_valid = 0;

    //---------------------------------------
    // READ PHASE
    //---------------------------------------

    rd_start_token = 0;
    rd_len = MAX_TOKENS;

    @(posedge clk);
    rd_req = 1;

    @(posedge clk);
    rd_req = 0;

    token_cnt = 0;

    while (token_cnt < MAX_TOKENS) begin

        @(posedge clk);

        if (rd_valid) begin

            for (int h=0; h<NUM_HEADS; h++) begin

                $display(
                "TOKEN %0d HEAD %0d: RD_VECTOR=%h (REF=%h) RD_SCALE=%0d (REF=%0d)",
                token_cnt,
                h,
                rd_vector[h],
                ref_vector[h][token_cnt],
                rd_scale[h],
                ref_scale[h][token_cnt]);

                if (rd_vector[h] !== ref_vector[h][token_cnt]) begin
                    $display("VECTOR MISMATCH!");
                    $stop;
                end

                if (rd_scale[h] !== ref_scale[h][token_cnt]) begin
                    $display("SCALE MISMATCH!");
                    $stop;
                end

            end

            token_cnt++;

        end
    end

    $display("TEST COMPLETE");
    $stop;

end

endmodule
