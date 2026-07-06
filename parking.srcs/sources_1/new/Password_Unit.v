module Password_Unit (
    input clk,
    input reset,
    input store_password,
    input [1:0] slot_num,
    input [3:0] password_in,
    input [3:0] password_entered,
    input vip_flag,
    output reg match,
    output reg [3:0] stored_password
);

    reg [3:0] password_mem [0:3];
    integer i;

    // Combinational logic for immediate password matching
    always @(*) begin
        stored_password = password_mem[slot_num];
        // VIP still needs to verify password for security
        match = (password_entered == password_mem[slot_num]);
    end

    // Sequential logic for password storage
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize all passwords to 0000
            for (i = 0; i < 4; i = i + 1) begin
                password_mem[i] <= 4'b0000;
            end
        end else begin
            if (store_password) begin
                password_mem[slot_num] <= password_in;
                $display("Time: %0t | Password stored: Slot %d, Password: %d", 
                         $time, slot_num, password_in);
            end
        end
    end

endmodule