; ==============================================================================
; RCA 1802/1806 Chess Engine - Endgame Heuristics
; ==============================================================================
; Special evaluation bonuses for endgame positions:
; 1. King centralization when material is low
; 2. Drive enemy king to edge/corner in winning positions
; 3. Passed pawn bonus
; ==============================================================================

; Endgame threshold (in centipawns of total material)
; Below this, we're in the endgame
; Roughly: 2 rooks + 2 minor = 2*500 + 2*325 = 1650
ENDGAME_THRESHOLD_LO    EQU $68     ; 1640 = $0668
ENDGAME_THRESHOLD_HI    EQU $06

; King centralization table (bonus for king being in center during endgame)
; Higher values in center, lower on edges
KING_CENTER_TABLE:
    ; Rank 8
    DB -30,-20,-10,  0,  0,-10,-20,-30
    ; Rank 7
    DB -20,-10,  0, 10, 10,  0,-10,-20
    ; Rank 6
    DB -10,  0, 10, 20, 20, 10,  0,-10
    ; Rank 5
    DB   0, 10, 20, 30, 30, 20, 10,  0
    ; Rank 4
    DB   0, 10, 20, 30, 30, 20, 10,  0
    ; Rank 3
    DB -10,  0, 10, 20, 20, 10,  0,-10
    ; Rank 2
    DB -20,-10,  0, 10, 10,  0,-10,-20
    ; Rank 1
    DB -30,-20,-10,  0,  0,-10,-20,-30

; King to edge table (bonus for enemy king on edge/corner — drive-to-mate)
; Use this when we're winning to drive enemy king to corner.
; Higher values at edges/corners, lower in center.
KING_EDGE_TABLE:
    ; Rank 8
    DB  60, 50, 40, 30, 30, 40, 50, 60
    ; Rank 7
    DB  50, 40, 30, 20, 20, 30, 40, 50
    ; Rank 6
    DB  40, 30, 20, 10, 10, 20, 30, 40
    ; Rank 5
    DB  30, 20, 10,  0,  0, 10, 20, 30
    ; Rank 4
    DB  30, 20, 10,  0,  0, 10, 20, 30
    ; Rank 3
    DB  40, 30, 20, 10, 10, 20, 30, 40
    ; Rank 2
    DB  50, 40, 30, 20, 20, 30, 40, 50
    ; Rank 1
    DB  60, 50, 40, 30, 30, 40, 50, 60

; ==============================================================================
; EVAL_ENDGAME / CALC_TOTAL_MATERIAL removed 2026-06-01 (branch see-exchange-eval):
; dead code (no live caller; SEE reclaim needed the headroom). KING_CENTER_TABLE
; and KING_EDGE_TABLE above are still live (used by evaluate.asm). Recover from
; git history if endgame king-distance heuristics are ever revived.
; ==============================================================================
