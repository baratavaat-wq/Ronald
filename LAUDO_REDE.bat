@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: =========================================================
::  LAUDO COMPLETO DE REDE v%VER% - GPON/ONU/ONT/Wi-Fi 2.4G-5G
::  Criado por: Ronald
::  - Pede NOME DO TECNICO, minutos, extra IPv4 e extra IPv6
::  - Laudo com perda + ping MIN / MEDIO / MAX + diagnostico
::  - ENVIA TUDO PARA O TELEGRAM (texto + ZIP do laudo)
:: =========================================================

title LAUDO DE REDE v%VER% - por Ronald
color 0A
set "AQUI=%~dp0"

:: +=======================================================+
::   VERSAO E ATUALIZACAO AUTOMATICA (GitHub)
::   Troque USUARIO e REPO pelos seus. Ramo: main.
:: +=======================================================+
:: +=======================================================+
::   >>> UNICO LUGAR PARA MUDAR A VERSAO <<<
::   Troque so este numero. Tudo abaixo se ajusta sozinho:
::   titulo, cabecalhos, telas e a checagem do GitHub.
:: +=======================================================+
set "VER=1009"
set "VERSAO_LOCAL=%VER%"
set "RAW_BASE=https://raw.githubusercontent.com/baratavaat-wq/Ronald/main/"
set "URL_VERSAO=%RAW_BASE%versao.txt"
set "URL_SCRIPT=%RAW_BASE%LAUDO_REDE.bat"
set "URL_NOTAS=%RAW_BASE%novidades.txt"
:: pagina do repo no navegador (link manual) - derivada abaixo em tempo de execucao
set "URL_PAGINA="
set "CHECAR_UPDATE=sim"

:: +=======================================================+
::   TELEGRAM  -  token e chat ficam em config.ini
::   (ProgramData\LaudoRede) - nao apaga ao atualizar.
::   Na 1a execucao o script pergunta e salva.
:: +=======================================================+
set "CFG_DIR=%ProgramData%\LaudoRede"
set "CFG=%CFG_DIR%\config.ini"
set "TG_ENVIAR=sim"
set "TG_TOKEN="
set "TG_CHAT="


:: +=======================================================+
::   ABA 1  -  PING DO ROTEADOR            janela VERDE
::   ALVO  : automatico (gateway da rede) - nao mexe
::   MUDA  : LIMITE = ms para bipar como ping alto
::           60 padrao / 30 exigente / 100 tolerante
:: +=======================================================+
set "LIMITE_ROTEADOR=60"


:: +=======================================================+
::   ABA 2  -  PING INTERNET IPv4          janela AMARELA
::   MUDA  : ALVO   = IP ou site
::           8.8.8.8 Google / 1.1.1.1 Cloudflare
::           9.9.9.9 Quad9  / uol.com.br
::   MUDA  : LIMITE = ms para bipar como ping alto
:: +=======================================================+
set "ALVO_INTERNET=8.8.8.8"
set "LIMITE_INTERNET=120"


:: +=======================================================+
::   ABA 3  -  PING DO SERVIDOR            janela AZUL
::   MUDA  : ALVO   = servidor interno / da empresa
::           10.1.1.1 / 192.168.1.10 / 172.16.0.1 / srv.local
::   MUDA  : LIMITE = ms para bipar como ping alto
:: +=======================================================+
set "SERVIDOR=10.1.1.7"
set "LIMITE_SERVIDOR=120"


:: +=======================================================+
::   ABA 4  -  PING EXTRA IPv4             janela VERMELHA
::   ALVO  : NAO se edita aqui - o script PERGUNTA ao rodar
::   MUDA  : LIMITE = ms para bipar como ping alto
:: +=======================================================+
set "LIMITE_EXTRA=120"


:: +=======================================================+
::   ABA 5  -  PING IPv6                   janela BRANCA
::   So abre se a rede tiver IPv6 (testado no inicio)
::   MUDA  : ALVO   = google.com
::                    2001:4860:4860::8888 Google
::                    2606:4700:4700::1111 Cloudflare
::   MUDA  : LIMITE = ms para bipar como ping alto
:: +=======================================================+
set "ALVO_IPV6=google.com"
set "LIMITE_IPV6=120"


:: +=======================================================+
::   ABA 6  -  PING EXTRA IPv6             janela AZUL CLARO
::   ALVO  : NAO se edita aqui - o script PERGUNTA ao rodar
::   MUDA  : LIMITE = ms para bipar como ping alto
:: +=======================================================+
set "LIMITE_EXTRA_IPV6=120"


:: +=======================================================+
::   ABA 7  -  SPEEDTEST                   janela CIANO
::   MUDA  : INTERVALO = roda a cada X segundos
::   MUDA  : NOME  = nome do .exe (aceita * curinga)
::   MUDA  : ARGS  = argumentos (vazio = nenhum)
:: +=======================================================+
set "INTERVALO_SPEED=120"
set "NOME_SPEED=speedtest.exe"
set "SPEEDARGS=--accept-license --accept-gdpr"


:: +=======================================================+
::   ABA 8  -  FAST                        janela ROSA
::   MUDA  : INTERVALO = roda a cada X segundos
::   MUDA  : NOME  = nome do .exe (aceita * curinga)
::   MUDA  : ARGS  = vazio = nenhum / -u = mede upload
:: +=======================================================+
set "INTERVALO_FAST=30"
set "NOME_FAST=fast*windows_386*"
set "FASTARGS="


:: +=======================================================+
::   ABA PRINCIPAL  -  cronometro, voz e veredito
::   TEMPO : o script PERGUNTA os MINUTOS ao rodar.
::           Abaixo so o valor PADRAO (ao dar ENTER)
::   MUDA  : VOZ   = curto / longo / nao (sem fala no final)
::   MUDA  : IPV6_NO_VEREDITO = 0 nao reprova / 1 reprova
::   MUDA  : TESTAR_IPV6 = auto / sim / nao
:: +=======================================================+
set "MINUTOS_PADRAO=15"
set "VOZ_MODO=nao"
set "IPV6_NO_VEREDITO=0"
set "TESTAR_IPV6=auto"


:: #########################################################
::            DAQUI PARA BAIXO NAO PRECISA MEXER
:: #########################################################

for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%i"
if not defined STAMP set "STAMP=sem_data"

call :CHECAR_ATUALIZACAO
call :CARREGAR_CONFIG
echo.
echo   ============================================
echo     [OK] VERSAO %VER% carregada com sucesso!
echo   ============================================
timeout /t 4 >nul

:: GATEWAY AUTOMATICO (ABA 1)
set "GW="
for /f "tokens=3" %%g in ('route print -4 ^| findstr /r /c:"^ *0\.0\.0\.0 *0\.0\.0\.0"') do if not defined GW set "GW=%%g"
:: plano B: se o route print nao achou, tenta pelo PowerShell (redes/VPN modernas)
if not defined GW for /f "delims=" %%g in ('powershell -NoProfile -Command "(Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null } ^| Select-Object -First 1 -ExpandProperty IPv4DefaultGateway).NextHop" 2^>nul') do if not defined GW set "GW=%%g"
if not defined GW set "GW=192.168.0.1"

:: CHECAGEM PREVIA DE IPv6 (ABA 5 e 6)
set "PCHK=%TEMP%\chk_ipv6.ps1"
del "%PCHK%" >nul 2>&1
echo param($alvo) >>"%PCHK%"
echo $als = @($alvo, "2001:4860:4860::8888") >>"%PCHK%"
echo foreach ($a in $als) { >>"%PCHK%"
echo $r = ping -6 -n 2 -w 1500 $a >>"%PCHK%"
echo if ($r -match "=\s*\d+\s*ms") { Write-Output $a; break } >>"%PCHK%"
echo } >>"%PCHK%"

set "TEM_IPV6=0"
set "IPV6_USADO="
cls
echo Verificando se a rede tem IPv6...
if /i not "%TESTAR_IPV6%"=="nao" (
  for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PCHK%" "%ALVO_IPV6%"') do if not defined IPV6_USADO set "IPV6_USADO=%%i"
)
if defined IPV6_USADO set "TEM_IPV6=1"
if /i "%TESTAR_IPV6%"=="sim" set "TEM_IPV6=1"
if /i "%TESTAR_IPV6%"=="sim" if not defined IPV6_USADO set "IPV6_USADO=%ALVO_IPV6%"

:: =========================================================
:: PERGUNTA 1 - NOME DO TECNICO (obrigatorio, so 1o nome)
:: =========================================================
:PERGUNTA_TECNICO
set "TECNICO="
set "TEC_OK="
cls
echo =====================================================
echo             LAUDO DE REDE v%VER% - Ronald
echo =====================================================
echo.
echo  IDENTIFICACAO DO TECNICO
echo  Digite APENAS O PRIMEIRO NOME de quem esta fazendo o teste.
echo  Exemplos: Ronald / Matheus / Carlos
echo.
set /p "TECNICO=  Primeiro nome do tecnico: "
if not defined TECNICO goto PERGUNTA_TECNICO
set "TECNICO=%TECNICO:"=%"
for /f "tokens=1" %%n in ("%TECNICO%") do set "TEC_OK=%%n"
if not defined TEC_OK goto PERGUNTA_TECNICO
set "TECNICO=%TEC_OK%"
title LAUDO DE REDE v%VER% - Tecnico: %TECNICO%

:: =========================================================
:: PERGUNTA 2 - NOME DO CLIENTE (obrigatorio)
:: =========================================================
:PERGUNTA_CLIENTE
set "CLIENTE="
echo.
echo  ----------------------------------------------------
echo  NOME DO CLIENTE
echo  Digite o nome do cliente / empresa do atendimento.
echo  Exemplos: Joao Silva / Padaria Central / Loja 42
echo.
set /p "CLIENTE=  Nome do cliente: "
if not defined CLIENTE goto PERGUNTA_CLIENTE
set "CLIENTE=%CLIENTE:"=%"
if not defined CLIENTE goto PERGUNTA_CLIENTE

:: nome do cliente limpo, para usar no nome da pasta
set "PSAN=%TEMP%\sanit.ps1"
del "%PSAN%" >nul 2>&1
echo param($txt) >>"%PSAN%"
echo $c = $txt -replace '[\\/:*?^<^>^|]', '' >>"%PSAN%"
echo $c = $c -replace '[^\x20-\x7E]', '' >>"%PSAN%"
echo $c = $c -replace '[\x00-\x1F]', '' >>"%PSAN%"
echo $c = $c -replace '\s+', '_' >>"%PSAN%"
echo $c = $c.Trim('. _') >>"%PSAN%"
echo if ($c.Length -gt 40) { $c = $c.Substring(0,40) } >>"%PSAN%"
echo if (-not $c) { $c = 'cliente' } >>"%PSAN%"
echo Write-Output $c >>"%PSAN%"
set "CLI_PASTA="
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PSAN%" "%CLIENTE%"') do set "CLI_PASTA=%%i"
if not defined CLI_PASTA set "CLI_PASTA=cliente"

:: PASTA DO LAUDO (com o nome do tecnico)
set "LAUDO=%USERPROFILE%\Desktop\LAUDO_%TECNICO%_%CLI_PASTA%_%STAMP%"
mkdir "%LAUDO%" >nul 2>&1

:: =========================================================
:: PERGUNTA 3 - MINUTOS
:: =========================================================
set "MINUTOS="
echo.
echo  ----------------------------------------------------
echo  TEMPO DE TESTE
echo  Quantos MINUTOS o teste vai rodar?
echo  Exemplos: 1 / 5 / 10 / 15 / 30 / 60
echo  ENTER em branco = %MINUTOS_PADRAO% minutos.
echo.
set /p "MINUTOS=  Minutos (ENTER = %MINUTOS_PADRAO%): "
if defined MINUTOS set "MINUTOS=%MINUTOS:"=%"
if not defined MINUTOS set "MINUTOS=%MINUTOS_PADRAO%"
echo %MINUTOS%| findstr /r "^[1-9][0-9]*$" >nul || set "MINUTOS=%MINUTOS_PADRAO%"
set /a "QTD_PING=%MINUTOS%*60"
if %QTD_PING% LSS 60 set /a "QTD_PING=60"

:: =========================================================
:: PERGUNTA 4 e 5 - ALVOS EXTRA
:: =========================================================
set "ALVO_EXTRA="
set "ALVO_EXTRA_IPV6="
echo.
echo  ----------------------------------------------------
echo  ABA 4 - PING EXTRA IPv4  (opcional)
echo  Digite o alvo para abrir a aba extra, ou so ENTER para NAO abrir.
echo  Exemplos: 1.1.1.1  /  9.9.9.9  /  200.160.2.3  /  globo.com
echo.
set /p "ALVO_EXTRA=  Alvo EXTRA IPv4 (ENTER = nenhum): "
if defined ALVO_EXTRA set "ALVO_EXTRA=%ALVO_EXTRA:"=%"

echo.
if not "%TEM_IPV6%"=="1" goto SEM_PERGUNTA_IPV6
echo  ----------------------------------------------------
echo  ABA 6 - PING EXTRA IPv6  (opcional)
echo  Digite o alvo para abrir a aba extra, ou so ENTER para NAO abrir.
echo  Exemplos: 2606:4700:4700::1111  /  2620:fe::fe  /  cloudflare.com
echo.
set /p "ALVO_EXTRA_IPV6=  Alvo EXTRA IPv6 (ENTER = nenhum): "
if defined ALVO_EXTRA_IPV6 set "ALVO_EXTRA_IPV6=%ALVO_EXTRA_IPV6:"=%"
goto FIM_PERGUNTAS

