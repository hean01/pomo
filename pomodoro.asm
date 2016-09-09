;;;
;;;	Pomodoro for AVR - ATtiny25/45/85
;;;
;;;	Copyright 2016 Henrik Andersson <henrik.4e@gmail.com>
;;;
;;; 	This program is free software: you can redistribute it and/or modify
;;; 	it under the terms of the GNU General Public License as published by
;;; 	the Free Software Foundation, either version 3 of the License, or
;;; 	(at your option) any later version.
;;;
;;; 	This program is distributed in the hope that it will be useful,
;;; 	but WITHOUT ANY WARRANTY ; without even the implied warranty of
;;; 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; 	GNU General Public License for more details.
;;;
;;; 	You should have received a copy of the GNU General Public License
;;;     along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;
;;;

	;;
	;; define I/O registers used in the program
	;;
	.equ PORTB	, 0x18
	.equ DDRB	, 0x19
	.equ TCCR0A 	, 0x2A		; Timer/Counter control register A
	.equ TCCR0B	, 0x33		; Timer/Counter control register B
	.equ OCR0A	, 0x29		; Output Compare Register A
	.equ TIMSK 	, 0x39		; Timer/Counter interrupt Mask Register
	.equ MCUCR	, 0x35		; MCU Control Register
	.equ GIMSK	, 0x3b		; General Interrupt Mask Register
	.equ PCMSK	, 0x15		; Pin Change Mask Register
	.equ MCUSR	, 0x34		; MCU Status Register
	.equ WDTCR	, 0x21		; Watchdog Timer Control Register

	;;
	;; general file registry
	;;
	.equ TMP		, 0x10	; r16 - temporary
	.equ TMP2		, 0x11	; r17 - temporary
	.equ TICK_CNT		, 0x12	; r18 - tick counter
	.equ LEDS		, 0x13  ; r19 - leds
	.equ LEDS_BIT		, 0x14	; r20 - leds bit
	.equ STATE		, 0x15	; r21 - pomodoro state
	.equ SECONDS		, 0x16	; r22 - seconds counter
	.equ MINUTES		, 0x17	; r23 - minutes counter
	.equ ANIM_FRAME		, 0x18  ; r24 - current frame in anim
	.equ ANIM_FRAME_CNT	, 0x19	; r25 - frame in current anim
	.equ ANIM_TICK_CNT	, 0x1a	; r26 - tick counter for animation frame
	.equ CURRENT_ANIM	, 0x1b	; r27 - current animation
	.equ ZL			, 0x1e	; r30 - low part of Z Register
	.equ ZH			, 0x1f	; r31 - high part of Z Register

	;;
	;; SRAM pointers for led animations
	;;
	.equ SRAM_ANIM_PAUSE	, 0x60 	; address to pause animation
	.equ SRAM_ANIM_START	, 0x6a 	; address to start animation
	.equ SRAM_ANIM_DONE	, 0x74 	; address to done animation

	;;
	;; pomodoro state enums
	;;
	.equ STATE_STARTUP	, 0x00
	.equ STATE_POMODOROS_1	, 0
	.equ STATE_PAUSE_1	, 1
	.equ STATE_POMODOROS_2	, 2
	.equ STATE_PAUSE_2	, 3
	.equ STATE_POMODOROS_3	, 4
	.equ STATE_PAUSE_3	, 5
	.equ STATE_POMODOROS_4	, 6
	.equ STATE_DONE		, 7

	.text
;;;
;;; setup interrupt vectors trampolines
;;;
main:	.org 0x0000
	rjmp reset			; reset interrupt vector
	reti
	rjmp button			; pin change interrupt
	reti
	reti
	reti
	reti
	reti
	reti
	reti
	rjmp tick			; timer0 overflow interrupt vector
	reti
	reti
	reti
	reti

