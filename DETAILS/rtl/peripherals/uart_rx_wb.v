// =============================================================================
// Đồng bộ Clock 27MHz để nhận đúng Baudrate 115200
// =============================================================================

module uart_rx_wb #(
    parameter CLOCK_FREQ = 27000000, // Xung nhịp hệ thống 27MHz
    parameter BAUD_RATE  = 115200   
)(
    input  wire        wb_clk_i,    
    input  wire        wb_rst_i,
    input  wire [31:0] wb_adr_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire        uart_rx,
    output wire [15:0] packet_16bit_out,
    output wire        ready_o
);

    // --- Bộ nhận UART 8-bit cơ bản ---
    reg [7:0]  rx_byte;
    reg        rx_done;
    reg [3:0]  bit_cnt;
    reg [15:0] baud_cnt;
    reg [1:0]  state;
    
    localparam DIVISOR = CLOCK_FREQ / BAUD_RATE; 

    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            state <= 0; 
            rx_done <= 0;
            baud_cnt <= 0;
            bit_cnt <= 0;
        end else begin
            rx_done <= 0;
            case (state)
                0: if (!uart_rx) begin 
                       baud_cnt <= DIVISOR / 2;
                       state <= 1; 
                   end 
                1: if (baud_cnt == 0) begin 
                       baud_cnt <= DIVISOR; 
                       bit_cnt <= 0; 
                       state <= 2; 
                   end else begin
                       baud_cnt <= baud_cnt - 1;
                   end
                2: if (baud_cnt == 0) begin
                       rx_byte[bit_cnt] <= uart_rx;
                       baud_cnt <= DIVISOR;
                       if (bit_cnt == 7) state <= 3; 
                       else bit_cnt <= bit_cnt + 1;
                   end else begin
                       baud_cnt <= baud_cnt - 1;
                   end
                3: if (baud_cnt == 0) begin 
                       rx_done <= 1; 
                       state <= 0;
                   end else begin
                       baud_cnt <= baud_cnt - 1;
                   end
            endcase
        end
    end

    // --- FSM Ghép 2 Byte & Giao tiếp Wishbone ---
    reg [7:0]  high_byte_reg;
    reg [15:0] packet_16bit;
    reg        ready_flag;

    assign packet_16bit_out = packet_16bit;
    assign ready_o = ready_flag;

    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            ready_flag <= 0;
            wb_ack_o   <= 0;
            wb_dat_o   <= 0;
            high_byte_reg <= 0;
            packet_16bit  <= 0;
        end else begin
            if (rx_done) begin
                if (rx_byte[7] == 1'b1) begin
                    high_byte_reg <= rx_byte; 
                end else begin
                    packet_16bit <= {high_byte_reg, rx_byte}; 
                    ready_flag <= 1; 
                end
            end

            wb_ack_o <= wb_stb_i && wb_cyc_i && !wb_ack_o;
            
            if (wb_stb_i && wb_cyc_i && !wb_ack_o && !wb_we_i) begin
                if (wb_adr_i[3:0] == 4'h0) begin
                    wb_dat_o <= {16'h0, packet_16bit};
                    ready_flag <= 0; 
                end else if (wb_adr_i[3:0] == 4'h4) begin
                    wb_dat_o <= {31'h0, ready_flag};
                end
            end
        end
    end
endmodule