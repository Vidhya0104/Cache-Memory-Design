module simple_mem #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter DEPTH_WORDS = (1<<16)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  mem_req,
    input  wire                  mem_we,
    input  wire [ADDR_WIDTH-1:0] mem_addr,
    input  wire [DATA_WIDTH-1:0] mem_wdata,
    output reg  [DATA_WIDTH-1:0] mem_rdata,
    output reg                   mem_ready
);

    localparam WORD_BYTES = DATA_WIDTH/8;
    localparam ADDR_LSB   = $clog2(WORD_BYTES);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH_WORDS-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= {DATA_WIDTH{1'b0}};
        end else begin
            mem_ready <= mem_req;
            if (mem_req) begin
                if (mem_we)
                    mem[mem_addr[ADDR_LSB +: $clog2(DEPTH_WORDS)]] <= mem_wdata;
                else
                    mem_rdata <= mem[mem_addr[ADDR_LSB +: $clog2(DEPTH_WORDS)]];
            end
        end
    end

endmodule