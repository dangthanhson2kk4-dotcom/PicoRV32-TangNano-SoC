# generate_hex.py
def bin_to_hex(bin_file, hex_file):
    with open(bin_file, 'rb') as f:
        data = f.read()
    
    with open(hex_file, 'w') as f:
        # PicoRV32 đọc mỗi lần 4 byte (32-bit)
        for i in range(0, 16384, 4): 
            if i < len(data):
                # Lấy 4 byte và đảo ngược 
                chunk = data[i:i+4]
                if len(chunk) < 4: chunk += b'\x00' * (4 - len(chunk))
                val = int.from_bytes(chunk, 'little')
                f.write(f"{val:08x}\n")
            else:
                f.write("00000013\n") # Điền lệnh NOP (để CPU không bị Trap)

bin_to_hex('firmware.bin', 'firmware.hex')
print("Da tao xong firmware.hex chuan!")