"""
    TonyHawkSaveSign.py - Python script to recalculate checksums in Tony Hawk Pro Skater save files.
    
    Author: Grimdoomer
    
    Requires Python 3.10 or greater
"""

import struct
import argparse
import hmac
import hashlib
import os.path

g_CRCTable = [
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
    0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
    0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
    0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
    0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
    0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
    0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
    0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
    0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
    0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
    0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
    0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
    0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
    0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
    0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
    0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
    0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
    0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
    0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
    0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
    0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
    0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
    0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
    0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
    0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
    0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d]


def getFileSize(file) -> int:
    # Save the current position.
    pos = file.tell()

    # Seek to the end of the file.
    file.seek(0, 2)

    # Get the file size.
    size = file.tell()

    # Restore the position in the file.
    file.seek(pos, 0)

    # Return the file size.
    return size


def computeCRC(data, size) -> int:
    # Initialize the crc counter.
    crc = 0xFFFFFFFF

    # Loop for the size of the data.
    for i in range(0, size):
        val = (data[i] ^ crc) & 0xFF
        crc = crc >> 8

        crc ^= g_CRCTable[val]

    # Done, return the checksum.
    return crc
    
    
def packUnpackSaveBufferGeneric(saveBuffer, magicIndex, startIndex, magic, pack):

    # Parse the secondary header so we can determine if the same is packed or not.
    nsMagic = int.from_bytes(saveBuffer[magicIndex:magicIndex+2], 'big')
    if nsMagic != magic:
    
        # The save file is unpacked.
        print("Save status: unpacked")
        if pack == False:
            pass
        
    else:
    
        # The save file is packed.
        print("Save status: packed")
        if pack == True:
            pass

    # Loop through the park data and byte flip every dword.
    for i in range(0, 3750):
    
        index = startIndex + (i * 4)
        val = int.from_bytes(saveBuffer[index:index + 4], byteorder='little')
        saveBuffer[index:index + 4] = int.to_bytes(val, 4, byteorder='big')

    # Parse the secondary header so we can determine if the same is packed or not.
    nsMagic = int.from_bytes(saveBuffer[magicIndex:magicIndex+2], 'big')
    if nsMagic != magic:
    
        # The save file is unpacked.
        print("Save is now unpacked")
        
    else:
    
        # The save file is packed.
        print("Save is now packed")
    
    
