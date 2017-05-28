/'
 *
 *  ao.h 
 *
 *	Original Copyright (C) Aaron Holtzman - May 1999
 *      Modifications Copyright (C) Stan Seibert - July 2000, July 2001
 *      More Modifications Copyright (C) Jack Moffitt - October 2000
 *
 *  This file is part of libao, a cross-platform audio outputlibrary.  See
 *  README for a history of this source code.
 *
 *  libao is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  libao is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 '/
#ifndef __AO_H__
#define __AO_H__

#inclib "ao"

extern "C"

' --- Constants ---

const AO_TYPE_LIVE   =   1
const AO_TYPE_FILE   =   2


const AO_ENODRIVER   =   1
const AO_ENOTFILE    =   2
const AO_ENOTLIVE    =   3
const AO_EBADOPTION  =   4
const AO_EOPENDEVICE =   5
const AO_EOPENFILE   =   6
const AO_EFILEEXISTS =   7
const AO_EBADFORMAT  =   8
const AO_EFAIL       = 100

const AO_FMT_LITTLE  =   1
const AO_FMT_BIG     =   2
const AO_FMT_NATIVE  =   4

type ao_info 
	as integer       type        'live output or file output?
	as zstring ptr   name        'full name of driver
	as zstring ptr   short_name  'short name of driver
	as zstring ptr   author      'driver author
	as zstring ptr   comment     'driver comment
	as integer       preferred_byte_format
	as integer       priority
	as ubyte ptr ptr options
	as integer       option_count
end type

type ao_functions as ao_functions
type ao_device as ao_device

type ao_sample_format
	as integer       bits        'bits per sample
	as integer       rate        'samples per second (in a single channel)
	as integer       channels    'number of audio channels
	as integer       byte_format 'Byte ordering in sample, see constants below
  as zstring ptr   matrix      'input channel location/ordering
end type

type ao_option
	as ubyte ptr     key
	as ubyte ptr     value
	as ao_option ptr next
end type

#if defined(AO_BUILDING_LIBAO)
	#include "ao_private.h"
#endif

' --- Functions --- 

' library setup/teardown 
declare sub ao_initialize()
declare sub ao_shutdown()

' device setup/playback/teardown
declare function ao_append_global_option(key as ubyte ptr, value as ubyte ptr) as integer
declare function ao_append_option(options as ao_option ptr ptr,  key as ubyte ptr,  value as ubyte ptr) as integer
declare sub      ao_free_options(options as ao_option ptr)
declare function ao_open_live(driver_id as integer,format as ao_sample_format ptr,option as ao_option ptr) as ao_device ptr
declare function ao_open_file(driver_id as integer, filename as ubyte ptr,overwrite as integer,format as ao_sample_format ptr,option as ao_option ptr) as ao_device ptr
declare function ao_play(device as ao_device ptr,output_samples as any ptr ptr,num_bytes as ulong) as integer
declare function ao_close(device as ao_device ptr) as integer

' driver information
declare function ao_driver_id( short_name as zstring ptr) as integer
declare function ao_default_driver_id() as integer
declare function ao_driver_info(driver_id as integer) as ao_info ptr
declare function ao_driver_info_list(driver_count as integer ptr) as ao_info ptr ptr
declare function ao_file_extension(driver_id as integer) as zstring ptr

' miscellaneous
declare function ao_is_big_endian() as integer

end extern

#endif  '__AO_H__