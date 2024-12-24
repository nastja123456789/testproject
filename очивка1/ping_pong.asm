.include "m8def.inc" ; Подключаем файл определений для ATmega8

.def  temp_reg    = r16    ; Временный регистр общего назначения
.def  temp_reg2   = r17    ; Еще один временный регистр общего назначения
.def  isr_source   = r18    ; Регистр для хранения источника прерывания

;--------------------------------------
; Константы
.equ  F_CPU_HZ       = 1000000 ; Частота процессора (1 МГц)
.equ  BAUD_RATE       = 9600   ; Скорость передачи данных (бод)
.equ  UBRR_VALUE_CALC  = (F_CPU_HZ / (16 * BAUD_RATE)) - 1  ; Значение для регистра UBRR, нужное для установки скорости

.equ  TIMER1_OCR_VAL  = 488    ; Значение для регистра OCR1A таймера 1
.equ  TIMER2_OCR_VAL  = 244    ; Значение для регистра OCR2 таймера 2
.equ  TIMER1_ISR_FLAG  = 0x01   ; Флаг прерывания от таймера 1
.equ  TIMER2_ISR_FLAG  = 0x02   ; Флаг прерывания от таймера 2
;---------------------------------------
.cseg               ; Начало сегмента кода
.org 0x0000         ; Адрес начала программы
    rjmp  RESET_INIT   ; Перейти к метке инициализации RESET_INIT

;--------------------------------------
; Таблица векторов прерываний (теперь перенаправляет в общий обработчик ISR)
.org OC2addr        ; Адрес вектора прерывания по совпадению таймера 2
    rjmp  COMMON_ISR_HANDLER ; Перейти к общему обработчику прерываний
.org OC1Aaddr       ; Адрес вектора прерывания по совпадению таймера 1 (A)
    rjmp  COMMON_ISR_HANDLER ; Перейти к общему обработчику прерываний

;---------------------------------------
RESET_INIT:          ; Метка начала инициализации
    ldi  temp_reg, 0x00      ; Загружаем 0 в регистр
    out  DDRB, temp_reg     ; Настройка порта B как вход (все выводы входные)
    out  DDRC, temp_reg     ; Настройка порта C как вход
    out  DDRD, temp_reg     ; Настройка порта D как вход

    ; Инициализация USART
    ldi  temp_reg, UBRR_VALUE_CALC ; Загружаем значение для установки скорости в регистр
    out  UBRRL, temp_reg    ; Устанавливаем младший байт регистра UBRR
    ldi  temp_reg, 0x00      ; Загружаем 0 в регистр
    out  UBRRH, temp_reg    ; Устанавливаем старший байт регистра UBRR
    ldi  temp_reg, (1 << RXEN) | (1 << TXEN) ; Включаем прием и передачу данных
    out  UCSRB, temp_reg    ; Обновляем управляющий регистр USART
    ldi  temp_reg, (1 << URSEL) | (3 << UCSZ0) ; Устанавливаем формат 8 бит данных
    out  UCSRC, temp_reg    ; Обновляем регистр формата USART

    ; Настройка таймера 1
    ldi  temp_reg, high(TIMER1_OCR_VAL) ; Загружаем старший байт OCR1A
	    out  OCR1AH, temp_reg
    ldi  temp_reg, low(TIMER1_OCR_VAL)  ; Загружаем младший байт OCR1A
    out  OCR1AL, temp_reg

    ldi  temp_reg, (1 << WGM12)  ; Устанавливаем режим CTC
    out  TCCR1B, temp_reg
    ldi  temp_reg, (1 << CS12) | (1 << CS10) ; Устанавливаем предделитель на 1024
    out  TCCR1B, temp_reg
    ldi  temp_reg, (1 << OCIE1A)  ; Включаем прерывание по совпадению А
    out  TIMSK, temp_reg

    ; Настройка таймера 2
    ldi  temp_reg, TIMER2_OCR_VAL  ; Загружаем значение OCR2
    out  OCR2, temp_reg
    ldi  temp_reg, (1 << WGM21) | (1 << CS22) | (1 << CS21) | (1 << CS20) ; Устанавливаем режим и предделитель 1024
    out  TCCR2, temp_reg
    in  temp_reg, TIMSK ; Читаем текущее значение TIMSK
    ori  temp_reg, (1 << OCIE2) ; Включаем прерывание Timer2 Output Compare Match
    out  TIMSK, temp_reg ; Обновляем регистр TIMSK


    ldi  isr_source, 0x00      ; Сбрасываем флаг источника прерывания
    sei                    ; Разрешаем глобальные прерывания