class XboxSaveSigner:

    # Retail xbox cert key.
    XBOX_RETAIL_CERT_KEY = bytearray.fromhex('5C0733AE0401F7E8BA7993FDCD2F1FE0')

    # Devkit xbox cert key.
    XBOX_DEBUG_CERT_KEY = bytearray.fromhex('66810d3791fd457fbfa976f8a446a494')
    
    # Save game signing keys:
    THPS3_SAVE_KEY = bytearray.fromhex('52BC6FFE29EF0EF9BC50885415782D5B')
    THPS4_SAVE_KEY = bytearray.fromhex('548B07CED20B5392BAA0005BC3064496')
    THAW_SAVE_KEY = bytearray.fromhex('27BDB0927C5BA4D0989D13851A204FFE')
    
    def __computeDigest(self, debug, key, data) -> []:
    
        # Compute the signing key by taking a hash of the signature key using the xbox cert key.
        signKey = hmac.HMAC((self.XBOX_DEBUG_CERT_KEY if debug == True else self.XBOX_RETAIL_CERT_KEY), key, hashlib.sha1).digest()[0:16]

        # Compute the hash of the save game data using the signing key.
        digest = hmac.HMAC(signKey, data, hashlib.sha1).digest()

        # Return the hash.
        return digest
        

    def signTonyHawksProSkater3(self, args, file) -> bool:
    
        # Check the file size to make sure it is correct.
        fileSize = getFileSize(file)
        if getFileSize(file) <= 24:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        file.seek(24, 0)
        saveBuffer = bytearray(file.read(fileSize - 24))

        # Compute the HMAC hash of the save file.
        hash = self.__computeDigest(args.debug, self.THPS3_SAVE_KEY, saveBuffer)

        # Seek to the beginning of the file and write the hash buffer.
        file.seek(0, 0)
        file.write(hash)

        # Done, return true.
        return True
        
        
    def signTonyHawksProSkater4(self, args, file) -> bool:
    
        # Check the file size to make sure it is correct.
        if getFileSize(file) != 0x4000:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        saveBuffer = bytearray(file.read(0x4000))

        # Blank out the first 20 bytes.
        for i in range(20):
            saveBuffer[i] = 0

        # Compute the HMAC hash of the save file.
        hash = self.__computeDigest(args.debug, self.THPS4_SAVE_KEY, saveBuffer)

        # Seek to the beginning of the file and write the hash buffer.
        file.seek(0, 0)
        file.write(hash)

        # Done, return true.
        return True
        
        
    def signTonyHawksAmericanWasteland(self, args, file) -> bool:
    
        # Check the file size to make sure it is correct.
        if getFileSize(file) != 0xC000:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        saveBuffer = bytearray(file.read(0xC000))

        # Blank out the first 20 bytes.
        for i in range(20):
            saveBuffer[i] = 0
        
        # Parse the header.
        startpos = 20
        headerChecksum = int.from_bytes(saveBuffer[20:24], 'little')
        headerDataSize = int.from_bytes(saveBuffer[24:28], 'little')
        dataSize = int.from_bytes(saveBuffer[28:32], 'little')

        # Check that the header size is valid.
        if headerDataSize > 100:
        
            # Park file is invalid.
            print("Park has invalid header size!")
            return False

        # Verify the checksum of the header is correct.
        headerChecksumNew = computeCRC(saveBuffer[36:], headerDataSize)
        if headerChecksumNew != headerChecksum:
            print("Header checksum: Fixed")
        else:
            print("Header checksum: Valid")

        # Save the new header checksum.
        saveBuffer[20:24] = int.to_bytes(headerChecksumNew, 4, 'little')

        # Compute the HMAC hash of the save file.
        hash = self.__computeDigest(args.debug, self.THAW_SAVE_KEY, saveBuffer)

        # Seek to the beginning of the file and write the hash buffer.
        file.seek(0, 0)
        file.write(hash)

        # Done, return true.
        return True
    

