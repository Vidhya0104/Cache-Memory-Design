module tb_cache;

  reg clk, rst_n, cpu_req, cpu_we;
  reg [31:0] cpu_addr, cpu_wdata;
  reg [3:0] cpu_wstrb;
  wire cpu_ready;
  wire [31:0] cpu_rdata;

  cache_top dut (
    .clk(clk), .rst_n(rst_n),
    .cpu_req(cpu_req), .cpu_we(cpu_we),
    .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata), .cpu_wstrb(cpu_wstrb),
    .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task cpu_read(input [31:0] addr);
  begin
    @(posedge clk);
    cpu_addr = addr; cpu_wdata = 0; cpu_wstrb = 0; cpu_we = 0; cpu_req = 1;
    wait (cpu_ready == 1); @(posedge clk);
    $display("[%0t] READ  addr=%h  data=%h", $time, addr, cpu_rdata);
    cpu_req = 0;
  end
  endtask

  task cpu_write(input [31:0] addr, input [31:0] data);
  begin
    @(posedge clk);
    cpu_addr = addr; cpu_wdata = data; cpu_wstrb = 4'hF; cpu_we = 1; cpu_req = 1;
    wait (cpu_ready == 1); @(posedge clk);
    $display("[%0t] WRITE addr=%h  data=%h", $time, addr, data);
    cpu_req = 0; cpu_we = 0;
  end
  endtask

  localparam [31:0] A0 = 32'h0000_0000;
  localparam [31:0] A1 = 32'h0000_2000;
  localparam [31:0] A2 = 32'h0000_4000;

  initial begin
    rst_n = 0; cpu_req = 0; #40 rst_n = 1;
    $display("[%0t] TB: reset deasserted", $time);
    
    $display("\n==== 1. READ MISS (A0) ====");
    cpu_read(A0);

    $display("\n==== 2. READ HIT (A0) ====");
    cpu_read(A0);

    $display("\n==== 3. WRITE MISS+ALLOCATE (A1) ====");
    cpu_write(A1, 32'h1111_AAAA);
    cpu_read(A1);

    $display("\n==== 4. WRITE HIT (A1) ====");
    cpu_write(A1, 32'h2222_BBBB);
    cpu_read(A1);

    $display("\n==== 5. Access A0 -> A1 now LRU ====");
    cpu_read(A0);

    $display("\n==== 6. WRITE MISS A2 -> Evicts A1 (dirty) ====");
    cpu_write(A2, 32'h3333_CCCC);
    cpu_read(A2);

    $display("\n==== 7. READ A1 -> MISS (evicted) ====");
    cpu_read(A1);

    #200 $display("\n==== CACHE TEST COMPLETE ===="); $finish;
  end

endmodule