/*
 * Moore FSM based traffic light controller
 */

module tlc #(
    parameter T_RED = 7'd100,
    parameter T_YELLOW = 4'd15,
    parameter T_GREEN = 6'd60,
    parameter T_PED_WALK = 5'd30
) (
    input wire clk,
    input wire rst_n,   // Asynchronous active low reset
    input wire ped_btn, // Button for pedestrians' signal

    output reg red,
    output reg yellow,
    output reg green,
    output reg ped_cross  // Pedestrian crossing light
);
  reg blink_pulse;
  reg [1:0] blink_ctr;

  // Independent counter for blinking yellow light (fallback)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      blink_pulse <= 1'b0;
      blink_ctr   <= 2'b0;
    end else begin
      blink_ctr <= blink_ctr + 1;
      if (blink_ctr == 2'd3) blink_pulse <= ~blink_pulse;
    end
  end

  reg [1:0] state;
  reg [7:0] counter;
  reg       ped_req;  // Stores pending pedestrians' request
  reg       ped_btn_prev;  // Stores previous button value to prevent race conditions

  localparam S_RED = 2'b00;  // s0
  localparam S_YELLOW = 2'b01;  // s1
  localparam S_GREEN = 2'b10;  // s2
  localparam S_PED_WALK = 2'b11;  // s3

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_RED;
      counter <= 8'b0;
      ped_req <= 1'b0;
      ped_btn_prev <= 1'b0;

      red <= 1'b1;  // Safe state as no vehicles or pedestrians move
      yellow <= 1'b0;
      green <= 1'b0;
      ped_cross <= 1'b0;

    end else begin
      counter <= counter + 1;
      if (ped_btn && !ped_btn_prev)
        ped_req <= 1'b1;  // Change only at rising edge (first instant) of button  
                          // press so requests don't get triggered multiple times
      ped_btn_prev <= ped_btn;
      case (state)

        S_RED: begin
          red <= 1'b1;
          yellow <= 1'b0;
          green <= 1'b0;
          ped_cross <= 1'b0;
          if (counter >= T_RED - 1) begin
            counter <= 8'b0;
            if (ped_req || (ped_btn && !ped_btn_prev)) begin
              ped_req <= 1'b0;
              state   <= S_PED_WALK;  // Move to pedestrian mode if pending requests
            end else state <= S_GREEN;  // else Go Green!
          end
        end

        S_YELLOW: begin
          red <= 1'b0;
          yellow <= 1'b1;
          green <= 1'b0;
          ped_cross <= 1'b0;
          if (counter >= T_YELLOW - 1) begin
            counter <= 8'b0;
            state   <= S_RED;
          end
        end

        S_GREEN: begin
          red <= 1'b0;
          yellow <= 1'b0;
          green <= 1'b1;
          ped_cross <= 1'b0;
          if (counter >= T_GREEN - 1) begin
            counter <= 8'b0;
            state   <= S_YELLOW;
          end
        end

        S_PED_WALK: begin
          red <= 1'b1;
          yellow <= 1'b0;
          green <= 1'b0;
          ped_cross <= 1'b1;
          if (counter >= T_PED_WALK - 1) begin
            counter <= 8'b0;
            state   <= S_GREEN;
          end
        end

        default: begin
          red <= 1'b0;
          yellow <= blink_pulse;  // Distinguishing behaviour to signal that 
                                  // there's a fault with the machine's states
          green <= 1'b0;
          ped_cross <= 1'b0;
          state <= S_RED;  // Move to safe state immediately after
          counter <= 8'b0;
        end

      endcase
    end
  end

endmodule
