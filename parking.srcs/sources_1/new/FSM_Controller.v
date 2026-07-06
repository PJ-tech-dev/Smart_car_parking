module FSM_Controller (
    input clk,
    input reset,
    input arrival,
    input exit_request,
    input [1:0] slot_num,
    input [3:0] password_entered,
    input vip_flag,
    input admin_override,
    input time_tick,
    input [1:0] wrong_attempts,
    input [3:0] stored_password,
    input match,  // Added password match signal
    input slot_occupied,
    input slot_vip,
    output reg gate_open,
    output reg [2:0] state,
    output reg request_password,
    output reg lockout_trigger,
    output reg free_slot,
    output reg store_password,
    output reg increment_wrong_attempt  // Added
);

    // State definitions
    localparam IDLE = 3'd0,
               ARRIVAL = 3'd1,
               PASSWORD_ENTRY = 3'd2,
               EXIT = 3'd3,
               LOCKOUT = 3'd4,
               ADMIN = 3'd5;

    // State name function for debugging
    function [79:0] state_name;
        input [2:0] s;
        case (s)
            IDLE:           state_name = "IDLE";
            ARRIVAL:        state_name = "ARRIVAL";
            PASSWORD_ENTRY: state_name = "PWD_ENTRY";
            EXIT:           state_name = "EXIT";
            LOCKOUT:        state_name = "LOCKOUT";
            ADMIN:          state_name = "ADMIN";
            default:        state_name = "UNKNOWN";
        endcase
    endfunction

    // FSM logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            gate_open <= 0;
            request_password <= 0;
            lockout_trigger <= 0;
            free_slot <= 0;
            store_password <= 0;
            increment_wrong_attempt <= 0;
        end else begin
            // Default outputs
            gate_open <= 0;
            free_slot <= 0;
            store_password <= 0;
            lockout_trigger <= 0;
            increment_wrong_attempt <= 0;
            
            case (state)
                IDLE: begin
                    request_password <= 0;
                    if (arrival && !slot_occupied)
                        state <= ARRIVAL;
                    else if (exit_request && slot_occupied)
                        state <= EXIT;
                    else if (admin_override)
                        state <= ADMIN;
                end

                ARRIVAL: begin
                    if (vip_flag) begin
                        // VIP arrival - no password needed
                        gate_open <= 1;
                        state <= IDLE;
                    end else begin
                        // Regular user - request password
                        request_password <= 1;
                        state <= PASSWORD_ENTRY;
                    end
                end

                PASSWORD_ENTRY: begin
                    if (password_entered != 4'b0000) begin
                        // Store password and open gate
                        store_password <= 1;
                        gate_open <= 1;
                        state <= IDLE;
                    end
                    // Stay in state until password entered
                end

                EXIT: begin
                    if (slot_vip) begin
                        // VIP exit - no password needed
                        free_slot <= 1;
                        gate_open <= 1;
                        state <= IDLE;
                    end else if (match) begin
                        // Correct password
                        free_slot <= 1;
                        gate_open <= 1;
                        state <= IDLE;
                    end else if (password_entered != 4'b0000) begin
                        // Wrong password entered
                        increment_wrong_attempt <= 1;
                        if (wrong_attempts >= 2'd2) begin
                            lockout_trigger <= 1;
                            state <= LOCKOUT;
                        end else begin
                            state <= IDLE; // Allow retry
                        end
                    end
                    // Stay in state if no password entered yet
                end

                LOCKOUT: begin
                    if (admin_override) begin
                        lockout_trigger <= 0;
                        state <= ADMIN;
                    end
                end

                ADMIN: begin
                    free_slot <= 1;
                    gate_open <= 1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase

            // Debug output
            $display("Time: %0t | State: %s | Slot: %d | Arrival: %b | Exit: %b | Gate: %b | Match: %b | WrongAttempts: %d",
                     $time, state_name(state), slot_num, arrival, exit_request, gate_open, 
                     match, wrong_attempts);
        end
    end
endmodule