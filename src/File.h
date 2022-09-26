/*=============================================================================
Blobby Volley 2
Copyright (C) 2006 Jonathan Sieber (jonathan_sieber@yahoo.de)
Copyright (C) 2006 Daniel Knobe (daniel-knobe@web.de)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
=============================================================================*/

#pragma once

#include <string>
#include <cinttypes>

#include "FileExceptions.h"
#include "BlobbyDebug.h"

struct PHYSFS_File;

/**
	\class File
	\brief convenience wrapper around PHYSFS_file
	\details This class provides object oriented access to physfs files. Furthermore,
			it automatically closes opened files on destruction to prevent leaks. 
			For now, it is defined as noncopyable, because we don't have implemented
			any copying behaviour yet.
			This class is not intended for direct use, it is a base class for FileRead
			and FileWrite which provide read/write functionality respectively, so it is
			impossible to accidentally read from a file opened for writing.
	\exception PhysfsException When any physfs function call reported an error, this
							exception is thrown. Its what() string contains the error
							message physfs created.
	\todo 	write tests for this class.
*/
class File : public ObjectCounter<File>
{
	public:
		/// \brief closes the file
		/// \details This function does nothing when no file is opened.
		///			This behaviour is necessary as this function is called in the destructor.
		/// \throw nothing
		void close();
		
		/// destructor, closes the file (if any open)
		/// \sa close()
		/// \throw nothing
		~File();

		// no copies
		File(const File&) = delete;
		File& operator=(const File&) = delete;
		
		// ------------------------------------
		// information querying interface
		// ------------------------------------
		
		/// \brief checks if a file is opened
		/// \throw nothing
		bool is_open() const;
		
		/// \todo check if these return types fit!
		
		/// gets the length of the currently opened file.
		/// \throw PhysfsFileException when Physfs reports an error
		/// \throw NoFileOpenedException when called while no file is opened.
		std::uint32_t length() const;
		
		/// gets the name of the currently opened file
		/// \todo function needs tests
		/// \return name of the opened file, or "" when no file is opened
		/// \throw nothing
		const std::string& getFileName() const;
		
		// ------------------------------------
		//  cursor interface
		// ------------------------------------

		/// gets the current reading position.
		/// \throw PhysfsFileException when Physfs reports an error.
		/// \throw NoFileOpenedException when called while no file is opened.
		uint32_t tell() const;
		
		/// moves the read/write cursor to the desired position
		/// \throw PhysfsFileException when Physfs reports an error
		/// \throw NoFileOpenedException when called while no file is opened.
		void seek(uint32_t target);
		
	protected:
		enum OpenMode 
		{
			OPEN_READ,		///!< open file for reading
			OPEN_WRITE		///!< open file for writing
		};
		
	
		/// \brief default ctor
		/// \details File has to be opened with open()
		/// \throw nothing
		explicit File();
		
		/// \brief constructor which opens a file.
		/// \param filename File to be opened
		/// \param mode Should this file be opened in reading or in writing mode.
		/// \param no_override Set to true if you want to forbid writing over existing file.
		/// \throw FileLoadException, if the file could not be loaded
		/// \throw FileAlreadyExistsException in case of trying to write over existing file with no_override = true
		File(const std::string& filename, OpenMode mode, bool no_override = false);
		
		/// \brief opens a file.
		/// \param filename File to be opened
		/// \param mode Should this file be opened in reading or in writing mode.
		/// \param no_override Set to true if you want to forbid writing over existing file.
		/// \throw FileLoadException, if the file could not be loaded
		/// \throw FileAlreadyExistsException in case of trying to write over existing file with no_override = true
		/// \pre No file is currently opened.
		void open(std::string filename, OpenMode mode, bool no_override = false);
		
		/// handle to the underlying physfs file
		PHYSFS_File* mHandle;
		
		/// we safe the name of the opened file, too, mainly for debugging/logging purposes
		std::string mFileName;
		
		/// helper function which checks if a file is opened and throws 
		/// an exception otherwise.
		/// this is called in every function that directly invokes physfs calls
		/// because physfs does not check that itself (just crashes)
		/// doing an assert would be acceptable from a coders point of view
		/// as trying to read/write/etc. from a closed file is clearly a
		/// programming error. But we don't do anything performance critical with
		/// files, and even then would hard-disk speed be the limiting factor,
		/// not the few additional cycles needed for this exception handling.
		/// so, i think. doing an exception is the best choice here, as it allows
		/// better error recovery and error reporting.
		
		void check_file_open() const;
};
