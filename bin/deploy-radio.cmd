echo off

set tgt=rfsuite

set srcfolder=%DEV_RFSUITE_GIT_SRC%
set dstfolder=%DEV_RADIO_SRC%

REM "Remove destination folder"
RMDIR "%dstfolder%\%tgt%" /S /Q


REM "copy files to folder"
mkdir "%dstfolder%\%tgt%"
xcopy "%srcfolder%\scripts\%tgt%" "%dstfolder%\%tgt%"  /h /i /c /k /e /r /y