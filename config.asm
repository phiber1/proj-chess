; ==============================================================================
; RCA 1802/1806 Chess Engine - Build Configuration  
; ==============================================================================
; Edit the #define lines below to configure your build
; This file is preprocessed with cpp before assembly
; ==============================================================================

; ==============================================================================
; SERIAL I/O CONFIGURATION
; ==============================================================================

; Uncomment ONE: USE_BIOS, USE_UART, or USE_BITBANG
#define CFG_USE_BIOS        /* Use BIOS entry points (F_TYPE, F_READ, F_MSG) */
/* #define CFG_USE_UART */
/* #define CFG_USE_BITBANG */

#ifdef CFG_USE_BIOS
USE_BIOS        EQU 1
USE_UART        EQU 0
USE_BITBANG     EQU 0
#else
#ifdef CFG_USE_UART
USE_BIOS        EQU 0
USE_UART        EQU 1
USE_BITBANG     EQU 0
#else
USE_BIOS        EQU 0
USE_UART        EQU 0
USE_BITBANG     EQU 1
#endif
#endif

; ------------------------------------------------------------------------------
; EF Line Selection for Bit-Bang Serial
; ------------------------------------------------------------------------------
; Uncomment ONE: CFG_USE_EF1, CFG_USE_EF2, CFG_USE_EF3, or CFG_USE_EF4
/* #define CFG_USE_EF1 */
/* #define CFG_USE_EF2 */
#define CFG_USE_EF3         /* Membership Card uses EF3 for serial RX */
/* #define CFG_USE_EF4 */

#ifdef CFG_USE_EF1
USE_EF1 EQU 1
#else
USE_EF1 EQU 0
#endif

#ifdef CFG_USE_EF2
USE_EF2 EQU 1
#else
USE_EF2 EQU 0
#endif

#ifdef CFG_USE_EF3
USE_EF3 EQU 1
#else
USE_EF3 EQU 0
#endif

#ifdef CFG_USE_EF4
USE_EF4 EQU 1
#else
USE_EF4 EQU 0
#endif

; ==============================================================================
; SERIAL PARAMETERS
; ==============================================================================
; Membership Card: 1.75 MHz clock, 9600 baud
; Uses Chuck's proven serial I/O routine (serial-io-9600.asm)
; R14.0 delay counter = 2 on entry (decremented to 1 for 9600 baud)
BAUD_RATE   EQU 9600
; CPU_CLOCK = 1.75 MHz (Membership Card) - comment only, not used in code

; Note: The serial-io-9600.asm uses inline delays with NOPs and the
; SMI 01H / BNZ loop structure. These values are for reference only.
; The actual timing is built into the proven routine.
BIT_DELAY   EQU 2       ; R14.0 value for 9600 baud (Chuck's routine)
HALF_DELAY  EQU 1       ; Not used by Chuck's routine     

; UART ports
UART_DATA   EQU $01     
UART_STATUS EQU $02     
UART_RX_RDY EQU $01     
UART_TX_RDY EQU $02     

; ==============================================================================
; SYSTEM CONFIGURATION
; ==============================================================================
CODE_START  EQU $0000   
STACK_TOP   EQU $7FFF   
BOARD_BASE  EQU $5000   
STATE_BASE  EQU $5080   

; ==============================================================================
; SEARCH CONFIGURATION
; ==============================================================================
DEFAULT_DEPTH   EQU 6   
MAX_DEPTH       EQU 12  

; ==============================================================================
; DEBUGGING OPTIONS
; ==============================================================================
/* #define CFG_DEBUG_NODES */
/* #define CFG_DEBUG_MOVES */
/* #define CFG_DEBUG_EVAL */

#ifdef CFG_DEBUG_NODES
DEBUG_NODES EQU 1
#else
DEBUG_NODES EQU 0
#endif

#ifdef CFG_DEBUG_MOVES
DEBUG_MOVES EQU 1
#else
DEBUG_MOVES EQU 0
#endif

#ifdef CFG_DEBUG_EVAL
DEBUG_EVAL EQU 1
#else
DEBUG_EVAL EQU 0
#endif

; ==============================================================================
; OPTIMIZATION OPTIONS
; ==============================================================================
/* #define CFG_USE_TRANSPOSITION_TABLE */
/* #define CFG_USE_OPENING_BOOK */
/* #define CFG_USE_PST */
/* #define CFG_USE_KILLER_MOVES */    /* DISABLED for debugging */
/* #define CFG_USE_HISTORY */

#ifdef CFG_USE_TRANSPOSITION_TABLE
USE_TRANSPOSITION_TABLE EQU 1
#else
USE_TRANSPOSITION_TABLE EQU 0
#endif

#ifdef CFG_USE_OPENING_BOOK
USE_OPENING_BOOK EQU 1
#else
USE_OPENING_BOOK EQU 0
#endif

#ifdef CFG_USE_PST
USE_PST EQU 1
#else
USE_PST EQU 0
#endif

#ifdef CFG_USE_KILLER_MOVES
USE_KILLER_MOVES EQU 1
#else
USE_KILLER_MOVES EQU 0
#endif

#ifdef CFG_USE_HISTORY
USE_HISTORY EQU 1
#else
USE_HISTORY EQU 0
#endif

; ==============================================================================
; EMULATOR-SPECIFIC SETTINGS
; ==============================================================================
/* #define CFG_EMU1802 */
/* #define CFG_EMMA02 */
/* #define CFG_COSMAC_ELF_SIM */
/* #define CFG_FAST_EMU_SERIAL */

#ifdef CFG_EMU1802
EMU1802 EQU 1
#else
EMU1802 EQU 0
#endif

#ifdef CFG_EMMA02
EMMA02 EQU 1
#else
EMMA02 EQU 0
#endif

#ifdef CFG_COSMAC_ELF_SIM
COSMAC_ELF_SIM EQU 1
#else
COSMAC_ELF_SIM EQU 0
#endif

#ifdef CFG_FAST_EMU_SERIAL
FAST_EMU_SERIAL EQU 1
#else
FAST_EMU_SERIAL EQU 0
#endif

; ==============================================================================
; VALIDATION
; ==============================================================================
#if !defined(CFG_USE_BIOS) && !defined(CFG_USE_UART) && !defined(CFG_USE_BITBANG)
#error "Must define one of: CFG_USE_BIOS, CFG_USE_UART, or CFG_USE_BITBANG"
#endif

#ifdef CFG_USE_BITBANG
#if !defined(CFG_USE_EF1) && !defined(CFG_USE_EF2) && !defined(CFG_USE_EF3) && !defined(CFG_USE_EF4)
#error "Must define one of: CFG_USE_EF1, CFG_USE_EF2, CFG_USE_EF3, or CFG_USE_EF4"
#endif
#endif

; ==============================================================================
; End of Configuration
; ==============================================================================
