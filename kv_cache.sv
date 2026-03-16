module kv_cache #(
    parameter NUM_HEADS  = 8,
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024,

    // Precision per head: 0=FP16 1=INT8 2=INT4
    parameter int PRECISION [0:NUM_HEADS-1] = '{default:0}
)(
    input  logic clk,
    input  logic rst_n,

    // WRITE (all heads simultaneously)
    input  logic wr_valid,
    input  logic [$clog2(MAX_TOKENS)-1:0] wr_token,
    input  logic [HEAD_DIM*16-1:0] wr_vector [0:NUM_HEADS-1],
    input  logic [15:0]            wr_scale  [0:NUM_HEADS-1],

    // READ STREAM
    input  logic rd_req,
    input  logic [$clog2(MAX_TOKENS)-1:0] rd_start_token,
    input  logic [15:0] rd_len,

    output logic rd_valid,

    // outputs for every head
    output logic [HEAD_DIM*16-1:0] rd_vector [0:NUM_HEADS-1],
    output logic [15:0]            rd_scale  [0:NUM_HEADS-1]
);

    // ---------------------------------------------------------
    // Read control FSM
    // ---------------------------------------------------------

    logic active;
    logic [$clog2(MAX_TOKENS)-1:0] cur_token;
    logic [15:0] burst_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active    <= 0;
            cur_token <= 0;
            burst_cnt <= 0;
        end
        else begin

            if (rd_req) begin
                active    <= 1;
                cur_token <= rd_start_token;
                burst_cnt <= rd_len;
            end

            else if (active) begin
                cur_token <= cur_token + 1;
                burst_cnt <= burst_cnt - 1;

                if (burst_cnt == 1)
                    active <= 0;
            end

        end
    end

    always_ff @(posedge clk) rd_valid <= active;

    // ---------------------------------------------------------
    // KV BANK INSTANCES (one per head)
    // ---------------------------------------------------------

    genvar i;

    generate
    for (i = 0; i < NUM_HEADS; i++) begin : HEAD_BANKS

        localparam LINE_WIDTH = HEAD_DIM*16;
        localparam TOKENS_PER_LINE =
            (PRECISION[i]==0) ? 1 :
            (PRECISION[i]==1) ? 2 :
                                4;
        localparam SLOT_WIDTH = LINE_WIDTH / TOKENS_PER_LINE;

        logic [SLOT_WIDTH-1:0] bank_rd_vec;

        kv_bank #( 
            .HEAD_DIM(HEAD_DIM),
            .MAX_TOKENS(MAX_TOKENS),
            .PRECISION(PRECISION[i])
        ) bank_i (
            .clk(clk),

            .wr_valid(wr_valid),
            .wr_token(wr_token),
            .wr_vector(wr_vector[i][SLOT_WIDTH-1:0]),
            .wr_scale(wr_scale[i]),

            .rd_en(active),
            .rd_token(cur_token),

            .rd_vector(bank_rd_vec),
            .rd_scale(rd_scale[i])
        );
 
        // -----------------------------
        // Sign-extend bank read to full LINE_WIDTH
        // -----------------------------
        always_comb begin
            case (PRECISION[i])
                0: rd_vector[i] = bank_rd_vec; // FP16
                1: begin // INT8 ? 16-bit
                    int j;
                    rd_vector[i] = '0;
                    for (j = 0; j < HEAD_DIM; j=j+1) begin
                        rd_vector[i][j*16 +: 16] =
                            {{8{bank_rd_vec[j*8 +7]}}, bank_rd_vec[j*8 +: 8]};
                    end
                end
                2: begin // INT4 ? 16-bit
                    integer j;
                    rd_vector[i] = '0;
                    for (j = 0; j < HEAD_DIM; j=j+1) begin
                        rd_vector[i][j*16 +: 16] =
                            {{12{bank_rd_vec[j*4 +3]}}, bank_rd_vec[j*4 +: 4]};
                    end
                end
                default: rd_vector[i] = bank_rd_vec;
            endcase
        end

    end
    endgenerate

endmodule
