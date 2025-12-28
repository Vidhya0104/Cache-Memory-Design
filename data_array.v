module data_array #(
    parameter DATA_WIDTH     = 32,
    parameter WORDS_PER_LINE = 16,
    parameter NUM_SETS       = 128
)(
    input  wire                        clk,
    input  wire                        we,
    input  wire [$clog2(NUM_SETS)-1:0] index,
    input  wire [$clog2(WORDS_PER_LINE)-1:0] word_idx,
    input  wire [DATA_WIDTH-1:0]       wdata,
    input  wire [(DATA_WIDTH/8)-1:0]   wstrb,
    output wire [DATA_WIDTH-1:0]       rdata
);

    reg [DATA_WIDTH-1:0] mem [0:NUM_SETS-1][0:WORDS_PER_LINE-1];

    assign rdata = mem[index][word_idx];
    integer i;
    always @(posedge clk) begin
        if (we) begin
            for (i = 0; i < DATA_WIDTH/8; i = i + 1)
                if (wstrb[i])
                    mem[index][word_idx][8*i +: 8] <= wdata[8*i +: 8];
        end
    end

endmodule