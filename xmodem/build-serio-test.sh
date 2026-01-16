a18 serio-test.asm -o serio-test.hex -l serio-test.lst
srec_cat serio-test.hex -intel -o serio-test.hex -intel -line-length=57
