@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title TESTE DE ROTEADOR - GPON/ONU/ONT - por Ronald
color 0A

:: =========================================================
::  TESTE DE ROTEADOR - VERSAO SIMPLES
::  - Nao pergunta NADA: acha o gateway sozinho
::  - Pega o MAC do roteador na tabela ARP
::  - Sobe os 3 pings ao vivo na hora
::  - No final: APROVADO / OSCILANDO / FALHA / CRITICO
::  - SEM teste de velocidade
:: =========================================================

:: =========================================================
:: MENU DE TEMPO - uma tecla so. Se nao apertar nada em 15s,
:: comeca sozinho com 30 minutos.
:: =========================================================
cls
echo =====================================================
echo             TESTE DE ROTEADOR
echo             Criado por: Ronald
echo =====================================================
echo.
echo   Quanto tempo vai durar o teste?
echo.
echo     [1]  1 minuto    - so pra testar o proprio script
echo     [2]  5 minutos   - conferida rapida
echo     [3] 10 minutos
echo     [4] 15 minutos
echo     [5] 30 minutos   ^(padrao^)
echo     [6] 60 minutos   - caso intermitente
echo.
echo   Sem apertar nada, comeca em 15s com 30 minutos.
echo =====================================================
echo.
choice /c 123456 /n /t 15 /d 5 /m "Escolha (1-6): "
set "MINUTOS=30"
if errorlevel 6 set "MINUTOS=60"
if errorlevel 6 goto TEMPO_OK
if errorlevel 5 set "MINUTOS=30"
if errorlevel 5 goto TEMPO_OK
if errorlevel 4 set "MINUTOS=15"
if errorlevel 4 goto TEMPO_OK
if errorlevel 3 set "MINUTOS=10"
if errorlevel 3 goto TEMPO_OK
if errorlevel 2 set "MINUTOS=5"
if errorlevel 2 goto TEMPO_OK
if errorlevel 1 set "MINUTOS=1"
:TEMPO_OK

set /a "QTD_PING=MINUTOS*60"
set /a "QTD_PACOTES=QTD_PING+120"

:: =========================================================
:: DATA / HORA
:: =========================================================
set DATA=%date:~0,2%-%date:~3,2%-%date:~6,4%
set HORA=%time:~0,2%-%time:~3,2%-%time:~6,2%
set HORA=%HORA: =0%

:: =========================================================
:: PASTA DO TESTE
:: =========================================================
set "TAG=TESTE_ROTEADOR_%DATA%_%HORA%"
set "LAUDO=%USERPROFILE%\Desktop\%TAG%"
mkdir "%LAUDO%" >nul 2>&1
cls

echo =====================================================
echo             TESTE DE ROTEADOR
echo             Criado por: Ronald
echo =====================================================
echo.
echo Procurando o gateway (roteador) da rede...

:: =========================================================
:: GATEWAY AUTOMATICO (nunca IP fixo, nunca pergunta)
:: =========================================================
set "GW="
for /f "tokens=3" %%g in ('route print -4 ^| findstr /r /c:"^ *0\.0\.0\.0 *0\.0\.0\.0"') do if not defined GW set "GW=%%g"
:: plano B: PowerShell (redes/VPN modernas)
if not defined GW for /f "delims=" %%g in ('powershell -NoProfile -Command "(Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null } ^| Select-Object -First 1 -ExpandProperty IPv4DefaultGateway).NextHop" 2^>nul') do if not defined GW set "GW=%%g"
:: plano C: ipconfig
if not defined GW call :GW_POR_IPCONFIG

if defined GW (set "GW_ACHADO=1") else (set "GW_ACHADO=0")
if not defined GW set "GW=192.168.0.1"

:: =========================================================
:: MAC DO ROTEADOR (tabela ARP do gateway detectado)
:: =========================================================
set "GW_MAC="
if "%GW_ACHADO%"=="0" goto MAC_MSG
call :OBTER_MAC_ARP
if defined GW_MAC goto MAC_UP
ping -n 1 -w 800 %GW% >nul 2>&1
call :OBTER_MAC_ARP
:MAC_UP
if not defined GW_MAC goto MAC_MSG
set "GW_MAC=!GW_MAC:a=A!"
set "GW_MAC=!GW_MAC:b=B!"
set "GW_MAC=!GW_MAC:c=C!"
set "GW_MAC=!GW_MAC:d=D!"
set "GW_MAC=!GW_MAC:e=E!"
set "GW_MAC=!GW_MAC:f=F!"
:MAC_MSG
if "%GW_ACHADO%"=="1" (set "GW_TXT=%GW%") else (set "GW_TXT=Gateway nao encontrado - usando padrao %GW%")
if not defined GW_MAC set "GW_MAC=MAC do roteador nao encontrado"

