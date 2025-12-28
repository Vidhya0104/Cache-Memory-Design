module tag_array #(
    parameter TAG_BITS = 19,
    parameter NUM_SETS = 128
)(
    input  wire                        clk,
    input  wire                        we,
    input  wire [$clog2(NUM_SETS)-1:0] index,
    input  wire [TAG_BITS-1:0]         tag_in,
    input  wire                        valid_in,
    input  wire                        dirty_in,
    output wire [TAG_BITS-1:0]         tag_out,
    output wire                        valid_out,
    output wire                        dirty_out
);

    reg [TAG_BITS-1:0] tags  [0:NUM_SETS-1];
    reg                valid [0:NUM_SETS-1];
    reg                dirty [0:NUM_SETS-1];

    assign tag_out   = tags[index];
    assign valid_out = valid[index];
    assign dirty_out = dirty[index];

    always @(posedge clk) begin
        if (we) begin
            tags[index]  <= tag_in;
            valid[index] <= valid_in;
            dirty[index] <= dirty_in;
        end
    end

endmodule