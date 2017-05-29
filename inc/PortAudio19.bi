''
''
'' portaudio -- header translated with help of SWIG FB wrapper
''
'' NOTICE: This file is part of the FreeBASIC Compiler package and can't
''         be included in other distributions without authorization.
''
''
#ifndef __portaudio2_bi__
#define __portaudio2_bi__

#inclib "portaudio"

extern "C"

type paUlong as unsigned long
type paInteger as long

type PaError as paInteger
type PaDeviceIndex as paInteger
type PaHostApiIndex as paInteger

enum PaErrorNum
	paNoError = 0
	paHostError = -10000
	paInvalidChannelCount
	paInvalidSampleRate
	paInvalidDeviceId
	paInvalidFlag
	paSampleFormatNotSupported
	paBadIODeviceCombination
	paInsufficientMemory
	paBufferTooBig
	paBufferTooSmall
	paNullCallback
	paBadStreamPtr
	paTimedOut
	paInternalError
	paDeviceUnavailable
end enum


declare function Pa_Initialize   () as PaError
declare function Pa_Terminate    () as PaError
declare function Pa_GetHostError () as paInteger
declare function Pa_GetErrorText (errnum as PaError) as zstring ptr

type PaTime as  double
type PaSampleFormat as paUlong

const as PaSampleFormat paFloat32        = &h00000001 
const as PaSampleFormat paInt32          = &h00000002 
const as PaSampleFormat paInt24          = &h00000004 
const as PaSampleFormat paInt16          = &h00000008 
const as PaSampleFormat paInt8           = &h00000010 
const as PaSampleFormat paUInt8          = &h00000020 
const as PaSampleFormat paCustomFormat   = &h00010000 
const as PaSampleFormat paNonInterleaved = &h80000000 

#define paNoDevice -1

declare function Pa_CountDevices () as paInteger

type PaDeviceInfo
  as paInteger structVersion 
  as zstring ptr name
  as PaHostApiIndex hostApi 
  as paInteger maxInputChannels
  as paInteger maxOutputChannels 
  as PaTime defaultLowInputLatency 
  as PaTime defaultLowOutputLatency 
  as PaTime defaultHighInputLatency 
  as PaTime defaultHighOutputLatency 
  as double defaultSampleRate
end type

declare function Pa_GetDefaultOutputDevice() as PaDeviceIndex
declare function Pa_GetDeviceInfo (device as PaDeviceIndex) as PaDeviceInfo ptr

type PaStreamCallbackFlags as paUlong
type PaStreamCallbackTimeInfo
  as PaTime inputBufferAdcTime
  as PaTime currentTime      
  as PaTime outputBufferDacTime
end type

'type PaTimestamp as double
'type PortAudioCallback as function(  inputbuffer as any ptr, outputBuffer as any ptr, framesPerBuffer as paUlong,  outTime as double, userData as any ptr ) as paInteger

type PaStreamCallback as function( input as any ptr , output as any ptr , framecount as paUlong , timeInfo as PaStreamCallbackTimeInfo ptr , statusFlags as PaStreamCallbackFlags , userData as any ptr ) as paInteger
type PortAudioCallback as function( byval inputbuffer as any ptr, outputBuffer as any ptr, framesPerBuffer as paUlong,  outTime as double, userData as any ptr ) as paInteger

type PaStreamFlags as paUlong
const as PaStreamFlags paNoFlag         = &h00000000
const as PaStreamFlags paClipOff        = &h00000001
const as PaStreamFlags paDitherOff      = &h00000002
const as PaStreamFlags paNeverDropInput = &h00000004
const as PaStreamFlags paPrimeOutputBuffersUsingStreamCallback = &h00000008
const as PaStreamFlags paPlatformSpecificFlags = &hFFFF0000

type PortAudioStream as any
type PaStream as PortAudioStream
type PaDeviceIndex as paInteger

type PaVersionInfo
  as paInteger versionMajor
  as paInteger versionMinor
  as paInteger versionSubMinor
  as zstring ptr versionControlRevision
  as zstring ptr versionText
end type

type PaStreamParameters
  device as PaDeviceIndex 
  channelCount as paInteger 
  sampleFormat as PaSampleFormat 	 
  suggestedLatency as PaTime 
  hostApiSpecificStreamInfo as any ptr
end type

declare function Pa_StreamActive ( stream as PortAudioStream ptr) as PaError
declare function Pa_GetCPULoad ( stream as PortAudioStream ptr) as double
declare function Pa_GetMinNumBuffers  ( framesPerBuffer as paInteger,  sampleRate as double) as paInteger
declare sub Pa_Sleep (msec as paInteger)
declare function Pa_GetSampleSize ( format as PaSampleFormat) as PaError

'v2 updated...
declare function Pa_GetDeviceCount() as PaDeviceIndex
declare function Pa_GetVersion() as paInteger
declare function Pa_GetVersionText() as zstring ptr
'declare function Pa_GetVersionInfo() as PaVersionInfo ptr
declare function Pa_OpenStream( stream as PortAudioStream ptr ptr , inputParameters as PaStreamParameters ptr , outputParameters as PaStreamParameters ptr , sampleRate as double, framesPerBuffer as paUlong , streamFlags as PaStreamFlags , streamCallback as PaStreamCallback ptr, userData as any ptr ) as PaError
declare function Pa_OpenDefaultStream ( stream as PortAudioStream ptr ptr,  numInputChannels as paInteger,  numOutputChannels as paInteger,  sampleFormat as PaSampleFormat,  sampleRate as double,  framesPerBuffer as paUlong, streamCallback as PaStreamCallback ptr, userData as any ptr) as PaError
declare function Pa_CloseStream ( as PortAudioStream ptr) as PaError
declare function Pa_StartStream ( stream as PortAudioStream ptr) as PaError
declare function Pa_StopStream ( stream as PortAudioStream ptr) as PaError
declare function Pa_AbortStream ( stream as PortAudioStream ptr) as PaError
declare function Pa_WriteStream ( stream as PortAudioStream ptr, buffer as any ptr, frames as paUlong) as PaError  
declare function Pa_GetStreamTime ( stream as PortAudioStream ptr) as PaTime

end extern

#endif