echo.
echo   Gateway detectado : %GW_TXT%
echo   MAC do roteador   : %GW_MAC%
echo   Duracao do teste  : %MINUTOS% minuto^(s^) ^(F encerra antes^)
echo   Pasta do teste    : %LAUDO%
echo.

:: =========================================================
:: RESUMO INICIAL
:: =========================================================
(
echo =====================================================
echo             TESTE DE ROTEADOR
echo             Criado por: Ronald
echo =====================================================
echo.
echo INICIO      : %date% %time%
echo COMPUTADOR  : %COMPUTERNAME%
echo USUARIO     : %USERNAME%
echo GATEWAY     : %GW_TXT%
echo MAC ROTEADOR: %GW_MAC%
echo PROGRAMADO  : %MINUTOS% minuto^(s^)
echo.
) > "%LAUDO%\RESUMO.txt"

:: =========================================================
:: PINGS AO VIVO - ROTEADOR / GOOGLE / SERVIDOR 10.1.1.1
:: =========================================================
:: MARCA O INICIO REAL DO TESTE (ticks) - base do tempo real do laudo
set "T0="
for /f "delims=" %%t in ('powershell -NoProfile -Command "(Get-Date).Ticks" 2^>nul') do if not defined T0 set "T0=%%t"

echo Abrindo monitores de ping ao vivo...
start "PING_ROTEADOR" cmd /k color 0A ^& powershell -Command "ping %GW% -n %QTD_PACOTES% | Tee-Object -FilePath '%LAUDO%\ping_roteador.txt'"
start "PING_GOOGLE" cmd /k color 0E ^& powershell -Command "ping -4 google.com -n %QTD_PACOTES% | Tee-Object -FilePath '%LAUDO%\ping_google.txt'"
start "PING_SERVIDOR" cmd /k color 0B ^& powershell -Command "ping 10.1.1.1 -n %QTD_PACOTES% | Tee-Object -FilePath '%LAUDO%\ping_servidor.txt'"

set /a "tempo_restante=QTD_PING"

:CONTAGEM
cls
echo =====================================================
echo             TESTE DE ROTEADOR - by Ronald
echo =====================================================
echo.
echo  Gateway : %GW_TXT%
echo  MAC     : %GW_MAC%
echo.
:: _RELMIN/_RELSEG de proposito: batch NAO diferencia maiuscula de
:: minuscula, entao "minutos" aqui sobrescrevia o %MINUTOS% do teste.
set /a "_RELMIN=tempo_restante / 60"
set /a "_RELSEG=tempo_restante %% 60"
if %_RELSEG% LSS 10 set _RELSEG=0%_RELSEG%

echo TEMPO RESTANTE DE TESTE: [ %_RELMIN%:%_RELSEG% ]
echo.
echo  [ F ]      encerra AGORA e gera a analise com o que ja coletou
echo  [ Ctrl+C ] aborta o teste SEM analise
echo =====================================================

:: choice espera 1 segundo; se apertar F sai antes e vai pro laudo
choice /c FX /n /t 1 /d X >nul
if errorlevel 2 goto SEGUE_CONTAGEM
if errorlevel 1 goto FINALIZAR

:SEGUE_CONTAGEM
set /a "tempo_restante-=1"
if %tempo_restante% GEQ 0 goto CONTAGEM

:: =========================================================
:: ENCERRA AS ABAS DE PING (sem derrubar esta janela)
:: =========================================================
:FINALIZAR
:: carimba o fim ANTES de matar as abas, senao o tempo real infla
set "T1="
for /f "delims=" %%t in ('powershell -NoProfile -Command "(Get-Date).Ticks" 2^>nul') do if not defined T1 set "T1=%%t"
cls
echo Encerrando os pings e analisando o resultado...

