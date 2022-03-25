;Universidad del Valle
;Juan Emilio Reyes 
;20959
;Jose Morales   
;Programación de microcontroladores
;PROYECTO 2
;                       
;Creado: 6 de marzo, 2022
;Última modificación: 21 de marzo , 2022

PROCESSOR 16F887
#include <xc.inc>
    
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)

;////////////////////////////////////////////////////////////////////////////
;                                MACROS
;////////////////////////////////////////////////////////////////////////////
  
//Macros para poder dividir
divlw	macro	denominator
    movwf   var_div
    clrf    var_div+1
    incf    var_div+1 ; Lo que hace es que prepara la división
    movlw   denominator
    subwf   var_div, f
    btfsc   CARRY;realiza la división
    goto    $-4
    decf    var_div+1, w
    movwf   res_div ; obtiene el resultado de la división
    movlw   denominator
    addwf   var_div, w
    movwf   rem_div ; lo mueve
    endm
    
    
tabdis   macro   clr, b_set, reg
    bcf	    PORTD, clr
    bsf	    PORTD, b_set
    bsf	    PORTD, b_set ; setea la Tabla utilizada
    movf    reg, w
    movwf   PORTC
    return
    endm
    
restart_tmr0	macro
    //Timer0 a 10ms
    banksel PORTA
    movlw   255		
    movwf   TMR0
    bcf	    T0IF
    endm
    
restart_tmr1	macro
    //Timer1 a 500ms
    movlw   194	    
    movwf   TMR1H
    movlw   247
    movwf   TMR1L
    bcf	    TMR1IF
    endm
    

;////////////////////////////////////////////////////////////////////////////
;                                VARIABLES
;////////////////////////////////////////////////////////////////////////////		    ;
PSECT udata_bank0
    banderas:	DS  1   //banderas para displays
    estados:	DS  1	//bits de estados
    C_1:	DS  1	//contador de 500ms
    CH:	DS  3   //contador de hora
    start_time:	DS  2	//registro momentanio para time, para dar valores 
			//iniciales 
    Fecha:	DS  2   //contador de fecha
    temporal_date: DS 2 //registro momentanio para date
    register_days_month: DS 1//registro para almacenar el número de días por mes
    nibbles:	DS  4	//separador de nibbles
    displays:	DS  4	//almacenar bits para displays
    
   
    //Variables del macro de división
    var_div:	DS  2   //variable de división
    res_div:	DS  1   //resultado para la división
    rem_div:	DS  1	//residuo de la división
    
    //Timer ultima funcion
    timer:	DS  2	//contador del timer
    flags_timer: DS  1	//banderas para el timer

PSECT udata_shr
    //Memoria temporal
    W_TEMP:	    DS	1   //memoria temporal para w
    STATUS_TEMP:    DS	1   //memoria temporal para STATUS
    
;------------------------------------
;   VECTOR RESET		    ;
;------------------------------------
PSECT resVect, class=CODE, abs, delta=2
ORG 00h
resetVec:
    PAGESEL main
    goto    main

;------------------------------------
;   INTERRUPT VECTOR 		    ;
;------------------------------------
PSECT intVect, class=CODE, abs, delta=2
ORG 04h	    //posici?n 0004h para las interrupciones
push:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
isr:
    btfsc   TMR0IF
    call    int_tmr0
    btfsc   TMR1IF
    call    int_tmr1
pop:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie
    
;////////////////////////////////////////////////////////////////////////////
;                                SUBRUTINAS
;////////////////////////////////////////////////////////////////////////////
//Alternar Displays
int_tmr0:
    restart_tmr0
    incf    banderas
    btfss   banderas, 0	//Comprobar si es 00 o 10
    goto    $+2
    goto    $+4
    btfss   banderas, 1	//Comprobar si es 00
    goto    display0
    goto    display2
    btfss   banderas, 1
    goto    display1
    goto    display3
 
//Hora/Dias/Para el timer es minutos
display0:
    tabdis  3, 0, displays+3
display1:
    tabdis  0, 1, displays+2
//Minutos/Meses/Para el timer son segundos
display2:
    tabdis  1, 2, displays+1
display3:
    tabdis  2, 3, displays
    
//Contador de Tiempo
//Leds titilando
int_tmr1:
    restart_tmr1
    incf    C_1
    btfsc   C_1, 0
    goto    incsecs
    goto    sametime
