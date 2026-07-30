; ==============================================================================
; OVERFLOW PAGE $7B00-$7BFF (256 B) — subroutine landing pad
; ==============================================================================
; This page is the ONLY free code region besides the main-segment tail (see
; memory/high_memory_map_authoritative.md). This module is cat'ed LAST by
; build.sh so its ORG cannot relocate any other module. Keep tenants small,
; LEAF, and one-page; run tools/audit_table_pages.py after any change here.
; ==============================================================================
        ORG $7B00

; ------------------------------------------------------------------------------
; OOO_DISCOMFORT - queenside-castle discomfort vs a developed enemy queen
; (2026-07-08, task #53). The corpus shows 10 of 13 O-O-O losses castled (or
; sat) queenside WHILE the enemy queen was developed on files a-d; 9 of 11
; O-O-O wins had her home on d8. v3's ZONE_R proximity gate cannot see a
; pre-aimed queen at castle time (a5 is rank-distance 4 from c1), so this term
; supplies the anticipation: a standing penalty for queenside king posture
; whenever the enemy queen stands developed on that wing, at ANY distance.
; Self-healing: reads the live board each eval — penalty lifts when the queen
; trades off or leaves the wing.
;   White fires: wK on files a-c, ranks 1-2 AND bQ on files a-d, not home d8.
;   Black mirror: bK files a-c, ranks 7-8 AND wQ files a-d, not home d1.
; In:  nothing (reads GAME_STATE king squares + W/B_QUEEN_SQ trackers)
; Out: D = signed net adjustment (-50 white-fire / +50 black-fire / 0 / 0 both)
; Preserves R9, R12. Clobbers R10, R11, R13, D. LEAF. X=2 assumed (caller = EVALUATE).
; ------------------------------------------------------------------------------
OOO_DISCOMFORT:
    RLDI 13, TRACE_WHERE
    LDI $E4
    STR 13              ; tracer: in OOO_DISCOMFORT
    LDI 0
    PLO 11              ; R11.0 = signed net adjustment
    ; --- white king in queenside posture? (files a-c, ranks 1-2) ---
    RLDI 10, GAME_STATE + STATE_W_KING_SQ
    LDN 10
    ANI $60
    LBNZ OOO_B_SIDE     ; rank > 2 -> no queenside-castle posture
    LDN 10
    ANI $07
    SMI 3
    LBDF OOO_B_SIDE     ; file >= d -> not queenside
    ; --- PAWN-STORM term (2026-07-30 exhibition-prep, loss19+loss23): both
    ; O-O-O mates this week were PAWNS-FIRST storms — the queen arrived last,
    ; so the queen-keyed term below stayed silent while a5/b5 (loss19) and
    ; b5/a5 (loss23, from mv8) rolled in and Ra1#/Qa1# followed on the ripped
    ; a-file. Signal: black storm pawn ON RANK 5 (a5/b5), -40 per file,
    ; independent of the queen term; self-healing (read live each eval).
    ; Rank 5 exactly, NOT missing-from-home: win36 (O-O-O blowout WIN)
    ; castled with black a4-blocked + b6 — home-absence would have taxed a
    ; proven-good castle; rank 5 is the crossing point where a storm is
    ; committed but not yet landed, and separates all four probe games. ---
    RLDI 10, BOARD + $40
    LDN 10              ; a5
    XRI B_PAWN
    LBNZ OOO_W_B5
    GLO 11
    SMI 40
    PLO 11              ; net -= 40 (a-pawn storming)
OOO_W_B5:
    RLDI 10, BOARD + $41
    LDN 10              ; b5
    XRI B_PAWN
    LBNZ OOO_W_QUEEN
    GLO 11
    SMI 40
    PLO 11              ; net -= 40 (b-pawn storming)
OOO_W_QUEEN:
    ; black queen developed on files a-d?
    RLDI 10, B_QUEEN_SQ
    LDN 10
    XRI $FF
    LBZ OOO_B_SIDE      ; no black queen -> quiet
    LDN 10
    XRI $73
    LBZ OOO_B_SIDE      ; home on d8 -> quiet (the 5 clean O-O-O wins)
    LDN 10
    ANI $04
    LBNZ OOO_B_SIDE     ; files e-h -> not aimed at the queenside
    GLO 11
    SMI 75
    PLO 11              ; net -= 75 (white king uncomfortable; raised from 50
                        ; 2026-07-14: master's v2 shield nets +25 PRO-castle in
                        ; the loss4 probe — e1 misses d2+e2, c1 only d2 — so 50
                        ; was outvoted; control probe immune, trigger-cold)
OOO_B_SIDE:
    ; --- black king in queenside posture? (files a-c, ranks 7-8) ---
    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10
    ANI $60
    XRI $60
    LBNZ OOO_DONE       ; rank nibble < $60 -> not on black's back two ranks
    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10
    ANI $07
    SMI 3
    LBDF OOO_DONE       ; file >= d -> not queenside
    ; --- mirror PAWN-STORM term: white storm pawn on rank 4 (a4/b4) ---
    RLDI 10, BOARD + $30
    LDN 10              ; a4
    XRI W_PAWN
    LBNZ OOO_B_B4
    GLO 11
    ADI 40
    PLO 11              ; net += 40 (a-pawn storming vs black king)
OOO_B_B4:
    RLDI 10, BOARD + $31
    LDN 10              ; b4
    XRI W_PAWN
    LBNZ OOO_B_QUEEN
    GLO 11
    ADI 40
    PLO 11              ; net += 40 (b-pawn storming vs black king)
OOO_B_QUEEN:
    ; white queen developed on files a-d?
    RLDI 10, W_QUEEN_SQ
    LDN 10
    XRI $FF
    LBZ OOO_DONE        ; no white queen -> quiet
    LDN 10
    XRI $03
    LBZ OOO_DONE        ; home on d1 -> quiet
    LDN 10
    ANI $04
    LBNZ OOO_DONE       ; files e-h -> not aimed
    GLO 11
    ADI 75
    PLO 11              ; net += 75 (black king uncomfortable; mirror of white)
OOO_DONE:
    GLO 11              ; D = signed net
    RETN

; ==============================================================================
; BP_VECTOR - IDLE-exit crash catcher (2026-07-23, Mark's design; tested in
; interrupt_demo.asm). The 1806 loads P from R0 on IDL, so a wild-PC freeze
; (the hang class: wild jump -> $00 byte -> IDLE) parks the CPU waiting on R0.
; START arms R0 = BP_VECTOR and enables IE (SEX 3/RET/$23 inline idiom), so
; grounding /INTERRUPT on a frozen machine executes THIS: MARK saves (X,P),
; SEP 1 enters the BIOS breakpoint handler = FULL register dump — including
; R3 = the address immediately after the fatal IDL = the crash site.
; /INT is hard-tied high; only a deliberate probe ground ever triggers this.
; Bonus signature: an armed frozen machine shows THIS address on the bus, not
; the old $FCF7 boot fossil.
; ==============================================================================
BP_VECTOR:
    MARK                ; T & M(R2) <- (X,P)
    SEP 1               ; -> BIOS breakpoint handler: full register dump
    LBR $8003           ; monitor warm start (safety, if handler returns)