:SEM_PERGUNTA_IPV6
echo  ----------------------------------------------------
echo  ABA 6 - PING EXTRA IPv6: a rede NAO tem IPv6, entao nem pergunto.
timeout /t 2 >nul

:FIM_PERGUNTAS
if "%TEM_IPV6%"=="1" (set "TXT_IPV6=SIM - alvo: %IPV6_USADO%") else (set "TXT_IPV6=NAO - abas IPv6 nao serao abertas")
if defined ALVO_EXTRA (set "TXT_EXTRA=%ALVO_EXTRA%") else (set "TXT_EXTRA=nao usado")
if defined ALVO_EXTRA_IPV6 (set "TXT_EXTRA6=%ALVO_EXTRA_IPV6%") else (set "TXT_EXTRA6=nao usado")

:: =========================================================
:: DETECCAO DA CONEXAO ATIVA
::   Wi-Fi 2.4 / 5 / 6 GHz, geracao Wi-Fi 4/5/6/7, ou LAN
::   e avisa se LAN e Wi-Fi estao ligados AO MESMO TEMPO
:: =========================================================
set "PNET=%TEMP%\rede_info.ps1"
del "%PNET%" >nul 2>&1
echo param($pasta) >>"%PNET%"
echo $det = @() >>"%PNET%"
echo $temLan = $false >>"%PNET%"
echo $temWifi = $false >>"%PNET%"
echo $lanNome = "" >>"%PNET%"
echo $lanVel = "" >>"%PNET%"
echo try { >>"%PNET%"
echo $ads = Get-NetAdapter -Physical -ErrorAction Stop ^| Where-Object { $_.Status -eq 'Up' } >>"%PNET%"
echo foreach ($a in $ads) { >>"%PNET%"
echo if ($a.MediaType -eq '802.3') { $temLan = $true; $lanNome = $a.InterfaceDescription; $lanVel = $a.LinkSpeed } >>"%PNET%"
echo } >>"%PNET%"
echo } catch {} >>"%PNET%"
echo $ssid = "" >>"%PNET%"
echo $banda = "" >>"%PNET%"
echo $canal = "" >>"%PNET%"
echo $radio = "" >>"%PNET%"
echo $sinal = "" >>"%PNET%"
echo $rx = "" >>"%PNET%"
echo $tx = "" >>"%PNET%"
echo $estado = "" >>"%PNET%"
echo $wl = netsh wlan show interfaces 2^>$null >>"%PNET%"
echo foreach ($l in $wl) { >>"%PNET%"
echo $t = [string]$l >>"%PNET%"
echo if ($t -match '(?i)^\s*(Estado^|State)\s*:\s*(.+)$') { $estado = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)^\s*SSID\s*:\s*(.+)$') { $ssid = $Matches[1].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)^\s*(Banda^|Band)\s*:\s*(.+)$') { $banda = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)^\s*(Canal^|Channel)\s*:\s*(.+)$') { $canal = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)(tipo de r.dio^|radio type)\s*:\s*(.+)$') { $radio = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)^\s*(Sinal^|Signal)\s*:\s*(.+)$') { $sinal = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)(recebimento^|receive rate).*:\s*(.+)$') { $rx = $Matches[2].Trim() } >>"%PNET%"
echo elseif ($t -match '(?i)(transmiss^|transmit rate).*:\s*(.+)$') { $tx = $Matches[2].Trim() } >>"%PNET%"
echo } >>"%PNET%"
echo if ($ssid -and $estado -match '(?i)(conectado^|connected)') { $temWifi = $true } >>"%PNET%"
echo $sinal = $sinal.TrimEnd([char]37) >>"%PNET%"
echo if (-not $banda -and $canal -match '^\d+$') { >>"%PNET%"
echo $c = [int]$canal >>"%PNET%"
echo if ($c -ge 1 -and $c -le 14) { $banda = '2.4 GHz' } elseif ($c -ge 32) { $banda = '5 GHz' } >>"%PNET%"
echo } >>"%PNET%"
echo $ger = 'Wi-Fi ?' >>"%PNET%"
echo if ($radio -match '(?i)802\.11be') { $ger = 'Wi-Fi 7' } >>"%PNET%"
echo elseif ($radio -match '(?i)802\.11ax') { $ger = 'Wi-Fi 6' ; if ($banda -match '6') { $ger = 'Wi-Fi 6E' } } >>"%PNET%"
echo elseif ($radio -match '(?i)802\.11ac') { $ger = 'Wi-Fi 5' } >>"%PNET%"
echo elseif ($radio -match '(?i)802\.11n') { $ger = 'Wi-Fi 4' } >>"%PNET%"
echo elseif ($radio -match '(?i)802\.11g') { $ger = 'Wi-Fi 3' } >>"%PNET%"
echo $rota = 'desconhecida' >>"%PNET%"
echo try { >>"%PNET%"
echo $fi = Find-NetRoute -RemoteIPAddress '8.8.8.8' -ErrorAction Stop ^| Select-Object -First 1 >>"%PNET%"
echo $ad = Get-NetAdapter -InterfaceIndex $fi.InterfaceIndex -ErrorAction Stop >>"%PNET%"
echo if ($ad.MediaType -eq '802.3') { $rota = 'LAN' } else { $rota = 'Wi-Fi' } >>"%PNET%"
echo } catch {} >>"%PNET%"
echo if ($temLan -and $temWifi) { $res = 'ATENCAO - LAN e Wi-Fi ligados AO MESMO TEMPO - o teste esta indo pela ' + $rota } >>"%PNET%"
echo elseif ($temWifi) { $res = 'Wi-Fi / ' + $banda + ' / ' + $ger + ' / SSID ' + $ssid + ' / canal ' + $canal + ' / sinal ' + $sinal } >>"%PNET%"
echo elseif ($temLan) { $res = 'LAN por cabo / ' + $lanVel } >>"%PNET%"
echo else { $res = 'Nenhuma conexao ativa detectada' } >>"%PNET%"
echo $det += '===== CONEXAO USADA NO TESTE =====' >>"%PNET%"
echo $det += 'Resumo .........: ' + $res >>"%PNET%"
echo $det += 'Rota ativa .....: ' + $rota >>"%PNET%"
echo $det += '' >>"%PNET%"
echo $det += '--- Wi-Fi ---' >>"%PNET%"
echo if ($temWifi) { >>"%PNET%"
echo $det += 'SSID ...........: ' + $ssid >>"%PNET%"
echo $det += 'Banda ..........: ' + $banda >>"%PNET%"
echo $det += 'Geracao ........: ' + $ger >>"%PNET%"
echo $det += 'Tipo de radio ..: ' + $radio >>"%PNET%"
echo $det += 'Canal ..........: ' + $canal >>"%PNET%"
echo $det += 'Sinal ..........: ' + $sinal >>"%PNET%"
echo $det += 'Taxa Rx ........: ' + $rx + ' Mbps' >>"%PNET%"
echo $det += 'Taxa Tx ........: ' + $tx + ' Mbps' >>"%PNET%"
echo } else { $det += 'Wi-Fi ..........: nao conectado' } >>"%PNET%"
echo $det += '' >>"%PNET%"
echo $det += '--- LAN por cabo ---' >>"%PNET%"
echo if ($temLan) { >>"%PNET%"
echo $det += 'Placa ..........: ' + $lanNome >>"%PNET%"
echo $det += 'Velocidade .....: ' + $lanVel >>"%PNET%"
echo } else { $det += 'LAN ............: nao conectada' } >>"%PNET%"
echo if ($temLan -and $temWifi) { >>"%PNET%"
echo $det += '' >>"%PNET%"
echo $det += 'AVISO: com LAN e Wi-Fi ligados juntos o Windows escolhe a rota' >>"%PNET%"
echo $det += 'de menor metrica. Para medir o Wi-Fi, desligue o cabo.' >>"%PNET%"
echo } >>"%PNET%"
echo Set-Content -Path (Join-Path $pasta "CONEXAO.txt") -Value $det -Encoding UTF8 >>"%PNET%"
echo Write-Output $res >>"%PNET%"

set "CONEXAO="
echo Detectando a conexao usada no teste...
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PNET%" "%LAUDO%"') do set "CONEXAO=%%i"
if not defined CONEXAO set "CONEXAO=nao detectada"

cls
echo =====================================================
echo          LAUDO COMPLETO DE REDE v%VER%
echo          Tecnico: %TECNICO%   Cliente: %CLIENTE%
echo =====================================================
echo.
echo  Pasta do laudo    : %LAUDO%
echo  CONEXAO           : %CONEXAO%
echo  TEMPO DE TESTE    : %MINUTOS% minutos   ^(%QTD_PING% pings^)
echo  Telegram          : %TG_ENVIAR%
echo.
echo  ABA1 Roteador     : %GW%   ^(limite %LIMITE_ROTEADOR% ms^)
echo  ABA2 Internet     : %ALVO_INTERNET%   ^(limite %LIMITE_INTERNET% ms^)
echo  ABA3 Servidor     : %SERVIDOR%   ^(limite %LIMITE_SERVIDOR% ms^)
echo  ABA4 Extra IPv4   : %TXT_EXTRA%
echo  ABA5 IPv6         : %TXT_IPV6%
echo  ABA6 Extra IPv6   : %TXT_EXTRA6%
echo  ABA7 Speed: %INTERVALO_SPEED%s   ABA8 Fast: %INTERVALO_FAST%s   Voz: %VOZ_MODO%
echo.

(
echo =====================================================
echo          LAUDO COMPLETO DE REDE v%VER%
echo          Tecnico: %TECNICO%
echo =====================================================
echo.
echo INICIO         : %date% %time%
echo TECNICO        : %TECNICO%
echo CLIENTE        : %CLIENTE%
echo CONEXAO        : %CONEXAO%
echo DURACAO        : %MINUTOS% minutos
echo COMPUTADOR     : %COMPUTERNAME%
echo USUARIO        : %USERNAME%
echo ROTEADOR       : %GW%
echo INTERNET IPv4  : %ALVO_INTERNET%
echo SERVIDOR       : %SERVIDOR%
echo EXTRA IPv4     : %TXT_EXTRA%
echo IPV6           : %TXT_IPV6%
echo EXTRA IPv6     : %TXT_EXTRA6%
echo.
) > "%LAUDO%\RESUMO.txt"

:: LOCALIZA OS EXECUTAVEIS (ABA 7 e 8)
echo Procurando executaveis no disco (pode demorar um pouco)...
call :LOCALIZAR SPEEDEXE "%NOME_SPEED%"
call :LOCALIZAR FASTEXE "%NOME_FAST%"
if defined SPEEDEXE (echo   ^> speedtest: %SPEEDEXE%) else (echo   [AVISO] speedtest nao encontrado.)
if defined FASTEXE  (echo   ^> fast     : %FASTEXE%)  else (echo   [AVISO] fast nao encontrado.)
echo.

:: =========================================================
:: MONITOR DE PING COM BIP (ping_beep.ps1)
:: =========================================================
set "PBEEP=%TEMP%\ping_beep.ps1"
del "%PBEEP%" >nul 2>&1
echo param($alvo, $log, $limite, $qtd, $flag) >>"%PBEEP%"
echo if (-not $limite) { $limite = 100 } >>"%PBEEP%"
echo if (-not $qtd) { $qtd = 1800 } >>"%PBEEP%"
echo $to = 0 >>"%PBEEP%"
echo $hi = 0 >>"%PBEEP%"
echo $ver = "IPv4" >>"%PBEEP%"
echo if ($flag -eq "6") { $ver = "IPv6" } >>"%PBEEP%"
echo Add-Content -Path $log -Value ("=== PING " + $alvo + " " + $ver + " limite " + $limite + "ms ===") >>"%PBEEP%"
echo $argos = @() >>"%PBEEP%"
echo if ($flag -eq "6") { $argos += "-6" } >>"%PBEEP%"
echo if ($flag -eq "4") { $argos += "-4" } >>"%PBEEP%"
echo $argos += $alvo >>"%PBEEP%"
echo $argos += "-n" >>"%PBEEP%"
echo $argos += "$qtd" >>"%PBEEP%"
echo ping @argos ^| ForEach-Object { >>"%PBEEP%"
echo $linha = $_ >>"%PBEEP%"
echo Write-Host $linha >>"%PBEEP%"
echo Add-Content -Path $log -Value $linha >>"%PBEEP%"
echo $txt = [string]$linha >>"%PBEEP%"
echo if ($txt -match "(?i)(esgotad|timed out|inacess|unreachable|falha ger|general fail)") { $to = $to + 1; [console]::beep(2200,500); [console]::beep(2200,500); Write-Host "   *** TIMEOUT ***" -ForegroundColor Red } >>"%PBEEP%"
echo elseif ($txt -match "(?i)[=]\s*([0-9]+)\s*ms") { $ms = [int]$Matches[1]; if ($ms -ge $limite) { $hi = $hi + 1; [console]::beep(1600,400); Write-Host ("   *** PING ALTO " + $ms + "ms ***") -ForegroundColor Yellow } } >>"%PBEEP%"
echo } >>"%PBEEP%"
echo Add-Content -Path $log -Value ("=== FIM timeouts=" + $to + " ping_alto=" + $hi + " ===") >>"%PBEEP%"
echo Write-Host ("RESUMO " + $alvo + " " + $ver + " : timeouts=" + $to + "  ping_alto=" + $hi) -ForegroundColor Cyan >>"%PBEEP%"

