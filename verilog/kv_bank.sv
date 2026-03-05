module kv_bank #(
    parameter HEAD_DIM   = 64,
    parameter MAX_TOKENS = 1024
)(
    input  logic clk,
    input  logic rst_n,

    // WRITE
    input  logic wr_valid,
    input  logic [1:0] wr_precision,   // 0=FP16 1=INT8 2=INT4
    input  logic [HEAD_DIM*16-1:0] wr_vector,
    input  logic [15:0] wr_scale,
    input  logic [$clog2(MAX_TOKENS)-1:0] wr_token,

    // READ
    input  logic rd_en,
    input  logic [$clog2(MAX_TOKENS)-1:0] rd_token,

    output logic [HEAD_DIM*16-1:0] rd_vector,
    output logic [1:0] rd_precision,
    output logic [15:0] rd_scale
);

localparam LINE_WIDTH = HEAD_DIM*16;
localparam MAX_LINES  = MAX_TOKENS;

logic [LINE_WIDTH-1:0] data_mem [0:MAX_LINES-1];
logic [1:0] precision_mem [0:MAX_LINES-1];
logic [15:0] scale_mem [0:MAX_LINES-1][0:3];
logic [3:0] valid_mem [0:MAX_LINES-1];

logic [$clog2(MAX_LINES)-1:0] line_addr;
logic [1:0] slot;

logic [$clog2(MAX_LINES)-1:0] rd_line_addr;
logic [1:0] rd_slot;

always_comb begin

    case (wr_precision)

        2'd0: begin
            line_addr = wr_token;
            slot      = 0;
        end

        2'd1: begin
            line_addr = wr_token >> 1;
            slot      = wr_token[0];
        end

        2'd2: begin
            line_addr = wr_token >> 2;
            slot      = wr_token[1:0];
        end

        default: begin
            line_addr = wr_token;
            slot      = 0;
        end

    endcase

end


always_comb begin

    case (precision_mem[rd_token])

        2'd0: begin
            rd_line_addr = rd_token;
            rd_slot      = 0;
        end

        2'd1: begin
            rd_line_addr = rd_token >> 1;
            rd_slot      = rd_token[0];
        end

        2'd2: begin
            rd_line_addr = rd_token >> 2;
            rd_slot      = rd_token[1:0];
        end

        default: begin
            rd_line_addr = rd_token;
            rd_slot      = 0;
        end

    endcase

end


always_ff @(posedge clk) begin

    if (wr_valid) begin

        precision_mem[line_addr] <= wr_precision;
        scale_mem[line_addr][slot] <= wr_scale;
        valid_mem[line_addr][slot] <= 1'b1;

        case (wr_precision)

            2'd0:
                data_mem[line_addr] <= wr_vector;

            2'd1:
                data_mem[line_addr][slot*512 +: 512]
                    <= wr_vector[511:0];

            2'd2:
                data_mem[line_addr][slot*256 +: 256]
                    <= wr_vector[255:0];

        endcase

    end

end


always_ff @(posedge clk) begin

    if (rd_en) begin

        rd_precision <= precision_mem[rd_line_addr];
        rd_scale     <= scale_mem[rd_line_addr][rd_slot];

        case (rd_precision)

            2'd0:
                rd_vector <= data_mem[rd_line_addr];

            2'd1:
                rd_vector <= {512'b0,
                    data_mem[rd_line_addr][rd_slot*512 +: 512]};

            2'd2:
                rd_vector <= {768'b0,
                    data_mem[rd_line_addr][rd_slot*256 +: 256]};

            default:
                rd_vector <= data_mem[rd_line_addr];

        endcase

    end

end

endmodule
