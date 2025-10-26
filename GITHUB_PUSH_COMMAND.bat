@echo off
echo ========================================
echo GitHub Push Helper
echo ========================================
echo.
echo This will push your code to GitHub.
echo.
set /p username="Enter your GitHub username: "
echo.
echo Creating and pushing to: https://github.com/%username%/teams-support-analyst
echo.
pause
echo.
echo Adding remote...
git remote add origin https://github.com/%username%/teams-support-analyst.git
echo.
echo Renaming branch to main...
git branch -M main
echo.
echo Pushing commits...
git push -u origin main
echo.
echo ========================================
echo Done! Check: https://github.com/%username%/teams-support-analyst
echo ========================================
pause
