# COCO-FastLoader
COCO Loader trough Audio sound card... to achieve rates over 1600 bytes/s (normal) and over 3200 bytes/s (double clock) (increases even more with compression)

![Youtube video preview](https://i.ytimg.com/vi/2GGTDwDIgDQ/hqdefault.jpg?sqp=-oaymwEWCKgBEF5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLD1Vk4BjYQR4BsdgfyIUEM3lq-q1w)
https://www.youtube.com/watch?v=peieARzk3bg

/play secret

## Compiling:

  To compile it you need [FreeBASIC](http://www.freebasic.net/) installed... (preferable 32bit)
  and may need LibAO, OpenAL or PortAudio installed to get sound for linux...
  (i'm having bad results with LibAO under 64bit right now, and OpenAL limiting to 44khz maximum)

  and so compiling is trivial...
  
  `fbc FastLoad.bas`
  
  ...or in case you want to use GCC backend
  
  `fbc -gen gcc -O 3 -asm intel FastLoad.bas`
  
  optionally one of these can be defined with `-d name` to force a specific backend
  
  * sndforce_mmsystem  (win32 only)
  * sndforce_libao
  * sndforce_openal
  * sndforce_portaudio
  
  example: `fbc FastLoad.bas -d sndforce_libao`
  
  would force LibAO to be used as sound backed (requiring LibAO.dll on windows)

## Usage:  
  
  `FastLoad -h`
  
  to get a list of possible options.... 
  the format of options is always -O#
  where "O" is the option char (case insensitive) 
  and # is a single digit number for options that require a parameter  
  
  `FastLoad -p file.bin`
  
  would start loading file.bin trough the sound card...
  
  `FastLoad -p -w file.bin`
  
  would load file.bin trough the sound card... and generate a file.bin.wav
  -w can be used alone to just generate it...
  
  if no filename is mentioned or if -p or -w is ommited or if -i switch is used
  the program enter in "interactive mode" where you can select options
  prior uploading... 
  
  to get it working all you need is an audio cable from the soundcard to the coco
  could be the same cable that would connect to the cassette deck...
  and so issuing a CLOADM on coco and then running the program on PC
  should first load the "LOADER" followed by the actual program.
  
  if that doesnt work, there's either a bad cable... or a cable with polarity (+/-)
  inverted... i have to see yet to add a option for such behavior since detecting it
  in realtime proved to not be reliable enough :)
  
  the program can output to the BACK SPEAKERS in a quadrophonic configuration...
  so that it wont mess with the front speakers on most programs...
  (not tested under linux...)
  
  the double rate mode works even on COCO-II... but to use it you need a card that support 58khz or 88khz
  and OpenAL seems to fail at that by limiting the maximum rate one can achieve... (harcoded? the lib must be recompiled?)
  so PortAudio,libAO or mmsystem must be used for such...
  
  the 6809 source asm files (or bin) are not required (in fact only the binary and possible .dll/.so dependencies are required)
  but so they were compiled with LWTOOLS emitted as hex bytes, and hardcoded into the fastload as an array...
  but any modification to that requires changing some parts of them that are dynamic modified by the FastLoader
  to provide compression... and double speed... and so on...
  
  
