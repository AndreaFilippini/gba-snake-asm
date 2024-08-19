arm-none-eabi-gcc -o snake.elf -specs=gba.specs snake.s
arm-none-eabi-objcopy -O binary snake.elf snake.gba
gbafix snake.gba