// =============================================================================
// Module: hamming_secded_core
// Chức năng: Giải mã Hamming (12,8) mở rộng (SEC-DED)
// Quy tắc Mapping: 
// High Byte: [1] [P8][P4][P2][P1] [D7][D6][D5]
// Low Byte:  [0] [0] [P0] [D4][D3][D2][D1][D0]  -> P0 nằm ở bit 5 của gói 16-bit
// =============================================================================

module hamming_secded_core (
    input  wire [15:0] uart_data_in,   
    output wire [7:0]  data_out_clean, 
    output wire [7:0]  data_out_raw,   
    output wire [1:0]  err_status      
);

    //  UNPACKING 
    wire [12:1] mapped_data;
    wire p0_in;

    // Phân bổ Parity 
    assign mapped_data[1]  = uart_data_in[11]; 
    assign mapped_data[2]  = uart_data_in[12]; 
    assign mapped_data[4]  = uart_data_in[13]; 
    assign mapped_data[8]  = uart_data_in[14]; 
    
    // P0 tại bit 5 của gói 16-bit
    assign p0_in           = uart_data_in[5];  
    
    // Phân bổ 8-bit Data ASCII
    assign mapped_data[12] = uart_data_in[10]; 
    assign mapped_data[11] = uart_data_in[9];  
    assign mapped_data[10] = uart_data_in[8];  
    assign mapped_data[9]  = uart_data_in[4];  
    assign mapped_data[7]  = uart_data_in[3];  
    assign mapped_data[6]  = uart_data_in[2];  
    assign mapped_data[5]  = uart_data_in[1];  
    assign mapped_data[3]  = uart_data_in[0];  

    // TÍNH TOÁN SYNDROME & PARITY TỔNG 
    wire s1, s2, s4, s8;
    wire [3:0] syndrome;
    wire p0_calc;

    assign s1 = mapped_data[1] ^ mapped_data[3] ^ mapped_data[5] ^ mapped_data[7] ^ mapped_data[9] ^ mapped_data[11];
    assign s2 = mapped_data[2] ^ mapped_data[3] ^ mapped_data[6] ^ mapped_data[7] ^ mapped_data[10] ^ mapped_data[11];
    assign s4 = mapped_data[4] ^ mapped_data[5] ^ mapped_data[6] ^ mapped_data[7] ^ mapped_data[12];
    assign s8 = mapped_data[8] ^ mapped_data[9] ^ mapped_data[10] ^ mapped_data[11] ^ mapped_data[12];

    assign syndrome = {s8, s4, s2, s1};
    assign p0_calc  = ^mapped_data; // XOR của toàn bộ 12 bit thực nhận

    //  LOGIC SEC-DED CHUẨN ECC RAM 
    reg [12:1] corrected_data;
    reg [1:0]  status_reg;

    always @(*) begin
        corrected_data = mapped_data; 
        status_reg = 2'b00;

        if (syndrome != 4'b0000) begin
            if (p0_calc != p0_in) begin
                // Lỗi 1 bit: Syndrome != 0 và Parity tổng báo sai -> SỬA ĐƯỢC
                if (syndrome <= 12) begin
                    corrected_data[syndrome] = ~mapped_data[syndrome];
                    status_reg = 2'b01; 
                end else begin
                    status_reg = 2'b10; 
                end
            end else begin
                // Lỗi 2 bit: Syndrome != 0 nhưng Parity tổng báo đúng 
                // Theo chuẩn ECC RAM: Báo lỗi kép (10) và KHÔNG SỬA
                status_reg = 2'b10; 
                corrected_data = mapped_data; 
            end
        end else begin
            if (p0_calc != p0_in) begin
                // Syndrome = 0 nhưng P0 sai -> Lỗi chính bit P0
                status_reg = 2'b01;
            end else begin
                // Tất cả đều khớp -> Sạch
                status_reg = 2'b00;
            end
        end
    end

    // --- BƯỚC 4: TRÍCH XUẤT ĐẦU RA ---
    assign err_status = status_reg;

    // Trích xuất 8 bit từ mảng đã sửa lỗi (Clean)
    assign data_out_clean = {corrected_data[12:9], corrected_data[7:5], corrected_data[3]};

    // Trích xuất 8 bit từ mảng thô (Raw)
    assign data_out_raw   = {mapped_data[12:9], mapped_data[7:5], mapped_data[3]};

endmodule