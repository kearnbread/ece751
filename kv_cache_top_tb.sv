module kv_cache_top_tb;

    parameter NUM_HEADS  = 8;
    parameter HEAD_DIM   = 64;
    parameter MAX_TOKENS = 577;

    parameter int PRECISION [0:NUM_HEADS-1] = '{0,1,2,0,1,2,0,1};

    logic clk;
    logic rst_n;

    // WRITE
    logic [$clog2(MAX_TOKENS)-1:0] wr_token;
    logic wr_valid_K, wr_valid_V;
    logic [HEAD_DIM*16-1:0] wr_K [0:NUM_HEADS-1];
    logic [HEAD_DIM*16-1:0] wr_V [0:NUM_HEADS-1];
    logic [15:0] wr_K_scale [0:NUM_HEADS-1];
    logic [15:0] wr_V_scale [0:NUM_HEADS-1];

    // READ
    logic rd_req;
    logic [$clog2(MAX_TOKENS)-1:0] rd_start_token;
    logic [15:0] rd_len;

    // READ OUTPUTS
    logic rd_valid_K, rd_valid_V;
    logic [HEAD_DIM*16-1:0] rd_K [0:NUM_HEADS-1];
    logic [HEAD_DIM*16-1:0] rd_V [0:NUM_HEADS-1];
    logic [15:0] rd_K_scale [0:NUM_HEADS-1];
    logic [15:0] rd_V_scale [0:NUM_HEADS-1];

    // Reference arrays
    logic [HEAD_DIM*16-1:0] ref_K [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [HEAD_DIM*16-1:0] ref_V [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0] ref_K_scale [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0] ref_V_scale [0:NUM_HEADS-1][0:MAX_TOKENS-1];

    // Instantiate top
    kv_cache_top #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
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

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    //---------------------------------------
    // Helpers
    //---------------------------------------
    task write_token(input int t, input int rand_mode);
        int h, j, val;

        wr_token = t;
        wr_valid_K = 1;
        wr_valid_V = 1;

        for (h=0; h<NUM_HEADS; h++) begin
            wr_K[h] = '0;
            wr_V[h] = '0;

            for (j=0; j<HEAD_DIM; j++) begin
                if (rand_mode) val = $urandom;
                else val = (t*100 + h*10 + j);

                case (PRECISION[h])
                    0: begin
                        wr_K[h][j*16 +:16] = val[15:0];
                        wr_V[h][j*16 +:16] = val[15:0];
                        ref_K[h][t][j*16 +:16] = val[15:0];
                        ref_V[h][t][j*16 +:16] = val[15:0];
                    end
                    1: begin
                        wr_K[h][j*8 +:8] = val[7:0];
                        wr_V[h][j*8 +:8] = val[7:0];
                        ref_K[h][t][j*16 +:16] = {{8{val[7]}}, val[7:0]};
                        ref_V[h][t][j*16 +:16] = {{8{val[7]}}, val[7:0]};
                    end
                    2: begin
                        wr_K[h][j*4 +:4] = val[3:0];
                        wr_V[h][j*4 +:4] = val[3:0];
                        ref_K[h][t][j*16 +:16] = {{12{val[3]}}, val[3:0]};
                        ref_V[h][t][j*16 +:16] = {{12{val[3]}}, val[3:0]};
                    end
                endcase
            end

            wr_K_scale[h] = rand_mode ? $urandom_range(1,100) : (t*2+h);
            wr_V_scale[h] = rand_mode ? $urandom_range(1,100) : (t*2+h);

            if (PRECISION[h]==0) begin
                ref_K_scale[h][t] = 16'h3C00;
                ref_V_scale[h][t] = 16'h3C00;
            end else begin
                ref_K_scale[h][t] = wr_K_scale[h];
                ref_V_scale[h][t] = wr_V_scale[h];
            end
        end

        @(posedge clk);
        wr_valid_K = 0;
        wr_valid_V = 0;
    endtask

    task check_token(input int t);
        int h;

        for (h=0; h<NUM_HEADS; h++) begin
            if (rd_K[h] !== ref_K[h][t]) begin
                $display("K VECTOR MISMATCH token=%0d head=%0d", t, h);
                $stop;
            end
            if (rd_V[h] !== ref_V[h][t]) begin
                $display("V VECTOR MISMATCH token=%0d head=%0d", t, h);
                $stop;
            end
            if (rd_K_scale[h] !== ref_K_scale[h][t]) begin
                $display("K SCALE MISMATCH token=%0d head=%0d", t, h);
                $stop;
            end
            if (rd_V_scale[h] !== ref_V_scale[h][t]) begin
                $display("V SCALE MISMATCH token=%0d head=%0d", t, h);
                $stop;
            end
        end
    endtask

    //---------------------------------------
    // TEST
    //---------------------------------------
    initial begin
        int t, i, token_cnt;

        // RESET
        rst_n = 0;
        wr_valid_K = 0;
        wr_valid_V = 0;
        rd_req = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;

        // PHASE 1: deterministic prefill
        for (t=0; t<MAX_TOKENS; t++) write_token(t, 0);

        // PHASE 2: random overwrites
        for (i=0; i<20; i++) write_token($urandom_range(0,MAX_TOKENS-1), 1);

        // PHASE 3: read all
        @(posedge clk);
        rd_start_token = 0;
        rd_len = MAX_TOKENS;
        rd_req = 1;
        @(posedge clk);
        rd_req = 0;

        token_cnt = 0;
        while (token_cnt < MAX_TOKENS) begin
            if (rd_valid_K && rd_valid_V) begin
                check_token(token_cnt);
                token_cnt++;
            end
            @(posedge clk);
        end

        $display("TOP TEST PASSED");
        $stop;
    end

endmodule