set "PFIM=%TEMP%\tr_fim.ps1"
del "%PFIM%" >nul 2>&1
echo param($tag) >>"%PFIM%"
echo $meu = $PID >>"%PFIM%"
echo $pai = 0 >>"%PFIM%"
echo try { $pai = (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $meu)).ParentProcessId } catch {} >>"%PFIM%"
echo $vovo = 0 >>"%PFIM%"
echo try { $vovo = (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $pai)).ParentProcessId } catch {} >>"%PFIM%"
echo $rx = [regex]::Escape($tag) >>"%PFIM%"
echo $todos = Get-CimInstance Win32_Process >>"%PFIM%"
echo $alvos = @() >>"%PFIM%"
echo foreach ($p in $todos) { if ($p.ProcessId -ne $meu -and $p.ProcessId -ne $pai -and $p.ProcessId -ne $vovo -and $p.CommandLine -match $rx) { $alvos += $p.ProcessId } } >>"%PFIM%"
echo $filhos = @() >>"%PFIM%"
echo foreach ($p in $todos) { if ($alvos -contains $p.ParentProcessId) { $filhos += $p.ProcessId } } >>"%PFIM%"
echo $netos = @() >>"%PFIM%"
echo foreach ($p in $todos) { if ($filhos -contains $p.ParentProcessId) { $netos += $p.ProcessId } } >>"%PFIM%"
echo foreach ($id in $netos)  { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch {} } >>"%PFIM%"
echo foreach ($id in $filhos) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch {} } >>"%PFIM%"
echo foreach ($id in $alvos)  { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch {} } >>"%PFIM%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PFIM%" "%TAG%" >nul 2>&1

echo Aguardando os logs serem liberados...
timeout /t 3 /nobreak >nul

