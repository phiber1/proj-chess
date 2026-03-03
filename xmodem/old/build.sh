a18 xrmem.asm -o xrmem.hex -l xrmem.lst
srec_cat xrmem.hex -intel -o xrmem.hex -intel -line-length=57
