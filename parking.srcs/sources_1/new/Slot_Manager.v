module Slot_Manager (
    input clk,
    input reset,
    input arrival,
    input free_slot,
    input [1:0] slot_num,
    input vip_set,
    input time_tick,
    input lockout_trigger,
    input increment_wrong_attempt,  // Added
    output reg [3:0] slot_status,
    output reg [3:0] vip_indicator,
    output reg [1:0] wrong_attempt_count_0,
    output reg [1:0] wrong_attempt_count_1,
    output reg [1:0] wrong_attempt_count_2,
    output reg [1:0] wrong_attempt_count_3,
    output reg [3:0] timer_status
);

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            slot_status <= 4'b0000;
            vip_indicator <= 4'b0000;
            timer_status <= 4'b0000;
            wrong_attempt_count_0 <= 2'd0;
            wrong_attempt_count_1 <= 2'd0;
            wrong_attempt_count_2 <= 2'd0;
            wrong_attempt_count_3 <= 2'd0;
        end else begin
            // Handle arrival - only if slot is free
            if (arrival && !slot_status[slot_num]) begin
                slot_status[slot_num] <= 1'b1;
                timer_status[slot_num] <= 4'd0; // Reset timer on arrival
            end

            // Handle slot freeing
            if (free_slot) begin
                slot_status[slot_num] <= 1'b0;
                timer_status[slot_num] <= 4'd0;
                // Reset wrong attempts for this slot
                case (slot_num)
                    2'd0: wrong_attempt_count_0 <= 2'd0;
                    2'd1: wrong_attempt_count_1 <= 2'd0;
                    2'd2: wrong_attempt_count_2 <= 2'd0;
                    2'd3: wrong_attempt_count_3 <= 2'd0;
                endcase
            end

            // Handle wrong password attempts
            if (increment_wrong_attempt) begin
                case (slot_num)
                    2'd0: wrong_attempt_count_0 <= wrong_attempt_count_0 + 1;
                    2'd1: wrong_attempt_count_1 <= wrong_attempt_count_1 + 1;
                    2'd2: wrong_attempt_count_2 <= wrong_attempt_count_2 + 1;
                    2'd3: wrong_attempt_count_3 <= wrong_attempt_count_3 + 1;
                endcase
            end

            // VIP assignment - only for free slots
            if (vip_set && !slot_status[slot_num]) begin
                vip_indicator[slot_num] <= 1'b1;
            end

            // Lockout - keep slot occupied
            if (lockout_trigger) begin
                slot_status[slot_num] <= 1'b1;
            end

            // Timer logic - check ALL slots every time_tick
            if (time_tick) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (slot_status[i]) begin
                        if (timer_status[i] < 4'd15) begin // Prevent overflow
                            timer_status[i] <= timer_status[i] + 1;
                        end
                        // Auto-release after timer reaches 10
                        if (timer_status[i] >= 4'd10) begin
                            slot_status[i] <= 1'b0;
                            timer_status[i] <= 4'd0;
                            // Reset wrong attempts for auto-released slot
                            case (i)
                                2'd0: wrong_attempt_count_0 <= 2'd0;
                                2'd1: wrong_attempt_count_1 <= 2'd0;
                                2'd2: wrong_attempt_count_2 <= 2'd0;
                                2'd3: wrong_attempt_count_3 <= 2'd0;
                            endcase
                            $display("Time: %0t | Auto-release triggered for slot %d", $time, i);
                        end
                    end
                end
            end

            // Debug output
            $display("Time: %0t | SlotMgr - Slot: %d | Status: %b | VIP: %b | Timer: %d | WrongAttempts: %d",
                     $time, slot_num, slot_status[slot_num], vip_indicator[slot_num],
                     timer_status[slot_num],
                     (slot_num == 2'd0) ? wrong_attempt_count_0 :
                     (slot_num == 2'd1) ? wrong_attempt_count_1 :
                     (slot_num == 2'd2) ? wrong_attempt_count_2 :
                     wrong_attempt_count_3);
        end
    end
endmodule