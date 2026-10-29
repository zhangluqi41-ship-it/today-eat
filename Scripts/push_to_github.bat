@echo off
setlocal
cd /d "%~dp0.."

set "GIT=%USERPROFILE%\.workbuddy\binaries\PortableGit\versions\1.3.0\mingw64\bin\git.exe"
if exist "%GIT%" goto havgit

for /d %%D in ("%USERPROFILE%\.workbuddy\binaries\PortableGit\versions\*") do if exist "%%D\mingw64\bin\git.exe" set "GIT=%%D\mingw64\bin\git.exe"

:havgit
if not exist "%GIT%" goto nogit

echo.
echo === Today Eat - push to GitHub ===
echo Folder: %CD%
echo.

"%GIT%" config --global credential.helper manager

if exist ".git" goto hasrepo
"%GIT%" init -b main
if errorlevel 1 goto failed
:hasrepo

"%GIT%" add -A
"%GIT%" -c user.name="TodayEat" -c user.email="todayeat@local" commit -m "Today Eat: 213 recipes + SwiftUI app"
if errorlevel 1 echo Nothing new to commit, continue.

start "" "https://github.com/new"
echo.
echo Step 1: create a PUBLIC repo named today-eat, do NOT tick any Initialize box
echo Step 2: copy its URL, like https://github.com/yourname/today-eat.git
echo.
set "REPO="
set /p "REPO=Repo URL: "
if "%REPO%"=="" goto norepo

"%GIT%" remote remove origin >nul 2>nul
"%GIT%" remote add origin "%REPO%"

echo.
echo Pushing now. A browser window may open for GitHub login.
echo.
"%GIT%" push -u origin main
if errorlevel 1 goto failed

echo.
echo Done. Now open your repo on github.com and click the Actions tab.
echo The first build takes about 10 minutes.
echo When it turns green, open the Releases page on your phone and download:
echo    TodayEat-sidestore.ipa
echo.
pause
exit /b 0

:nogit
echo [ERROR] Portable git not found.
echo Looked under: %USERPROFILE%\.workbuddy\binaries\PortableGit
pause
exit /b 1

:norepo
echo [ERROR] No repo URL given.
pause
exit /b 1

:failed
echo.
echo [ERROR] Something failed. Read the message above.
pause
exit /b 1
