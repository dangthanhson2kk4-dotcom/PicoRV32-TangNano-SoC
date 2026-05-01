import serial
import time
import random

# --- LOGIC TÍNH TOÁN SEC-DED ---
def calculate_sec_ded(data_byte):
    d = [(data_byte >> i) & 1 for i in range(8)]
    
    p1 = d[0] ^ d[1] ^ d[3] ^ d[4] ^ d[6]
    p2 = d[0] ^ d[2] ^ d[3] ^ d[5] ^ d[6]
    p4 = d[1] ^ d[2] ^ d[3] ^ d[7]
    p8 = d[4] ^ d[5] ^ d[6] ^ d[7]
    
    hamming_12bit = [p1, p2, d[0], p4, d[1], d[2], d[3], p8, d[4], d[5], d[6], d[7]]
    
    p0 = 0
    for b in hamming_12bit: p0 ^= b
        
    return {
        'p': [p1, p2, p4, p8], 
        'p0': p0, 
        'd': d, 
        'full_13': hamming_12bit + [p0] 
    }

# --- LOGIC CHÈN LỖI ---
def inject_error(sec_ded_data, mode):
    bits = list(sec_ded_data['full_13']) 
    status = " -> [HỢP LỆ] Dữ liệu truyền đi an toàn."
    
    if mode == 1: 
        err_pos = random.randint(0, 12)
        bits[err_pos] ^= 1
        status = f" -> [CẢNH BÁO] Đã tạo lỗi 1 bit tại vị trí {err_pos} (FPGA có thể tự sửa)."
    elif mode == 2: 
        err_pos = random.sample(range(13), 2)
        for p in err_pos: bits[p] ^= 1
        status = f" -> [NGHIÊM TRỌNG] Lỗi 2 bit tại vị trí {err_pos} - KHÔNG THỂ SỬA ĐƯỢC!"
        
    return bits, status

# --- ĐÓNG GÓI THEO QUY CHUẨN MSB FLAG ---
def pack_sec_ded(bits_13):
    p1, p2, d0, p4, d1, d2, d3, p8, d4, d5, d6, d7, p0 = bits_13
    byte1 = (1 << 7) | (p8 << 6) | (p4 << 5) | (p2 << 4) | (p1 << 3) | (d7 << 2) | (d6 << 1) | d5
    byte2 = (0 << 7) | (0 << 6) | (p0 << 5) | (d4 << 4) | (d3 << 3) | (d2 << 2) | (d1 << 1) | d0
    return byte1, byte2 

# --- MAIN PROGRAM ---
try:
    ser = serial.Serial('COM3', 115200, timeout=1) 
    
    print("===========================================")
    print("   UART SEC-DED TRANSMITTER MONITOR")
    print("===========================================")

    while True:
        user_input = input("\n[BÀN PHÍM] Nhập chuỗi cần gửi: ")
        if user_input.lower() == 'exit': break
        
        print(">> Chế độ nhiễu: [0] Sạch  |  [1] Lỗi 1 bit  |  [2] Lỗi 2 bit")
        try: mode = int(input(">> Chọn Mode: "))
        except: mode = 0

        print("-" * 45)

        dummy_data = calculate_sec_ded(0) 
        db1, db2 = pack_sec_ded(dummy_data['full_13'])
        for _ in range(2):
            ser.write(bytes([db1, db2]))
            time.sleep(0.05) 

        for char in user_input:
            data = calculate_sec_ded(ord(char))
            corrupted_bits, status = inject_error(data, mode)
            b1, b2 = pack_sec_ded(corrupted_bits)
            
            # Gửi dữ liệu
            ser.write(bytes([b1, b2]))
            
            # HIỂN THỊ LOG RA MÀN HÌNH PYTHON
            if mode == 2:
                # Báo lỗi mạnh mẽ với Mode 2
                print(f"❌ Ký tự '{char}'{status}")
            elif mode == 1:
                print(f"⚠️ Ký tự '{char}'{status}")
            else:
                print(f"✅ Ký tự '{char}'{status}")
                
            print(f"       + Byte High: {bin(b1)[2:].zfill(8)} (Hex: {hex(b1)})")
            print(f"       + Byte Low : {bin(b2)[2:].zfill(8)} (Hex: {hex(b2)})")
            time.sleep(0.05) 

    ser.close()
except Exception as e:
    print(f"Lỗi: {e}")