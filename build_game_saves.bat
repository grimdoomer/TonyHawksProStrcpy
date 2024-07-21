@echo off

set XEP="D:\Visual Studio 2008\XePatcher\XePatcher\bin\Debug\XePatcher.exe"

:: Can be set to "-d" to sign for debug consoles (xbox only).
set DEBUG=

mkdir Release

:: ----------------------------------------------------------- XBOX
echo **********************************
echo ************** XBOX **************
echo **********************************
echo.

:: Tony Hawk's Pro Skater 3
echo ************** THPS3 **************
xcopy ".\Xbox\Tony Hawk's Pro Skater 3\41560004" ".\Release\Xbox\Tony Hawk's Pro Skater 3\41560004" /E /I /Y
echo.
%XEP% -p "%cd%\Xbox\Tony Hawk's Pro Skater 3\TonyHawkProSkater3-NTSC.asm" -proc x86 -bin "%cd%\Release\Xbox\Tony Hawk's Pro Skater 3\41560004\3DDF5FA578FC\3DDF5FA578FC"
echo.
python ".\TonyHawkSaveSigner.py" thps3 xbox "%cd%\Release\Xbox\Tony Hawk's Pro Skater 3\41560004\3DDF5FA578FC\3DDF5FA578FC" %DEBUG%
echo.

:: Tony Hawk's Pro Skater 4
echo ************** THPS4 **************
xcopy ".\Xbox\Tony Hawk's Pro Skater 4\41560017" ".\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017" /E /I /Y
xcopy ".\Xbox\Tony Hawk's Pro Skater 4\41560017" ".\Release\Xbox\Tony Hawk's Pro Skater 4\PAL\41560017" /E /I /Y
xcopy ".\Xbox\Tony Hawk's Pro Skater 4\41560017" ".\Release\Xbox\Tony Hawk's Pro Skater 4\REGION FREE\41560017" /E /I /Y
echo.

%XEP% -p "%cd%\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-NTSC.asm" -proc x86 -bin "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC"
echo.
%XEP% -p "%cd%\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-PAL.asm" -proc x86 -bin "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\PAL\41560017\3DDF5FA578FC\3DDF5FA578FC"
echo.
%XEP% -p "%cd%\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-RF.asm" -proc x86 -bin "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\REGION FREE\41560017\3DDF5FA578FC\3DDF5FA578FC"
echo.

python ".\TonyHawkSaveSigner.py" thps4 xbox "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC" %DEBUG%
echo.
python ".\TonyHawkSaveSigner.py" thps4 xbox "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\PAL\41560017\3DDF5FA578FC\3DDF5FA578FC" %DEBUG%
echo.
python ".\TonyHawkSaveSigner.py" thps4 xbox "%cd%\Release\Xbox\Tony Hawk's Pro Skater 4\REGION FREE\41560017\3DDF5FA578FC\3DDF5FA578FC" %DEBUG%
echo.

:: Tony Hawk's American Wasteland
echo ************** THAW **************
xcopy ".\Xbox\Tony Hawk's American Wasteland\41560049" ".\Release\Xbox\Tony Hawk's American Wasteland\NTSC\41560049" /E /I /Y
echo.
%XEP% -p "%cd%\Xbox\Tony Hawk's American Wasteland\TonyHawkAmericanWasteland-NTSC.asm" -proc x86 -bin "%cd%\Release\Xbox\Tony Hawk's American Wasteland\NTSC\41560049\3DDF5FA578FC\3DDF5FA578FC"
echo.
python ".\TonyHawkSaveSigner.py" thaw xbox "%cd%\Release\Xbox\Tony Hawk's American Wasteland\NTSC\41560049\3DDF5FA578FC\3DDF5FA578FC" %DEBUG%