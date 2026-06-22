//////////////////////////////////////////////////////////////////////
// OpenTibia - an opensource roleplaying game
//////////////////////////////////////////////////////////////////////
// various definitions needed by most files
//////////////////////////////////////////////////////////////////////
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//////////////////////////////////////////////////////////////////////


#ifndef __definitions_h
#define __definitions_h


// Modernization: the hand-rolled fixed-width typedefs (uint64_t here, uint32/16/8
// on Windows, and <stdint.h> on *nix below) collided with <stdint.h> on modern
// LP64 systems (uint64_t is `unsigned long` there, not `unsigned long long`).
// Use the standard, identical-width <cstdint> on every platform instead.
#include <cstdint>

#ifdef XML_GCC_FREE
#define xmlFreeOTSERV(s)	free(s)
#else
#define xmlFreeOTSERV(s)	xmlFree(s)
#endif

#if defined __WINDOWS__ || defined WIN32

#define OTSYS_THREAD_RETURN  void

#define EWOULDBLOCK WSAEWOULDBLOCK

#pragma warning(disable:4786) // msvc too long debug names in stl

#ifdef MIN
#undef MIN
#endif

#ifdef MAX
#undef MAX
#endif

#ifndef NOMINMAX
#define NOMINMAX
#endif

#else

#define OTSYS_THREAD_RETURN void*

// Modernization: keep code that still spells the Win32 type __int64 working on
// *nix (same width as before). Fixed-width types come from <cstdint> above.
typedef int64_t __int64;

#endif


#endif // __definitions_h
