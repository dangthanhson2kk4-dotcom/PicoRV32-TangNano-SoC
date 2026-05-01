// =============================================================================
// File: soc_system_tb.v
// Chức năng: Testbench chạy toàn bộ SoC (CPU + RAM + UART + SPI + Hamming)
// =============================================================================

`timescale 1ns / 1ps

module soc_system_tb;

    reg         clk;
    reg         reset_n;
    reg         uart_rx_wire;
    wire [1:0]  leds_out;
    wire        trap_out;

    // Các chân màn hình SPI (Thêm vào để khớp với soc_top mới)
    wire        tft_sck, tft_mosi, tft_cs_n, tft_dc;

    // --- 1. GỌI CON CHIP TỔNG HỢP ---
    soc_top dut (
        .clk      (clk),
        .reset_n  (reset_n),
        .uart_rx  (uart_rx_wire),
        .tft_sck  (tft_sck),
        .tft_mosi (tft_mosi),
        .tft_cs_n (tft_cs_n),
        .tft_dc   (tft_dc),
        .leds     (leds_out),
        .trap_led (trap_out)
    );

    // --- 2. TẠO XUNG CLOCK (27MHz) ---
    initial begin
        clk = 0;
        forever #18.5 clk = ~clk; 
    end

    // --- 3. TASK GỬI UART ---
    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx_wire = 0; // Start bit
            #8680; 
            for (i=0; i<8; i=i+1) begin
                uart_rx_wire = b[i];
                #8680;
            end
            uart_rx_wire = 1; // Stop bit
            #8680;
        end
    endtask

    // --- 4. KỊCH BẢN MÔ PHỎNG ---
    initial begin
        reset_n = 0;
        uart_rx_wire = 1;
        
        #200;
        reset_n = 1;
        $display("\n[%0t] SOC BOOT SUCCESS!", $time);

        #50000; // Chờ khởi tạo

        // Gửi dữ liệu giả lập
        $display("[%0t] SENDING DATA: 0xC2...", $time);
        send_uart_byte(8'hC2);
        #10000;
        $display("[%0t] SENDING DATA: 0x21...", $time);
        send_uart_byte(8'h21);

        // TĂNG THỜI GIAN CHỜ: 
        // Vẽ 1 chữ cái 8x16 qua SPI mất hàng trăm nghìn ns
        $display("[%0t] WAITING FOR CPU PROCESSING & SPI DRAWING...", $time);
        #1000000; // Chờ hẳn 1ms (1.000.000 ns)

        if (trap_out) begin
            $display(">> [FAILED] CPU TRAPPED!");
        end else begin
            $display("===========================================");
            $display(">> [SUCCESS] SYSTEM RUNNING.");
            $display(">> HAMMING LEDS: %b", leds_out);
            $display("===========================================");
        end

        $stop;
    end

endmodule