:: =========================================================
:: LAUDO TECNICO + VOZ + TEXTO DO TELEGRAM (falar_status.ps1)
:: =========================================================
:: LAUDO TECNICO + VOZ + TELEGRAM (falar_status.ps1)  [v%VER%]
::   - evidencia por PADRAO (rajada / alternancia) com
::     contexto de amostra e quantidade de eventos
::   - CONSENSO entre multiplos destinos
::   - INDICE DE CONFIANCA do diagnostico
::   - gateway continua sendo a referencia maxima
:: =========================================================
set "PFALA=%TEMP%\falar_status.ps1"
del "%PFALA%" >nul 2>&1
echo param($pasta, $modo, $ipv6Conta, $temIpv6, $mins, $tec, $cli, $conx, $aRot, $aInt, $aSrv, $aIp6, $aExt, $aExt6, $lRot, $lInt, $lSrv, $lIp6, $lExt, $lExt6) >>"%PFALA%"
echo if (-not $modo) { $modo = "curto" } >>"%PFALA%"
echo Add-Type -AssemblyName System.Speech >>"%PFALA%"
echo $voz = New-Object System.Speech.Synthesis.SpeechSynthesizer >>"%PFALA%"
echo foreach ($v in $voz.GetInstalledVoices()) { if ($v.VoiceInfo.Culture.Name -eq "pt-BR") { try { $voz.SelectVoice($v.VoiceInfo.Name) } catch {} } } >>"%PFALA%"
echo $ci = [System.Globalization.CultureInfo]::InvariantCulture >>"%PFALA%"
echo $ESC = @("EXCELENTE","BOM","ACEITAVEL","RUIM","REPROVADO","PROBLEMA DETECTADO","PROBLEMA GRAVE") >>"%PFALA%"
echo function NotaMed($v) { if ($v -lt 0) { return -1 }; if ($v -le 50) { return 0 }; if ($v -le 100) { return 1 }; if ($v -le 150) { return 2 }; if ($v -le 200) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaMax($v) { if ($v -lt 0) { return -1 }; if ($v -le 150) { return 0 }; if ($v -le 300) { return 1 }; if ($v -le 600) { return 2 }; if ($v -le 1000) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaJit($v) { if ($v -lt 0) { return -1 }; if ($v -le 20) { return 0 }; if ($v -le 50) { return 1 }; if ($v -le 100) { return 2 }; if ($v -le 200) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaPer($p) { if ($p -le 2) { return 0 }; if ($p -le 5) { return 1 }; return 2 } >>"%PFALA%"
echo $alvos = @("ping_modem.txt","ping_internet.txt","ping_servidor.txt","ping_ipv6.txt","ping_extra.txt","ping_extra6.txt") >>"%PFALA%"
echo $nomes = @("roteador","internet","servidor","IPv6","extra IPv4","extra IPv6") >>"%PFALA%"
echo $ends  = @($aRot, $aInt, $aSrv, $aIp6, $aExt, $aExt6) >>"%PFALA%"
echo $limites = @([int]$lRot, [int]$lInt, [int]$lSrv, [int]$lIp6, [int]$lExt, [int]$lExt6) >>"%PFALA%"
echo for ($j = 0; $j -lt 6; $j = $j + 1) { if ($limites[$j] -le 0) { $limites[$j] = 120 }; if (-not $ends[$j]) { $ends[$j] = "-" } } >>"%PFALA%"
echo $toA = @(0,0,0,0,0,0); $envA = @(0,0,0,0,0,0); $respA = @(0,0,0,0,0,0); $hiA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $rajA = @(0,0,0,0,0,0); $rajGA = @(0,0,0,0,0,0); $rajMaxA = @(0,0,0,0,0,0); $altA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $dnsA = @(0,0,0,0,0,0); $pctA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $pminA = @(-1,-1,-1,-1,-1,-1); $pmedA = @(-1,-1,-1,-1,-1,-1); $pmaxA = @(-1,-1,-1,-1,-1,-1); $jitA = @(-1,-1,-1,-1,-1,-1) >>"%PFALA%"
echo $pmedianA = @(-1,-1,-1,-1,-1,-1) >>"%PFALA%"
echo $evA = @(0,0,0,0,0,0); $clsA = @("","","","","",""); $pesoA = @("-","-","-","-","-","-") >>"%PFALA%"
echo $semIpv6 = $false >>"%PFALA%"
echo for ($i = 0; $i -lt 6; $i = $i + 1) { >>"%PFALA%"
echo $arq = Join-Path $pasta $alvos[$i] >>"%PFALA%"
echo $to = 0; $hi = 0; $env = 0; $resp = 0; $dns = 0; $seq = 0; $raj = 0; $rajG = 0; $rajMax = 0; $alt = 0; $lastLoss = -99 >>"%PFALA%"
echo $lat = New-Object System.Collections.ArrayList >>"%PFALA%"
echo if (Test-Path $arq) { >>"%PFALA%"
echo foreach ($linha in (Get-Content $arq)) { >>"%PFALA%"
echo $txt = [string]$linha >>"%PFALA%"
echo $perdeu = $false >>"%PFALA%"
echo if ($txt -match "(?i)(encontrar o host|find host)") { $dns = $dns + 1; $perdeu = $true } >>"%PFALA%"
echo elseif ($txt -match "(?i)(esgotad|timed out|inacess|unreachable|falha ger|general fail|transmit fail)") { $perdeu = $true } >>"%PFALA%"
echo elseif ($txt -match "(?i)[=]\s*([0-9]+)\s*ms") { $ms = [int]$Matches[1]; $env = $env + 1; $resp = $resp + 1; $seq = 0; [void]$lat.Add($ms); if ($ms -ge $limites[$i]) { $hi = $hi + 1 } } >>"%PFALA%"
echo if ($perdeu) { $to = $to + 1; $env = $env + 1; $seq = $seq + 1; if ($seq -eq 1) { $raj = $raj + 1; if ($lastLoss -gt 0 -and ($env - $lastLoss) -le 3) { $alt = $alt + 1 } }; if ($seq -eq 2) { $rajG = $rajG + 1 }; if ($seq -gt $rajMax) { $rajMax = $seq }; $lastLoss = $env } >>"%PFALA%"
echo } >>"%PFALA%"
echo } >>"%PFALA%"
echo $pct = 0; if ($env -gt 0) { $pct = [math]::Round(($to / $env) * 100, 1) } >>"%PFALA%"
echo if ($env -gt 0) { $pesoA[$i] = ([math]::Round(100.0 / $env, 1)).ToString($ci) } >>"%PFALA%"
echo if ($resp -gt 0) { $st = $lat ^| Measure-Object -Minimum -Maximum -Average; $pminA[$i] = [int]$st.Minimum; $pmaxA[$i] = [int]$st.Maximum; $pmedA[$i] = [math]::Round($st.Average); $jitA[$i] = $pmaxA[$i] - $pminA[$i]; $ord = $lat ^| Sort-Object; $n = $ord.Count; if ($n %% 2 -eq 1) { $pmedianA[$i] = [int]$ord[[math]::Floor($n/2)] } else { $pmedianA[$i] = [int][math]::Round(($ord[$n/2 - 1] + $ord[$n/2]) / 2) } } >>"%PFALA%"
echo $toA[$i] = $to; $envA[$i] = $env; $respA[$i] = $resp; $hiA[$i] = $hi; $rajA[$i] = $raj; $rajGA[$i] = $rajG; $rajMaxA[$i] = $rajMax; $altA[$i] = $alt; $dnsA[$i] = $dns; $pctA[$i] = $pct >>"%PFALA%"
echo if ($i -eq 3 -and $temIpv6 -ne "1") { $clsA[$i] = "SEM IPV6 NA REDE"; $semIpv6 = $true; $evA[$i] = -1 } >>"%PFALA%"
echo elseif ($env -eq 0) { $clsA[$i] = "SEM DADOS"; $evA[$i] = -1 } >>"%PFALA%"
echo elseif (($i -eq 3 -or $i -eq 5) -and $resp -eq 0 -and $dns -gt 0) { $clsA[$i] = "ALVO SEM IPV6"; $evA[$i] = -1 } >>"%PFALA%"
echo elseif ($i -eq 3 -and $resp -eq 0) { $clsA[$i] = "SEM IPV6 NA REDE"; $semIpv6 = $true; $evA[$i] = -1 } >>"%PFALA%"
echo elseif ($to -eq 0) { $evA[$i] = 0 } >>"%PFALA%"
echo elseif ($rajMax -ge 3 -or ($rajMax -eq 2 -and ($env -lt 600 -or $pct -ge 1 -or $rajG -ge 2)) -or ($alt -ge 3 -and ($pct -ge 2 -or $alt -ge 6))) { $evA[$i] = 3 } >>"%PFALA%"
echo elseif ($rajMax -eq 2 -or $alt -ge 3) { $evA[$i] = 2 } >>"%PFALA%"
echo else { $evA[$i] = 1 } >>"%PFALA%"
echo } >>"%PFALA%"
echo $nForte = 0; $nMod = 0; $nIsoPerda = 0; $nExtTest = 0 >>"%PFALA%"
echo for ($j = 1; $j -le 5; $j = $j + 1) { if ($evA[$j] -ge 0) { $nExtTest = $nExtTest + 1; if ($evA[$j] -eq 3) { $nForte = $nForte + 1 } elseif ($evA[$j] -eq 2) { $nMod = $nMod + 1 } elseif ($evA[$j] -eq 1 -and $toA[$j] -gt 0) { $nIsoPerda = $nIsoPerda + 1 } } } >>"%PFALA%"
echo $consenso = (($nForte + $nMod) -ge 2) >>"%PFALA%"
echo $tg = @() >>"%PFALA%"
echo $tg += "LAUDO DE REDE" >>"%PFALA%"
echo $tg += "Tecnico: " + $tec >>"%PFALA%"
echo $tg += "Cliente: " + $cli >>"%PFALA%"
echo $tg += "Conexao: " + $conx >>"%PFALA%"
echo $tg += "PC: " + $env:COMPUTERNAME + "   Data: " + (Get-Date -Format "dd/MM/yyyy HH:mm") >>"%PFALA%"
echo $tg += "Duracao: " + $mins + " minutos" >>"%PFALA%"
echo $tg += "" >>"%PFALA%"
echo $rel = @() >>"%PFALA%"
echo $rel += "=========================================================" >>"%PFALA%"
echo $rel += "        LAUDO DE REDE - VEREDITO TECNICO" >>"%PFALA%"
echo $rel += "=========================================================" >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "TECNICO .........: " + $tec >>"%PFALA%"
echo $rel += "CLIENTE .........: " + $cli >>"%PFALA%"
echo $rel += "CONEXAO USADA ...: " + $conx >>"%PFALA%"
echo $rel += "DATA / HORA .....: " + (Get-Date -Format "dd/MM/yyyy HH:mm:ss") >>"%PFALA%"
echo $rel += "COMPUTADOR ......: " + $env:COMPUTERNAME >>"%PFALA%"
echo $rel += "USUARIO .........: " + $env:USERNAME >>"%PFALA%"
echo $rel += "DURACAO DO TESTE : " + $mins + " minutos" >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "RESULTADO POR ALVO" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $totTo = 0; $totHi = 0; $problemas = @(); $atencoes = @(); $suspeitos = @(); $reprovados = @(); $ruins = @(); $detalhe = "" >>"%PFALA%"
echo $linhasCsv = @("alvo;enviados;perdidos;perda_percentual;ping_min;ping_medio;ping_max;picos;classificacao") >>"%PFALA%"
echo for ($i = 0; $i -lt 6; $i = $i + 1) { >>"%PFALA%"
echo if ($i -ge 4 -and $envA[$i] -eq 0) { continue } >>"%PFALA%"
echo $to = $toA[$i]; $env = $envA[$i]; $resp = $respA[$i]; $hi = $hiA[$i]; $raj = $rajA[$i]; $rajG = $rajGA[$i]; $rajMax = $rajMaxA[$i]; $alt = $altA[$i]; $pct = $pctA[$i]; $peso = $pesoA[$i] >>"%PFALA%"
echo $pctTxt = $pct.ToString($ci) >>"%PFALA%"
echo $pmin = "-"; $pmed = "-"; $pmax = "-"; $jit = "-" >>"%PFALA%"
echo if ($resp -gt 0) { $pmin = $pminA[$i]; $pmed = $pmedA[$i]; $pmax = $pmaxA[$i]; $jit = $jitA[$i] } >>"%PFALA%"
echo $obs = "" >>"%PFALA%"
echo $classe = $clsA[$i] >>"%PFALA%"
echo $notaTxt = "" >>"%PFALA%"
echo $puxou = "" >>"%PFALA%"
echo if ($evA[$i] -ge 0) { >>"%PFALA%"
echo $ev = $evA[$i] >>"%PFALA%"
echo if ($ev -eq 3) { >>"%PFALA%"
echo if ($rajMax -ge 3) { $nRaj = 6 } else { $nRaj = 5 } >>"%PFALA%"
echo $partes = @() >>"%PFALA%"
echo if ($rajMax -ge 2) { $partes += "maior rajada de " + $rajMax + " consecutivos, " + $rajG + " evento(s) de rajada" } >>"%PFALA%"
echo if ($alt -ge 3) { $partes += "padrao alternado (" + $alt + " perdas em cadencia curta)" } >>"%PFALA%"
echo $obs = ($partes -join " e ") + " em " + $env + " pacotes (" + $pctTxt + " por cento) - perda continua real, nao e limite de ICMP" >>"%PFALA%"
echo } >>"%PFALA%"
echo elseif ($ev -eq 2) { >>"%PFALA%"
echo if ($consenso) { $nRaj = 5; $obs = "evidencia moderada (evento unico de 2 consecutivas ou alternancia leve) corroborada por perda em outros destinos" } >>"%PFALA%"
echo else { >>"%PFALA%"
echo $nRaj = 3 >>"%PFALA%"
echo if ($rajMax -eq 2) { $obs = "indicio fraco: um unico evento de 2 perdas consecutivas em " + $env + " pacotes (" + $pctTxt + " por cento), sem eco nos demais destinos - monitorar e repetir com teste mais longo" } >>"%PFALA%"
echo else { $obs = "indicio fraco: alternancia leve de perdas (" + $alt + " pares proximos), sem eco nos demais destinos - monitorar e repetir com teste mais longo" } >>"%PFALA%"
echo } >>"%PFALA%"
echo } >>"%PFALA%"
echo elseif ($ev -eq 1) { >>"%PFALA%"
echo $nRaj = NotaPer $pct >>"%PFALA%"
echo if ($pct -le 2) { $obs = "perda isolada (provavel limitacao de ICMP ou evento momentaneo) - " + $to + " de " + $env + " pacotes, 1 pacote = " + $peso + " por cento" } >>"%PFALA%"
echo elseif ($pct -le 5) { $obs = [string]$to + " perdas isoladas em " + $env + " pacotes, nenhuma rajada - compativel com limitacao de ICMP; sem evidencia de queda de enlace" } >>"%PFALA%"
echo else { $obs = "volume alto de perdas isoladas (" + $to + " de " + $env + "), porem nenhuma rajada - correlacionar com jitter e repetir com teste mais longo" } >>"%PFALA%"
echo } >>"%PFALA%"
echo else { $nRaj = 0 } >>"%PFALA%"
echo $nMed = NotaMed ([int]$pmedA[$i]) >>"%PFALA%"
echo $nMax = NotaMax ([int]$pmaxA[$i]) >>"%PFALA%"
echo $nJit = NotaJit ([int]$jitA[$i]) >>"%PFALA%"
echo $nPer = NotaPer $pct >>"%PFALA%"
echo $pior = $nRaj >>"%PFALA%"
echo $quem = "rajada/perda continua" >>"%PFALA%"
echo if ($nPer -gt $pior) { $pior = $nPer; $quem = "perda de pacotes" } >>"%PFALA%"
echo if ($nMed -gt $pior) { $pior = $nMed; $quem = "ping medio " + $pmedA[$i] + " ms" } >>"%PFALA%"
echo $maxObs = "" >>"%PFALA%"
echo $nMaxEf = $nMax >>"%PFALA%"
echo $corrobora = (($nJit -ge 1) -or ($hi -ge 2) -or ($nMed -ge 2) -or ($to -gt 0) -or ($rajMax -ge 2)) >>"%PFALA%"
echo if ($nMax -ge 3 -and -not $corrobora) { >>"%PFALA%"
echo $nMaxEf = 2 >>"%PFALA%"
echo if ($nMaxEf -gt $pior) { $pior = $nMaxEf; $quem = "pico isolado de " + $pmaxA[$i] + " ms (nao corroborado - ver observacao)" } >>"%PFALA%"
echo $maxObs = "pico unico de " + $pmaxA[$i] + " ms sem corroboracao (jitter baixo, 1 unico pico, sem perda) - tratado como evento isolado, nao reprova o enlace" >>"%PFALA%"
echo } >>"%PFALA%"
echo else { >>"%PFALA%"
echo if ($nMax -gt $pior) { $pior = $nMax; $quem = "ping maximo " + $pmaxA[$i] + " ms" } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($nJit -gt $pior) { $pior = $nJit; $quem = "jitter " + $jitA[$i] + " ms" } >>"%PFALA%"
echo $classe = $ESC[$pior] >>"%PFALA%"
echo if ($pior -eq 0) { $puxou = "" } else { $puxou = " (puxado por: " + $quem + ")" } >>"%PFALA%"
echo $maxLbl = $ESC[[math]::Max($nMax,0)] >>"%PFALA%"
echo if ($maxObs -ne "") { $maxLbl = $ESC[[math]::Max($nMaxEf,0)] + "* (pico " + $ESC[[math]::Max($nMax,0)] + " isolado)" } >>"%PFALA%"
echo $notaTxt = "perda " + $ESC[$nPer] + " / medio " + $ESC[[math]::Max($nMed,0)] + " / maximo " + $maxLbl + " / jitter " + $ESC[[math]::Max($nJit,0)] + " / rajada " + $ESC[$nRaj] >>"%PFALA%"
echo if ($maxObs -ne "") { if ($obs -eq "") { $obs = $maxObs } else { $obs = $obs + ". " + $maxObs } } >>"%PFALA%"
echo if ($pior -ge 3 -and $obs -eq "") { $obs = "sem perda relevante, porem a latencia reprova: " + $quem } >>"%PFALA%"
echo if ($classe -like "PROBLEMA*" -and $env -gt 0 -and $env -lt 300) { $obs = $obs + ". Amostra de " + $env + " pacotes e pequena - confirmar com teste de 5 minutos ou mais" } >>"%PFALA%"
echo $clsA[$i] = $classe >>"%PFALA%"
echo } >>"%PFALA%"
echo $ana = "" >>"%PFALA%"
echo if ($classe -eq "SEM IPV6 NA REDE") { $ana = "A rede nao entrega IPv6. Nao e falha do link." } >>"%PFALA%"
echo elseif ($classe -eq "ALVO SEM IPV6") { $ana = "O destino nao tem registro AAAA. Nao e falha do link." } >>"%PFALA%"
echo elseif ($classe -eq "SEM DADOS") { $ana = "Aba nao utilizada neste teste." } >>"%PFALA%"
echo elseif ($classe -like "PROBLEMA*" -and $i -eq 0) { $ana = "Perda continua no proprio gateway - falha fisica no trecho local (Wi-Fi, cabo, placa ou roteador). " + $obs } >>"%PFALA%"
echo elseif ($classe -like "PROBLEMA*") { $ana = "Perda continua confirmada no caminho externo. " + $obs } >>"%PFALA%"
echo elseif ($classe -eq "RUIM" -or $classe -eq "REPROVADO") { $ana = "Reprovado por latencia" + $puxou + ". " + $obs } >>"%PFALA%"
echo elseif ($classe -eq "BOM" -or $classe -eq "ACEITAVEL") { $ana = "Aprovado com ressalva" + $puxou + ". " + $obs } >>"%PFALA%"
echo elseif ($to -gt 0) { $ana = $obs } >>"%PFALA%"
echo elseif ($hi -gt 0) { $ana = "Sem perda, porem com picos de latencia (jitter). Pode travar voz e jogo." } >>"%PFALA%"
echo else { $ana = "Estavel. Latencia dentro do esperado, sem perda e sem picos." } >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "[" + $nomes[$i].ToUpper() + "]   alvo: " + $ends[$i] >>"%PFALA%"
echo $rel += "   Pacotes enviados ...: " + $env >>"%PFALA%"
echo $rel += "   Respondidos ........: " + $resp >>"%PFALA%"
echo $rel += "   Perdidos ...........: " + $to + "   (" + $pctTxt + " %%)" >>"%PFALA%"
echo $rel += "   Peso de 1 pacote ...: " + $peso + " %% da amostra" >>"%PFALA%"
echo $rel += "   Ping minimo ........: " + $pmin + " ms" >>"%PFALA%"
echo $rel += "   Ping medio .........: " + $pmed + " ms" >>"%PFALA%"
echo $rel += "   Ping mediana .......: " + $(if ($pmedianA[$i] -ge 0) { [string]$pmedianA[$i] + " ms - valor central, ignora picos" } else { "-" }) >>"%PFALA%"
echo $rel += "   Ping maximo ........: " + $pmax + " ms" >>"%PFALA%"
echo $rel += "   Variacao (max-min) .: " + $jit + " ms" >>"%PFALA%"
echo $rel += "   Picos acima de " + $limites[$i] + " ms: " + $hi + $(if ($hi -eq 1 -and $pmaxA[$i] -gt (2*$limites[$i])) { "  (1 pico isolado - ver observacao)" } else { "" }) >>"%PFALA%"
echo $rel += "   Perda em rajada ....: " + $rajG + " evento(s) de 2+ / maior rajada " + $rajMax + " pacotes" >>"%PFALA%"
echo $rel += "   Perda alternada ....: " + $alt + " perdas em cadencia curta" >>"%PFALA%"
echo $rel += "   NOTAS ..............: " + $notaTxt >>"%PFALA%"
echo $rel += "   CLASSIFICACAO ......: " + $classe + $puxou >>"%PFALA%"
echo $rel += "   Analise ............: " + $ana >>"%PFALA%"
echo $linhasCsv += ($nomes[$i] + ";" + $env + ";" + $to + ";" + $pctTxt + ";" + $pmin + ";" + $pmed + ";" + $pmax + ";" + $hi + ";" + $classe) >>"%PFALA%"
echo $tg += $nomes[$i] + " (" + $ends[$i] + ")" >>"%PFALA%"
echo $tg += "   perda " + $pctTxt + " %% - min " + $pmin + " / med " + $pmed + " / max " + $pmax + " ms - picos " + $hi >>"%PFALA%"
echo $tg += "   " + $classe + $puxou >>"%PFALA%"
echo $detalhe = $detalhe + $nomes[$i] + ": perda " + $pctTxt + " por cento, minimo " + $pmin + " ms, media " + $pmed + " ms, maximo " + $pmax + " ms, " + $hi + " picos, " + $classe + ". " >>"%PFALA%"
echo if ($classe -eq "SEM DADOS") { continue } >>"%PFALA%"
echo if ($classe -eq "ALVO SEM IPV6") { continue } >>"%PFALA%"
echo if ($classe -eq "SEM IPV6 NA REDE" -and $ipv6Conta -ne "1") { continue } >>"%PFALA%"
echo $totTo = $totTo + $to >>"%PFALA%"
echo $totHi = $totHi + $hi >>"%PFALA%"
echo if ($classe -like "PROBLEMA*") { $tag = "rajada de " + $rajMax; if ($rajMax -lt 2) { $tag = "padrao alternado" }; $problemas += ($nomes[$i] + " (" + $tag + ")") } >>"%PFALA%"
echo elseif ($classe -eq "REPROVADO") { $reprovados += ($nomes[$i] + $puxou) } >>"%PFALA%"
echo elseif ($classe -eq "RUIM") { $ruins += ($nomes[$i] + $puxou) } >>"%PFALA%"
echo elseif ($classe -eq "ATENCAO") { $atencoes += $nomes[$i] } >>"%PFALA%"
echo if ($nRaj -eq 3 -and $classe -eq "RUIM") { $suspeitos += $nomes[$i] } >>"%PFALA%"
echo } >>"%PFALA%"
echo Set-Content -Path (Join-Path $pasta "PERDA_PACOTES.csv") -Value $linhasCsv -Encoding UTF8 >>"%PFALA%"
echo $curto = "Teste finalizado. " >>"%PFALA%"
echo if ($conx -match "(?i)^ATENCAO") { $curto = $curto + "Atencao, LAN e Wi-Fi ligados ao mesmo tempo. " } >>"%PFALA%"
echo if ($semIpv6) { $curto = $curto + "Rede sem IPv6. " } >>"%PFALA%"
echo if ($problemas.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Perda continua em " + ($problemas -join ", e ") + ". Falha real detectada." >>"%PFALA%"
echo if ($reprovados.Count -gt 0) { $curto = $curto + " Latencia tambem reprovada em " + ($reprovados -join ", ") + "." } >>"%PFALA%"
echo [console]::beep(400,700); [console]::beep(300,900) >>"%PFALA%"
echo } elseif ($reprovados.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "REPROVADO por latencia em " + ($reprovados -join ", ") + "." >>"%PFALA%"
echo [console]::beep(400,700); [console]::beep(300,900) >>"%PFALA%"
echo } elseif ($ruins.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Latencia ruim em " + ($ruins -join ", ") + "." >>"%PFALA%"
echo [console]::beep(700,400); [console]::beep(600,400) >>"%PFALA%"
echo } elseif ($suspeitos.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Indicio fraco de perda em " + ($suspeitos -join ", ") + " - sem consenso; monitorar." >>"%PFALA%"
echo [console]::beep(1000,300); [console]::beep(800,300) >>"%PFALA%"
echo } elseif ($atencoes.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Sem rajadas, porem volume alto de perdas isoladas em " + ($atencoes -join ", ") + "." >>"%PFALA%"
echo [console]::beep(1000,300); [console]::beep(800,300) >>"%PFALA%"
echo } elseif ($totHi -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Sem perda real, com " + $totHi + " picos de ping." >>"%PFALA%"
echo [console]::beep(1200,250); [console]::beep(1600,250) >>"%PFALA%"
echo } else { >>"%PFALA%"
echo $pioresc = 0 >>"%PFALA%"
echo for ($j = 0; $j -lt 6; $j = $j + 1) { if ($evA[$j] -ge 0) { $k = [array]::IndexOf($ESC, $clsA[$j]); if ($k -gt $pioresc) { $pioresc = $k } } } >>"%PFALA%"
echo if ($pioresc -eq 0) { $curto = $curto + "Tudo excelente. Sem perda real e sem picos." } else { $curto = $curto + "Resultado geral: " + $ESC[$pioresc] + "." } >>"%PFALA%"
echo $refI = 1; if ($envA[1] -eq 0) { $refI = 0 } >>"%PFALA%"
echo $scMed = $pmedA[$refI]; if ($scMed -lt 0) { $scMed = 0 } >>"%PFALA%"
echo $scJit = $jitA[$refI]; if ($scJit -lt 0) { $scJit = 0 } >>"%PFALA%"
echo $scPer = $pctA[$refI] >>"%PFALA%"
echo $compPer = 40 - ($scPer * 6); if ($compPer -lt 0) { $compPer = 0 } >>"%PFALA%"
echo $compLat = 25 - [math]::Max(0, ($scMed - 50)) * 0.125; if ($compLat -lt 0) { $compLat = 0 }; if ($compLat -gt 25) { $compLat = 25 } >>"%PFALA%"
echo $compJit = 20 - [math]::Max(0, ($scJit - 20)) * 0.111; if ($compJit -lt 0) { $compJit = 0 }; if ($compJit -gt 20) { $compJit = 20 } >>"%PFALA%"
echo $compRaj = 15 >>"%PFALA%"
echo if ($rajMaxA[$refI] -ge 3) { $compRaj = 0 } elseif ($rajMaxA[$refI] -eq 2) { $compRaj = 7 } elseif ($toA[$refI] -gt 0) { $compRaj = 12 } >>"%PFALA%"
echo $score = [math]::Round($compPer + $compLat + $compJit + $compRaj) >>"%PFALA%"
echo if ($score -lt 0) { $score = 0 }; if ($score -gt 100) { $score = 100 } >>"%PFALA%"
echo if ($pioresc -ge 4) { if ($score -gt 40) { $score = 40 } } elseif ($pioresc -eq 3) { if ($score -gt 60) { $score = 60 } } elseif ($pioresc -eq 2) { if ($score -gt 75) { $score = 75 } } >>"%PFALA%"
echo if ($score -ge 90) { $scLbl = "EXCELENTE" } elseif ($score -ge 75) { $scLbl = "BOM" } elseif ($score -ge 60) { $scLbl = "ACEITAVEL" } elseif ($score -ge 40) { $scLbl = "RUIM" } else { $scLbl = "CRITICO" } >>"%PFALA%"
echo [console]::beep(1500,150); [console]::beep(2000,350) >>"%PFALA%"
echo } >>"%PFALA%"
echo $perdaLanB = $pctA[0] >>"%PFALA%"
echo $perdaForaB = [math]::Max([math]::Max([math]::Max($pctA[1], $pctA[2]), [math]::Max($pctA[3], $pctA[4])), $pctA[5]) >>"%PFALA%"
echo $perdaLan = 0; if ($clsA[0] -like "PROBLEMA*") { $perdaLan = $pctA[0] } >>"%PFALA%"
echo $perdaFora = 0 >>"%PFALA%"
echo for ($j = 1; $j -le 5; $j = $j + 1) { if ($clsA[$j] -like "PROBLEMA*" -and $pctA[$j] -gt $perdaFora) { $perdaFora = $pctA[$j] } } >>"%PFALA%"
echo $medNet = $pmedA[1]; $jitNet = $jitA[1]; $jitLan = $jitA[0] >>"%PFALA%"
echo $ehWifi = ($conx -match '(?i)Wi-Fi') >>"%PFALA%"
echo $eh24 = ($conx -match '2\.4') >>"%PFALA%"
echo $duplo = ($conx -match '(?i)^ATENCAO') >>"%PFALA%"
echo $gwProb = ($clsA[0] -like 'PROBLEMA*') >>"%PFALA%"
echo $netProb = ($clsA[1] -like 'PROBLEMA*') >>"%PFALA%"
echo $srvProb = ($clsA[2] -like 'PROBLEMA*') >>"%PFALA%"
echo $ext4Prob = ($clsA[4] -like 'PROBLEMA*') >>"%PFALA%"
echo $v6Prob = (($clsA[3] -like 'PROBLEMA*') -or ($clsA[5] -like 'PROBLEMA*')) >>"%PFALA%"
echo $isoExt = ($nIsoPerda -gt 0) >>"%PFALA%"
echo $atenc = ($atencoes.Count -gt 0) >>"%PFALA%"
echo if ($gwProb) { $cen = 'LOCAL' } >>"%PFALA%"
echo elseif (($netProb -or $ext4Prob) -and $srvProb) { $cen = 'ACESSO' } >>"%PFALA%"
echo elseif (($netProb -or $ext4Prob) -and $clsA[2] -eq 'EXCELENTE') { $cen = 'ROTA' } >>"%PFALA%"
echo elseif ($netProb -or $ext4Prob) { $cen = 'WANGEN' } >>"%PFALA%"
echo elseif ($srvProb) { $cen = 'SRV' } >>"%PFALA%"
echo elseif ($v6Prob) { $cen = 'IPV6ROTA' } >>"%PFALA%"
echo elseif ($suspeitos.Count -gt 0) { $cen = 'SUSPEITA' } >>"%PFALA%"
echo elseif ($reprovados.Count -gt 0 -or $ruins.Count -gt 0) { $cen = 'LATREPROVA' } >>"%PFALA%"
echo elseif ($totHi -gt 0) { $cen = 'JITTER' } >>"%PFALA%"
echo elseif ($isoExt -or $atenc) { $cen = 'ISOLADAS' } >>"%PFALA%"
echo elseif ($medNet -ge 100) { $cen = 'LATENCIA' } >>"%PFALA%"
echo else { $cen = 'OK' } >>"%PFALA%"
echo $diagT = @() >>"%PFALA%"
echo if ($cen -eq 'LOCAL') { >>"%PFALA%"
echo $diagT += "Perda continua detectada no proprio gateway - maior rajada de " + $rajMaxA[0] + " pacotes." >>"%PFALA%"
echo $diagT += "Falha no trecho estacao-roteador: Wi-Fi, cabo, placa de rede, porta ou o proprio roteador." >>"%PFALA%"
echo $diagT += "Com o primeiro salto perdendo, nenhuma medicao externa e conclusiva - corrigir o trecho local e repetir." >>"%PFALA%"
echo if ($ehWifi) { $diagT += "A conexao do teste foi via Wi-Fi, o meio mais provavel da falha." } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'ACESSO') { >>"%PFALA%"
echo $diagT += "Gateway integro (sem perda continua), porem o marco interno e a internet apresentaram perda real." >>"%PFALA%"
echo $diagT += "A falha esta no trecho de ACESSO, entre o roteador do cliente e a borda da operadora." >>"%PFALA%"
echo $diagT += "Esse segmento inclui ONU ou mini ONU, conversor de midia, switch, enlace optico e CGNAT." >>"%PFALA%"
echo $diagT += "Perda apos o gateway NAO caracteriza defeito no roteador nem nos equipamentos do cliente." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'ROTA') { >>"%PFALA%"
echo $diagT += "Gateway e marco interno da operadora integros; a perda continua aparece somente em destinos externos." >>"%PFALA%"
echo $diagT += "A evidencia aponta para alem da borda da operadora: transito, peering ou o proprio destino." >>"%PFALA%"
echo $diagT += "Sem qualquer indicio de falha no equipamento do cliente." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'WANGEN') { >>"%PFALA%"
echo $diagT += "Gateway integro; a perda continua ocorre do roteador para fora, sem marco intermediario valido para separar acesso de rota." >>"%PFALA%"
echo $diagT += "Segmento suspeito: ONU ou mini ONU, conversor de midia, CGNAT e borda da operadora - nao o equipamento do cliente." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'SRV') { >>"%PFALA%"
echo $diagT += "Perda continua restrita ao marco interno; gateway e internet integros." >>"%PFALA%"
echo $diagT += "Falha limitada ao caminho ate esse servidor, ou ao proprio servidor - o enlace do cliente esta saudavel." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'IPV6ROTA') { >>"%PFALA%"
echo $diagT += "Perda continua apenas nos alvos IPv6, com todos os alvos IPv4 integros." >>"%PFALA%"
echo $diagT += "O enlace fisico esta saudavel; a falha e da pilha ou da rota IPv6 da operadora." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'SUSPEITA') { >>"%PFALA%"
echo $diagT += "Indicio fraco de perda real em: " + ($suspeitos -join ", ") + "." >>"%PFALA%"
echo $diagT += "O padrao observado (evento unico de perdas consecutivas ou alternancia leve) nao encontrou eco nos demais destinos." >>"%PFALA%"
echo $diagT += "Sem consenso entre alvos e com o gateway integro, nao ha base para condenar a rede - repetir com teste mais longo antes de qualquer acao." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'LATREPROVA') { >>"%PFALA%"
echo $diagT += "Sem perda continua, porem a LATENCIA reprova o enlace - a nota final e definida pelo pior criterio, nao apenas pela perda." >>"%PFALA%"
echo if ($reprovados.Count -gt 0) { $diagT += "REPROVADO em: " + ($reprovados -join ", ") + "." } >>"%PFALA%"
echo if ($ruins.Count -gt 0) { $diagT += "Latencia RUIM em: " + ($ruins -join ", ") + "." } >>"%PFALA%"
echo if ($pmedA[0] -ge 0 -and (NotaMed ([int]$pmedA[0])) -ge 3) { $diagT += "O proprio gateway ja responde lento - degradacao comeca no trecho LOCAL (Wi-Fi saturado, cabo ruim ou roteador sobrecarregado)." } >>"%PFALA%"
echo else { $diagT += "O gateway responde rapido; a degradacao nasce FORA da LAN - buffer cheio no acesso, congestionamento no PON/upstream ou rota longa." } >>"%PFALA%"
echo $diagT += "Perda baixa com latencia alta e o padrao classico de bufferbloat: os pacotes chegam, porem enfileirados - voz e jogo ficam inviaveis mesmo com a velocidade contratada intacta." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'JITTER') { >>"%PFALA%"
echo $diagT += "Nenhuma perda continua; ha picos de latencia (jitter) acima do limite configurado." >>"%PFALA%"
echo $diagT += "Sintoma de meio compartilhado disputado ou de fila em algum salto - afeta voz e jogo, nao afeta download." >>"%PFALA%"
echo if ($isoExt) { $diagT += "As perdas isoladas observadas sao compativeis com limitacao de ICMP e nao caracterizam queda." } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'ISOLADAS') { >>"%PFALA%"
echo $diagT += "O enlace local permanece estavel. Foram observadas perdas isoladas em destinos externos," >>"%PFALA%"
echo $diagT += "compativeis com limitacao de respostas ICMP ou eventos transitorios da rede." >>"%PFALA%"
echo $diagT += "Nao ha evidencias suficientes para concluir falha no equipamento do cliente." >>"%PFALA%"
echo if ($atenc) { $diagT += "Volume alto de perdas isoladas em: " + ($atencoes -join ', ') + " - repetir com teste mais longo e correlacionar com jitter." } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'LATENCIA') { >>"%PFALA%"
echo $diagT += "Sem perda e sem jitter relevante, porem com latencia media alta." >>"%PFALA%"
echo $diagT += "Costuma indicar rota longa, PoP distante ou saturacao constante de upstream - nao e defeito do equipamento do cliente." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'OK') { >>"%PFALA%"
echo $diagT += "Entrega integra em todos os alvos: sem perda continua, sem rajadas e sem picos de latencia." >>"%PFALA%"
echo $diagT += "Enlace dentro do padrao para trafego de tempo real." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($semIpv6) { $diagT += "OBS: a rede nao entrega IPv6." } >>"%PFALA%"
echo $pts = 0; $sinais = @() >>"%PFALA%"
echo if ($gwProb) { $pts = $pts + 3; $sinais += "perda continua no proprio gateway (falha local evidente)" } >>"%PFALA%"
echo if ($nForte -ge 1) { $pts = $pts + (2 * $nForte); $sinais += [string]$nForte + " destino(s) com evidencia forte (rajada ou alternancia intensa)" } >>"%PFALA%"
echo if ($nMod -ge 1) { $pts = $pts + $nMod; $sinais += [string]$nMod + " destino(s) com evidencia moderada" } >>"%PFALA%"
echo if ($consenso) { $pts = $pts + 1; $sinais += "consenso entre multiplos destinos" } >>"%PFALA%"
echo if ($totHi -gt 0) { $pts = $pts + 1; $sinais += "picos de latencia corroboram" } >>"%PFALA%"
echo $amostraRef = $envA[1]; if ($amostraRef -eq 0) { $amostraRef = $envA[0] } >>"%PFALA%"
echo if ($amostraRef -ge 600) { $pts = $pts + 1; $sinais += "amostra grande (" + $amostraRef + " pacotes)" } >>"%PFALA%"
echo if ($amostraRef -gt 0 -and $amostraRef -lt 300) { $pts = $pts - 1; $sinais += "amostra pequena (" + $amostraRef + " pacotes) reduz a certeza" } >>"%PFALA%"
echo if ($problemas.Count -gt 0) { >>"%PFALA%"
echo if ($pts -ge 5) { $conf = "ALTA" } elseif ($pts -ge 3) { $conf = "MEDIA" } else { $conf = "BAIXA" } >>"%PFALA%"
echo $confTxt = "confianca de que EXISTE falha real" >>"%PFALA%"
echo } elseif ($suspeitos.Count -gt 0) { >>"%PFALA%"
echo $conf = "BAIXA"; $confTxt = "confianca de que existe falha real" >>"%PFALA%"
echo $sinais += "apenas indicios fracos, sem consenso entre destinos" >>"%PFALA%"
echo } else { >>"%PFALA%"
echo if ($amostraRef -ge 300 -and $nMod -eq 0 -and $nForte -eq 0) { $conf = "ALTA" } else { $conf = "MEDIA" } >>"%PFALA%"
echo $confTxt = "confianca de que NAO ha falha real" >>"%PFALA%"
echo if ($clsA[0] -eq "EXCELENTE") { $sinais += "gateway integro isola o trecho local" } >>"%PFALA%"
echo if ($nIsoPerda -gt 0) { $sinais += "perdas apenas isoladas (padrao de limite de ICMP)" } >>"%PFALA%"
echo if ($amostraRef -ge 300) { $sinais += "amostra suficiente (" + $amostraRef + " pacotes)" } >>"%PFALA%"
echo } >>"%PFALA%"
echo $dg = @() >>"%PFALA%"
echo $dg += "[TECNICO]" >>"%PFALA%"
echo foreach ($x in $diagT) { $dg += $x } >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $dg += "[CONFIANCA DO DIAGNOSTICO]" >>"%PFALA%"
echo $dg += "  Nivel ..: " + $conf + " (" + $confTxt + ")" >>"%PFALA%"
echo foreach ($x in $sinais) { $dg += "  - " + $x } >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $unid = "-"; if ($amostraRef -gt 0) { $unid = ([math]::Round(100.0 / $amostraRef, 2)).ToString($ci) } >>"%PFALA%"
echo $baseLan = $pminA[0]; $baseNet = $pminA[1] >>"%PFALA%"
echo $custo = -1; if ($baseLan -ge 0 -and $baseNet -ge 0) { $custo = $baseNet - $baseLan } >>"%PFALA%"
echo $filaLan = -1; if ($pmedA[0] -ge 0) { $filaLan = $pmedA[0] - $pminA[0] } >>"%PFALA%"
echo $filaNet = -1; if ($pmedA[1] -ge 0) { $filaNet = $pmedA[1] - $pminA[1] } >>"%PFALA%"
echo $jitFora = -1; if ($jitLan -ge 0 -and $jitNet -ge 0) { $jitFora = $jitNet - $jitLan } >>"%PFALA%"
echo $rjMaxG = 0; $rjEvG = 0; $altG = 0; $toExt = 0 >>"%PFALA%"
echo for ($j = 1; $j -le 5; $j = $j + 1) { if ($evA[$j] -ge 0) { if ($rajMaxA[$j] -gt $rjMaxG) { $rjMaxG = $rajMaxA[$j] }; $rjEvG = $rjEvG + $rajGA[$j]; $altG = $altG + $altA[$j]; $toExt = $toExt + $toA[$j] } } >>"%PFALA%"
echo $padrao = "sem perda" >>"%PFALA%"
echo if ($rjMaxG -ge 2) { $padrao = "EM RAJADA - maior rajada " + $rjMaxG + " pacotes, " + $rjEvG + " evento(s) de 2+ consecutivos" } >>"%PFALA%"
echo elseif ($altG -ge 3) { $padrao = "ALTERNADA - " + $altG + " perdas em cadencia curta (persistente sem rajada)" } >>"%PFALA%"
echo elseif ($toExt -gt 0) { $padrao = "ISOLADA - espalhadas, compativel com limite de ICMP" } >>"%PFALA%"
echo $pLanTxt = ([double]$perdaLanB).ToString($ci) >>"%PFALA%"
echo $pForaTxt = ([double]$perdaForaB).ToString($ci) >>"%PFALA%"
echo $dg += "[EVIDENCIA TECNICA]" >>"%PFALA%"
echo $dg += "  Amostra por alvo .......: " + $amostraRef + " pacotes - 1 pacote vale " + $unid + " por cento" >>"%PFALA%"
echo $dg += "  RTT base LAN ...........: " + $baseLan + " ms - piso do meio local" >>"%PFALA%"
echo $dg += "  RTT base WAN ...........: " + $baseNet + " ms - piso do enlace de acesso" >>"%PFALA%"
echo $dg += "  Custo do enlace ........: " + $custo + " ms - base WAN menos base LAN" >>"%PFALA%"
echo $dg += "  Atraso de fila LAN .....: " + $filaLan + " ms - media menos minimo" >>"%PFALA%"
echo $dg += "  Atraso de fila WAN .....: " + $filaNet + " ms" >>"%PFALA%"
echo $dg += "  Jitter LAN .............: " + $jitLan + " ms" >>"%PFALA%"
echo $dg += "  Jitter WAN .............: " + $jitNet + " ms" >>"%PFALA%"
echo $dg += "  Jitter gerado fora da LAN: " + $jitFora + " ms" >>"%PFALA%"
echo $dg += "  Perda LAN ..............: " + $pLanTxt + " por cento" >>"%PFALA%"
echo $dg += "  Perda WAN ..............: " + $pForaTxt + " por cento" >>"%PFALA%"
echo $dg += "  Padrao da perda ........: " + $padrao >>"%PFALA%"
echo $dg += "  Consenso de destinos ...: " + ($nForte + $nMod) + " de " + $nExtTest + " externos com evidencia de perda real" >>"%PFALA%"
echo if ($perdaLan -gt 0 -or $perdaFora -gt 0) { $sig = "SIM - perda continua confirmada (rajada ou alternancia com contexto)" } else { $sig = "NAO - somente perdas isoladas ou indicios fracos; desconsideradas no veredito" } >>"%PFALA%"
echo $dg += "  Perda significativa ....: " + $sig >>"%PFALA%"
echo $dg += "  Picos acima do limite ..: " + $totHi >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $pMax = [math]::Max([double]$perdaLan, [double]$perdaFora) >>"%PFALA%"
echo $jMax = [math]::Max($jitLan, $jitNet) >>"%PFALA%"
echo $rtt = $medNet >>"%PFALA%"
echo if ($pMax -le 1 -and $jMax -le 30 -and $rtt -ge 0 -and $rtt -le 150) { $sVoip = "OK" } elseif ($pMax -le 3 -and $jMax -le 50) { $sVoip = "MARGINAL" } else { $sVoip = "INVIAVEL" } >>"%PFALA%"
echo if ($pMax -le 0.5 -and $jMax -le 20 -and $rtt -ge 0 -and $rtt -le 80) { $sJogo = "OK" } elseif ($pMax -le 2 -and $jMax -le 40 -and $rtt -le 150) { $sJogo = "MARGINAL" } else { $sJogo = "RUIM" } >>"%PFALA%"
echo if ($pMax -le 2) { $sStr = "OK" } elseif ($pMax -le 5) { $sStr = "MARGINAL" } else { $sStr = "RUIM" } >>"%PFALA%"
echo if ($pMax -le 3 -and $rtt -le 300) { $sNav = "OK" } elseif ($pMax -le 5) { $sNav = "MARGINAL" } else { $sNav = "RUIM" } >>"%PFALA%"
echo $dg += "[APTIDAO POR SERVICO]" >>"%PFALA%"
echo $dg += "  VoIP / chamada .........: " + $sVoip + "   limite: perda 1, jitter 30 ms, RTT 150 ms" >>"%PFALA%"
echo $dg += "  Jogo online ............: " + $sJogo + "   limite: perda 0.5, jitter 20 ms, RTT 80 ms" >>"%PFALA%"
echo $dg += "  Streaming / video ......: " + $sStr + "   limite: perda 2" >>"%PFALA%"
echo $dg += "  Navegacao / trabalho ...: " + $sNav + "   limite: perda 3, RTT 300 ms" >>"%PFALA%"
echo if ($eh24 -and ($totHi -gt 0 -or $perdaLan -gt 0)) { >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $dg += "[BANDA 2.4 GHZ]" >>"%PFALA%"
echo $dg += "  Faixa disputada com vizinhos, micro-ondas e Bluetooth. Repita em 5 GHz antes" >>"%PFALA%"
echo $dg += "  de concluir defeito no roteador." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($duplo) { >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $dg += "[AVISO DE METODO]" >>"%PFALA%"
echo $dg += "  LAN e Wi-Fi ligados juntos. O Windows usa a rota de menor metrica, entao o" >>"%PFALA%"
echo $dg += "  resultado pode nao ser do meio que voce quer medir. Desligue um e repita." >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($semIpv6) { >>"%PFALA%"
echo $dg += "" >>"%PFALA%"
echo $dg += "[IPv6]" >>"%PFALA%"
echo $dg += "  Rede sem IPv6. Nao e defeito, fica apenas registrado." >>"%PFALA%"
echo } >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "DIAGNOSTICO" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo foreach ($x in $dg) { $rel += $x } >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "VEREDITO FALADO: " + $curto >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "TABELA DE REFERENCIA - NOTA COMPOSTA (o PIOR criterio define a nota)" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "  Ping medio : ate 50 EXCELENTE / 100 BOM / 150 ACEITAVEL / 200 RUIM / acima REPROVADO" >>"%PFALA%"
echo $rel += "  Ping maximo: ate 150 EXCELENTE / 300 BOM / 600 ACEITAVEL / 1000 RUIM / acima REPROVADO" >>"%PFALA%"
echo $rel += "  Jitter     : ate 20 EXCELENTE / 50 BOM / 100 ACEITAVEL / 200 RUIM / acima REPROVADO" >>"%PFALA%"
echo $rel += "  Perda      : ate 2 %% EXCELENTE / 5 %% BOM / acima ACEITAVEL (se isolada)" >>"%PFALA%"
echo $rel += "  Rajada     : 2 consecutivas com contexto = PROBLEMA DETECTADO" >>"%PFALA%"
echo $rel += "               3 ou mais consecutivas = PROBLEMA GRAVE" >>"%PFALA%"
echo $rel += "               indicio fraco sem consenso = RUIM (monitorar, nao condena)" >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "  Perda isolada nao condena o enlace: padrao tipico de limite de ICMP." >>"%PFALA%"
echo $rel += "  Perda 0 %% NAO aprova sozinha: latencia alta reprova por si so." >>"%PFALA%"
echo $rel += "=========================================================" >>"%PFALA%"
echo $topo = @() >>"%PFALA%"
echo $topo += "=========================================================" >>"%PFALA%"
echo $topo += "  RESUMO DO LAUDO" >>"%PFALA%"
echo $topo += "=========================================================" >>"%PFALA%"
echo $topo += "  Tecnico ...: " + $tec >>"%PFALA%"
echo $topo += "  Cliente ...: " + $cli >>"%PFALA%"
echo $topo += "  Conexao ...: " + $conx >>"%PFALA%"
echo $topo += "  Data ......: " + (Get-Date -Format "dd/MM/yyyy HH:mm") >>"%PFALA%"
echo $topo += "  RESULTADO .: " + $ESC[$pioresc] >>"%PFALA%"
echo $topo += "  SCORE .....: " + $score + "/100 (" + $scLbl + ")" >>"%PFALA%"
echo $topo += "  Confianca .: " + $conf >>"%PFALA%"
echo $topo += "" >>"%PFALA%"
echo $topo += "  " + $curto >>"%PFALA%"
echo $topo += "=========================================================" >>"%PFALA%"
echo $topo += "" >>"%PFALA%"
echo $rel = $topo + $rel >>"%PFALA%"
echo Set-Content -Path (Join-Path $pasta "VEREDITO.txt") -Value $rel -Encoding UTF8 >>"%PFALA%"
echo $notaGeral = $ESC[$pioresc] >>"%PFALA%"
echo $resumoDiag = "" >>"%PFALA%"
echo if ($diagT.Count -ge 1) { $resumoDiag = $diagT[0] } >>"%PFALA%"
echo if ($diagT.Count -ge 2) { $resumoDiag = $resumoDiag + " " + $diagT[1] } >>"%PFALA%"
echo $tg += "==== VEREDITO ====" >>"%PFALA%"
echo $tg += "RESULTADO: " + $notaGeral >>"%PFALA%"
echo $tg += "SCORE: " + $score + "/100 (" + $scLbl + ")" >>"%PFALA%"
echo $tg += $resumoDiag >>"%PFALA%"
echo $tg += "Confianca: " + $conf >>"%PFALA%"
echo $tg += "" >>"%PFALA%"
echo $tg += ">> Evidencia tecnica completa, aptidao por servico e tracert no arquivo do ZIP." >>"%PFALA%"
echo $tgTxt = ($tg -join "`r`n") >>"%PFALA%"
echo if ($tgTxt.Length -gt 3800) { $tgTxt = $tgTxt.Substring(0,3800) + "`r`n...(cortado - veja o ZIP)" } >>"%PFALA%"
echo Set-Content -Path (Join-Path $pasta "TELEGRAM.txt") -Value $tgTxt -Encoding UTF8 >>"%PFALA%"
echo $longo = "Teste de rede finalizado. " + $detalhe + $curto >>"%PFALA%"
echo if ($modo -eq "longo") { $fala = $longo } else { $fala = $curto } >>"%PFALA%"
echo Write-Host "" >>"%PFALA%"
echo Write-Host ($diagT -join " ") -ForegroundColor Yellow >>"%PFALA%"
echo Write-Host ("Confianca: " + $conf) -ForegroundColor Magenta >>"%PFALA%"
echo Write-Host $curto -ForegroundColor Green >>"%PFALA%"
echo if ($modo -ne "nao") { $voz.Speak($fala) } >>"%PFALA%"

:: =========================================================
:: ENVIO PARA O TELEGRAM (tg_send.ps1)
::   - HttpClient: SEMPRE mostra a resposta real da API
::   - Copia segura dos logs antes de zipar (arquivo em uso)
:: =========================================================
set "PTG=%TEMP%\tg_send.ps1"
del "%PTG%" >nul 2>&1
echo param($pasta, $tec, $cliNome) >>"%PTG%"
echo $token = "%TG_TOKEN%" >>"%PTG%"
echo $chat  = "%TG_CHAT%" >>"%PTG%"
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 >>"%PTG%"
echo Add-Type -AssemblyName System.Net.Http >>"%PTG%"
echo $api = "https://api.telegram.org/bot" + $token >>"%PTG%"
echo $cli = New-Object System.Net.Http.HttpClient >>"%PTG%"
echo $cli.Timeout = [TimeSpan]::FromMinutes(5) >>"%PTG%"
echo Write-Host "" >>"%PTG%"
echo Write-Host "Enviando laudo para o Telegram...  [MODULO TELEGRAM v%VER%]" -ForegroundColor Cyan >>"%PTG%"
echo Write-Host ("  chat_id: " + $chat) -ForegroundColor DarkGray >>"%PTG%"
echo $arqMsg = Join-Path $pasta "TELEGRAM.txt" >>"%PTG%"
echo $msg = "" >>"%PTG%"
echo if (Test-Path $arqMsg) { $msg = [string](Get-Content $arqMsg -Raw -Encoding UTF8) } >>"%PTG%"
echo if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Laudo de rede finalizado - Tecnico: " + $tec } >>"%PTG%"
echo if ($msg.Length -gt 4000) { $msg = $msg.Substring(0,4000) } >>"%PTG%"
echo try { >>"%PTG%"
echo $f1 = New-Object System.Net.Http.MultipartFormDataContent >>"%PTG%"
echo $f1.Add((New-Object System.Net.Http.StringContent($chat, [System.Text.Encoding]::UTF8)), "chat_id") >>"%PTG%"
echo $f1.Add((New-Object System.Net.Http.StringContent($msg, [System.Text.Encoding]::UTF8)), "text") >>"%PTG%"
echo $r1 = $cli.PostAsync(($api + "/sendMessage"), $f1).Result >>"%PTG%"
echo $b1 = $r1.Content.ReadAsStringAsync().Result >>"%PTG%"
echo if ($r1.IsSuccessStatusCode) { Write-Host "  [OK] Resumo enviado." -ForegroundColor Green } >>"%PTG%"
echo else { Write-Host ("  [FALHA] sendMessage HTTP " + [int]$r1.StatusCode) -ForegroundColor Red; Write-Host ("  [TELEGRAM] " + $b1) -ForegroundColor Yellow } >>"%PTG%"
echo } catch { Write-Host ("  [ERRO] sendMessage: " + $_.Exception.Message) -ForegroundColor Red } >>"%PTG%"
echo $stage = Join-Path $env:TEMP ("stage_" + (Split-Path $pasta -Leaf)) >>"%PTG%"
echo if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue } >>"%PTG%"
echo New-Item -ItemType Directory -Path $stage -Force ^| Out-Null >>"%PTG%"
echo foreach ($f in (Get-ChildItem -Path $pasta -File)) { >>"%PTG%"
echo try { >>"%PTG%"
echo $ent = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite) >>"%PTG%"
echo $sai = New-Object System.IO.FileStream((Join-Path $stage $f.Name), [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None) >>"%PTG%"
echo $ent.CopyTo($sai) >>"%PTG%"
echo $sai.Close() >>"%PTG%"
echo $ent.Close() >>"%PTG%"
echo } catch { Write-Host ("  [aviso] arquivo em uso, pulei: " + $f.Name) -ForegroundColor DarkYellow } >>"%PTG%"
echo } >>"%PTG%"
echo $zip = Join-Path $env:TEMP ((Split-Path $pasta -Leaf) + ".zip") >>"%PTG%"
echo try { >>"%PTG%"
echo if (Test-Path $zip) { Remove-Item $zip -Force } >>"%PTG%"
echo Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force >>"%PTG%"
echo $f2 = New-Object System.Net.Http.MultipartFormDataContent >>"%PTG%"
echo $f2.Add((New-Object System.Net.Http.StringContent($chat, [System.Text.Encoding]::UTF8)), "chat_id") >>"%PTG%"
echo $f2.Add((New-Object System.Net.Http.StringContent(("Laudo completo - Tecnico: " + $tec + " - Cliente: " + $cliNome), [System.Text.Encoding]::UTF8)), "caption") >>"%PTG%"
echo $fs = [System.IO.File]::OpenRead($zip) >>"%PTG%"
echo $sc = New-Object System.Net.Http.StreamContent($fs) >>"%PTG%"
echo $f2.Add($sc, "document", [System.IO.Path]::GetFileName($zip)) >>"%PTG%"
echo $r2 = $cli.PostAsync(($api + "/sendDocument"), $f2).Result >>"%PTG%"
echo $b2 = $r2.Content.ReadAsStringAsync().Result >>"%PTG%"
echo $fs.Close() >>"%PTG%"
echo if ($r2.IsSuccessStatusCode) { Write-Host "  [OK] ZIP do laudo enviado." -ForegroundColor Green } >>"%PTG%"
echo else { Write-Host ("  [FALHA] sendDocument HTTP " + [int]$r2.StatusCode) -ForegroundColor Red; Write-Host ("  [TELEGRAM] " + $b2) -ForegroundColor Yellow } >>"%PTG%"
echo } catch { Write-Host ("  [ERRO] ZIP: " + $_.Exception.Message) -ForegroundColor Red } >>"%PTG%"
echo Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue >>"%PTG%"
echo Write-Host "" >>"%PTG%"
echo Write-Host "  'chat not found' = ID errado / 'bot is not a member' = adicione o bot no grupo" -ForegroundColor DarkGray >>"%PTG%"

:: =========================================================
:: ESPERA COM Ctrl+C / F (aguardar.ps1)
:: =========================================================
set "PWAIT=%TEMP%\aguardar.ps1"
del "%PWAIT%" >nul 2>&1
echo param($segundos, $gw, $alvo, $mins, $tec, $conx) >>"%PWAIT%"
echo if (-not $segundos) { $segundos = 900 } >>"%PWAIT%"
echo [Console]::TreatControlCAsInput = $true >>"%PWAIT%"
echo $fim = (Get-Date).AddSeconds([int]$segundos) >>"%PWAIT%"
echo while ((Get-Date) -lt $fim) { >>"%PWAIT%"
echo $rest = [int]($fim - (Get-Date)).TotalSeconds >>"%PWAIT%"
echo $m = [int]($rest / 60) >>"%PWAIT%"
echo $s = $rest - ($m * 60) >>"%PWAIT%"
echo Clear-Host >>"%PWAIT%"
echo Write-Host "=====================================================" >>"%PWAIT%"
echo Write-Host ("       LAUDO DE REDE v%VER% - Tecnico: " + $tec) >>"%PWAIT%"
echo Write-Host "=====================================================" >>"%PWAIT%"
echo Write-Host ("  Roteador : " + $gw) >>"%PWAIT%"
echo Write-Host ("  Internet : " + $alvo) >>"%PWAIT%"
echo Write-Host ("  Conexao  : " + $conx) >>"%PWAIT%"
echo Write-Host ("  Teste de : " + $mins + " minutos") >>"%PWAIT%"
echo Write-Host ("  TEMPO RESTANTE: " + ("{0:00}:{1:00}" -f $m, $s)) >>"%PWAIT%"
echo Write-Host ("") >>"%PWAIT%"
echo Write-Host "  Ctrl+C ou F = encerrar agora, falar e enviar ao Telegram." >>"%PWAIT%"
echo Write-Host "=====================================================" >>"%PWAIT%"
echo $t0 = Get-Date >>"%PWAIT%"
echo while (((Get-Date) - $t0).TotalMilliseconds -lt 1000) { >>"%PWAIT%"
echo if ([Console]::KeyAvailable) { >>"%PWAIT%"
echo $k = [Console]::ReadKey($true) >>"%PWAIT%"
echo if ($k.Key -eq 'F') { return } >>"%PWAIT%"
echo if (($k.Modifiers -band [ConsoleModifiers]::Control) -and ($k.Key -eq 'C')) { return } >>"%PWAIT%"
echo } >>"%PWAIT%"
echo Start-Sleep -Milliseconds 80 >>"%PWAIT%"
echo } >>"%PWAIT%"
echo } >>"%PWAIT%"

:: ABA 7 - LOOP SPEEDTEST
if defined SPEEDEXE (
  > "%TEMP%\speed_loop.bat" (
    echo @echo off
    echo chcp 65001 ^>nul
    echo title LAUDO_SPEED
    echo color 0B
    echo :loop
    echo echo ----------------------------- ^>^> "%LAUDO%\speedlog.txt"
    echo echo SPEEDTEST EM %%date%% %%time%% ^>^> "%LAUDO%\speedlog.txt"
    echo "%SPEEDEXE%" %SPEEDARGS% ^>^> "%LAUDO%\speedlog.txt" 2^>^&1
    echo echo. ^>^> "%LAUDO%\speedlog.txt"
    echo timeout /t %INTERVALO_SPEED% ^>nul
    echo goto loop
  )
  start "LAUDO_SPEED" cmd /k "%TEMP%\speed_loop.bat"
)

:: ABA 8 - LOOP FAST
if defined FASTEXE (
  > "%TEMP%\fast_loop.bat" (
    echo @echo off
    echo chcp 65001 ^>nul
    echo title LAUDO_FAST
    echo color 0D
    echo :loop
    echo echo ----------------------------- ^>^> "%LAUDO%\fastlog.txt"
    echo echo FAST EM %%date%% %%time%% ^>^> "%LAUDO%\fastlog.txt"
    echo "%FASTEXE%" %FASTARGS% ^>^> "%LAUDO%\fastlog.txt" 2^>^&1
    echo echo. ^>^> "%LAUDO%\fastlog.txt"
    echo timeout /t %INTERVALO_FAST% ^>nul
    echo goto loop
  )
  start "LAUDO_FAST" cmd /k "%TEMP%\fast_loop.bat"
)

:: ABAS 1 a 6 - PINGS AO VIVO COM BIP
echo Abrindo as abas de ping com BIP...
start "LAUDO_PING_MODEM"    cmd /k color 0A ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%GW%" "%LAUDO%\ping_modem.txt" %LIMITE_ROTEADOR% %QTD_PING%
start "LAUDO_PING_INTERNET" cmd /k color 0E ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%ALVO_INTERNET%" "%LAUDO%\ping_internet.txt" %LIMITE_INTERNET% %QTD_PING% 4
start "LAUDO_PING_SERVIDOR" cmd /k color 0B ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%SERVIDOR%" "%LAUDO%\ping_servidor.txt" %LIMITE_SERVIDOR% %QTD_PING%

if defined ALVO_EXTRA (
  start "LAUDO_PING_EXTRA" cmd /k color 0C ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%ALVO_EXTRA%" "%LAUDO%\ping_extra.txt" %LIMITE_EXTRA% %QTD_PING% 4
)

if "%TEM_IPV6%"=="1" (
  start "LAUDO_PING_IPV6" cmd /k color 0F ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%IPV6_USADO%" "%LAUDO%\ping_ipv6.txt" %LIMITE_IPV6% %QTD_PING% 6
) else (
  echo   [INFO] Rede sem IPv6 - abas 5 e 6 NAO foram abertas.
)

if defined ALVO_EXTRA_IPV6 if "%TEM_IPV6%"=="1" (
  start "LAUDO_PING_EXTRA6" cmd /k color 09 ^& powershell -NoProfile -ExecutionPolicy Bypass -File "%PBEEP%" "%ALVO_EXTRA_IPV6%" "%LAUDO%\ping_extra6.txt" %LIMITE_EXTRA_IPV6% %QTD_PING% 6
)
echo.

:: ESPERA (Ctrl+C ou F encerra na hora)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PWAIT%" %QTD_PING% "%GW%" "%ALVO_INTERNET%" "%MINUTOS%" "%TECNICO%" "%CONEXAO%"

:: =========================================================
:: FINALIZAR
:: =========================================================
:FINALIZAR
cls
echo Encerrando testes e gerando laudo tecnico...
:: 1) fecha as janelas pelo TITULO EXATO (nunca por curinga, para nao
::    acertar a janela principal por engano)
for %%W in (LAUDO_PING_MODEM LAUDO_PING_INTERNET LAUDO_PING_SERVIDOR LAUDO_PING_EXTRA LAUDO_PING_IPV6 LAUDO_PING_EXTRA6 LAUDO_SPEED LAUDO_FAST) do taskkill /F /T /FI "WINDOWTITLE eq %%W" >nul 2>&1

:: 2) varredura de sobra - IGNORA o proprio PowerShell e o pai dele.
::    (sem isso, o proprio comando se encontrava na busca e se matava)
set "PFIM=%TEMP%\fim.ps1"
del "%PFIM%" >nul 2>&1
echo $meu = $PID >>"%PFIM%"
echo $pai = 0 >>"%PFIM%"
echo try { $pai = (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $meu)).ParentProcessId } catch {} >>"%PFIM%"
echo $vovo = 0 >>"%PFIM%"
echo try { $vovo = (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $pai)).ParentProcessId } catch {} >>"%PFIM%"
echo $lista = Get-CimInstance Win32_Process ^| Where-Object { $_.ProcessId -ne $meu -and $_.ProcessId -ne $pai -and $_.ProcessId -ne $vovo -and $_.CommandLine -match 'ping_beep^|speed_loop^|fast_loop' } >>"%PFIM%"
echo foreach ($p in $lista) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {} } >>"%PFIM%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PFIM%" >nul 2>&1

:: mata o speedtest.exe e o fast.exe pelo NOME (senao eles seguram o log e o ZIP falha)
if defined SPEEDEXE for %%A in ("%SPEEDEXE%") do taskkill /F /IM "%%~nxA" >nul 2>&1
if defined FASTEXE  for %%A in ("%FASTEXE%")  do taskkill /F /IM "%%~nxA" >nul 2>&1
echo Aguardando os arquivos de log serem liberados...
timeout /t 3 /nobreak >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%PFALA%" "%LAUDO%" "%VOZ_MODO%" "%IPV6_NO_VEREDITO%" "%TEM_IPV6%" "%MINUTOS%" "%TECNICO%" "%CLIENTE%" "%CONEXAO%" "%GW%" "%ALVO_INTERNET%" "%SERVIDOR%" "%IPV6_USADO%" "%ALVO_EXTRA%" "%ALVO_EXTRA_IPV6%" %LIMITE_ROTEADOR% %LIMITE_INTERNET% %LIMITE_SERVIDOR% %LIMITE_IPV6% %LIMITE_EXTRA% %LIMITE_EXTRA_IPV6%

if /i "%TG_ENVIAR%"=="sim" powershell -NoProfile -ExecutionPolicy Bypass -File "%PTG%" "%LAUDO%" "%TECNICO%" "%CLIENTE%"

:: TELA FINAL
echo.
echo =========================================================================
echo    FINALIZADO - Tecnico: %TECNICO%  -  Cliente: %CLIENTE%
echo    Conexao: %CONEXAO%   -   %MINUTOS% MINUTOS DE TESTE
echo =========================================================================
echo   ALVO         PERDA    MIN      MEDIA    MAX      PICOS   CLASSIFICACAO
echo   -------------------------------------------------------------------
if exist "%LAUDO%\PERDA_PACOTES.csv" (
  for /f "usebackq skip=1 tokens=1-9 delims=;" %%a in ("%LAUDO%\PERDA_PACOTES.csv") do (
    echo   %%a  %%d%%  %%e ms  %%f ms  %%g ms  %%h  %%i
  )
) else (
  echo   [AVISO] PERDA_PACOTES.csv nao encontrado - veja os logs de ping.
)
echo   Perda isolada nao reprova. Rajada e avaliada com contexto de amostra e consenso.
echo   SUSPEITO = indicio fraco sem consenso entre destinos - monitorar, nao reprova.
echo.
echo  LAUDO TECNICO : %LAUDO%\VEREDITO.txt
echo  PASTA COMPLETA: %LAUDO%
echo.
echo  Tracando a rota ate a internet (tracert) - aguarde...
(
echo ===== ROTA ATE %ALVO_INTERNET% (tracert) =====
echo Data: %date% %time%
echo.
tracert -d -h 20 -w 800 %ALVO_INTERNET%
) > "%LAUDO%\ROTA_tracert.txt" 2>&1
echo  Rota salva em ROTA_tracert.txt
echo.

:: limpeza dos temporarios gerados por este laudo
del "%PBEEP%" "%PFALA%" "%PWAIT%" "%PTG%" "%PNET%" "%PCHK%" "%PSAN%" "%PVER%" >nul 2>&1
del "%TEMP%\speed_loop.bat" "%TEMP%\fast_loop.bat" "%TEMP%\lr_ver.ps1" "%TEMP%\lr_notas.txt" >nul 2>&1
echo.
pause
endlocal
exit /b 0

:: SUB-ROTINA: LOCALIZAR
:: =========================================================
:: SUB-ROTINA: CHECAR ATUALIZACAO NO GITHUB
:: =========================================================
:CHECAR_ATUALIZACAO
if /i not "%CHECAR_UPDATE%"=="sim" goto :eof
set "VERSAO_REMOTA="
set "PVER=%TEMP%\lr_ver.ps1"
del "%PVER%" >nul 2>&1
:: PowerShell com TIMEOUT proprio (4s) - WebClient puro trava sem isso
echo $ProgressPreference = 'SilentlyContinue' >>"%PVER%"
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 >>"%PVER%"
echo try { >>"%PVER%"
echo $r = Invoke-WebRequest -Uri '%URL_VERSAO%' -UseBasicParsing -TimeoutSec 4 >>"%PVER%"
echo Write-Output ([string]$r.Content).Trim() >>"%PVER%"
echo } catch { Write-Output 'ERRO' } >>"%PVER%"

:: tenta ate 3 vezes; cada tentativa desiste em ~4s (nao trava)
set "VERSAO_REMOTA="
set "TENT=1"
call :TENTAR_VER
if defined VERSAO_REMOTA goto VER_OK
set "TENT=2"
call :TENTAR_VER
if defined VERSAO_REMOTA goto VER_OK
set "TENT=3"
call :TENTAR_VER
if defined VERSAO_REMOTA goto VER_OK
echo   Sem conexao com o GitHub apos 3 tentativas - seguindo normal.
timeout /t 2 >nul
goto :eof

:TENTAR_VER
echo   Verificando atualizacoes... tentativa %TENT% de 3
set "RESP_VER="
for /f "delims=" %%v in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PVER%" 2^>nul') do set "RESP_VER=%%v"
if not defined RESP_VER goto :eof
if /i "%RESP_VER%"=="ERRO" goto :eof
set "VERSAO_REMOTA=%RESP_VER%"
goto :eof

:VER_OK
set /a "VL=%VERSAO_LOCAL%" 2>nul
set /a "VR=%VERSAO_REMOTA%" 2>nul
if not defined VR goto :eof
:: iguais = nada a fazer
if %VR% EQU %VL% (echo   Voce ja esta na versao publicada ^(v%VERSAO_LOCAL%^). & timeout /t 2 >nul & goto :eof)
:: define o sentido: subir (nova) ou voltar (retorno a uma versao anterior)
set "DIRECAO=ATUALIZAR"
set "PALAVRA=atualizacao disponivel"
if %VR% LSS %VL% (set "DIRECAO=RETORNAR" & set "PALAVRA=RETORNO de versao solicitado")

set "NOTAS=%TEMP%\lr_notas.txt"
del "%NOTAS%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { (New-Object System.Net.WebClient).DownloadFile('%URL_NOTAS%','%NOTAS%') } catch {}" >nul 2>&1

cls
echo =====================================================
echo            %PALAVRA%
echo =====================================================
echo.
echo   Sua versao no PC : v%VERSAO_LOCAL%
echo   Versao publicada : v%VERSAO_REMOTA%
echo.
if exist "%NOTAS%" (
  echo   Novidades:
  for /f "usebackq delims=" %%l in ("%NOTAS%") do echo     %%l
  echo.
)
:MENU_UPDATE
echo   O que deseja fazer?
echo     [1] Aplicar agora (baixar a versao publicada e reiniciar)
echo     [2] Baixar manualmente (abre o link do repositorio no navegador)
echo     [3] Continuar na versao atual
echo.
echo   Se voce nao escolher em 5 segundos, aplica automaticamente.
echo.
choice /c 123 /t 5 /d 1 /n /m "  Escolha 1, 2 ou 3 (auto em 5s = 1): "
set "RESP_UP=%ERRORLEVEL%"
if "%RESP_UP%"=="1" goto FAZER_UPDATE
if "%RESP_UP%"=="2" goto UPDATE_MANUAL
if "%RESP_UP%"=="3" (echo   Mantendo a versao atual. & timeout /t 1 >nul & goto :eof)
goto FAZER_UPDATE

:UPDATE_MANUAL
:: deriva o endereco da pagina do repo a partir do RAW_BASE
set "URL_PAGINA=%RAW_BASE:raw.githubusercontent.com=github.com%"
set "URL_PAGINA=%URL_PAGINA:/main/=%"
cls
echo =====================================================
echo            DOWNLOAD MANUAL DA ATUALIZACAO
echo =====================================================
echo.
echo   Abrindo o repositorio no seu navegador...
echo.
echo   Se nao abrir sozinho, copie e cole este endereco:
echo   %URL_PAGINA%
echo.
echo   No site, abra o arquivo LAUDO_REDE.bat e clique em
echo   "Download raw file" (ou no botao de download / Raw).
echo   Depois substitua o arquivo antigo pelo novo.
echo.
echo   Link direto do arquivo:
echo   %URL_SCRIPT%
echo.
start "" "%URL_PAGINA%"
echo   Pressione uma tecla para continuar na versao atual...
pause >nul
goto :eof

:FAZER_UPDATE

echo.
echo   Baixando a nova versao...
set "NOVO=%AQUI%LAUDO_REDE.new"
del "%NOVO%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { (New-Object System.Net.WebClient).DownloadFile('%URL_SCRIPT%','%NOVO%'); exit 0 } catch { exit 1 }"
if errorlevel 1 (echo   [FALHA] Nao consegui baixar. Seguindo com a versao atual. & del "%NOVO%" >nul 2>&1 & timeout /t 2 >nul & goto :eof)

for %%A in ("%NOVO%") do set "TAM_NOVO=%%~zA"
if not defined TAM_NOVO (del "%NOVO%" >nul 2>&1 & goto :eof)
if %TAM_NOVO% LSS 2000 (echo   [FALHA] Arquivo baixado invalido. Mantendo a versao atual. & del "%NOVO%" >nul 2>&1 & timeout /t 2 >nul & goto :eof)

set "UPD=%TEMP%\lr_update.bat"
set "EU=%~f0"
del "%UPD%" >nul 2>&1
>"%UPD%" echo @echo off
>>"%UPD%" echo chcp 65001 ^>nul
>>"%UPD%" echo title Atualizando LAUDO DE REDE...
>>"%UPD%" echo ping 127.0.0.1 -n 4 ^>nul
>>"%UPD%" echo copy /y "%NOVO%" "%EU%" ^>nul
>>"%UPD%" echo if exist "%NOVO%" del "%NOVO%" ^>nul 2^>^&1
>>"%UPD%" echo start "" "%EU%"
>>"%UPD%" echo ^(goto^) 2^>nul ^& del "%%~f0"
echo   Atualizando e reiniciando...
start "" cmd /c "%UPD%"
exit

:: =========================================================
:: SUB-ROTINA: CARREGAR / CRIAR CONFIG.INI (Telegram)
:: =========================================================
:CARREGAR_CONFIG
if not exist "%CFG_DIR%" mkdir "%CFG_DIR%" >nul 2>&1
if not exist "%CFG_DIR%" (set "CFG_DIR=%APPDATA%\LaudoRede" & set "CFG=%APPDATA%\LaudoRede\config.ini" & if not exist "%CFG_DIR%" mkdir "%CFG_DIR%" >nul 2>&1)

if exist "%CFG%" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%CFG%") do (
    if /i "%%a"=="TG_TOKEN" set "TG_TOKEN=%%b"
    if /i "%%a"=="TG_CHAT" set "TG_CHAT=%%b"
    if /i "%%a"=="TG_ENVIAR" set "TG_ENVIAR=%%b"
  )
)
if defined TG_TOKEN if defined TG_CHAT goto :eof

