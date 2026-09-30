@echo off
rem Starts a local server for the web build and opens the game in the browser.
rem Browsers cannot run build\web\index.html straight from disk (file://).
cd /d "%~dp0"
start "" http://localhost:8060
node .claude\serve_web.js
