a18 xmodem-recv.asm -o xmodem-recv.hex -l xmodem-recv.lst
srec_cat xmodem-recv.hex -intel -o xmodem-recv.hex -intel -line-length=57
