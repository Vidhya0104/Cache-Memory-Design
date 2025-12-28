module cache_top #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter LINE_BYTES  = 64,
    parameter NUM_SETS    = 128,
    parameter WAYS        = 2,
    parameter MEM_DEPTH   = (1<<16)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  cpu_req,
    input  wire                  cpu_we,
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] cpu_wstrb,
    output wire                   cpu_ready,
    output wire [DATA_WIDTH-1:0] cpu_rdata
);

    wire mem_req, mem_we, mem_ready;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_wdata, mem_rdata;

    cache_controller #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LINE_BYTES(LINE_BYTES), .NUM_SETS(NUM_SETS), .WAYS(WAYS)) cache_ctrl (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata), .cpu_wstrb(cpu_wstrb),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

    simple_mem #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH_WORDS(MEM_DEPTH)) mem_inst (
        .clk(clk), .rst_n(rst_n),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

endmodule