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
    SMI 50
    PLO 11              ; net -= 50 (white king uncomfortable)
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
    ADI 50
    PLO 11              ; net += 50 (black king uncomfortable)
OOO_DONE:
    GLO 11              ; D = signed net
    RETN
