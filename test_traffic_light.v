`timescale 1ns / 1ps


module tb_tl;
  reg clk = 0, rst_n = 0, ped_btn = 0;
  wire red, yellow, green, ped_cross;

  traffic_light #(
      .T_RED(10),
      .T_YELLOW(2),
      .T_GREEN(6),
      .T_PED_WALK(4)
  ) uut (
      .clk(clk),
      .rst_n(rst_n),
      .ped_btn(ped_btn),
      .red(red),
      .yellow(yellow),
      .green(green),
      .ped_cross(ped_cross)
  );

  initial forever #5 clk = ~clk;

  task check_outputs;
    input expc_red, expc_yellow, expc_green, expc_ped;
    input [80*8:1] test_name;

    begin
      if (red!==expc_red||yellow!==expc_yellow||green!==expc_green||ped_cross!==expc_ped) begin
        $display("[ERROR] %s failed at time %0t!", test_name, $time);
        $display("        Expected: R=%b Y=%b G=%b P=%b", expc_red, expc_yellow, expc_green,
                 expc_ped);
        $display("        Got     : R=%b Y=%b G=%b P=%b", red, yellow, green, ped_cross);
      end else begin
        $display("[PASS] %s at time %0t", test_name, $time);
      end
    end
  endtask

  initial begin
    $dumpfile("dump_traffic_light.vcd");
    $dumpvars(0, tb_tl);

    // Verify initialization reset
    #15 rst_n = 1;
    check_outputs(1, 0, 0, 0, "Initial Reset to RED");

    #80 begin
      @(posedge clk) ped_btn <= 1;
      @(posedge clk) ped_btn <= 0;
    end

    // Handle simultaneous button edge
    @(posedge clk) #1 check_outputs(1, 0, 0, 1, "Simultaneous edge routes to PED_WALK");

    // Post-walk transition to green
    #40 check_outputs(0, 0, 1, 0, "Transitions from PED_WALK to GREEN");

    // Check spamming button behavior
    repeat (4) @(posedge clk) ped_btn <= ~ped_btn;
    #100 check_outputs(1, 0, 0, 0, "Transitions to RED despite spamming");

    // Verify pre-reset green state
    #120 check_outputs(0, 0, 1, 0, "Before Async Reset (State = GREEN)");
    rst_n = 0;

    // Asynchronous reset safety check
    #1 check_outputs(1, 0, 0, 0, "Immediate Async Reset Snap to RED");
    rst_n = 1;

    // Verify undefined state recovery
    #20 uut.state = 2'bxx;
    #10 @(posedge clk) #1 check_outputs(1, 0, 0, 0, "Fault State recovery to RED");

    #44 $display("All tests completed");
    $finish;
  end

endmodule