class Ps2SaveSigner:

    def signTonyHawksProSkater3(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")
        

    def signTonyHawksProSkater4(self, args, file) -> bool:
    
        # Get the size of the save file.
        fileSize = getFileSize(file)
        if fileSize != 0x4000:
        
            # File is invalid.
            print("Error park file is incorrect size!")
            return False

        # Read the file into a buffer we can work with.
        saveData = bytearray(file.read(fileSize))

        # Parse the header.
        dataChecksum = int.from_bytes(saveData[0:4], 'little')
        headerChecksum = int.from_bytes(saveData[4:8], 'little')
        headerDataSize = int.from_bytes(saveData[8:12], 'little')
        dataSize = int.from_bytes(saveData[12:16], 'little')

        # Check that the header size is valid.
        if headerDataSize > 100:
        
            # Park file is invalid.
            print("Park has invalid header size!")
            return False

        # Verify the checksum of the header is correct.
        headerChecksumNew = computeCRC(saveData[20:], headerDataSize)
        if headerChecksumNew != headerChecksum:
            print("Header checksum: Fixed")
        else:
            print("Header checksum: Valid")

        # Save the new header checksum.
        saveData[4:8] = int.to_bytes(headerChecksumNew, 4, 'little')

        # Zero out the data checksum so we can verify it.
        saveData[0:4] = [0, 0, 0, 0]

        # Verify the checksum for the main block of save data.
        dataChecksumNew = computeCRC(saveData, dataSize)
        if dataChecksumNew != dataChecksum:
            print("Data checksum: Fixed")
        else:
            print("Data checksum: Valid")

        # Save the data checksum.
        saveData[0:4] = int.to_bytes(dataChecksumNew, 4, 'little')

        # Write the new save data back to file.
        file.seek(0, 0)
        file.write(saveData)

        # Done, park file successfully processed.
        return True
        
        
    def signTonyHawksAmericanWasteland(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")

    
class GamecubeSaveSigner:

    def signTonyHawksProSkater3(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")
        

    def signTonyHawksProSkater4(self, args, file) -> bool:
    
        # Note: .gci files have a 64 byte header, so the offsets in this python script will be 64 bytes
        #   off from what you'll see in the game code.
    
        # Check the file size to make sure it is correct.
        if getFileSize(file) != 0x8040:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        saveBuffer = bytearray(file.read(0x8040))
        
        # Check if the save file needs to be packed.
        nsMagic = int.from_bytes(saveBuffer[11444:11446], 'big')
        if nsMagic != 0x4E21:
        
            # Save file needs to be packed before signing.
            packUnpackSaveBufferGeneric(saveBuffer, 11444, 11440, 0x4E21, True)
            
        # Parse the header.
        dataChecksum = int.from_bytes(saveBuffer[11392:11396], 'big')
        headerChecksum = int.from_bytes(saveBuffer[11396:11400], 'big')
        headerDataSize = int.from_bytes(saveBuffer[11400:11404], 'big')
        dataSize = int.from_bytes(saveBuffer[11404:11408], 'big')
        
        # Check that the header size is valid.
        if headerDataSize > 100:
        
            # Park file is invalid.
            print("Park has invalid header size!")
            return False
            
        # Verify the checksum of the header is correct.
        headerChecksumNew = computeCRC(saveBuffer[11412:], headerDataSize)
        if headerChecksumNew != headerChecksum:
            print("Header checksum: Fixed")
        else:
            print("Header checksum: Valid")

        # Save the new header checksum.
        saveBuffer[11396:11400] = int.to_bytes(headerChecksumNew, 4, 'big')
        
        # Zero out the data checksum so we can verify it.
        saveBuffer[11392:11396] = [0, 0, 0, 0]
        
        # Verify the checksum for the main block of save data.
        dataChecksumNew = computeCRC(saveBuffer[64:], dataSize)
        if dataChecksumNew != dataChecksum:
            print("Data checksum: Fixed")
        else:
            print("Data checksum: Valid")

        # Save the data checksum.
        saveBuffer[11392:11396] = int.to_bytes(dataChecksumNew, 4, 'big')
        
        # Write the new save data back to file.
        file.seek(0, 0)
        file.write(saveBuffer)
            
        return True
        
        
    def signTonyHawksAmericanWasteland(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")
    
    
    def packUnpackSaveBuffer(self, args, file) -> bool:
    
        # Check the file size to make sure it is correct.
        if getFileSize(file) != 0x8040:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        saveBuffer = bytearray(file.read(0x8040))
        
        # Pack or unpack the save buffer.
        packUnpackSaveBufferGeneric(saveBuffer, 11444, 11440, 0x4E21, args.pack)
        
        # Write the new save data back to file.
        file.seek(0, 0)
        file.write(saveBuffer)
            
        return True

    
class Xbox360SaveSigner:

    def signTonyHawksProSkater3(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")
        

    def signTonyHawksProSkater4(self, args, file) -> bool:
    
        # Not supported.
        print("Game not supported for this platform")
        

    def signTonyHawksAmericanWasteland(self, args, file) -> bool:
    
        # Get the size of the save file.
        fileSize = getFileSize(file)
        if fileSize != 0xC000:
        
            # File is invalid.
            print("Error park file is incorrect size!")
            return False

        # Read the file into a buffer we can work with.
        saveData = bytearray(file.read(fileSize))

        # Parse the header.
        dataChecksum = int.from_bytes(saveData[0:4], 'big')
        headerChecksum = int.from_bytes(saveData[4:8], 'big')
        headerDataSize = int.from_bytes(saveData[8:12], 'big')
        dataSize = int.from_bytes(saveData[12:16], 'big')

        # Parse the secondary header so we can determine if the same is packed or not.
        nsMagic = int.from_bytes(saveData[96:98], 'big')
        if nsMagic == 0x4E24:  # 'N$'
            
            # Save file needs to be packed before signing.
            packUnpackSaveBufferGeneric(saveData, 96, 90, 0x4E24, True)

        # Check that the header size is valid.
        if headerDataSize > 100:
        
            # Park file is invalid.
            print("Park has invalid header size!")
            return False

        # Verify the checksum of the header is correct.
        headerChecksumNew = computeCRC(saveData[20:], headerDataSize)
        if headerChecksumNew != headerChecksum:
            print("Header checksum: Fixed")
        else:
            print("Header checksum: Valid")

        # Save the new header checksum.
        saveData[4:8] = int.to_bytes(headerChecksumNew, 4, 'big')

        # Zero out the data checksum so we can verify it.
        saveData[0:4] = [0, 0, 0, 0]

        # Verify the checksum for the main block of save data.
        dataChecksumNew = computeCRC(saveData, dataSize)
        if dataChecksumNew != dataChecksum:
            print("Data checksum: Fixed")
        else:
            print("Data checksum: Valid")

        # Save the data checksum.
        saveData[0:4] = int.to_bytes(dataChecksumNew, 4, 'big')

        # Write the new save data back to file.
        file.seek(0, 0)
        file.write(saveData)

        # Done, park file successfully processed.
        return True
        
        
    def packUnpackSaveBuffer(self, args, file) -> bool:
    
        # Check the file size to make sure it is correct.
        if getFileSize(file) != 0xC000:
        
            # The file size is incorrect, we can not sign this file.
            print('Error park file size is incorrect!')
            return False

        # Read the save file into a buffer.
        saveBuffer = bytearray(file.read(0xC000))
        
        # Pack or unpack the save buffer.
        packUnpackSaveBufferGeneric(saveData, 96, 90, 0x4E24, args.pack)
        
        # Write the new save data back to file.
        file.seek(0, 0)
        file.write(saveBuffer)
            
        return True
    
    
def main() -> None:

    # Initialize argparse.
    parser = argparse.ArgumentParser()
    parser.add_argument('game', help='Tony Hawk game to sign for', choices=['thps3', 'thps4', 'thaw'])
    parser.add_argument('platform', help='Platform to sign for', choices=['xbox', 'xbox360', 'ps2', 'gc'])
    parser.add_argument('savefile', help='Save game file')

    # Optional arguments.
    parser.add_argument('-d', '--debug', help='Sign the file for debug consoles (Xbox only)', default=False, action='store_true')
    parser.add_argument('-u', '--unpack', help='Unpacks (byte flips) save file data to little endian ordering (Xbox 360 and Gamecube only)', default=False, action='store_true')
    parser.add_argument('-p', '--pack', help='Packs (byte flips) save file data to big endian ordering (Xbox 360 and Gamecube only)', default=False, action='store_true')

    # Parse the arguments.
    args = parser.parse_args()
    
    # Initialize save signer instances.
    saveSigners = {
        'xbox' : XboxSaveSigner(),
        'ps2' : Ps2SaveSigner(),
        'gc' : GamecubeSaveSigner(),
        'xbox360' : Xbox360SaveSigner()
    }

    # Open the file for processing.
    try:
        fileHandle = open(args.savefile, 'r+b')
    except IOError:
        # Failed to open the file for reading.
        print('Error opening file: \'%s\'' % args.savefile)
        return
    
    # Check for pack/unpack operations.
    if args.pack == True or args.unpack == True:
    
        # Pack/unpack the park file.
        match args.platform:
            case 'gc':
                saveSigners[args.platform].packUnpackSaveBuffer(args, fileHandle)
            case 'xbox360':
                saveSigners[args.platform].packUnpackSaveBuffer(args, fileHandle)
            case _:
                print("Platform '%s' does not support packing/unpacking" % args.platform)
    
    else:
    
        # Sign the park file.
        result = False
        match args.game:
            case 'thps3':
                result = saveSigners[args.platform].signTonyHawksProSkater3(args, fileHandle)
            case 'thps4':
                result = saveSigners[args.platform].signTonyHawksProSkater4(args, fileHandle)
            case 'thaw':
                result = saveSigners[args.platform].signTonyHawksAmericanWasteland(args, fileHandle)
            case _:
                print("Invalid game version '%s'" % args.game)
                
        if result == True:
            print("Successfully signed '%s'" % args.savefile)
        else:
            print("Failed to sign '%s'" % args.savefile)

    # Close the file handle.
    fileHandle.close()


if __name__ == '__main__':
    main()
    