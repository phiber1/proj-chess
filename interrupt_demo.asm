0000              ORG 0000H
0000 E3           SEX R3
0001 70           RET
0002 23           DEC R3
0003 F8 00        LDI 00H
0005 B0           PHI R0
0006 F8 20        LDI 20H
0008 A0           PLO R0
0009 00           IDL
000A C0 80 03     LBR 8003H
000D              ORG 0020H
0020 79           MARK
0021 D1           SEP R1
0022 C0 80 03     LBR 8003H
