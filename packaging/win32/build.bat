@ echo off

REM --
REM -- Ensure that an ISS file was given on the command line
REM --

IF [%1] == [] GOTO NoISSFile


REM --
REM -- If the tag has already been checked out, then just skip to the
REM -- update process
REM --

CD cleanbranch
IF %ERRORLEVEL% EQU 1 GOTO CheckOut
CD ..
rmdir /s/q cleanbranch

:Checkout

REM --
REM -- Checkout a clean copy of our repository
REM --

echo Performing a checkout...
hg archive cleanbranch

GOTO DoBuild

REM --
REM -- Build our installer
REM --

:DoBuild
echo Ensuring binaries are compressed
upx ..\..\bin\creole.exe
upx ..\..\bin\eub.exe
upx ..\..\bin\eubind.exe
upx ..\..\bin\eubw.exe
upx ..\..\bin\euc.exe
upx ..\..\bin\eucoverage.exe
upx ..\..\bin\eudoc.exe
upx ..\..\bin\eui.exe
upx ..\..\bin\euiw.exe
upx ..\..\bin\euloc.exe
upx ..\..\bin\eutest.exe

echo Building our installer...
ISCC.exe /Q %1

GOTO Done

:NoISSFile
echo.
echo ** ERROR **
echo.
echo Usage: build.bat package-name.iss
echo.

:Done