sametime:
    bcf	    PORTB, 7
    return
    
//Incremento de segundos
incsecs:
    bsf	    PORTB, 7
    btfsc   flags_timer, 1
    call    dec_timer_sec_count
    incf    CH
    movf    CH, w
    sublw   60
    btfsc   STATUS, 2
    call    incmin
    return

//Incremento de minutos
incmin:
    clrf    CH
    incf    CH+1
    movf    CH+1, w
    sublw   60
    btfsc   STATUS, 2
    call    inchour
    return
    
//Incremento de horas
inchour:
    clrf    CH+1
    incf    CH+2
    movf    CH+2, w
    sublw   24
    btfsc   STATUS, 2
    call    incday
    return
    
//Incremento de dias
incday:
    clrf    CH+2
    movf    Fecha+1, w
    call    table_days
    movwf   register_days_month
    movf    Fecha, w
    subwf   register_days_month
    btfsc   STATUS, 2
    goto    incmonth
    incf    Fecha
    return
    
//Incremento de horas  
incmonth:
    clrf    Fecha
    incf    Fecha+1
    movf    Fecha+1, w
    sublw   11
    btfsc   STATUS, 2
    call    clear_month
    return

//Para que la fecha del meses inicie en 01 y no 00
clear_month:
    clrf    Fecha+1
    return
    
;////////////////////////////////////////////////////////////////////////////
;                                MAIN 
;////////////////////////////////////////////////////////////////////////////
PSECT code, delta=2, abs
ORG 100h
 

;   TABLAS
tabla:
    clrf   PCLATH
    bsf    PCLATH, 0   
    andlw  0x0f        
    addwf  PCL         
    retlw  00111111B   ;0
    retlw  00000110B   ;1
    retlw  01011011B   ;2
    retlw  01001111B   ;3
    retlw  01100110B   ;4
    retlw  01101101B   ;5
    retlw  01111101B   ;6
    retlw  00000111B   ;7
    retlw  01111111B   ;8
    retlw  01101111B   ;9

   ; TABLA DÍAS POR MESES 
table_days:
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0f
    addwf   PCL
    retlw   30	    //enero
    retlw   27	    //febrero
    retlw   30	    //marzo
    retlw   29	    //abril
    retlw   30	    //mayo
    retlw   29	    //junio
    retlw   30	    //julio
    retlw   30	    //agosto
    retlw   29	    //septiembre
    retlw   30	    //octubre
    retlw   29	    //noviembre
    retlw   30	    //diciembre 
    

;   MAIN 		    

main:
    call    config_io
    call    config_clk
    call    config_tmr0
    call    config_tmr1
    call    config_int_enable
    banksel PORTA
    //Clear a la variables para que conmiecen en sus varlores iniciales
    clrf    estados
    clrf    banderas
    clrf    CH
    clrf    CH+1
    clrf    CH+2
    clrf    Fecha
    clrf    Fecha+1
    clrf    flags_timer
    clrf    timer
    clrf    timer+1
    

;////////////////////////////////////////////////////////////////////////////
;                                LOOP
;////////////////////////////////////////////////////////////////////////////

loop:
    //Loop General
    call    mov_displays
    btfss   PORTB, 0
    call    cambio_de_estado
    //Estados
    btfsc   estados, 2
    goto    estado4
    btfss   estados, 0
    goto    estado02
    goto    estado13
    goto    loop

estado02:
    btfss   estados, 1
    goto    estado0
    goto    estado2

estado13:
    btfss   estados, 1
    goto    estado1
    goto    estado3

estado0:
    bcf	    PORTA, 4
    bsf	    PORTA, 0
    call    time_nibbles
    goto    loop

estado1:
    bcf	    PORTA, 0
    bsf	    PORTA, 1
    call    set_time_nibbles
    btfss   PORTB, 4
    call    inc_min_display
    btfss   PORTB, 3
    call    dec_min_display
    btfss   PORTB, 2
    call    inc_hour_display
    btfss   PORTB, 1
    call    dec_hour_display
    goto    loop

estado2:
    bcf	    PORTA, 1
    bsf	    PORTA, 2
    call    date_nibbles
    goto    loop

estado3:
    bcf	    PORTA, 2
    bsf	    PORTA, 3
    call    set_date_nibbles
    btfss   PORTB, 2
    call    inc_day_display
    btfss   PORTB, 1
    call    dec_day_display
    btfss   PORTB, 4
    call    inc_month_display
    btfss   PORTB, 3
    call    dec_month_display
    goto    loop


