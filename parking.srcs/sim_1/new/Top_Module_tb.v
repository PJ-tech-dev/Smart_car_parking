`timescale 1ns / 1ps
module Top_Module_tb;

// Inputs
reg clk;
reg reset;
reg arrival;
reg exit_request;
reg [1:0] slot_num;
reg [3:0] password_entered;
reg vip_set;
reg admin_override;
reg time_tick;

// Outputs
wire gate_open;
wire [3:0] slot_status;
wire [3:0] vip_indicator;
wire [1:0] wrong_attempt_count_0;
wire [1:0] wrong_attempt_count_1;
wire [1:0] wrong_attempt_count_2;
wire [1:0] wrong_attempt_count_3;
wire [3:0] timer_status;

// Instantiate the Top Module
Top_Module uut (
    .clk(clk),
    .reset(reset),
    .arrival(arrival),
    .exit_request(exit_request),
    .slot_num(slot_num),
    .password_entered(password_entered),
    .vip_set(vip_set),
    .admin_override(admin_override),
    .time_tick(time_tick),
    .gate_open(gate_open),
    .slot_status(slot_status),
    .vip_indicator(vip_indicator),
    .wrong_attempt_count_0(wrong_attempt_count_0),
    .wrong_attempt_count_1(wrong_attempt_count_1),
    .wrong_attempt_count_2(wrong_attempt_count_2),
    .wrong_attempt_count_3(wrong_attempt_count_3),
    .timer_status(timer_status)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// -----------------------
// Helper: bitmask for a slot
// -----------------------
function [3:0] slot_mask;
    input [1:0] s;
    begin
        slot_mask = 4'd0;
        slot_mask[s] = 1'b1;
    end
endfunction

// -----------------------
// Enhanced Tasks (Verilog compatible)
// -----------------------
task do_arrival;
    input [1:0] s;
    input [3:0] pwd;
    input is_vip;
    begin
        @(posedge clk);
        slot_num = s;
        if (is_vip) begin
            vip_set = 1;
            @(posedge clk);
            vip_set = 0;
            #1;
        end
        arrival = 1;
        password_entered = pwd;
        @(posedge clk);
        arrival = 0;
        if (!is_vip) begin
            repeat(2) @(posedge clk);
        end
        password_entered = 4'd0;
    end
endtask

task do_exit;
    input [1:0] s;
    input [3:0] pwd;
    begin
        @(posedge clk);
        slot_num = s;
        password_entered = pwd;
        exit_request = 1;
        @(posedge clk);
        exit_request = 0;
        repeat(2) @(posedge clk);
        password_entered = 4'd0;
    end
endtask

task tick_once;
    begin
        @(posedge clk);
        time_tick = 1;
        @(posedge clk);
        time_tick = 0;
    end
endtask

task do_admin_override;
    input [1:0] s;
    begin
        @(posedge clk);
        slot_num = s;
        admin_override = 1;
        @(posedge clk);
        admin_override = 0;
    end
endtask

// -----------------------
// Checker tasks (Verilog compatible)
// -----------------------
task expect_slot_set;
    input [1:0] s;
    begin
        @(posedge clk); #1;
        if ((slot_status & slot_mask(s)) == 0)
            $display("ERROR: expected slot %0d to be SET at time %t, slot_status=%b", s, $time, slot_status);
        else
            $display("PASS: slot %0d set correctly", s);
    end
endtask

task expect_slot_cleared;
    input [1:0] s;
    begin
        @(posedge clk); #1;
        if ((slot_status & slot_mask(s)) != 0)
            $display("ERROR: expected slot %0d to be CLEARED at time %t, slot_status=%b", s, $time, slot_status);
        else
            $display("PASS: slot %0d cleared correctly", s);
    end
endtask

task expect_gate_open;
    input expected;
    begin
        @(posedge clk); #1;
        if (gate_open !== expected)
            $display("ERROR: gate_open = %b (expected %b) at time %t", gate_open, expected, $time);
        else
            $display("PASS: gate_open = %b as expected", gate_open);
    end
endtask

task expect_vip_status;
    input [1:0] s;
    input expected;
    begin
        @(posedge clk); #1;
        if (vip_indicator[s] !== expected)
            $display("ERROR: slot %0d VIP = %b (expected %b)", s, vip_indicator[s], expected);
        else
            $display("PASS: slot %0d VIP status correct", s);
    end
endtask

task check_wrong_attempts;
    input [1:0] s;
    input [1:0] expected;
    reg [1:0] actual;
    begin
        case(s)
            0: actual = wrong_attempt_count_0;
            1: actual = wrong_attempt_count_1;
            2: actual = wrong_attempt_count_2;
            3: actual = wrong_attempt_count_3;
        endcase
        
        if (actual !== expected)
            $display("ERROR: slot %0d wrong attempts = %d (expected %d)", s, actual, expected);
        else
            $display("PASS: slot %0d wrong attempts = %d", s, actual);
    end
endtask

// -----------------------
// MAIN Simulation
// -----------------------
initial begin
    // Initialize
    reset = 1;
    arrival = 0;
    exit_request = 0;
    slot_num = 2'd0;
    password_entered = 4'd0;
    vip_set = 0;
    admin_override = 0;
    time_tick = 0;

    repeat (3) @(posedge clk);
    reset = 0;
    $display("\n=== Reset released at time %t ===\n", $time);

    // Test 1: Normal User Flow
    $display("\n=== TEST 1: Normal User Arrival & Exit ===");
    do_arrival(2'd0, 4'd4, 0);
    expect_slot_set(0);
    expect_gate_open(1);
    
    repeat(3) @(posedge clk);
    expect_gate_open(0);
    
    do_exit(2'd0, 4'd4);
    expect_gate_open(1);
    expect_slot_cleared(0);

    // Test 2: VIP User Flow  
    $display("\n=== TEST 2: VIP User ===");
    do_arrival(2'd1, 4'd0, 1);
    expect_vip_status(1, 1);
    
    do_arrival(2'd1, 4'd0, 0);
    expect_slot_set(1);
    expect_gate_open(1);
    
    repeat(3) @(posedge clk);
    do_exit(2'd1, 4'd0);
    expect_gate_open(1);
    expect_slot_cleared(1);

    // Test 3: Wrong Password Lockout
    $display("\n=== TEST 3: Wrong Password Lockout ===");
    do_arrival(2'd2, 4'd5, 0);
    expect_slot_set(2);
    
    do_exit(2'd2, 4'd1);
    check_wrong_attempts(2, 1);
    
    do_exit(2'd2, 4'd2);
    check_wrong_attempts(2, 2);
    
    do_exit(2'd2, 4'd3);
    check_wrong_attempts(2, 3);
    expect_gate_open(0);
    expect_slot_set(2);
    
    do_exit(2'd2, 4'd5);
    expect_gate_open(0);

    // Test 4: Admin Override
    $display("\n=== TEST 4: Admin Override ===");
    do_admin_override(2'd2);
    expect_gate_open(1);
    expect_slot_cleared(2);
    check_wrong_attempts(2, 0);

    // Test 5: Timer Auto-Release
    $display("\n=== TEST 5: Timer Auto-Release ===");
    do_arrival(2'd3, 4'd8, 0);
    expect_slot_set(3);
    
    $display("Applying timer ticks...");
    begin : TIMER_TEST
        integer tick_count;
        for (tick_count = 0; tick_count < 15; tick_count = tick_count + 1) begin
            tick_once();
            @(posedge clk); #1;
            if ((slot_status & slot_mask(3)) == 0) begin
                $display("Auto-release occurred after %0d ticks", tick_count + 1);
                disable TIMER_TEST;
            end
        end
        if (tick_count >= 15)
            $display("ERROR: Auto-release did not occur within 15 ticks");
    end
    
    expect_slot_cleared(3);
    check_wrong_attempts(3, 0);

    $display("\n=== ALL TESTS COMPLETED at time %t ===", $time);
    $display("\n=== SUMMARY ===");
    $display("Check above for PASS/ERROR messages");
    #100 $finish;
end

endmodule