#include <stdint.h>

// ==========================================
// ĐỊNH NGHĨA ĐỊA CHỈ CƠ SỞ (BASE ADDRESS)
// ==========================================
#define UART_BASE     0x40000000
#define HAMMING_BASE  0x50000000
#define TFT_BASE      0x60000000

#define UART_DATA     (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_STATUS   (*(volatile uint32_t*)(UART_BASE + 0x04))

#define HAM_IN        (*(volatile uint32_t*)(HAMMING_BASE + 0x00))
#define HAM_CLEAN     (*(volatile uint32_t*)(HAMMING_BASE + 0x04)) 
#define HAM_STATUS    (*(volatile uint32_t*)(HAMMING_BASE + 0x08)) 
#define HAM_RAW       (*(volatile uint32_t*)(HAMMING_BASE + 0x0C)) 

#define TFT_CHAR      (*(volatile uint32_t*)(TFT_BASE + 0x00))
#define TFT_ROW       (*(volatile uint32_t*)(TFT_BASE + 0x04))
#define TFT_CONFIG    (*(volatile uint32_t*)(TFT_BASE + 0x08)) 
#define TFT_SPI_TX    (*(volatile uint32_t*)(TFT_BASE + 0x0C)) 
#define TFT_STATUS    (*(volatile uint32_t*)(TFT_BASE + 0x0C)) 

// ==========================================
// CÁC HÀM ĐIỀU KHIỂN CƠ BẢN
// ==========================================
int uart_has_data() { return (UART_STATUS & 0x01); }
int tft_is_busy()   { return (TFT_STATUS & 0x01); }

void delay_loop(uint32_t count) {
    for (volatile uint32_t i = 0; i < count; i++);
}

// --- DRIVER TFT ---
void tft_write_cmd(uint8_t cmd) {
    while(tft_is_busy());
    TFT_CONFIG = 6; 
    TFT_SPI_TX = cmd;
    while(tft_is_busy());
    TFT_CONFIG = 5; 
}

void tft_write_data(uint8_t data) {
    while(tft_is_busy());
    TFT_CONFIG = 7; 
    TFT_SPI_TX = data;
    while(tft_is_busy());
    TFT_CONFIG = 5;
}

void tft_init() {
    TFT_CONFIG = 1; delay_loop(50000);
    TFT_CONFIG = 5; delay_loop(50000);
    tft_write_cmd(0x11); delay_loop(50000);
    tft_write_cmd(0x36); tft_write_data(0x00); 
    tft_write_cmd(0x3A); tft_write_data(0x05);
    tft_write_cmd(0x29); delay_loop(50000);
}

void tft_clear_black() {
    tft_write_cmd(0x2A); tft_write_data(0x00); tft_write_data(0x00); tft_write_data(0x00); tft_write_data(0xEF); 
    tft_write_cmd(0x2B); tft_write_data(0x00); tft_write_data(0x00); tft_write_data(0x00); tft_write_data(0xEF); 
    tft_write_cmd(0x2C); 
    for(int i = 0; i < 57600; i++) { tft_write_data(0x00); tft_write_data(0x00); }
}

void tft_draw_char_at(uint8_t ascii, uint8_t x, uint8_t y) {
    tft_write_cmd(0x2A); tft_write_data(0x00); tft_write_data(x); tft_write_data(0x00); tft_write_data(x + 7); 
    tft_write_cmd(0x2B); tft_write_data(0x00); tft_write_data(y); tft_write_data(0x00); tft_write_data(y + 15); 
    tft_write_cmd(0x2C); 
    TFT_CHAR = ascii;
    for (int r = 0; r < 16; r++) { TFT_ROW = r; while(tft_is_busy()); }
}

// Hàm in chuỗi ký tự
void tft_draw_string(const char *s, uint8_t x, uint8_t y) {
    while (*s) {
        tft_draw_char_at(*s, x, y);
        x += 10;
        s++;
    }
}

// ==========================================
// CHƯƠNG TRÌNH CHÍNH
// ==========================================
int main() {
    tft_init();
    tft_clear_black(); 

    // 1. VẼ CÁC NHÃN CỐ ĐỊNH (Chỉ vẽ 1 lần để tránh giật hình)
    tft_draw_string("DATA_RAW:", 0, 10);
    tft_draw_string("DATA_FIXED:", 0, 60);
    tft_draw_string("ERR_BITS:", 0, 110);
    tft_draw_string("FIXABLE:", 0, 140);
    tft_draw_string("NHOM4_HTS", 0, 180);

    uint8_t cursor_x = 0;

    while (1) {
        while (!uart_has_data());
        uint32_t raw_packet = UART_DATA;

        HAM_IN = raw_packet; 
        
        uint8_t char_fix = (uint8_t)(HAM_CLEAN & 0xFF);
        uint8_t char_err = (uint8_t)(HAM_RAW & 0xFF);
        uint8_t status   = (uint8_t)(HAM_STATUS & 0x03); 

        // Bộ lọc dummy byte 
        if (char_fix == 0) continue; 

        // --- CẬP NHẬT DỮ LIỆU ---
        
        tft_draw_char_at(char_err, cursor_x, 30); 

        if (status == 2) {
            tft_draw_char_at('?', cursor_x, 80); 
        } else {
            tft_draw_char_at(char_fix, cursor_x, 80); 
        }

        tft_draw_char_at('0' + status, 100, 110);

        if (status < 2) {
            tft_draw_string("YES", 100, 140);
        } else {
            tft_draw_string("NO ", 100, 140); 
        }

        // Cập nhật vị trí con trỏ cho các chuỗi DATA
        cursor_x += 10;
        if (cursor_x >= 230) {
            cursor_x = 0;
        }
    }
    return 0;
}