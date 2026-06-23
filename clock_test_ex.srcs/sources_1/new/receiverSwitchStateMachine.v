module receiverSwitchStateMachine(
    input clk,
    input reset,  // Adding a reset input for good practice
    input header_start,
    input header_stop,
    input [63:0] header_dur,
    input [31:0] DIVISOR_header_sw,
    output wire receiver_sw_0
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam WAIT_FOR_STOP = 3'b001;
    localparam DELAY = 3'b010;
    localparam COUNTDOWN = 3'b011;

    // State registers
    reg [2:0] current_state, next_state;

    // Counter registers
    reg [63:0] counter_header_dur;
    reg [31:0] delay_counter;

    // Combinational output
    reg receiver_sw_0_comb;

    // State transition logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic and combinational output logic
    always @(*) begin
        if (reset) begin
            receiver_sw_0_comb <= 1'b0;
        end
        next_state = current_state;
        receiver_sw_0_comb = 1'b0;

        case (current_state)
            IDLE: begin
                if (header_start) begin
                    next_state = WAIT_FOR_STOP;
                end
            end

            WAIT_FOR_STOP: begin
                if (header_stop) begin
                    next_state = DELAY;
                end
            end

            DELAY: begin
                if (delay_counter == 32'd0) begin
                    next_state = COUNTDOWN;
                end
            end

            COUNTDOWN: begin
                receiver_sw_0_comb = 1'b1;
                if (counter_header_dur == 64'd0) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Counter logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_header_dur <= 64'd0;
            delay_counter <= 32'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (header_start) begin
                        counter_header_dur <= header_dur;
                        delay_counter <= DIVISOR_header_sw;
                    end
                end

                DELAY: begin
                    if (delay_counter > 32'd0) begin
                        delay_counter <= delay_counter - 1'b1;
                    end
                end

                COUNTDOWN: begin
                    if (counter_header_dur > 64'd0) begin
                        counter_header_dur <= counter_header_dur - 1'b1;
                    end
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

    //  output
    assign receiver_sw_0 = receiver_sw_0_comb;

endmodule