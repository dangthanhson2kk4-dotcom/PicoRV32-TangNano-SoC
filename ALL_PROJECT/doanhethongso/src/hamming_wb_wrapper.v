
module hamming_wb_wrapper (
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire        wb_stb_i,
    input  wire        wb_cyc_i,
    input  wire        wb_we_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    output wire [1:0]  error_leds 
);

    reg [15:0] ham_in_reg; 
    wire [7:0] data_clean, data_raw;
    wire [1:0] status;

    assign error_leds = status;

    // --- GỌI LÕI LOGIC ---
    hamming_secded_core core_inst (
        .uart_data_in(ham_in_reg),
        .data_out_clean(data_clean),
        .data_out_raw(data_raw),
        .err_status(status)
    );

    // --- LOGIC BUS WISHBONE ---
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
            ham_in_reg <= 16'h0;
        end else begin
            wb_ack_o <= wb_stb_i && wb_cyc_i && !wb_ack_o;
            
            // Nếu CPU thực hiện lệnh GHI (we=1) vào địa chỉ 0x4000_2000 (offset 0)
            if (wb_stb_i && wb_cyc_i && wb_we_i && (wb_adr_i[3:0] == 4'h0)) begin
                ham_in_reg <= wb_dat_i[15:0];
            end
        end
    end

    // --- LOGIC ĐỌC DỮ LIỆU ---
    always @(*) begin
        wb_dat_o = 32'h0;
        if (wb_stb_i && wb_cyc_i && !wb_we_i) begin
            case (wb_adr_i[3:0])
                4'h4:    wb_dat_o = {24'h0, data_clean}; // CPU đọc kết quả sạch
                4'h8:    wb_dat_o = {30'h0, status};     // CPU đọc trạng thái lỗi
                4'hC:    wb_dat_o = {24'h0, data_raw};   // CPU đọc kết quả thô
                default: wb_dat_o = 32'h0;
            endcase
        end
    end
endmodule