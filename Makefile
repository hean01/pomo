MCU=attiny85
CPU=1000000UL
AS=avr-as
LD=avr-ld
AVRDUDE=avrdude
OBJCOPY=avr-objcopy
SFLAGS=-mmcu=$(MCU) -agslh --statistics

OBJS=pomodoro.o

all: pomodoro.hex


%.o: %.asm
	$(AS) $(SFLAGS) -c -o $@ $<

pomodoro.elf: $(OBJS)
	$(LD) $(LDFLAS) -o $@ $<

pomodoro.hex: pomodoro.elf
	$(OBJCOPY) --output-target=ihex $< $@

upload: $(FILE)
ifdef FILE
	$(AVRDUDE) -v -c usbtiny -p t85 -U flash:w:$(FILE)
else
	@echo "You need to specify file to upload like:"
	@echo "  make upload FILE=\"test.hex\""
endif

.PHONY: clean

clean:
	rm -f *.elf *.hex *.o
