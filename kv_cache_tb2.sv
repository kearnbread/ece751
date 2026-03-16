module kv_cache_tb2;

    parameter NUM_HEADS  = 8;
    parameter HEAD_DIM   = 64;
    parameter MAX_TOKENS = 264;

    parameter int PRECISION [0:NUM_HEADS-1] = '{0,1,2, 0,1,2, 0,1};

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

    // Reference model
    logic [HEAD_DIM*16-1:0] ref_vector [0:NUM_HEADS-1][0:MAX_TOKENS-1];
    logic [15:0] ref_scale  [0:NUM_HEADS-1][0:MAX_TOKENS-1];

    kv_cache #(
        .NUM_HEADS(NUM_HEADS),
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
    ) dut (.*);

    // clock
    initial clk = 0;
    always #5 clk = ~clk;

    //---------------------------------------
    // Helpers
    //---------------------------------------
    task write_token(input int t, input int rand_mode);
        int h, j, val;

        wr_token = t;
        wr_valid = 1;

        for (h=0; h<NUM_HEADS; h++) begin
            wr_vector[h] = '0;

            for (j=0; j<HEAD_DIM; j++) begin

                if (rand_mode)
                    val = $urandom;
                else
                    val = (t*100 + h*10 + j); // deterministic

                case (PRECISION[h])
                    0: begin
                        wr_vector[h][j*16 +:16] = val[15:0];
                        ref_vector[h][t][j*16 +:16] = val[15:0];
                    end
                    1: begin
                        wr_vector[h][j*8 +:8] = val[7:0];
                        ref_vector[h][t][j*16 +:16] =
                            {{8{val[7]}}, val[7:0]};
                    end
                    2: begin
                        wr_vector[h][j*4 +:4] = val[3:0];
                        ref_vector[h][t][j*16 +:16] =
                            {{12{val[3]}}, val[3:0]};
                    end
                endcase
            end

            wr_scale[h] = rand_mode ? $urandom_range(1,100) : (t*2+h);

            if (PRECISION[h]==0)
                ref_scale[h][t] = 16'h3C00;
            else
                ref_scale[h][t] = wr_scale[h];
        end

        @(posedge clk);
        wr_valid = 0;
    endtask


    task check_token(input int t);
        int h, j;

        for (h=0; h<NUM_HEADS; h++) begin

            if (rd_vector[h] !== ref_vector[h][t]) begin
                $display("VECTOR MISMATCH token=%0d head=%0d", t, h);
                $display("RD=%h REF=%h", rd_vector[h], ref_vector[h][t]);

                for (j=0; j<HEAD_DIM; j++) begin
                    $display(" elem[%0d]: RD=%h REF=%h",
                        j,
                        rd_vector[h][j*16 +:16],
                        ref_vector[h][t][j*16 +:16]);
                end
                $stop;
            end

            if (rd_scale[h] !== ref_scale[h][t]) begin
                $display("SCALE MISMATCH token=%0d head=%0d", t, h);
                $display("RD=%h REF=%h", rd_scale[h], ref_scale[h][t]);
                $stop;
            end
        end
    endtask


initial begin
    int t, i;
    int token_cnt;

    //---------------------------------------
    // RESET
    //---------------------------------------
    rst_n = 0;
    wr_valid = 0;
    rd_req = 0;

    repeat(2) @(posedge clk);
    rst_n = 1;

    //---------------------------------------
    // PHASE 1: DETERMINISTIC PREFILL
    //---------------------------------------
    for (t=0; t<MAX_TOKENS; t++) begin
        write_token(t, 0);
    end

    //---------------------------------------
    // PHASE 2: RANDOM OVERWRITES
    //---------------------------------------
    for (i=0; i<MAX_TOKENS/2; i++) begin
        write_token($urandom_range(0,MAX_TOKENS-1), 1);
    end

    //---------------------------------------
    // PHASE 3: RANDOM READS (VALID ONLY)
    //---------------------------------------
    for (i=0; i<MAX_TOKENS/2; i++) begin

        int start;
        int len;

        start = $urandom_range(0, MAX_TOKENS-1);
        len   = $urandom_range(1, MAX_TOKENS - start);

        @(posedge clk);
        rd_start_token = start;
        rd_len = len;
        rd_req = 1;

        @(posedge clk);
        rd_req = 0;
		
        token_cnt = 0;

        while (token_cnt < len) begin
            if (rd_valid) begin
                check_token(start + token_cnt);
                token_cnt++;
            end
			@(posedge clk);
        end
    end

    $display("TEST PASSED");
    $stop;
end

endmodule
