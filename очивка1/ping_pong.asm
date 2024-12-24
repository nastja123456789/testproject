.include "m8def.inc"

.def temp = r16
.def temp2 = r17
.def isr_flag = r18 ; Flag to indicate which ISR to execute

;--------------------------------------
; Constants
.equ F_CPU = 1000000 ; Frequency (1 MHz)
.equ BAUD = 9600
.equ UBRR_VALUE = (F_CPU / (16 * BAUD)) - 1

.equ OCR1A_VAL = 488
.equ OCR2_VAL = 244
.equ TIMER1_FLAG = 0x01
.equ TIMER2_FLAG = 0x02
;---------------------------------------
.cseg
.org 0x0000
rjmp RESET

;--------------------------------------
; Interrupt Vector Table (now redirects to common ISR handler)
.org OC2addr
rjmp COMMON_ISR
.org OC1Aaddr
rjmp COMMON_ISR


;---------------------------------------
RESET:
    ldi temp, 0x00
    out DDRB, temp
    out DDRC, temp
    out DDRD, temp

    ldi temp, UBRR_VALUE
    out UBRRL, temp
    ldi temp, 0
    out UBRRH, temp
    ldi temp, (1 << RXEN) | (1 << TXEN)
    out UCSRB, temp
    ldi temp, (1 << URSEL) | (3 << UCSZ0)
    out UCSRC, temp

    ; Timer1 Setup
    ldi temp, high(OCR1A_VAL)
    out OCR1AH, temp
    ldi temp, low(OCR1A_VAL)
    out OCR1AL, temp

    ldi temp, (1 << WGM12)
    out TCCR1B, temp
    ldi temp, (1 << CS12) | (1 << CS10)
    out TCCR1B, temp
    ldi temp, (1 << OCIE1A)
    out TIMSK, temp


    ; Timer2 Setup
    ldi temp, OCR2_VAL
    out OCR2, temp
    ldi temp, (1 << WGM21) | (1 << CS22) | (1 << CS21) | (1 << CS20)
    out TCCR2, temp
    in temp, TIMSK
    ori temp, (1 << OCIE2)
    out TIMSK, temp
    
    ldi isr_flag, 0x00;reset isr flags
    sei

main_loop:
    rjmp main_loop

;--------------------------------------
; USART Functions
send_char:
    sbis UCSRA, UDRE
    rjmp send_char
    out UDR, r24 ; Send byte in R24
    ret

send_string:
next_char:
    lpm r24, Z+
    tst r24
    breq done_string
    rcall send_char
    rjmp next_char
done_string:
    ret

;---------------------------------------
; String data
ping_str:
    .db "ping\r\n", 0
pong_str:
    .db "pong\r\n", 0


;---------------------------------------
; Common ISR Handler
COMMON_ISR:
    push r16
    push r17
    push r18
    push r24
    push r25
    push ZH
    push ZL

;save the reason of interrupt in isr_flag
    in r16, TIFR ; Read interrupt flags from TIFR
    sbrc r16,OCF2 ; check for timer2 interrupt flag
    ldi isr_flag,TIMER2_FLAG
    sbrs r16,OCF2
    sbrc r16,OCF1A ; check for timer1 interrupt flag
    ldi isr_flag,TIMER1_FLAG
;clear flags, in case they are set by some reason
    out TIFR,r16
    
    
; Jump table
    cpi isr_flag,TIMER1_FLAG
    breq TIMER1_ISR_DISPATCH
    cpi isr_flag,TIMER2_FLAG
    breq TIMER2_ISR_DISPATCH
    rjmp COMMON_ISR_END

TIMER1_ISR_DISPATCH:
    ldi r24, high(ping_str*2)
    ldi r25, low(ping_str*2)
    mov ZH, r24
    mov ZL, r25
    rcall send_string
    rjmp COMMON_ISR_END

TIMER2_ISR_DISPATCH:
    ldi r24, high(pong_str*2)
    ldi r25, low(pong_str*2)
    mov ZH, r24
    mov ZL, r25
    rcall send_string
    
COMMON_ISR_END:
    pop ZL
    pop ZH
    pop r25
    pop r24
    pop r18
    pop r17
    pop r16
    reti