;;;
;;; button interrupt handler
;;;
button:	cpi STATE, 0x00			; do nothing if we are in startup state
	brne . + 2			; skip if not equal
	reti

	cpi STATE, (1 << STATE_DONE)	; soft reset program if we are in done state
	breq soft_reset

	mov TMP, STATE			; soft reset program if we are in a pomodoro state
	andi TMP, 0b10101010
	cpi TMP, 0x00
	breq soft_reset

	;;
	;; take care of transition from PAUSE to next POMODOROS state
	;;
	clr SECONDS			; reset the pomodoro clock
	clr MINUTES
	clr ZL
	clr ZH

	;;
	;; advance to next pomodoro state and set corresponding
	;; display of leds
	;;
	lsl STATE			; advance state
	sbrs STATE, STATE_POMODOROS_2	; check if we are in second pomodoro state
	brne . + 4			; skip to next case if not equal
	ldi LEDS, 0b00000011
	reti

	sbrs STATE, STATE_POMODOROS_3
	brne . + 4
	ldi LEDS, 0b00000111
	reti

	sbrs STATE, STATE_POMODOROS_4
	brne . + 4
	ldi LEDS, 0b00001111
	reti

	;;
	;; unhandled state transition, shouldn't ever occur, just
	;; a fench for following soft reset
	;;
	reti

	;;
	;; generate a soft reset of the program using watchdog
	;;
soft_reset:	ldi TMP, 0b00011000		; soft reset the program using watchdog timeout
		out WDTCR, TMP
		reti


;;;
;;; render leds and clock the pomodoro process
;;;
;;;   this is called for each 5ms of time passed eg. 200 fps,
;;;   each led is lit for 5ms at 200fps for lower current draw.
;;;
;;;   for each 200 frames (1 second) clock the pomodoro process
;;;
tick:	mov TMP, LEDS				; get which led to display and its on/off state
	and TMP, LEDS_BIT
	ori TMP, 0b00010000			; important to set other bits due to out instruction
	out PORTB, TMP

	lsl LEDS_BIT				; advance display to next led
	cpi LEDS_BIT, (1 << 4)			; check if we reached end of cylce
	brne . + 2				; skip if not equal
	ldi LEDS_BIT, 0b00000001 		; reset cycle

	cpi ZL, 0x00				; skip animation if not loaded into Z registry
	breq fin

	inc ANIM_TICK_CNT 			; increase anim tick counter
	cpi ANIM_TICK_CNT, 25
	brne fin
	clr ANIM_TICK_CNT
	ld LEDS, Z+				; read anim frame into leds
	inc ANIM_FRAME				; increase current frame
	cp ANIM_FRAME, ANIM_FRAME_CNT 		; reset current frame if end is reached
	brne fin
	clr ANIM_FRAME
	mov ZL, CURRENT_ANIM			; setup pause anim
	clr ZH
	ld ANIM_FRAME_CNT, Z+			; get frame count and advance to first frame in anim


fin:	inc TICK_CNT				; increase clock tick counter
	cpi TICK_CNT, 200			; check if counter reached 200, clock pomodoro timer
	breq clock
	reti

;;;
;;; clock the pomodoro process.
;;;
;;;   this is called for each second passed
;;;
clock:	clr TICK_CNT				; reset TICK_CNT

	inc SECONDS				; increase pomodoro clock with one second
	cpi SECONDS, 60				; if we reached 60 secs, increase MINUTES counter
	brne states
	inc MINUTES
	clr SECONDS

	;; check which is our current state and call thee
	;; appropiated handler for each state available
states:	cpi STATE, 0x00				; check if in statup state
	breq startup

	cpi STATE, (1 << STATE_DONE)		; check if in done state
	breq done

	mov TMP, STATE				; check if in a pomodoro state
	andi TMP, 0b01010101
	cpi TMP, 0x00
	brne pomodoro

	mov TMP, STATE				; check if in a pause state
	andi TMP, 0b10101010
	cpi TMP, 0x00
	brne pause

	;;
	;; Unhandled states does nothing
	;;
	reti

	;;
	;; process the clock for startup state and handle transition
	;; to next state if time has been reached
	;;
startup:
	cpi SECONDS, 2				; check if we have reached end of startup state
	breq . + 2				; skip if equal
	reti
	clr SECONDS				; reset clock and advance to next state
	clr MINUTES
	ldi STATE, (1 << STATE_POMODOROS_1) 	; setup next state, first pomodoro cycle
	ldi LEDS, 0b00000001
	clr ZH
	clr ZL
	reti

	;;
	;; process the clock for a pomodoros state and handle transition
	;; to next pause state if time has been reached
	;;
