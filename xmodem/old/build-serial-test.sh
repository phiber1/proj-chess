a18 serial-test.asm -o serial-test.hex -l serial-test.lst
srec_cat serial-test.hex -intel -o serial-test.hex -intel -line-length=57
