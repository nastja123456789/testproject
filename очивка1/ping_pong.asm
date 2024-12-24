;======================================
; Пример работы с двумя таймерами (Atmega8)
;  Вывод "ping" и "pong" в USART с разными интервалами
;======================================
.include "m8def.inc"   ; Подключаем определения для ATmega8

.def  temp      = r16    ; Временный регистр
.def  str_ptr_hi = r24   ; Регистр для старшей части указателя на строку
.def  str_ptr_lo = r25   ; Регистр для младшей части указателя на строку

;--------------------------------------
; Константы
.equ F_CPU      = 1000000      ; Частота (1 MHz)
.equ BAUD       = 9600        ; Скорость передачи данных
.equ UBRR_VALUE = (F_CPU/(16*BAUD))-1   ; Значение для регистра UBRR

; Интервалы таймеров. 
; Значения OCRx_VAL выбраны исходя из делителя тактовой частоты и
; желаемого интервала. 
.equ TIMER1_INTERVAL = 488  ; Значение для таймера 1
.equ TIMER2_INTERVAL = 244  ; Значение для таймера 2


;--------------------------------------
; Секция кода
.cseg

.org 0x0000
    rjmp reset    ; Переход на метку RESET при старте программы

.org OC2addr     ; Вектор прерывания от таймера 2
    rjmp timer2_isr  ; Переход на обработчик прерывания таймера 2

.org OC1Aaddr    ; Вектор прерывания от таймера 1
    rjmp timer1_isr  ; Переход на обработчик прерывания таймера 1


reset:
    ; Инициализация портов ввода/вывода
    ldi temp, 0x00
    out DDRB, temp  ; Порт B как вход
    out DDRC, temp  ; Порт C как вход
    out DDRD, temp  ; Порт D как вход

    ; Инициализация USART
    ldi temp, UBRR_VALUE
    out UBRRL, temp    ; Запись младшего байта скорости в регистр UBRRL
    ldi temp, 0
    out UBRRH, temp    ; Запись старшего байта скорости в регистр UBRRH
    ldi temp, (1<<RXEN)|(1<<TXEN)
    out UCSRB, temp    ; Включение приемника и передатчика
    ldi temp, (1<<URSEL)|(3<<UCSZ0)
    out UCSRC, temp    ; Установка формата кадра данных (8 бит)

    ; Инициализация таймера 1
    ldi temp, high(TIMER1_INTERVAL)
    out OCR1AH, temp    ; Запись старшего байта значения сравнения
    ldi temp, low(TIMER1_INTERVAL)
    out OCR1AL, temp    ; Запись младшего байта значения сравнения

    ldi temp, (1<<WGM12)
    out TCCR1B, temp    ; Установка режима CTC (сброс таймера по совпадению)
    ldi temp, (1<<CS12)|(1<<CS10)
    out TCCR1B, temp    ; Установка делителя частоты (1024)

    ldi temp, (1<<OCIE1A)
    out TIMSK, temp    ; Разрешение прерывания по совпадению таймера 1

    ; Инициализация таймера 2
    ldi temp, TIMER2_INTERVAL
    out OCR2, temp       ; Запись значения сравнения в регистр OCR2
    ldi temp, (1<<WGM21)|(1<<CS22)|(1<<CS21)|(1<<CS20)
    out TCCR2, temp    ; Установка режима CTC и делителя частоты (1024)
    in temp, TIMSK
    ori temp, (1<<OCIE2)
    out TIMSK, temp      ; Разрешение прерывания по совпадению таймера 2

    sei          ; Разрешение глобальных прерываний

main_loop:
    rjmp main_loop   ; Бесконечный цикл

;--------------------------------------
; Функции отправки в USART
;--------------------------------------
send_char:
    sbis UCSRA, UDRE
    rjmp send_char      ; Ожидание готовности буфера передачи
    out  UDR, str_ptr_hi  ; Отправка байта (символа)
    ret

send_string:
next_char:
    lpm str_ptr_hi, Z+     ; Загрузка символа из памяти программ в r24
    tst str_ptr_hi       ; Проверка на нулевой символ (конец строки)
    breq done_string    ; Если ноль - переход в конец
    rcall send_char       ; Отправка символа в USART
    rjmp next_char     ; Переход к следующему символу
done_string:
    ret          ; Возврат из подпрограммы

;--------------------------------------
; Строки для вывода
;--------------------------------------
ping_str:
    .db "ping\r\n", 0  ; Строка для таймера 1
pong_str:
    .db "pong\r\n", 0  ; Строка для таймера 2

;--------------------------------------
; Обработчики прерываний
;--------------------------------------
timer1_isr:
    push str_ptr_hi     ; Сохранение регистров в стеке
    push str_ptr_lo
    push ZH
    push ZL

    ldi str_ptr_hi, high(ping_str*2) ; Загрузка адреса строки "ping\r\n"
    ldi str_ptr_lo, low(ping_str*2)
    mov ZH, str_ptr_hi
    mov ZL, str_ptr_lo
    rcall send_string  ; Вызов функции отправки строки

    pop ZL            ; Восстановление регистров из стека
    pop ZH
    pop str_ptr_lo
    pop str_ptr_hi
    reti          ; Возврат из прерывания

timer2_isr:
    push str_ptr_hi      ; Сохранение регистров в стеке
    push str_ptr_lo
    push ZH
    push ZL

    ldi str_ptr_hi, high(pong_str*2)  ; Загрузка адреса строки "pong\r\n"
    ldi str_ptr_lo, low(pong_str*2)
    mov ZH, str_ptr_hi
    mov ZL, str_ptr_lo
    rcall send_string  ; Вызов функции отправки строки

    pop ZL            ; Восстановление регистров из стека
    pop ZH
    pop str_ptr_lo
    pop str_ptr_hi
    reti          ; Возврат из прерывания