:: =========================================================
:: ANALISE (perda, latencia, jitter IPDV) E VEREDITO
:: =========================================================
set "PSAN=%TEMP%\tr_analise.ps1"
del "%PSAN%" >nul 2>&1
echo param($pasta,$gw,$gwmac,$mins,$t0,$t1) >>"%PSAN%"
echo $nomes = @('ROTEADOR  ' + $gw, 'INTERNET  google.com', 'SERVIDOR  10.1.1.1') >>"%PSAN%"
echo $arqs  = @('ping_roteador.txt','ping_google.txt','ping_servidor.txt') >>"%PSAN%"
echo $pctA=@(); $medA=@(); $maxA=@(); $jitA=@(); $okA=@(); $peA=@(); $clsA=@() >>"%PSAN%"
echo function Classe($pct,$med,$jit,$ehLocal) { >>"%PSAN%"
echo   if ($pct -lt 0) { return 'SEM DADOS' } >>"%PSAN%"
echo   if ($pct -gt 5 -or $med -gt 300) { return 'CRITICO' } >>"%PSAN%"
echo   if ($pct -ge 3) { return 'FALHA' } >>"%PSAN%"
echo   if (-not $ehLocal -and $med -gt 200) { return 'FALHA' } >>"%PSAN%"
echo   if ($pct -ge 1) { return 'OSCILANDO' } >>"%PSAN%"
echo   if ($ehLocal -and ($med -gt 20 -or $jit -gt 15)) { return 'OSCILANDO' } >>"%PSAN%"
echo   if (-not $ehLocal -and ($med -gt 120 -or $jit -gt 40)) { return 'OSCILANDO' } >>"%PSAN%"
echo   return 'APROVADO' >>"%PSAN%"
echo } >>"%PSAN%"
echo for ($i=0; $i -lt 3; $i++) { >>"%PSAN%"
echo   $p = Join-Path $pasta $arqs[$i] >>"%PSAN%"
echo   $ok=0; $pe=0; $lat=@() >>"%PSAN%"
echo   if (Test-Path $p) { foreach ($l in (Get-Content $p -ErrorAction SilentlyContinue)) { >>"%PSAN%"
echo     if ($l -match '(?i)TTL=') { $ok++; if ($l -match '(?i)tempo[=^<]([0-9]+)ms') { $lat += [int]$matches[1] } elseif ($l -match '(?i)time[=^<]([0-9]+)ms') { $lat += [int]$matches[1] } } >>"%PSAN%"
echo     elseif ($l -match '(?i)(esgotad^|timed out^|inacess^|unreachable^|falha ger^|general fail^|transmit fail^|encontrar o host^|find host)') { $pe++ } >>"%PSAN%"
echo   } } >>"%PSAN%"
echo   $tot = $ok + $pe >>"%PSAN%"
echo   if ($tot -gt 0) { $pct = [math]::Round(($pe*100.0)/$tot,1) } else { $pct = -1 } >>"%PSAN%"
echo   if ($lat.Count -gt 0) { $med = [math]::Round((($lat ^| Measure-Object -Average).Average),1); $mx = ($lat ^| Measure-Object -Maximum).Maximum } else { $med = -1; $mx = -1 } >>"%PSAN%"
echo   $jit = -1 >>"%PSAN%"
echo   if ($lat.Count -gt 1) { $s=0.0; for ($k=1; $k -lt $lat.Count; $k++) { $s += [math]::Abs($lat[$k]-$lat[$k-1]) }; $jit = [math]::Round($s/($lat.Count-1),1) } >>"%PSAN%"
echo   $ehLocal = ($i -eq 0) >>"%PSAN%"
echo   $pctA += $pct; $medA += $med; $maxA += $mx; $jitA += $jit; $okA += $ok; $peA += $pe; $clsA += (Classe $pct $med $jit $ehLocal) >>"%PSAN%"
echo } >>"%PSAN%"
echo $rank = @{ 'APROVADO'=0; 'NAO RESPONDE'=0; 'SEM DADOS'=1; 'OSCILANDO'=2; 'FALHA'=3; 'CRITICO'=4 } >>"%PSAN%"
echo $obs = '' >>"%PSAN%"
echo $ini = 0 >>"%PSAN%"
echo if ($pctA[0] -gt 2 -and $pctA[1] -ge 0 -and $pctA[1] -le 1 -and $pctA[2] -ge 0 -and $pctA[2] -le 1) { >>"%PSAN%"
echo   $obs = 'O roteador deixou de responder parte dos pings, MAS a internet e o servidor - cujo trafego passa por ele - vieram limpos. Isso e limite de resposta ICMP do proprio roteador, NAO perda de trafego. Nao condena o equipamento.' >>"%PSAN%"
echo   $ini = 1 >>"%PSAN%"
echo } >>"%PSAN%"
echo $pulaSrv = $false >>"%PSAN%"
echo if ($pctA[2] -ge 99 -and $pctA[1] -ge 0 -and $pctA[1] -le 2) { >>"%PSAN%"
echo   $clsA[2] = 'NAO RESPONDE' >>"%PSAN%"
echo   $pulaSrv = $true >>"%PSAN%"
echo   if ($obs -ne '') { $obs = $obs + ' ' } >>"%PSAN%"
echo   $obs = $obs + 'O servidor 10.1.1.1 nao respondeu a nenhum ping enquanto a internet vinha limpa: ele nao existe nesta rede ou bloqueia ICMP. Foi tirado do veredito para nao reprovar o cliente por engano.' >>"%PSAN%"
echo } >>"%PSAN%"
echo $ver = 'APROVADO' >>"%PSAN%"
echo for ($i=$ini; $i -lt 3; $i++) { if ($i -eq 2 -and $pulaSrv) { continue }; if ($rank[$clsA[$i]] -gt $rank[$ver]) { $ver = $clsA[$i] } } >>"%PSAN%"
echo if ($ver -eq 'APROVADO') { $frase = 'REDE APROVADA - roteador e link estao saudaveis.' } >>"%PSAN%"
echo elseif ($ver -eq 'OSCILANDO') { $frase = 'REDE OSCILANDO - funciona, mas com instabilidade perceptivel.' } >>"%PSAN%"
echo elseif ($ver -eq 'FALHA') { $frase = 'REDE REPROVADA - falha confirmada, precisa de correcao.' } >>"%PSAN%"
echo elseif ($ver -eq 'CRITICO') { $frase = 'REDE CRITICA - problema grave, atendimento imediato.' } >>"%PSAN%"
echo else { $frase = 'SEM DADOS suficientes - refazer o teste.' } >>"%PSAN%"
echo $durTxt = 'nao medida' >>"%PSAN%"
echo try { >>"%PSAN%"
echo   $dtIni = New-Object DateTime ([long]$t0) >>"%PSAN%"
echo   $dtFim = New-Object DateTime ([long]$t1) >>"%PSAN%"
echo   $sp = $dtFim - $dtIni >>"%PSAN%"
echo   if ($sp.TotalHours -ge 1) { $durTxt = ('{0} h {1} min {2} s' -f [int]$sp.TotalHours, $sp.Minutes, $sp.Seconds) } >>"%PSAN%"
echo   else { $durTxt = ('{0} min {1} s' -f $sp.Minutes, $sp.Seconds) } >>"%PSAN%"
echo   if ($sp.TotalSeconds -lt ([double]$mins * 60 - 5)) { $durTxt = $durTxt + '  (encerrado antes pela tecla F)' } >>"%PSAN%"
echo } catch { $durTxt = 'nao medida' } >>"%PSAN%"
echo $o = @() >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo $o += '            RESULTADO DO TESTE DE ROTEADOR' >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo $o += ' Gateway     : ' + $gw >>"%PSAN%"
echo $o += ' MAC do rot. : ' + $gwmac >>"%PSAN%"
echo $o += ' Programado  : ' + $mins + ' minuto(s)' >>"%PSAN%"
echo $o += ' Tempo real  : ' + $durTxt >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo for ($i=0; $i -lt 3; $i++) { >>"%PSAN%"
echo   $o += '' >>"%PSAN%"
echo   $o += ' ' + $nomes[$i] >>"%PSAN%"
echo   if ($pctA[$i] -lt 0) { $o += '   Sem dados - o log nao foi gerado.'; continue } >>"%PSAN%"
echo   $o += '   Pacotes    : ' + $okA[$i] + ' ok / ' + $peA[$i] + ' perdidos' >>"%PSAN%"
echo   $o += '   Perda      : ' + $pctA[$i] + ' %%' >>"%PSAN%"
echo   if ($medA[$i] -ge 0) { $o += '   Latencia   : media ' + $medA[$i] + ' ms  /  pico ' + $maxA[$i] + ' ms' } >>"%PSAN%"
echo   if ($jitA[$i] -ge 0) { $o += '   Jitter     : ' + $jitA[$i] + ' ms (IPDV)' } >>"%PSAN%"
echo   $o += '   Situacao   : ' + $clsA[$i] >>"%PSAN%"
echo } >>"%PSAN%"
echo $o += '' >>"%PSAN%"
echo if ($obs -ne '') { $o += ' OBSERVACAO:'; $o += ' ' + $obs; $o += '' } >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo $o += '  VEREDITO FINAL: ' + $ver >>"%PSAN%"
echo $o += '  ' + $frase >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo $o += '' >>"%PSAN%"
echo $o += ' TABELA DE REFERENCIA (PERDA - GPON/ONT/ROTEADOR)' >>"%PSAN%"
echo $o += '  [ 0%% ]   - APROVADO : perfeito para jogos, voz e filmes.' >>"%PSAN%"
echo $o += '  [ 1-2%% ] - OSCILANDO: Wi-Fi congestionado ou rota instavel.' >>"%PSAN%"
echo $o += '  [ 3-5%% ] - FALHA    : lentidao, quedas e chamadas travando.' >>"%PSAN%"
echo $o += '  [ +5%% ]  - CRITICO  : fibra atenuada, conector sujo ou cabo ruim.' >>"%PSAN%"
echo $o += '=====================================================' >>"%PSAN%"
echo $o ^| Set-Content -Path (Join-Path $pasta 'RESULTADO.txt') -Encoding ASCII >>"%PSAN%"
echo $o ^| Add-Content -Path (Join-Path $pasta 'RESUMO.txt') -Encoding ASCII >>"%PSAN%"
echo $ver ^| Set-Content -Path (Join-Path $pasta 'veredito.txt') -Encoding ASCII >>"%PSAN%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PSAN%" "%LAUDO%" "%GW_TXT%" "%GW_MAC%" "%MINUTOS%" "%T0%" "%T1%"