estado4:
    bcf	    PORTA, 3
    bsf	    PORTA, 4
    call    timer_nibbles
    btfsc   flags_timer, 0
    goto    timer_estado1
    btfsc   flags_timer, 1
    goto    timer_estado2
    btfsc   flags_timer, 2
    goto    timer_estado3
    goto    timer_estado0

timer_estado0:
   
    bsf	    PORTD, 4
    bcf	    PORTB, 6
    btfss   PORTB, 2
    bsf	    flags_timer, 0
    btfss   PORTB, 1
    bsf	    flags_timer, 0
    btfss   PORTB, 4
    bsf	    flags_timer, 0
    btfss   PORTB, 3
    bsf	    flags_timer, 0
    goto    loop

timer_estado1:
    
    bsf	    PORTD, 5
    btfss   PORTB, 2
    call    inc_timer_min
    btfss   PORTB, 1
    call    dec_timer_min
    btfss   PORTB, 4
    call    inc_timer_sec
    btfss   PORTB, 3
    call    dec_timer_sec
    btfss   PORTB, 0
    call    start_timer
    goto    loop

timer_estado2:
    
    bsf	    PORTD, 6
    goto    loop

timer_estado3:
    
    bsf	    PORTD, 7
    bsf	    PORTB, 6
    btfss   PORTB, 0
    call    end_alarm
    goto    loop
    
;////////////////////////////////////////////////////////////////////////////
;                                CONFI
;////////////////////////////////////////////////////////////////////////////	
   
config_io:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH
    
    //OUTPUTS
    banksel TRISA
    clrf    TRISA	//salidas de LEDs
    bsf	    TRISB, 0
    bsf	    TRISB, 1
    bsf	    TRISB, 2
    bsf	    TRISB, 3
    bsf	    TRISB, 4
    bcf	    TRISB, 6	//salida del LED de alarma
    bcf	    TRISB, 7	//salida LEDs titilantes
    clrf    TRISC	//salidas a displays
    clrf    TRISD	//salidas a transistores y LEDs

    //INPUTS
    bcf	    OPTION_REG, 7
    bsf	    WPUB, 0
    bsf	    WPUB, 1
    bsf	    WPUB, 2
    bsf	    WPUB, 3
    bsf	    WPUB, 4
    
    ;Limpiar puertos
    banksel PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    return

config_clk:
    banksel OSCCON
    bcf	    IRCF2   ;reloj a 250kHz (0,1,0), 0
    bsf	    IRCF1   ;1
    bcf	    IRCF0   ;0
    bsf	    SCS	    ;reloj interno
    return

config_tmr0:
    banksel TRISA
    //Configurar OPTION_REG
    bcf	    T0CS
    bcf	    PSA
    bsf	    PS2	    ;prescaler 1:128
    bsf	    PS1
    bcf	    PS0
    restart_tmr0
    return

config_tmr1:
    banksel PORTA
    bcf	    TMR1GE
    bcf	    T1CKPS1  ;prescaler 1:2
    bsf	    T1CKPS0
    bcf	    T1OSCEN  ;reloj interno
    bcf	    TMR1CS
    bsf	    TMR1ON   ;habilitar TMR1
    restart_tmr1
    return

config_int_enable:
    banksel TRISA
    bsf	    TMR1IE  ;interrupción TMR1
    banksel PORTA
    bsf	    GIE	    ;interrupciones globales
    bsf	    PEIE    ;interrupciones perif?ricas
    bsf	    T0IE    ;interrupci?n TMR0
    bcf	    T0IF    ;limpiar bandera TMR0
    bcf	    TMR1IF  ;limpiar bandera TMR1
    return
    
;////////////////////////////////////////////////////////////////////////////
;                                SUB
;////////////////////////////////////////////////////////////////////////////
cambio_de_estado:
    btfss   PORTB, 0
    goto    $-1
    incf    estados
    movf    estados, w
    sublw   5
    btfsc   STATUS, 2
    clrf    estados

    movf    estados, w
    sublw   1
    btfsc   STATUS, 2
    call    start_temporary_time
    //Subrutinas Previas al Camio a Estado 10
    movf    estados, w
    sublw   2
    btfsc   STATUS, 2
    call    end_temporary_time
    //Subrutinas Previas al Camio a Estado 11
    movf    estados, w
    sublw   3
    btfss   STATUS, 2
    goto    $+4
    call    start_temporary_date
    btfsc   flags_timer, 2
    clrf    flags_timer
    
    //subrutinas Previas al Cambio a Estado 100
    movf    estados, w
    sublw   4
    btfsc   STATUS, 2
    call    end_temporary_date
    return

