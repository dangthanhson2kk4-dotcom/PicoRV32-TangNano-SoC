// =============================================================================
// Module: soc_ram
// Chức năng: Bộ nhớ RAM 16KB dùng Block RAM (BSRAM) chuẩn của FPGA Gowin
// =============================================================================

module soc_ram (
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    input  wire        wb_cyc_i,
    output reg  [31:0] wb_dat_o,  
    output reg         wb_ack_o
);

    reg [31:0] mem [0:4095];

    // Nạp mã máy từ file hex
    integer i;
    initial begin
    $readmemh("D:/doanhethongso/Verilog/Final/doanhethongso/src/firmware.hex", mem);  
    end

    wire [11:0] addr = wb_adr_i[13:2];
    wire valid = wb_stb_i && wb_cyc_i;

    // Đọc/Ghi bắt buộc phải có xung Clock 
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'h0;
        end else begin
            // Nếu có yêu cầu hợp lệ và chưa trả lời (chưa báo ACK)
            if (valid && !wb_ack_o) begin
                if (wb_we_i) begin
                    mem[addr] <= wb_dat_i; 
                end
                // Đọc dữ liệu đồng bộ
                wb_dat_o <= mem[addr];
                
                // Báo cho CPU biết đã chuẩn bị xong dữ liệu trong nhịp clock này
                wb_ack_o <= 1'b1;
            end else begin
                // Hạ cờ ACK sau 1 chu kỳ để kết thúc phiên giao dịch
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule