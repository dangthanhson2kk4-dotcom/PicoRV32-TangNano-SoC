module font_rom (
    input  wire        clk,
    input  wire [11:0] ad, 
    output reg  [7:0]  dout
);
    reg [7:0] rom_array [0:4095]; 
    initial begin
        $readmemh("D:/doanhethongso/Verilog/Final/doanhethongso/src/font.hex", rom_array); 
    end

    always @(posedge clk) begin
        dout <= rom_array[ad];
    end
endmodule