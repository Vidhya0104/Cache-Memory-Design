module cache_controller #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter LINE_BYTES  = 64,
    parameter NUM_SETS    = 128,
    parameter WAYS        = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // CPU interface
    input  wire                  cpu_req,
    input  wire                  cpu_we,
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] cpu_wstrb,
    output reg                   cpu_ready,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,

    // Memory interface
    output reg                   mem_req,
    output reg                   mem_we,
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg  [DATA_WIDTH-1:0] mem_wdata,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_ready
);

    localparam WORD_BYTES     = DATA_WIDTH/8;
    localparam WORDS_PER_LINE = LINE_BYTES / WORD_BYTES;
    localparam OFFSET_BITS    = $clog2(LINE_BYTES);
    localparam INDEX_BITS     = $clog2(NUM_SETS);
    localparam TAG_BITS       = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;

    // FSM States
    localparam S_IDLE      = 3'd0,
               S_LOOKUP    = 3'd1,
               S_WRITEBACK = 3'd2,
               S_REFILL    = 3'd3,
               S_RESPOND   = 3'd4;

    reg [2:0] state, next_state;
    reg [ADDR_WIDTH-1:0] req_addr;
    reg req_we;
    reg [DATA_WIDTH-1:0] req_wdata;
    reg [(DATA_WIDTH/8)-1:0] req_wstrb;
    reg [$clog2(WORDS_PER_LINE)-1:0] beat_cnt;
    reg was_miss;

    // Address decoding on buffered request
    wire [INDEX_BITS-1:0]  index  = req_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0]    tag_in = req_addr[ADDR_WIDTH-1 -: TAG_BITS];
    wire [$clog2(WORDS_PER_LINE)-1:0] word_idx = req_addr[OFFSET_BITS-1 : 2];

    // Array outputs
    wire [TAG_BITS-1:0] tag_out[0:WAYS-1];
    wire valid_out[0:WAYS-1];
    wire dirty_out[0:WAYS-1];
    wire [DATA_WIDTH-1:0] rdata_way[0:WAYS-1];

    // Array control signals
    reg tag_we, data_we;
    reg [$clog2(WAYS)-1:0] way_sel;
    reg tag_dirty_in;
    reg [$clog2(WORDS_PER_LINE)-1:0] data_word_idx;
    reg [DATA_WIDTH-1:0] data_wdata;
    reg [(DATA_WIDTH/8)-1:0] data_wstrb;

    // Array Instantiations
    genvar w;
    generate
        for (w = 0; w < WAYS; w = w + 1) begin : ARRAY_WAYS
            tag_array #(.TAG_BITS(TAG_BITS), .NUM_SETS(NUM_SETS)) tag_inst (
                .clk(clk),
                .we(tag_we && (way_sel == w)),
                .index(index),
                .tag_in(tag_in),
                .valid_in(1'b1),
                .dirty_in(tag_dirty_in),
                .tag_out(tag_out[w]),
                .valid_out(valid_out[w]),
                .dirty_out(dirty_out[w])
            );
            data_array #(.DATA_WIDTH(DATA_WIDTH), .WORDS_PER_LINE(WORDS_PER_LINE), .NUM_SETS(NUM_SETS)) data_inst (
                .clk(clk),
                .we(data_we && (way_sel == w)),
                .index(index),
                .word_idx(data_word_idx),
                .wdata(data_wdata),
                .wstrb(data_wstrb),
                .rdata(rdata_way[w])
            );
        end
    endgenerate

    // LRU
    wire victim_way;
    reg  lru_update_en;
    reg  new_mru_way;
    lru #(.NUM_SETS(NUM_SETS)) lru_inst (
        .clk(clk), .rst_n(rst_n), .index(index),
        .update_en(lru_update_en), .new_mru_way(new_mru_way),
        .victim_way(victim_way)
    );

    // Hit Detection
    wire hit_way0 = valid_out[0] && (tag_out[0] == tag_in);
    wire hit_way1 = valid_out[1] && (tag_out[1] == tag_in);
    wire hit = hit_way0 || hit_way1;
    wire hit_way_idx = hit_way0 ? 1'b0 : 1'b1;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // Buffer CPU request
    always @(posedge clk) begin
        if (cpu_req && state == S_IDLE) begin
            req_addr <= cpu_addr;
            req_we <= cpu_we;
            req_wdata <= cpu_wdata;
            req_wstrb <= cpu_wstrb;
            beat_cnt <= 0;
            was_miss <= 1'b1;
        end else if (mem_ready && (state == S_WRITEBACK || state == S_REFILL)) begin
            beat_cnt <= beat_cnt + 1;
        end else if (state == S_LOOKUP && hit) begin
            was_miss <= 1'b0;
        end
    end

    // Combinational Logic
    always @(*) begin
        // Defaults
        cpu_ready = 1'b0; cpu_rdata = {DATA_WIDTH{1'b0}};
        mem_req = 1'b0; mem_we = 1'b0; mem_addr = 32'h0; mem_wdata = 32'h0;
        tag_we = 1'b0; data_we = 1'b0; way_sel = victim_way;
        tag_dirty_in = 1'b0; data_word_idx = beat_cnt; data_wdata = mem_rdata; data_wstrb = 4'hF;
        lru_update_en = 1'b0; new_mru_way = 1'b0;
        next_state = state;

        case (state)
            S_IDLE: begin
                if (cpu_req) next_state = S_LOOKUP;
            end

            S_LOOKUP: begin
                if (hit) begin
                    cpu_rdata = rdata_way[hit_way_idx];
                    lru_update_en = 1'b1;
                    new_mru_way = hit_way_idx;
                    // For a write hit, update cache immediately
                    if (req_we) begin
                        tag_we = 1'b1;
                        way_sel = hit_way_idx;
                        tag_dirty_in = 1'b1;
                        data_we = 1'b1;
                        data_word_idx = word_idx;
                        data_wdata = req_wdata;
                        data_wstrb = req_wstrb;
                    end
                    next_state = S_RESPOND;
                end else if (valid_out[victim_way] && dirty_out[victim_way]) begin
                    next_state = S_WRITEBACK;
                end else begin
                    next_state = S_REFILL;
                end
            end

            S_WRITEBACK: begin
                mem_req = 1'b1; mem_we = 1'b1;
                mem_addr = {tag_out[victim_way], index, {OFFSET_BITS{1'b0}}} + (beat_cnt * WORD_BYTES);
                mem_wdata = rdata_way[victim_way];
                data_word_idx = beat_cnt;
                way_sel = victim_way;
                if (mem_ready && (beat_cnt == WORDS_PER_LINE-1)) next_state = S_REFILL;
            end

            S_REFILL: begin
                mem_req = 1'b1; mem_we = 1'b0;
                mem_addr = {tag_in, index, {OFFSET_BITS{1'b0}}} + (beat_cnt * WORD_BYTES);
                way_sel = victim_way;
                if (mem_ready) begin
                    data_we = 1'b1;
                    data_wdata = mem_rdata;
                    if (beat_cnt == WORDS_PER_LINE-1) next_state = S_RESPOND;
                end
            end

            S_RESPOND: begin
                cpu_ready = 1'b1;
                cpu_rdata = rdata_way[was_miss ? victim_way : hit_way_idx];
                if (was_miss) begin
                    tag_we = 1'b1;
                    way_sel = victim_way;
                    tag_dirty_in = req_we;
                    lru_update_en = 1'b1;
                    new_mru_way = victim_way;
                    if (req_we) begin
                        data_we = 1'b1;
                        data_word_idx = word_idx;
                        data_wdata = req_wdata;
                        data_wstrb = req_wstrb;
                    end
                end
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule