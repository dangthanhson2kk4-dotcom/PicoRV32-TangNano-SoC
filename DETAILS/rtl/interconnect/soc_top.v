// =============================================================================
// Module: soc_top
// Chức năng: Kết nối toàn bộ hệ thống SoC - Sửa lỗi Port và Gating Control Bus
// =============================================================================

module soc_top (
    input  wire        clk,        
    input  wire        reset_n,    
    input  wire        uart_rx,    
    
    // --- GIAO TIẾP MÀN HÌNH SPI TFT ---
    output wire        tft_sck,    
    output wire        tft_mosi,   
    output wire        tft_cs_n,   
    output wire        tft_dc,     
    output wire        tft_res,    
    
    // --- HIỂN THỊ TRẠNG THÁI ---
    output wire        led0,       // LED đơn 1 (Báo lỗi 1 bit)
    output wire        led1,       // LED đơn 2 (Báo lỗi 2 bit)
    output wire        trap_led    // LED đơn 3 (Báo lỗi CPU Trap)
);

    // --- CLOCK & RESET LOGIC ---
    wire clk_soc = clk;       

    // Tạo mạch đếm Reset siêu tốc lúc vừa cấp điện
    reg [7:0] reset_counter = 8'h00;
    always @(posedge clk_soc) begin
        if (reset_counter != 8'hFF) begin
            reset_counter <= reset_counter + 8'd1;
        end
    end

    // cpu_reset = 1 (Đang Reset) khi đếm chưa xong HOẶC người dùng đang bấm nút S1.
    wire cpu_reset = (reset_counter != 8'hFF) || (!reset_n); 
    
    // sys_rst_n = 0 (Đang Reset) khi đếm chưa xong HOẶC người dùng đang bấm nút S1.
    wire sys_rst_n = (reset_counter == 8'hFF) && (reset_n);

    // --- MASTER BUS (CPU) ---
    wire [31:0] wbm_adr, wbm_dat_o, wbm_dat_i;
    wire [3:0]  wbm_sel;
    wire        wbm_we, wbm_cyc, wbm_stb, wbm_ack;
    wire        cpu_trap;
    
    assign trap_led = ~cpu_trap; // LED báo CPU ngừng hoạt động

    // --- TẠO TÍN HIỆU ĐIỀU KHIỂN RIÊNG CHO TỪNG SLAVE ---
    // Broadcast data & control signals tới tất cả Slave
    wire [31:0] slave_dat_i = wbm_dat_o; 
    wire        slave_we    = wbm_we;
    wire        slave_cyc   = wbm_cyc;

    // Giải mã địa chỉ để chỉ kích hoạt (Strobe) đúng Slave cần thiết
    wire sel_ram  = (wbm_adr[31:28] == 4'h0);
    wire sel_uart = (wbm_adr[31:28] == 4'h4);
    wire sel_ham  = (wbm_adr[31:28] == 4'h5);
    wire sel_tft  = (wbm_adr[31:28] == 4'h6);

    wire s0_stb = wbm_stb & sel_ram;  // Gửi cho RAM
    wire s1_stb = wbm_stb & sel_uart; // Gửi cho UART
    wire s2_stb = wbm_stb & sel_tft;  // Gửi cho TFT
    wire s3_stb = wbm_stb & sel_ham;  // Gửi cho Hamming

    // Tín hiệu trả về từ các Slaves
    wire [31:0] s0_adr, s0_dat_o; wire s0_ack;
    wire [31:0] s1_adr, s1_dat_o; wire s1_ack;
    wire [31:0] s2_adr, s2_dat_o; wire s2_ack;
    wire [31:0] s3_adr, s3_dat_o; wire s3_ack;

    // --- ĐIỀU KHIỂN LED HAMMING (Logic Active Low) ---
    wire [1:0] ham_status;
    assign led0 = ~ham_status[0]; // Sáng khi trạng thái là 01 (Sửa lỗi 1 bit)
    assign led1 = ~ham_status[1]; // Sáng khi trạng thái là 10 (Lỗi kép 2 bit)

    // --- INSTANTIATIONS ---
    
    // CPU PicoRV32
    picorv32_wb_optimized cpu_inst (
        .wb_clk_i (clk_soc),
        .wb_rst_i (cpu_reset),
        .wbm_adr_o(wbm_adr),
        .wbm_dat_o(wbm_dat_o),
        .wbm_dat_i(wbm_dat_i),
        .wbm_we_o (wbm_we),
        .wbm_sel_o(wbm_sel),
        .wbm_stb_o(wbm_stb),
        .wbm_cyc_o(wbm_cyc),
        .wbm_ack_i(wbm_ack),
        .trap     (cpu_trap)
    );

    // Gọi chính xác các Port name của module soc_interconnect
    soc_interconnect bus_inst (
        .m_wb_adr_i(wbm_adr), 
        .m_wb_dat_i(wbm_dat_o), 
        .m_wb_dat_o(wbm_dat_i), 
        .m_wb_we_i (wbm_we),
        .m_wb_stb_i(wbm_stb), 
        .m_wb_cyc_i(wbm_cyc), 
        .m_wb_ack_o(wbm_ack),

        .s_ram_adr (s0_adr), .s_ram_dat (s0_dat_o), .s_ram_ack (s0_ack),
        .s_uart_adr(s1_adr), .s_uart_dat(s1_dat_o), .s_uart_ack(s1_ack),
        .s_tft_adr (s2_adr), .s_tft_dat (s2_dat_o), .s_tft_ack (s2_ack),
        .s_ham_adr (s3_adr), .s_ham_dat (s3_dat_o), .s_ham_ack (s3_ack)
    );

    // Bộ nhớ RAM
    soc_ram ram_inst (
        .wb_clk_i(clk_soc), .wb_rst_i(~sys_rst_n),
        .wb_adr_i(s0_adr), .wb_dat_i(slave_dat_i), .wb_we_i(slave_we),
        .wb_stb_i(s0_stb), .wb_cyc_i(slave_cyc), .wb_dat_o(s0_dat_o), .wb_ack_o(s0_ack)
    );

    // UART Receiver
    uart_rx_wb #(.CLOCK_FREQ(27000000)) uart_inst (
        .wb_clk_i(clk_soc), .wb_rst_i(~sys_rst_n),
        .wb_adr_i(s1_adr), .wb_dat_o(s1_dat_o), .wb_ack_o(s1_ack),
        .wb_cyc_i(slave_cyc), .wb_stb_i(s1_stb), .wb_we_i(slave_we),
        .uart_rx (uart_rx), .packet_16bit_out(), .ready_o()
    );

    // SPI LCD Controller
    spi_tft_controller spi_inst (
        .clk_i(clk_soc), .rst_ni(sys_rst_n),
        .s_wb_adr_i(s2_adr), .s_wb_dat_i(slave_dat_i), .s_wb_we_i(slave_we),
        .s_wb_stb_i(s2_stb), .s_wb_cyc_i(slave_cyc), .s_wb_dat_o(s2_dat_o), .s_wb_ack_o(s2_ack),
        .tft_sck(tft_sck), .tft_mosi(tft_mosi), .tft_cs_n(tft_cs_n), .tft_dc(tft_dc), .tft_res(tft_res)
    );

    // Module Hamming
    hamming_wb_wrapper hamming_inst (
        .wb_clk_i(clk_soc), .wb_rst_i(~sys_rst_n),
        .wb_adr_i(s3_adr), .wb_dat_i(slave_dat_i), .wb_stb_i(s3_stb),
        .wb_cyc_i(slave_cyc), .wb_we_i(slave_we), .wb_dat_o(s3_dat_o),
        .wb_ack_o(s3_ack), 
        .error_leds(ham_status) 
    );
     
endmodule