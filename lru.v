module lru #(
    parameter NUM_SETS = 128
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire [$clog2(NUM_SETS)-1:0] index,
    input  wire                        update_en,
    input  wire                        new_mru_way,
    output wire                        victim_way
);

    reg lru_bits [0:NUM_SETS-1];

    assign victim_way = lru_bits[index];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1)
                lru_bits[i] <= 1'b0;
        end else if (update_en) begin
            lru_bits[index] <= ~new_mru_way;
        end
    end

endmodule