pomodoro:
	cpi MINUTES, 25				; check if we have reached end of pomodoro cycle
	breq . + 2				; skip if equal
	reti
	clr SECONDS				; reset clock and advance to next state
	clr MINUTES
	lsl STATE				; advance to next pause state
	clr ZH					; setup pause led animation
	ldi CURRENT_ANIM, SRAM_ANIM_PAUSE
	cpi STATE, (1 << STATE_DONE)		; set done anim if last pomodoro
	brne . + 2				; skip if equal
	ldi CURRENT_ANIM, SRAM_ANIM_DONE

	mov ZL, CURRENT_ANIM
	ld ANIM_FRAME_CNT, Z+
	clr ANIM_FRAME
	clr ANIM_TICK_CNT
	reti

	;;
	;; external button is used to advance from pause state to next
	;;
pause:	reti

	;;
	;; when done is reached, a soft reset is requires to restart a pomodoro cycle using button
	;;
done:	reti



;;;
;;; reset and main loop
;;;
;;;   initialization code, called upon program start and through reset
;;;   switch and then enters the program main loop
;;;
reset:  wdr				; disable the watch dog reset flag
	clr TMP
	out MCUSR, TMP
	ldi TMP, 0b00011000
	out WDTCR, TMP
	ldi TMP, 0b00010000
	out WDTCR, TMP

	cli				; disable interrupts

	;;
	;; setup timer and interrupt
	;;
	ldi TMP, 0b00000010		; clear on compare match
	out TCCR0A, TMP
	ldi TMP, 0b00000100		; set /256 prescaler
	out TCCR0B, TMP
	ldi TMP, 19			; (F_CPU / prescaler) / 200fps
	out OCR0A, TMP
	ldi TMP, 0b00010000		; enable output compare match A interrupt
	out TIMSK, TMP

	;;
	;; setup io ports
	;;
	ldi TMP, 0b00001111
	out DDRB, TMP
	ldi TMP, 0b00010000
	out PORTB, TMP

	;;
	;; setup PCINT4 interrupt
	;;
	ldi TMP, 0b00100000		; enable pin change interrupt
	out GIMSK, TMP
	ldi TMP, 0b00010000		; enable PCINT4
	out PCMSK, TMP

	;;
	;; setup sleep mode
	;;
	ldi TMP, 0b00100000
	out MCUCR, TMP

	;;
	;; intialize program registers
	;;
	clr LEDS
	ldi LEDS_BIT, 0b00000001
	clr TICK_CNT
	clr SECONDS
	clr MINUTES
	clr STATE

	;;
	;; store pause animation in SRAM
	;;
	clr ZH
	ldi ZL, SRAM_ANIM_PAUSE
	ldi TMP	, 0x06
	st Z+	, TMP		       ; frame count
	ldi TMP	, 0x01
	st Z+	, TMP
	ldi TMP	, 0x02
	st Z+	, TMP
	ldi TMP	, 0x04
	st Z+	, TMP
	ldi TMP	, 0x08
	st Z+	, TMP
	ldi TMP	, 0x04
	st Z+	, TMP
	ldi TMP	, 0x02
	st Z+	, TMP

	;;
	;; store start anim in SRAM
	;;
	clr ZH
	ldi ZL, SRAM_ANIM_START
	ldi TMP, 0x2			; frame count
	st Z+	, TMP
	ldi TMP	, 0x0f
	st Z+	, TMP
	ldi TMP	, 0x00
	st Z+	, TMP

	;;
	;; store done animation in SRAM
	;;
	clr ZH
	ldi ZL, SRAM_ANIM_DONE
	ldi TMP	, 0x06
	st Z+	, TMP		       ; frame count
	ldi TMP	, 0x0e
	st Z+	, TMP
	ldi TMP	, 0x0d
	st Z+	, TMP
	ldi TMP	, 0x0b
	st Z+	, TMP
	ldi TMP	, 0x07
	st Z+	, TMP
	ldi TMP	, 0x0b
	st Z+	, TMP
	ldi TMP	, 0x0d
	st Z+	, TMP

	;;
	;; setup animation for inital start state
	;;
	clr ZH
	ldi CURRENT_ANIM, SRAM_ANIM_START
	mov ZL, CURRENT_ANIM
	ld ANIM_FRAME_CNT, Z+
	clr ANIM_FRAME
	clr ANIM_TICK_CNT

	sei				; enable interrupts

;;;
;;; main loop
;;;
loop:	sleep				; enter sleep
	rjmp loop