mov_displays:
    //Mandar a Displays Unidades de Minutos
    movf    nibbles, w
    call    tabla
    movwf   displays
    //Mandar a Displays Decenas de Minutos
    movf    nibbles+1, w
    call    tabla
    movwf   displays+1
    //Mandar a Displays Unidades de Horas
    movf    nibbles+2, w
    call    tabla
    movwf   displays+2
    //Mandar a Displays Decenas de Minutos
    movf    nibbles+3, w
    call    tabla
    movwf   displays+3
    return
    
;////////////////////////////////////////////////////////////////////////////
;                                ESTADO 00  HORA
;////////////////////////////////////////////////////////////////////////////

//Mover Registro Temporal a Fecha
end_temporary_date:
    movf    temporal_date, w
    movwf   Fecha
    movf    temporal_date+1, w
    movwf   Fecha+1
    return
//Setear Nibbles para Mandar a Displays

time_nibbles:
    //Divisi?n de Minutos
    movf    CH+1, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+1
    movf    rem_div, w
    movwf   nibbles
    //Divisi?n de Horas
    movf    CH+2, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+3
    movf    rem_div, w
    movwf   nibbles+2
    return
    
;////////////////////////////////////////////////////////////////////////////
;                                ESTADO 01  CONFI HORA
;////////////////////////////////////////////////////////////////////////////
//Mover Time a Registro Temporal
start_temporary_time:
    movf    CH+1, w
    movwf   start_time
    movf    CH+2, w
    movwf   start_time+1
    return
//Botones Para Displays
//Incremento de minutos
inc_min_display:
    btfss   PORTB, 4       //antirrebote
    goto    $-1
    incf    start_time  
    movf    start_time, w
    sublw   60
    btfsc   STATUS, 2
    clrf    start_time
    return

//Decremento de minutos
dec_min_display:
    btfss   PORTB, 3
    goto    $-1
    decf    start_time
    movf    start_time, w
    sublw   255
    btfss   STATUS, 2
    return
    movlw   59
    movwf   start_time
    return

//Incremento de horas
inc_hour_display:
    btfss   PORTB, 2
    goto    $-1
    incf    start_time+1
    movf    start_time+1, w
    sublw   24
    btfsc   STATUS, 2
    clrf    start_time+1
    return

//Decremento de horas    
dec_hour_display:
    btfss   PORTB, 1
    goto    $-1
    decf    start_time+1 
    movf    start_time+1, w
    sublw   255
    btfss   STATUS, 2
    return
    movlw   23
    movwf   start_time+1
    return
    
//Mover a Registro de Displays
set_time_nibbles:
    //Divisi?n de Minutos
    movf    start_time, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+1
    movf    rem_div, w
    movwf   nibbles
    //Divisi?n de Horas
    movf    start_time+1, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+3
    movf    rem_div, w
    movwf   nibbles+2
    return

;////////////////////////////////////////////////////////////////////////////
;                                ESTADO 10  FECHA
;//////////////////////////////////////////////////////////////////////////// 
//Mover Registro Temporal a Time
end_temporary_time:
    clrf    CH
    movf    start_time, w
    movwf   CH+1
    movf    start_time+1, w
    movwf   CH+2
    return
    
//Setear Nibbles para Mandar a Displays
date_nibbles:
    //Divisi?n de D?as
    movlw   1
    addwf   Fecha, 0
    divlw   10
    movf    res_div, w
    movwf   nibbles+3
    movf    rem_div, w
    movwf   nibbles+2
    //Divisi?n de Meses
    movlw   1
    addwf   Fecha+1, 0
    divlw   10
    movf    res_div, w
    movwf   nibbles+1
    movf    rem_div, w
    movwf   nibbles
    return
;////////////////////////////////////////////////////////////////////////////
;                                ESTADO 00  CONFI FECHA
;////////////////////////////////////////////////////////////////////////////
//Mover Time a Registro Temporal
start_temporary_date:
    movf    Fecha, w
    movwf   temporal_date
    movf    Fecha+1, w
    movwf   temporal_date+1
    return
    