cls
echo =====================================================
echo         CONFIGURACAO INICIAL DO TELEGRAM
echo =====================================================
echo.
echo   Primeira execucao neste computador.
echo   Os dados ficam salvos e NAO serao perguntados de novo,
echo   nem quando o script se atualizar pelo GitHub.
echo.
echo   Onde fica salvo: %CFG%
echo.
echo   Enviar os laudos para o Telegram?
set "QTG="
set /p "QTG=  [S] Sim  /  [N] Nao: "
if /i not "%QTG%"=="S" (set "TG_ENVIAR=nao" & set "TG_TOKEN=x" & set "TG_CHAT=x" & goto GRAVA_CONFIG)
set "TG_ENVIAR=sim"
echo.
echo   TOKEN do bot ^(BotFather^). Ex: 123456:AAF...
set /p "TG_TOKEN=  Token: "
if defined TG_TOKEN set "TG_TOKEN=%TG_TOKEN:"=%"
echo.
echo   CHAT ID do grupo ^(comeca com -100...^).
set /p "TG_CHAT=  Chat ID: "
if defined TG_CHAT set "TG_CHAT=%TG_CHAT:"=%"

:GRAVA_CONFIG
>"%CFG%" echo TG_ENVIAR=%TG_ENVIAR%
>>"%CFG%" echo TG_TOKEN=%TG_TOKEN%
>>"%CFG%" echo TG_CHAT=%TG_CHAT%
echo.
echo   Configuracao salva em %CFG%
timeout /t 2 >nul
goto :eof

:LOCALIZAR
setlocal disabledelayedexpansion
set "_ACHOU="
for /f "delims=" %%f in ('dir /b /a-d "%AQUI%%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%AQUI%%%f"
if not defined _ACHOU for /f "delims=" %%f in ('dir /s /b /a-d "%USERPROFILE%\%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%%f"
if not defined _ACHOU for /f "delims=" %%f in ('dir /s /b /a-d "%SystemDrive%\%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%%f"
endlocal & set "%~1=%_ACHOU%"
goto :eof
