@echo off
SET GH=gh
SET max=15
echo Recreating github.releases database...
del github.releases
for /l %%x in (1, 1, %max%) do echo %%x/%max% & %GH% api -X GET "repos/FarGroup/FarManager/releases?page=%%x&per_page=100" --jq ".[] | .name, (.assets.[].browser_download_url | select(.|test(\"7z$\") and (test(\"\\.pdb\") or test(\"ARM64\")|not)))">>github.releases
