// =============================================================================
// File: soc_interconnect.v
// Chức năng: Giải mã địa chỉ và điều phối Bus Wishbone cho PicoRV32
// =============================================================================

module soc_interconnect (
    // Wishbone Master (CPU PicoRV32)
    input  wire [31:0] m_wb_adr_i,
    input  wire [31:0] m_wb_dat_i,
    output reg  [31:0] m_wb_dat_o,
    input  wire        m_wb_we_i,
    input  wire        m_wb_stb_i,
    input  wire        m_wb_cyc_i,
    output reg         m_wb_ack_o,

    // Slaves: RAM, UART, Hamming, TFT
    // (Kết nối các tín hiệu này tới các module tương ứng trong soc_top.v)
    output wire [31:0] s_ram_adr, input wire [31:0] s_ram_dat, input wire s_ram_ack,
    output wire [31:0] s_uart_adr, input wire [31:0] s_uart_dat, input wire s_uart_ack,
    output wire [31:0] s_ham_adr, input wire [31:0] s_ham_dat, input wire s_ham_ack,
    output wire [31:0] s_tft_adr, input wire [31:0] s_tft_dat, input wire s_tft_ack
);

    // Giải mã địa chỉ dựa trên 4 bit cao nhất
    wire sel_ram  = (m_wb_adr_i[31:28] == 4'h0); 
    wire sel_uart = (m_wb_adr_i[31:28] == 4'h4); 
    wire sel_ham  = (m_wb_adr_i[31:28] == 4'h5); 
    wire sel_tft  = (m_wb_adr_i[31:28] == 4'h6); 

    // Điều hướng dữ liệu và ACK ngược về CPU
    always @(*) begin
        if (sel_ram) begin
            m_wb_dat_o = s_ram_dat;
            m_wb_ack_o = s_ram_ack;
        end else if (sel_uart) begin
            m_wb_dat_o = s_uart_dat;
            m_wb_ack_o = s_uart_ack;
        end else if (sel_ham) begin
            m_wb_dat_o = s_ham_dat;
            m_wb_ack_o = s_ham_ack;
        end else if (sel_tft) begin
            m_wb_dat_o = s_tft_dat;
            m_wb_ack_o = s_tft_ack;
        end else begin
            m_wb_dat_o = 32'h0;
            m_wb_ack_o = 1'b0;
        end
    end

    // Truyền tín hiệu địa chỉ tới các Slaves (Dùng địa chỉ tương đối)
    assign s_ram_adr  = m_wb_adr_i;
    assign s_uart_adr = m_wb_adr_i;
    assign s_ham_adr  = m_wb_adr_i;
    assign s_tft_adr  = m_wb_adr_i;

endmodule