param([string]$DosBoxPath = 'C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe')
$ErrorActionPreference = 'Stop'
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\verify-programs.ps1') -Suite conversion -DosBoxPath $DosBoxPath