:: =========================================================
:: TELA FINAL
:: =========================================================
set "VER="
if exist "%LAUDO%\veredito.txt" for /f "usebackq delims=" %%v in ("%LAUDO%\veredito.txt") do if not defined VER set "VER=%%v"
if /i "%VER%"=="APROVADO"  color 0A
if /i "%VER%"=="OSCILANDO" color 0E
if /i "%VER%"=="FALHA"     color 0C
if /i "%VER%"=="CRITICO"   color 0C

cls
if exist "%LAUDO%\RESULTADO.txt" (
  type "%LAUDO%\RESULTADO.txt"
) else (
  echo Nao foi possivel gerar o resultado. Confira os logs em:
  echo %LAUDO%
)
echo.
echo  Arquivos salvos em:
echo  %LAUDO%
echo.
pause
goto :FIM

:: =========================================================
:: SUB-ROTINAS
:: =========================================================
:OBTER_MAC_ARP
for /f "tokens=1,2" %%a in ('arp -a 2^>nul') do (
  if "%%a"=="%GW%" set "GW_MAC=%%b"
)
goto :eof

:GW_POR_IPCONFIG
for /f "tokens=2 delims=:" %%g in ('ipconfig ^| findstr /i /c:"Gateway"') do (
  set "_gwtmp=%%g"
  set "_gwtmp=!_gwtmp: =!"
  if defined _gwtmp if not defined GW call :GW_VALIDA_IP "!_gwtmp!"
)
goto :eof

:GW_VALIDA_IP
echo %~1| findstr /r /c:"^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul && set "GW=%~1"
goto :eof

:FIM
endlocal
