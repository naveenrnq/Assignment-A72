// Transaction Class
class transaction;
    bit [3:0] a;
    bit [3:0] b;
    bit [7:0] mul;

    function new();
        this.a = '0;
        this.b = '0;
        this.mul = '0;
    endfunction

    function void display();
        $display("a: %0d \t b: %0d \t prod = %0d", a, b, mul);
    endfunction
endclass

// Interface with clocking block for better synchronization
interface top_if;
    logic clk;
    logic [3:0] a, b;
    logic [7:0] mul;

    // Clocking block to avoid race conditions
    clocking cb @(posedge clk);
        input a, b, mul;
    endclocking
endinterface

// Monitor Class: Captures data from the interface and sends it to the mailbox
class monitor;
    mailbox #(transaction) mbx;
    transaction t;
    virtual top_if vif;

    // Constructor
    function new(input mailbox #(transaction) mbx, input virtual top_if vif);
        this.mbx = mbx;
        this.vif = vif;
    endfunction

    // Monitor run task
    task run();
        forever begin
            t = new();
            @(vif.cb); // Sync with clocking block
            t.a = vif.a;
            t.b = vif.b;
            t.mul = vif.mul;
            $display("[MON]: Captured transaction:");
            t.display();
            mbx.put(t);
        end
    endtask
endclass

// Scoreboard Class: Receives data from the mailbox and performs comparison
class scoreboard;
    mailbox #(transaction) mbx;
    transaction t;

    // Constructor
    function new(input mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    // Comparison task
    task compare(input transaction t);
        if (t.mul == (t.a * t.b)) begin
            $display("[SCB]: Result matched for a=%0d, b=%0d, mul=%0d", t.a, t.b, t.mul);
        end else begin
            $error("[SCB]: Result mismatched for a=%0d, b=%0d, mul=%0d (Expected: %0d)", t.a, t.b, t.mul, t.a * t.b);
        end
    endtask

    // Scoreboard run task
    task run();
        forever begin
            mbx.get(t);
            $display("[SCB]: Transaction received from monitor:");
            t.display();
            compare(t);
            #10; // Optional delay for timing alignment if needed
        end
    endtask
endclass

// Testbench Module
module tb;
    // Interface instantiation
    top_if vif();

    // Class and mailbox declarations
    monitor mon;
    scoreboard scb;
    mailbox #(transaction) mbx;

    // DUT instantiation (assuming top is the DUT module)
    top dut (vif.clk, vif.a, vif.b, vif.mul);

    // Clock generation
    initial vif.clk = 0;
    always #5 vif.clk = ~vif.clk;

    // Stimulus generation
    initial begin
        for (int i = 0; i < 20; i++) begin
            @(posedge vif.clk);
            vif.a <= $urandom_range(1, 15);
            vif.b <= $urandom_range(1, 15);
            #10; // Delay to observe each transaction
        end
    end

    // Environment setup
    initial begin
        // Initialize mailbox, monitor, and scoreboard
        mbx = new();
        mon = new(mbx, vif);
        scb = new(mbx);

        // Run monitor and scoreboard in parallel
        fork
            mon.run();
            scb.run();
        join_none
    end

    // Waveform generation
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
        #300;
        $finish;
    end
endmodule
