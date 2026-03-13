`timescale 1ns/1ps
module kv_cache_top_tb;

    // -------------------------------
    // Parameters
    // -------------------------------
    parameter NUM_HEADS  = 4;
    parameter HEAD_DIM   = 8;       // small for simulation
    parameter MAX_TOKENS = 16;
    parameter PRECISION  = 1;       // INT8

    // -------------------------------
    // Signals
    // -------------------------------
    logic clk;
    logic rst_n;

    logic [$clog2(MAX_TOKENS)-1:0] wr_token;
    logic wr_valid_K, wr_valid_V;
    logic [HEAD_DIM*16-1:0] wr_K [0:NUM_HEADS-1];
    logic [HEAD_DIM*16-1:0] wr_V [0:NUM_HEADS-1];
    logic [15:0] wr_K_scale [0:NUM_HEADS-1];
    logic [15:0] wr_V_scale [0:NUM_HEADS-1];

    logic rd_req;
    logic [$clog2(MAX_TOKENS)-1:0] rd_start_token;
    logic [15:0] rd_len;

    logic rd_valid_K, rd_valid_V;
    logic [HEAD_DIM*16-1:0] rd_K [0:NUM_HEADS-1];
    logic [HEAD_DIM*16-1:0] rd_V [0:NUM_HEADS-1];
    logic [15:0] rd_K_scale [0:NUM_HEADS-1];
    logic [15:0] rd_V_scale [0:NUM_HEADS-1];

    // -------------------------------
    // Instantiate DUT
    // -------------------------------
    kv_cache_top #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION('{default:PRECISION})
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_token(wr_token),
        .wr_valid_K(wr_valid_K),
        .wr_valid_V(wr_valid_V),
        .wr_K(wr_K),
        .wr_V(wr_V),
        .wr_K_scale(wr_K_scale),
        .wr_V_scale(wr_V_scale),
        .rd_req(rd_req),
        .rd_start_token(rd_start_token),
        .rd_len(rd_len),
        .rd_valid_K(rd_valid_K),
        .rd_valid_V(rd_valid_V),
        .rd_K(rd_K),
        .rd_V(rd_V),
        .rd_K_scale(rd_K_scale),
        .rd_V_scale(rd_V_scale)
    );

    // -------------------------------
    // Clock
    // -------------------------------
    always #5 clk = ~clk;

    // -------------------------------
    // Reference memory
    // -------------------------------
    logic [HEAD_DIM*16-1:0] ref_K [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [HEAD_DIM*16-1:0] ref_V [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0] ref_K_scale [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0] ref_V_scale [0:NUM_HEADS-1][0:MAX_TOKENS-1];

    // -------------------------------
    // Test sequence
    // -------------------------------
    initial begin
	automatic int token_cnt = 0;
        clk = 0;
        rst_n = 0;
        wr_valid_K = 0;
        wr_valid_V = 0;
        rd_req = 0;
	

        // reset
        repeat (2) @(posedge clk);
        rst_n = 1;

        // ---------------------------
        // Step 1: Pre-fill all tokens
        // ---------------------------
        for (int t = 0; t < MAX_TOKENS; t++) begin
            @(posedge clk);
            wr_token   = t;
            wr_valid_K = 1;
            wr_valid_V = 1;
            for (int h = 0; h < NUM_HEADS; h++) begin
                wr_K[h]       = $urandom;
                wr_V[h]       = $urandom;
                wr_K_scale[h] = $urandom;
                wr_V_scale[h] = $urandom;

                // update reference
                ref_K[h][t]       = wr_K[h];
                ref_V[h][t]       = wr_V[h];
                ref_K_scale[h][t] = wr_K_scale[h];
                ref_V_scale[h][t] = wr_V_scale[h];
            end
        end

        @(posedge clk);
        wr_valid_K = 0;
        wr_valid_V = 0;

        // ---------------------------
        // Step 2: Read back all tokens
        // ---------------------------
        rd_start_token = 0;
        rd_len         = MAX_TOKENS;
        rd_req         = 1;
        @(posedge clk);
        rd_req = 0;


        while (token_cnt < 2) begin
            @(posedge clk);
            if (rd_valid_K && rd_valid_V) begin
                for (int h = 0; h < NUM_HEADS; h++) begin
                    if (rd_K[h] !== ref_K[h][token_cnt]) begin
                        $error("HEAD %0d token %0d K mismatch: expected %0h got %0h",
                               h, token_cnt, ref_K[h][token_cnt], rd_K[h]);
                    end
                    if (rd_V[h] !== ref_V[h][token_cnt]) begin
                        $error("HEAD %0d token %0d V mismatch: expected %0h got %0h",
                               h, token_cnt, ref_V[h][token_cnt], rd_V[h]);
                    end
                    if (rd_K_scale[h] !== ref_K_scale[h][token_cnt]) begin
                        $error("HEAD %0d token %0d K_scale mismatch: expected %0h got %0h",
                               h, token_cnt, ref_K_scale[h][token_cnt], rd_K_scale[h]);
                    end
                    if (rd_V_scale[h] !== ref_V_scale[h][token_cnt]) begin
                        $error("HEAD %0d token %0d V_scale mismatch: expected %0h got %0h",
                               h, token_cnt, ref_V_scale[h][token_cnt], rd_V_scale[h]);
                    end
                end
                token_cnt++;
            end
        end

        $display("ALL TOKENS READ SUCCESSFULLY!");
        $stop;
    end

endmodule
