@echo off
set file=github.releases
set GH=gh
set max=100
del %file%
echo Recreating %file% database...

setlocal enabledelayedexpansion
set lastsize=0
for /l %%x in (1, 1, %max%) do (
  echo %%x..
  %GH% api -X GET "repos/FarGroup/FarManager/releases?page=%%x&per_page=100" --jq ".[] | .name, (.assets.[].browser_download_url | select(.|test(\"7z$\") and (test(\"\\.pdb\") or test(\"ARM64\")|not)))">>%file%
  call :setsize %file%
  if !size!==!lastsize! goto :eof
  set lastsize=!size!
)
goto :eof

:setsize
set size=%~z1
