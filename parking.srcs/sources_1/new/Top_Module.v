module Top_Module (
    input clk,
    input reset,
    input arrival,
    input exit_request,
    input [1:0] slot_num,
    input [3:0] password_entered,
    input vip_set,
    input admin_override,
    input time_tick,
    output gate_open,
    output [3:0] slot_status,
    output [3:0] vip_indicator,
    output [1:0] wrong_attempt_count_0,
    output [1:0] wrong_attempt_count_1,
    output [1:0] wrong_attempt_count_2,
    output [1:0] wrong_attempt_count_3,
    output [3:0] timer_status
);

    // Internal wires
    wire request_password, lockout_trigger, free_slot, store_password;
    wire [3:0] stored_password;
    wire match;
    wire [2:0] state;
    wire increment_wrong_attempt;  // Added for wrong attempt counting

    // Wrong attempts multiplexer
    wire [1:0] wrong_attempts_mux;
    assign wrong_attempts_mux = (slot_num == 2'd0) ? wrong_attempt_count_0 :
                                (slot_num == 2'd1) ? wrong_attempt_count_1 :
                                (slot_num == 2'd2) ? wrong_attempt_count_2 :
                                                     wrong_attempt_count_3;

    // Instantiate FSM Controller
    FSM_Controller fsm (
        .clk(clk),
        .reset(reset),
        .arrival(arrival),
        .exit_request(exit_request),
        .slot_num(slot_num),
        .password_entered(password_entered),
        .vip_flag(vip_indicator[slot_num]),
        .admin_override(admin_override),
        .time_tick(time_tick),
        .wrong_attempts(wrong_attempts_mux),
        .stored_password(stored_password),
        .match(match),  // Added password match signal
        .slot_occupied(slot_status[slot_num]),
        .slot_vip(vip_indicator[slot_num]),
        .gate_open(gate_open),
        .state(state),
        .request_password(request_password),
        .lockout_trigger(lockout_trigger),
        .free_slot(free_slot),
        .store_password(store_password),
        .increment_wrong_attempt(increment_wrong_attempt)  // Added
    );

    // Instantiate Slot Manager
    Slot_Manager sm (
        .clk(clk),
        .reset(reset),
        .arrival(arrival),
        .free_slot(free_slot),
        .slot_num(slot_num),
        .vip_set(vip_set),
        .time_tick(time_tick),
        .lockout_trigger(lockout_trigger),
        .increment_wrong_attempt(increment_wrong_attempt),  // Added
        .slot_status(slot_status),
        .vip_indicator(vip_indicator),
        .wrong_attempt_count_0(wrong_attempt_count_0),
        .wrong_attempt_count_1(wrong_attempt_count_1),
        .wrong_attempt_count_2(wrong_attempt_count_2),
        .wrong_attempt_count_3(wrong_attempt_count_3),
        .timer_status(timer_status)
    );

    // Instantiate Password Unit
    Password_Unit pu (
        .clk(clk),
        .reset(reset),
        .store_password(store_password),
        .slot_num(slot_num),
        .password_in(password_entered),
        .password_entered(password_entered),
        .vip_flag(vip_indicator[slot_num]),
        .match(match),
        .stored_password(stored_password)
    );

endmodule