//Botones Para Displays Fecha
//Incremento de dias
inc_day_display:
    btfss   PORTB, 2
    goto    $-1
    movf    temporal_date+1, w
    call    table_days
    movwf   register_days_month
    movf    temporal_date, w
    subwf   register_days_month
    btfss   STATUS, 2
    goto    $+3
    clrf    temporal_date
    return
    incf    temporal_date 
    return
    
//Decremento de dias
dec_day_display:
    btfss   PORTB, 1
    goto    $-1
    decf    temporal_date
    movf    temporal_date, w
    sublw   255
    btfss   STATUS, 2
    return
    movf    temporal_date+1, w
    call    table_days
    movwf   temporal_date
    return

//Incremento de meses
inc_month_display:
    btfss   PORTB, 4
    goto    $-1
    movf    temporal_date+1, w
    sublw   11
    btfss   STATUS, 2
    goto    $+3
    clrf    temporal_date+1
    return
    incf    temporal_date+1
    clrf    temporal_date
    return
    
//Decremento de meses    
dec_month_display:
    btfss   PORTB, 3
    goto    $-1
    decf    temporal_date+1 
    clrf    temporal_date
    movf    temporal_date+1, w
    sublw   255
    btfss   STATUS, 2
    return
    movlw   11
    movwf   temporal_date+1
    return
    
//Mover a Registro de Displays
set_date_nibbles:
    //Divisi?n de Minutos
    movlw   1
    addwf   temporal_date, 0
    divlw   10
    movf    res_div, w
    movwf   nibbles+3
    movf    rem_div, w
    movwf   nibbles+2
    //Divisi?n de Horas
    movlw   1
    addwf   temporal_date+1, 0
    divlw   10
    movf    res_div, w
    movwf   nibbles+1
    movf    rem_div, w
    movwf   nibbles
    return
    
;////////////////////////////////////////////////////////////////////////////
;                                ESTADO 100  TIMER
;////////////////////////////////////////////////////////////////////////////
//Separar el timer en decenas y unidades
timer_nibbles:
    movf    timer, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+1
    movf    rem_div, w
    movwf   nibbles
    //Divisi?n de Horas
    movf    timer+1, w
    divlw   10
    movf    res_div, w
    movwf   nibbles+3
    movf    rem_div, w
    movwf   nibbles+2
    return
    
//Incremento del Timer, segundos
inc_timer_sec:
    btfss   PORTB, 4
    goto    $-1
    incf    timer 
    movf    timer, w
    sublw   60
    btfsc   STATUS, 2
    clrf    timer
    return
    
//Decremento del Timer, segundos  
dec_timer_sec:
    btfss   PORTB, 3
    goto    $-1
    decf    timer
    movf    timer, w
    sublw   255
    btfss   STATUS, 2
    goto    $+3
    movlw   59
    movwf   timer
    return

//Incremento del Timer, minutos    
inc_timer_min:
    btfss   PORTB, 2
    goto    $-1
    incf    timer+1
    movf    timer+1, w
    sublw   100
    btfsc   STATUS, 2
    clrf    timer+1
    return

//Decremento del Timer, minutos        
dec_timer_min:
    btfss   PORTB, 1
    goto    $-1
    decf    timer+1
    movf    timer+1, w
    sublw   255
    btfss   STATUS, 2
    goto    $+3
    movlw   99
    movwf   timer+1
    return
    
//comenzar el conteo del timer
start_timer:
    bcf	    flags_timer, 0    //se sale del estado 1
    bsf	    flags_timer, 1    //se inicializa el estado 2 de cuenta regresiva
    return
    
//decremento timer, segundos
dec_timer_sec_count:
    decf    timer
    movf    timer, w
    sublw   255
    btfss   STATUS, 2
    return
    movlw   59
    movwf   timer
    call    dec_timer_min_count
    return
    
//decremento timer, minutos  
dec_timer_min_count:
    decf    timer+1
    movf    timer+1, w
    sublw   255
    btfss   STATUS, 2
    return
    bcf	    flags_timer, 1
    bsf	    flags_timer, 2
    clrf    timer
    clrf    timer+1
    return
    
//terminar la alarma
end_alarm:
    btfss   PORTB, 0
    goto    $-1
    bcf	    flags_timer, 2
        
END