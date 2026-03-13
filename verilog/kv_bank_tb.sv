module kv_bank_tb;

    parameter HEAD_DIM   = 8;     // small for simulation
    parameter MAX_TOKENS = 32;
    parameter PRECISION  = 1;     // test INT8 packing

    logic clk;

    // WRITE
    logic wr_valid;
    logic [$clog2(MAX_TOKENS)-1:0] wr_token;
    logic [HEAD_DIM*8-1:0] wr_vector;
    logic [15:0] wr_scale;

    // READ
    logic rd_en;
    logic [$clog2(MAX_TOKENS)-1:0] rd_token;
    logic [HEAD_DIM*8-1:0] rd_vector;
    logic [15:0] rd_scale;

    // DUT instance
    kv_bank #(
        .HEAD_DIM(HEAD_DIM),
        .MAX_TOKENS(MAX_TOKENS),
        .PRECISION(PRECISION)
    ) dut (
        .clk(clk),
        .wr_valid(wr_valid),
        .wr_token(wr_token),
        .wr_vector(wr_vector),
        .wr_scale(wr_scale),
        .rd_en(rd_en),
        .rd_token(rd_token),
        .rd_vector(rd_vector),
        .rd_scale(rd_scale)
    );

    // clock
    always #5 clk = ~clk;

    // reference model
    logic [HEAD_DIM*8-1:0] ref_vector [0:MAX_TOKENS-1];
    logic [15:0] ref_scale [0:MAX_TOKENS-1];

    initial begin
        clk = 0;
        wr_valid = 0;
        rd_en    = 0;

        // initialize reference memory
        for (int i=0;i<MAX_TOKENS;i++) begin
            ref_vector[i] = '0;
            ref_scale[i]  = '0;
        end

        @(posedge clk);

        // ---------------------------
        // Step 1: Pre-fill all tokens
        // ---------------------------
        $display("Pre-filling memory...");
        for (int t = 0; t < MAX_TOKENS; t++) begin
            @(posedge clk);
            wr_valid = 1;
            wr_token = t;
            wr_vector = $urandom;
            wr_scale  = $urandom;

            // update reference
            ref_vector[t] = wr_vector;
            ref_scale[t]  = wr_scale;
        end
	@(posedge clk);	// write last token
        wr_valid = 0;

        // small delay before starting reads
        @(posedge clk);

        // --------------------------------
        // Step 2: Random reads with known data
        // --------------------------------
        $display("Starting random reads...");
        for (int i=0; i<20; i++) begin
            @(posedge clk);

            rd_en    = 1;
            rd_token = $urandom_range(0, MAX_TOKENS-1);

            @(posedge clk); // wait for registered read
		#1;

            // check DUT output against reference
            if (rd_vector !== ref_vector[rd_token]) begin
                $error("VECTOR MISMATCH token=%0d expected=%0h got=%0h",
                       rd_token, ref_vector[rd_token], rd_vector);
		$stop;
            end

            if (rd_scale !== ref_scale[rd_token]) begin
                $error("SCALE MISMATCH token=%0d expected=%0h got=%0h",
                       rd_token, ref_scale[rd_token], rd_scale);
		$stop;
            end
        end
        rd_en = 0;

        $display("TEST PASSED");
        $stop;
    end

endmodule