main_loop:               ; Бесконечный цикл
    rjmp  main_loop        ;  В главном цикле ничего не делаем

;--------------------------------------
; Функции USART
send_char:             ; Функция для отправки одного символа
    sbis  UCSRA, UDRE       ; Ожидаем, пока буфер передачи будет готов
    rjmp  send_char       ; Если буфер занят, повторяем ожидание
    out  UDR, r24          ; Отправляем байт из r24
    ret

send_string:            ; Функция для отправки строки
next_char:
    lpm  r24, Z+         ; Загружаем байт из строки, на которую указывает Z, с постинкрементом
    tst  r24             ; Проверяем, является ли байт нулевым (конец строки)
    breq done_string      ; Если байт 0, заканчиваем отправку строки
    rcall  send_char      ; Вызываем функцию для отправки байта через USART
    rjmp  next_char       ; Переходим к следующему байту
done_string:
    ret

;---------------------------------------
; Строковые данные
ping_str:              ; Строка "ping\r\n"
    .db "ping\r\n", 0
pong_str:              ; Строка "pong\r\n"
    .db "pong\r\n", 0


;---------------------------------------
; Общий обработчик прерываний
COMMON_ISR_HANDLER:      ; Метка начала общего обработчика прерываний
    push  temp_reg        ; Сохраняем временные регистры
    push  temp_reg2
    push  isr_source
    push  r24
    push  r25
    push  ZH
    push  ZL

; Сохраняем причину прерывания в регистре isr_source
    in temp_reg, TIFR      ; Читаем регистр флагов прерываний
    sbrc temp_reg,OCF2    ; Проверяем флаг прерывания от таймера 2
    ldi isr_source,TIMER2_ISR_FLAG ; Устанавливаем флаг источника в TIMER2_ISR_FLAG
    sbrs temp_reg,OCF2
    sbrc temp_reg,OCF1A    ; Проверяем флаг прерывания от таймера 1
    ldi isr_source,TIMER1_ISR_FLAG ; Устанавливаем флаг источника в TIMER1_ISR_FLAG

; Очищаем флаги, в случае, если они установлены по какой-либо причине
    out TIFR,temp_reg

; Таблица переходов на нужный обработчик прерывания
    cpi  isr_source, TIMER1_ISR_FLAG
    breq  TIMER1_ISR_DISPATCH  ; Если источник - таймер 1, переходим к обработчику таймера 1
    cpi  isr_source, TIMER2_ISR_FLAG
    breq  TIMER2_ISR_DISPATCH  ; Если источник - таймер 2, переходим к обработчику таймера 2
    rjmp  COMMON_ISR_END     ; Если источник не определен, переходим к концу обработчика

TIMER1_ISR_DISPATCH:      ; Метка начала обработчика прерывания от таймера 1
    ldi  r24, high(ping_str*2) ; Загружаем старший байт адреса строки ping_str в Z
    ldi  r25, low(ping_str*2)  ; Загружаем младший байт адреса строки ping_str в Z
    mov  ZH, r24        ; Устанавливаем старший байт регистра Z
    mov  ZL, r25        ; Устанавливаем младший байт регистра Z
    rcall  send_string      ; Вызываем функцию отправки строки
    rjmp  COMMON_ISR_END      ; Переходим к концу обработчика

TIMER2_ISR_DISPATCH:      ; Метка начала обработчика прерывания от таймера 2
    ldi  r24, high(pong_str*2) ; Загружаем старший байт адреса строки pong_str в Z
    ldi  r25, low(pong_str*2)  ; Загружаем младший байт адреса строки pong_str в Z
    mov  ZH, r24        ; Устанавливаем старший байт регистра Z
    mov  ZL, r25        ; Устанавливаем младший байт регистра Z
    rcall  send_string      ; Вызываем функцию отправки строки

COMMON_ISR_END:         ; Метка конца общего обработчика прерываний
    pop  ZL          ; Восстанавливаем младший байт Z
    pop  ZH          ; Восстанавливаем старший байт Z
    pop  r25         ; Восстанавливаем r25
    pop  r24         ; Восстанавливаем r24
    pop  isr_source   ; Восстанавливаем источник прерывания
    pop  temp_reg2     ; Восстанавливаем временные регистры
    pop  temp_reg
    reti               ; Выход из прерывания
