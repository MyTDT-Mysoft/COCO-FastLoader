cStateOnStack  equ 128
cFirqMask      equ 64
cHalfCarry     equ 32
cIrqMask       equ 16
cNegative      equ 8
cZero          equ 4
COverflow      equ 2
CCarry         equ 1

R00_JoyIn      equ 128

R01_HSyncFlag  equ 128
R01_MuxSelLSB  equ 8
R01_HDirection equ 4
R01_HPolarity  equ 2
R01_HSyncIrq   equ 1

R03_VsyncFlag  equ 128
R03_MuxSelMSB  equ 8
R03_VDirection equ 4
R03_VPolarity  equ 2
R03_VsyncIrq   equ 1

R20_Dac        equ $FC
R20_SerialOut  equ 2
R20_CasIn      equ 1

R21_SerialFlag equ 128
R21_MotorOn    equ 8
R21_DDirection equ 4
R21_DPolarity  equ 2
R21_SerialFirq equ 1

R23_CartFlag   equ 128
R23_SoundOn    equ 8
R23_CDirection equ 4
R23_CPolarity  equ 2
R23_CartFirq   equ 1


