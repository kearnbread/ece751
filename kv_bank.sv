module kv_bank #(
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024,
    parameter PRECISION  = 0   // 0=FP16, 1=INT8, 2=INT4
)(
    input  logic clk,

    // WRITE
    input  logic wr_valid,
    input  logic [$clog2(MAX_TOKENS)-1:0] wr_token,
    input  logic [(
        (PRECISION==0) ? HEAD_DIM*16 :
        (PRECISION==1) ? HEAD_DIM*8  :
        (PRECISION==2) ? HEAD_DIM*4  :
			 HEAD_DIM*16)
        -1 : 0
    ] wr_vector,
    input  logic [15:0] wr_scale,

    // READ
    input  logic rd_en,
    input  logic [$clog2(MAX_TOKENS)-1:0] rd_token,
    output  logic [(
        (PRECISION==0) ? HEAD_DIM*16 :
        (PRECISION==1) ? HEAD_DIM*8  :
        (PRECISION==2) ? HEAD_DIM*4  :
			 HEAD_DIM*16)
        -1 : 0
    ] rd_vector,
    output logic [15:0] rd_scale
);
    localparam LINE_WIDTH = HEAD_DIM*16;	 
    localparam TOKENS_PER_LINE =
            (PRECISION==0) ? 1 :
            (PRECISION==1) ? 2 :
            (PRECISION==2) ? 4 :
                             1;
    localparam SLOT_WIDTH = LINE_WIDTH / TOKENS_PER_LINE;
    // Number of memory lines (ceil division)
    localparam NUM_LINES = (MAX_TOKENS + TOKENS_PER_LINE - 1) / TOKENS_PER_LINE;
    localparam SLOT_BITS = (TOKENS_PER_LINE > 1) ? $clog2(TOKENS_PER_LINE) : 1;
	localparam USE_SCALE = (PRECISION != 0);

    // -----------------------------------------------------------------------
	// Line and slot addresses
    logic [$clog2(NUM_LINES)-1:0] wr_line, rd_line; 
    logic [SLOT_BITS-1:0] wr_slot, rd_slot;
	
    // Memory arrays
    logic [LINE_WIDTH-1:0] data_mem [0:NUM_LINES-1];
	// Conditionally generated scale memory
    generate
	if (USE_SCALE) begin : GEN_SCALE

		logic [15:0] scale_mem [0:NUM_LINES-1][0:TOKENS_PER_LINE-1];

		always_ff @(posedge clk) begin
			if (wr_valid)
				scale_mem[wr_line][wr_slot] <= wr_scale;
		end

		always_ff @(posedge clk) begin
			if (rd_en)
				rd_scale <= scale_mem[rd_line][rd_slot];
		end

	end else begin : NO_SCALE

		always_ff @(posedge clk) begin
			if (rd_en)
				rd_scale <= 16'h3C00;
		end

	end
	endgenerate


    // -----------------------------------------------------------------------
    // Compute line and slot addresses using bit-shifts (no div/mod)
    always_comb begin
        wr_line = '0;
        wr_slot = '0;
        rd_line = '0;
        rd_slot = '0;
        case (PRECISION)
            0: begin // FP16, 1 token per line
                wr_line = wr_token;
                wr_slot = 0;
                rd_line = rd_token;
                rd_slot = 0;
            end
            1: begin // INT8, 2 tokens per line
                wr_line = wr_token >> 1;
                wr_slot = wr_token[0];
                rd_line = rd_token >> 1;
                rd_slot = rd_token[0];
            end
            2: begin // INT4, 4 tokens per line
                wr_line = wr_token >> 2;
                wr_slot = wr_token[1:0];
                rd_line = rd_token >> 2;
                rd_slot = rd_token[1:0];
            end
            default: begin
                wr_line = wr_token;
                wr_slot = 0;
                rd_line = rd_token;
                rd_slot = 0;
            end
        endcase
    end

    // -----------------------------------------------------------------------
    // WRITE: store vector and scale
    always_ff @(posedge clk) begin
        if (wr_valid) begin
            data_mem[wr_line][wr_slot*SLOT_WIDTH +: SLOT_WIDTH] <= wr_vector;
        end
    end

    // -----------------------------------------------------------------------
    // READ: extract slot directly, no padding needed
    always_ff @(posedge clk) begin
        if (rd_en) begin
            rd_vector <= data_mem[rd_line][rd_slot*SLOT_WIDTH +: SLOT_WIDTH];
        end
    end

endmodule

