module spi_tft_controller (
    input  wire        clk_i, rst_ni,
    input  wire [31:0] s_wb_adr_i, s_wb_dat_i,
    input  wire        s_wb_we_i, s_wb_stb_i, s_wb_cyc_i,
    output reg  [31:0] s_wb_dat_o,
    output reg         s_wb_ack_o,
    output reg         tft_sck, tft_mosi, tft_cs_n, tft_dc, tft_res
);

    localparam S_IDLE=0, S_WAIT_ROM=1, S_LOAD_PIXEL=2, S_SPI_LOW=3, S_SPI_HIGH=4, S_SPI_END=5, S_NEXT_PIXEL=6;
    reg [2:0] state;
    reg [7:0] char_ascii;
    reg busy, is_raw;
    reg [3:0] row_cnt;
    reg [2:0] col_cnt;
    reg [15:0] shift_reg;
    reg [4:0] bit_cnt;
    
    reg [3:0] spi_div;

    // --- FONT ROM ---
    wire [7:0] rom_data;
    font_rom my_font (.clk(clk_i), .ad({char_ascii[7:0], row_cnt[3:0]}), .dout(rom_data));

    wire wb_valid = s_wb_stb_i & s_wb_cyc_i;

    always @(posedge clk_i) begin
        if (!rst_ni) begin
            state <= S_IDLE; busy <= 0; s_wb_ack_o <= 0; s_wb_dat_o <= 0;
            tft_cs_n <= 1; tft_sck <= 0; tft_mosi <= 0; tft_dc <= 1; tft_res <= 1;
            spi_div <= 0;
        end else begin
            // GIAO TIẾP WISHBONE
            s_wb_ack_o <= wb_valid && !s_wb_ack_o;
            
            if (wb_valid && !s_wb_ack_o) begin
                if (s_wb_we_i) begin
                    case (s_wb_adr_i[3:0])
                        4'h0: char_ascii <= s_wb_dat_i[7:0]; 
                        4'h4: begin row_cnt <= s_wb_dat_i[3:0]; state <= S_WAIT_ROM; busy<=1; is_raw<=0; tft_cs_n<=0; end 
                        4'h8: begin tft_dc <= s_wb_dat_i[0]; tft_cs_n <= ~s_wb_dat_i[1]; tft_res <= s_wb_dat_i[2]; end 
                        4'hC: begin shift_reg <= {s_wb_dat_i[7:0], 8'h00}; bit_cnt <= 8; busy <= 1; is_raw <= 1; state <= S_SPI_LOW; tft_cs_n <= 0; end 
                    endcase
                end else begin
                    if (s_wb_adr_i[3:0] == 4'hC) s_wb_dat_o <= {31'd0, busy}; 
                    else s_wb_dat_o <= 32'h0;
                end
            end

            // ĐỘNG CƠ SPI
            if (busy) begin
                spi_div <= spi_div + 1;
                if (spi_div == 4'd13) begin 
                    spi_div <= 0;
                    case (state)
                        S_WAIT_ROM: begin col_cnt <= 7; state <= S_LOAD_PIXEL; end
                        S_LOAD_PIXEL: begin 
                            shift_reg <= rom_data[col_cnt] ? 16'hFFFF : 16'h0000; 
                            bit_cnt <= 16; tft_dc <= 1; state <= S_SPI_LOW; 
                        end
                        S_SPI_LOW: begin tft_sck <= 0; tft_mosi <= shift_reg[15]; state <= S_SPI_HIGH; end
                        S_SPI_HIGH: begin
                            tft_sck <= 1; shift_reg <= {shift_reg[14:0], 1'b0}; bit_cnt <= bit_cnt - 1;
                            if (bit_cnt == 1) state <= S_SPI_END; 
                            else state <= S_SPI_LOW;
                        end
                        S_SPI_END: begin
                            tft_sck <= 0; 
                            state <= S_NEXT_PIXEL;
                        end
                        S_NEXT_PIXEL: begin
                            if (is_raw) begin busy <= 0; state <= S_IDLE; tft_cs_n <= 1; end
                            else begin
                                if (col_cnt == 0) begin busy <= 0; state <= S_IDLE; tft_cs_n <= 1; end
                                else begin col_cnt <= col_cnt - 1; state <= S_LOAD_PIXEL; end
                            end
                        end
                    endcase
                end
            end else begin
                tft_sck <= 0; 
            end
        end
    end
endmodule