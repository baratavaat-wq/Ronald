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
set "VER=1042"
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
set "IA_KEY="


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
call :VERIFICAR_CHAVES
call :GRAVAR_BASE
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

:: =========================================================
:: PERGUNTA 3 - ID DA O.S. (obrigatorio)
:: =========================================================
:PERGUNTA_OS
set "OS_ID="
echo.
echo  ----------------------------------------------------
echo  ID DA O.S. ^(ordem de servico^)
echo  Digite o numero / codigo da O.S. do atendimento.
echo  Se nao houver O.S., digite SEM
echo.
set /p "OS_ID=  ID da O.S.: "
if not defined OS_ID goto PERGUNTA_OS
set "OS_ID=%OS_ID:"=%"
if not defined OS_ID goto PERGUNTA_OS

:: =========================================================
:: PERGUNTA 4 - APARELHOS NO LOCAL (1 obrigatorio, 2o opcional)
:: =========================================================
:PERGUNTA_APAR
set "APAR1="
set "APAR2="
echo.
echo  ----------------------------------------------------
echo  APARELHOS NO LOCAL DO TESTE
echo  Informe o aparelho principal. Se houver um segundo,
echo  informe depois ^(ou ENTER para pular^).
echo  Exemplos: ONU Intelbras 121AC / Roteador TP-Link C6
echo.
set /p "APAR1=  Aparelho 1: "
if not defined APAR1 goto PERGUNTA_APAR
set "APAR1=%APAR1:"=%"
if not defined APAR1 goto PERGUNTA_APAR
set /p "APAR2=  Aparelho 2 ^(ENTER se so tem um^): "
if defined APAR2 set "APAR2=%APAR2:"=%"
set "APARELHOS=%APAR1%"
if defined APAR2 set "APARELHOS=%APAR1% + %APAR2%"

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
:: laudos na pasta central (fora da area de trabalho)
set "BASE_LAUDOS=%ProgramData%\LaudoRede\Laudos"
mkdir "%BASE_LAUDOS%" >nul 2>&1
break>"%BASE_LAUDOS%\_t.tmp" 2>nul
if exist "%BASE_LAUDOS%\_t.tmp" (
  del "%BASE_LAUDOS%\_t.tmp" >nul 2>&1
) else (
  set "BASE_LAUDOS=%APPDATA%\LaudoRede\Laudos"
  mkdir "%APPDATA%\LaudoRede\Laudos" >nul 2>&1
)
set "LAUDO=!BASE_LAUDOS!\LAUDO_%TECNICO%_%CLI_PASTA%_%STAMP%"
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
:PERGUNTA_EXTRA4
set "ALVO_EXTRA="
set /p "ALVO_EXTRA=  Alvo EXTRA IPv4 (ENTER = nenhum): "
if not defined ALVO_EXTRA goto FIM_EXTRA4
set "ALVO_EXTRA=%ALVO_EXTRA:"=%"
if not defined ALVO_EXTRA goto FIM_EXTRA4
echo   Testando %ALVO_EXTRA% com 2 pings...
ping -n 2 -w 1500 "%ALVO_EXTRA%" >nul 2>&1
if not errorlevel 1 goto EXTRA4_OK
echo.
echo   [X] Sem resposta de %ALVO_EXTRA%.
echo       Confira se digitou certo. O alvo tambem pode estar
echo       fora do ar ou nao responder ping.
choice /c SN /n /m "  Digitar outro alvo? [S] sim  [N] seguir sem extra: "
if errorlevel 2 goto EXTRA4_CANCELA
goto PERGUNTA_EXTRA4
:EXTRA4_CANCELA
set "ALVO_EXTRA="
echo   Seguindo sem alvo extra IPv4.
goto FIM_EXTRA4
:EXTRA4_OK
echo   [OK] %ALVO_EXTRA% respondeu.
:FIM_EXTRA4

echo.
if not "%TEM_IPV6%"=="1" goto SEM_PERGUNTA_IPV6
echo  ----------------------------------------------------
echo  ABA 6 - PING EXTRA IPv6  (opcional)
echo  Digite o alvo para abrir a aba extra, ou so ENTER para NAO abrir.
echo  Exemplos: 2606:4700:4700::1111  /  2620:fe::fe  /  cloudflare.com
echo.
:PERGUNTA_EXTRA6
set "ALVO_EXTRA_IPV6="
set /p "ALVO_EXTRA_IPV6=  Alvo EXTRA IPv6 (ENTER = nenhum): "
if not defined ALVO_EXTRA_IPV6 goto FIM_EXTRA6
set "ALVO_EXTRA_IPV6=%ALVO_EXTRA_IPV6:"=%"
if not defined ALVO_EXTRA_IPV6 goto FIM_EXTRA6
echo   Testando %ALVO_EXTRA_IPV6% com 2 pings IPv6...
ping -6 -n 2 -w 1500 "%ALVO_EXTRA_IPV6%" >nul 2>&1
if not errorlevel 1 goto EXTRA6_OK
echo.
echo   [X] Sem resposta de %ALVO_EXTRA_IPV6%.
echo       Confira se digitou certo. Lembre que o alvo precisa
echo       ter IPv6 de verdade.
choice /c SN /n /m "  Digitar outro alvo? [S] sim  [N] seguir sem extra: "
if errorlevel 2 goto EXTRA6_CANCELA
goto PERGUNTA_EXTRA6
:EXTRA6_CANCELA
set "ALVO_EXTRA_IPV6="
echo   Seguindo sem alvo extra IPv6.
goto FIM_EXTRA6
:EXTRA6_OK
echo   [OK] %ALVO_EXTRA_IPV6% respondeu.
:FIM_EXTRA6
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
set "PIA=%TEMP%\ia_ask.ps1"
:: --- gera o script da IA (assistente) uma vez ---
del "%PIA%" >nul 2>&1
echo param([string]$key,[string]$saida) >>"%PIA%"
echo # ============================================================ >>"%PIA%"
echo # Assistente IA - API oficial DeepSeek (chat/completions) >>"%PIA%"
echo # A chave vem por parametro (lida do config.ini pelo .bat). >>"%PIA%"
echo # ============================================================ >>"%PIA%"
echo $ErrorActionPreference = 'Stop' >>"%PIA%"
echo $OutputEncoding = [Text.Encoding]::UTF8 >>"%PIA%"
echo try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {} >>"%PIA%"
echo.>>"%PIA%"
echo # --- configuracao central (trocar aqui se mudar de modelo/URL) --- >>"%PIA%"
echo $API_URL   = 'https://api.deepseek.com/chat/completions' >>"%PIA%"
echo $API_MODEL = 'deepseek-v4-flash' >>"%PIA%"
echo $TIMEOUT   = 60 >>"%PIA%"
echo $LIMITE_CHARS = 4000 >>"%PIA%"
echo $LOG = Join-Path $env:ProgramData 'LaudoRede\ia.log' >>"%PIA%"
echo.>>"%PIA%"
echo function Gravar-Log($txt) { try { $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Add-Content -Path $LOG -Value "$ts  $txt" -Encoding UTF8 } catch {} } >>"%PIA%"
echo.>>"%PIA%"
echo try { >>"%PIA%"
echo   # le contexto (dados do teste) + pergunta do arquivo >>"%PIA%"
echo   $raw = Get-Content -Path "$env:TEMP\ia_ctx.txt" -Raw -Encoding UTF8 >>"%PIA%"
echo   $partes = $raw -split '###PERGUNTA###' >>"%PIA%"
echo   $ctx = $partes[0].Trim() >>"%PIA%"
echo   $perg = '' >>"%PIA%"
echo   if ($partes.Count -gt 1) { $perg = $partes[1].Trim() } >>"%PIA%"
echo   # respeita limite de caracteres do contexto >>"%PIA%"
echo   if ($ctx.Length -gt $LIMITE_CHARS) { $ctx = $ctx.Substring(0,$LIMITE_CHARS) } >>"%PIA%"
echo.>>"%PIA%"
echo   $sys = 'Voce e um assistente tecnico de redes FTTH/GPON. Responda em portugues do Brasil, curto e pratico. REGRA CRITICA: os unicos numeros medidos sao os que aparecem em DADOS DO TESTE. Este teste NAO mede quantidade de dispositivos conectados, potencia optica em dBm, canal Wi-Fi, velocidade contratada nem consumo de banda. NUNCA some, calcule ou invente numeros que nao estao nos dados, e nunca trate ping ou perda como contagem de aparelhos. Se a resposta depender de algo nao medido, diga que o teste nao mediu isso e explique como o tecnico pode verificar. Use a BASE DE CONHECIMENTO para conceitos. Se perguntarem algo em tempo real (noticias, site fora do ar agora), diga que nao tem dados em tempo real.' >>"%PIA%"
echo   $kb = '' >>"%PIA%"
echo   $kbPaths = @((Join-Path $env:ProgramData 'LaudoRede\base_conhecimento.txt'),(Join-Path $env:APPDATA 'LaudoRede\base_conhecimento.txt'),(Join-Path $env:TEMP 'LaudoRede\base_conhecimento.txt')) >>"%PIA%"
echo   foreach ($kp in $kbPaths) { if (Test-Path $kp) { $kb = Get-Content -Path $kp -Raw -Encoding UTF8; break } } >>"%PIA%"
echo   if ($kb) { $sys = $sys + "`n`nBASE DE CONHECIMENTO:`n" + $kb } >>"%PIA%"
echo   $userMsg = "Dados do teste: $ctx`n`nPergunta: $perg" >>"%PIA%"
echo.>>"%PIA%"
echo   $body = @{ model = $API_MODEL; messages = @( @{ role='system'; content=$sys }, @{ role='user'; content=$userMsg } ); stream = $false } ^| ConvertTo-Json -Depth 6 >>"%PIA%"
echo   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 >>"%PIA%"
echo   $headers = @{ 'Authorization' = "Bearer $key"; 'Content-Type' = 'application/json' } >>"%PIA%"
echo.>>"%PIA%"
echo   $wr = Invoke-WebRequest -Uri $API_URL -Method Post -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec $TIMEOUT -UseBasicParsing >>"%PIA%"
echo   $jsonUtf8 = [Text.Encoding]::UTF8.GetString($wr.RawContentStream.ToArray()) >>"%PIA%"
echo   $resp = $jsonUtf8 ^| ConvertFrom-Json >>"%PIA%"
echo   $txt = $resp.choices[0].message.content >>"%PIA%"
echo   Write-Host '' >>"%PIA%"
echo   Write-Host '  --- Resposta da IA ---' -ForegroundColor Cyan >>"%PIA%"
echo   [Console]::WriteLine($txt) >>"%PIA%"
echo   if ($saida -and $txt) { $txt ^| Out-File -FilePath $saida -Encoding UTF8 } >>"%PIA%"
echo   Gravar-Log 'OK - resposta recebida.' >>"%PIA%"
echo } >>"%PIA%"
echo catch { >>"%PIA%"
echo   # tenta extrair o codigo HTTP e o corpo do erro da API >>"%PIA%"
echo   $code = 0 >>"%PIA%"
echo   $corpo = '' >>"%PIA%"
echo   try { if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } } catch {} >>"%PIA%"
echo   try { $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); $corpo = $sr.ReadToEnd() } catch {} >>"%PIA%"
echo   Write-Host '' >>"%PIA%"
echo   switch ($code) { >>"%PIA%"
echo     401 { Write-Host '  [IA] Chave invalida (401). Confira a IA_KEY no config.ini.' -ForegroundColor Yellow } >>"%PIA%"
echo     402 { Write-Host '  [IA] Sem saldo (402). Adicione creditos na conta DeepSeek.' -ForegroundColor Yellow } >>"%PIA%"
echo     429 { Write-Host '  [IA] Limite de requisicoes atingido (429). Aguarde e tente de novo.' -ForegroundColor Yellow } >>"%PIA%"
echo     500 { Write-Host '  [IA] Erro no servidor da IA (500). Tente novamente em instantes.' -ForegroundColor Yellow } >>"%PIA%"
echo     502 { Write-Host '  [IA] Servidor da IA indisponivel (502).' -ForegroundColor Yellow } >>"%PIA%"
echo     503 { Write-Host '  [IA] Servico da IA sobrecarregado (503). Tente depois.' -ForegroundColor Yellow } >>"%PIA%"
echo     default { Write-Host "  [IA] Nao consegui resposta (erro $code). Verifique a internet e a chave." -ForegroundColor Yellow } >>"%PIA%"
echo   } >>"%PIA%"
echo   if ($corpo) { Write-Host ('  Detalhe da API: ' + $corpo) -ForegroundColor DarkGray } >>"%PIA%"
echo   else { Write-Host ('  Detalhe: ' + $_.Exception.Message) -ForegroundColor DarkGray } >>"%PIA%"
echo   Gravar-Log ("ERRO $code - " + $_.Exception.Message) >>"%PIA%"
echo } >>"%PIA%"

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
echo if ($banda -and $radio -match '(?i)802\.11(ax^|be)') { $banda = $banda + ' (ou 6 GHz - nao confirmado pelo Windows)' } >>"%PNET%"
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
echo if ($ad.MediaType -eq '802.3') { $rota = 'LAN'; $lanNome = $ad.InterfaceDescription; $lanVel = $ad.LinkSpeed } else { $rota = 'Wi-Fi' } >>"%PNET%"
echo } catch {} >>"%PNET%"
echo if ($temLan -and $temWifi) { $res = 'ATENCAO - LAN e Wi-Fi ligados AO MESMO TEMPO - o teste esta indo pela ' + $rota } >>"%PNET%"
echo elseif ($temWifi) { $res = 'Wi-Fi / ' + $banda + ' / ' + $ger + ' / SSID ' + $ssid + ' / canal ' + $canal + ' / sinal ' + $sinal + ([char]37) } >>"%PNET%"
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
echo $det += 'Sinal (qualidade): ' + $sinal + ([char]37) + '  (0 a 100 - quanto maior melhor)' >>"%PNET%"
echo $det += 'Obs: valor de QUALIDADE do sinal reportado pelo Windows, nao e dBm.' >>"%PNET%"
echo $det += 'Para dBm exato use o medidor do proprio aparelho.' >>"%PNET%"
echo $det += 'Taxa Rx ........: ' + $rx + ' Mbps' >>"%PNET%"
echo $det += 'Taxa Tx ........: ' + $tx + ' Mbps' >>"%PNET%"
echo } else { $det += 'Wi-Fi ..........: nao conectado' } >>"%PNET%"
echo $det += '' >>"%PNET%"
echo $det += '--- LAN por cabo ---' >>"%PNET%"
echo if ($temLan) { >>"%PNET%"
echo $det += 'Placa ..........: ' + $lanNome >>"%PNET%"
echo $det += 'Velocidade .....: ' + $lanVel >>"%PNET%"
echo try { Set-Content -Path (Join-Path $pasta '_link.txt') -Value @(('LINKSPEED=' + $lanVel),('NOME_ADAPTADOR=' + $lanNome)) -Encoding UTF8 } catch {} >>"%PNET%"
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
set "BANDA24=N"
echo "%CONEXAO%" | find "2.4" >nul && set "BANDA24=S"
if /i "%BANDA24%"=="S" (
  echo.
  echo   -----------------------------------------------------
  echo   ATENCAO: conexao Wi-Fi em 2.4 GHz.
  echo   Nessa banda o ping costuma ser mais alto e instavel
  echo   ^(interferencia de vizinhos, micro-ondas, bluetooth^).
  echo   Se rodar teste de velocidade junto, o ping sobe mais
  echo   ainda por saturacao - isso NAO significa link ruim.
  echo   Para julgar latencia com precisao: 5 GHz ou cabo,
  echo   e sem speedtest.
  echo   -----------------------------------------------------
  echo.
  pause
)

cls
echo =====================================================
echo          LAUDO COMPLETO DE REDE v%VER%
echo          Tecnico: %TECNICO%   Cliente: %CLIENTE%
echo          O.S.: %OS_ID%   Aparelhos: %APARELHOS%
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
echo O.S.           : %OS_ID%
echo APARELHOS      : %APARELHOS%
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

:: =========================================================
:: PERGUNTA - rodar os testes de velocidade?
::   Se responder N, a janela nem abre (evita processo preso
::   segurando o log e travando o ZIP no final).
:: =========================================================
echo.
echo  ----------------------------------------------------
:: =========================================================
:: VERIFICA OS ALVOS PADRAO (2 pings cada)
::   se responder, nem aparece na tela
::   se falhar, mostra e deixa o tecnico corrigir na hora
:: =========================================================
:CHECA_INTERNET
ping -n 2 -w 1500 "%ALVO_INTERNET%" >nul 2>&1
if not errorlevel 1 goto CHECA_ALVO_IPV6
color 0E
echo.
echo   -----------------------------------------------------
echo   ALVO DE INTERNET nao respondeu: %ALVO_INTERNET%
echo   Pode estar fora do ar ou bloqueando ping.
echo   Exemplos: 8.8.8.8 / 1.1.1.1 / 9.9.9.9
echo   -----------------------------------------------------
set "NOVO_ALVO="
set /p "NOVO_ALVO=  Novo alvo (ENTER = manter assim): "
color 0A
if not defined NOVO_ALVO goto CHECA_ALVO_IPV6
set "ALVO_INTERNET=%NOVO_ALVO:"=%"
goto CHECA_INTERNET

:CHECA_SERVIDOR
:: verificacao do SERVIDOR removida a pedido - editar o IP no topo do script

:CHECA_ALVO_IPV6
if not "%TEM_IPV6%"=="1" goto FIM_CHECA_ALVOS
ping -6 -n 2 -w 1500 "%ALVO_IPV6%" >nul 2>&1
if not errorlevel 1 goto FIM_CHECA_ALVOS
color 0E
echo.
echo   -----------------------------------------------------
echo   ALVO IPv6 nao respondeu: %ALVO_IPV6%
echo   Exemplos: google.com / 2001:4860:4860::8888
echo   -----------------------------------------------------
set "NOVO_ALVO="
set /p "NOVO_ALVO=  Novo alvo IPv6 (ENTER = manter assim): "
color 0A
if not defined NOVO_ALVO goto FIM_CHECA_ALVOS
set "ALVO_IPV6=%NOVO_ALVO:"=%"
goto CHECA_ALVO_IPV6
:FIM_CHECA_ALVOS

echo  TESTES DE VELOCIDADE (opcionais)
echo.
echo  Recomendado escolher SOMENTE UM. O SPEEDTEST (Ookla) e o
echo  mais indicado. Rodar os dois juntos faz um roubar banda do
echo  outro e atrapalha a analise.
echo.
set "USAR_SPEED=N"
choice /c SN /n /m "  Rodar SPEEDTEST (Ookla)? [S/N]: "
if errorlevel 2 (set "USAR_SPEED=N") else (set "USAR_SPEED=S")
if /i "%USAR_SPEED%"=="S" goto INT_SPEED
goto FIM_INT_SPEED

:INT_SPEED
echo.
echo   Intervalo entre as rodadas do SPEEDTEST, em segundos.
echo   Padrao atual: %INTERVALO_SPEED%s.
echo   Abaixo de 185s costuma funcionar, mas a Ookla pode
echo   bloquear por excesso de testes seguidos.
set "RESP_INT="
set /p "RESP_INT=  Intervalo em segundos (ENTER = %INTERVALO_SPEED%): "
if not defined RESP_INT goto FIM_INT_SPEED
echo %RESP_INT%| findstr /r "^[0-9][0-9]*$" >nul || goto INT_SPEED
set "INTERVALO_SPEED=%RESP_INT%"
if %INTERVALO_SPEED% LSS 5 set "INTERVALO_SPEED=5"
if %INTERVALO_SPEED% LSS 185 echo   [!] Abaixo de 185s: risco de bloqueio pela Ookla.
echo   Intervalo do SPEEDTEST: %INTERVALO_SPEED%s
:FIM_INT_SPEED

set "USAR_FAST=N"
choice /c SN /n /m "  Rodar FAST (Netflix)? [S/N]: "
if errorlevel 2 (set "USAR_FAST=N") else (set "USAR_FAST=S")
if /i "%USAR_FAST%"=="S" goto INT_FAST
goto FIM_INT_FAST

:INT_FAST
echo.
echo   Intervalo entre as rodadas do FAST, em segundos.
echo   Padrao atual: %INTERVALO_FAST%s.
set "RESP_INTF="
set /p "RESP_INTF=  Intervalo em segundos (ENTER = %INTERVALO_FAST%): "
if not defined RESP_INTF goto FIM_INT_FAST
echo %RESP_INTF%| findstr /r "^[0-9][0-9]*$" >nul || goto INT_FAST
set "INTERVALO_FAST=%RESP_INTF%"
if %INTERVALO_FAST% LSS 5 set "INTERVALO_FAST=5"
echo   Intervalo do FAST: %INTERVALO_FAST%s
:FIM_INT_FAST

:: marcou os dois? avisa que atrapalha
if /i not "%USAR_SPEED%"=="S" goto FIM_DOIS
if /i not "%USAR_FAST%"=="S" goto FIM_DOIS
color 0E
echo.
echo   -----------------------------------------------------
echo   ATENCAO: SPEEDTEST e FAST marcados JUNTOS.
echo   Os dois disputam a mesma banda ao mesmo tempo, entao
echo   as duas medicoes de velocidade saem menores que o real
echo   e a analise fica menos confiavel.
echo   -----------------------------------------------------
choice /c SN /n /m "  Deixar so o SPEEDTEST (recomendado)? [S/N]: "
if errorlevel 2 goto MANTEM_DOIS
set "USAR_FAST=N"
echo   FAST desligado. Seguindo so com o SPEEDTEST.
goto COR_DOIS
:MANTEM_DOIS
echo   Ok, mantendo os dois por sua conta.
:COR_DOIS
color 0A
timeout /t 3 >nul
:FIM_DOIS
echo.

:: LOCALIZA OS EXECUTAVEIS (so os que o tecnico quer usar)
set "SPEEDEXE="
set "FASTEXE="
if /i not "%USAR_SPEED%"=="S" goto PULA_SPEED
echo Procurando o speedtest no disco (pode demorar um pouco)...
call :LOCALIZAR SPEEDEXE "%NOME_SPEED%"
if defined SPEEDEXE (echo   ^> speedtest: %SPEEDEXE%) else (echo   [AVISO] speedtest nao encontrado - o teste sera pulado.)
:PULA_SPEED
if /i not "%USAR_FAST%"=="S" goto PULA_FAST
echo Procurando o fast no disco (pode demorar um pouco)...
call :LOCALIZAR FASTEXE "%NOME_FAST%"
if defined FASTEXE (echo   ^> fast     : %FASTEXE%) else (echo   [AVISO] fast nao encontrado - o teste sera pulado.)
:PULA_FAST
if /i "%USAR_SPEED%"=="N" echo   SPEEDTEST: nao sera executado (escolha do tecnico).
if /i "%USAR_FAST%"=="N" echo   FAST: nao sera executado (escolha do tecnico).
:: marca que havera saturacao proposital do link durante a coleta
set "SATURA=N"
:: so conta como saturacao se o programa foi realmente encontrado
if defined SPEEDEXE set "SATURA=S"
if defined FASTEXE set "SATURA=S"
set "MOTIVO_SEM_SPEED=escolha do tecnico"
if /i "%USAR_SPEED%"=="S" if not defined SPEEDEXE set "MOTIVO_SEM_SPEED=programa nao encontrado no disco"
if /i "%USAR_FAST%"=="S" if not defined FASTEXE set "MOTIVO_SEM_SPEED=programa nao encontrado no disco"
if /i "%SATURA%"=="N" (
  color 0E
  echo.
  echo   -----------------------------------------------------
  echo   ALERTA
  echo   O teste de velocidade NAO vai rodar.
  echo   Motivo: !MOTIVO_SEM_SPEED!
  echo.
  echo   Se o programa nao foi encontrado, coloque o
  echo   speedtest.exe na mesma pasta deste script e rode
  echo   de novo.
  echo.
  echo   A analise continua normalmente, porem metricas que
  echo   dependem do teste de velocidade, como bufferbloat e
  echo   comportamento do link sob carga, nao poderao ser
  echo   avaliadas.
  echo   -----------------------------------------------------
  echo.
  pause
  color 0A
)

:: aviso vale para QUALQUER conexao: cabo, Wi-Fi 5 GHz ou 2.4 GHz
if /i "%SATURA%"=="S" (
  color 0E
  echo.
  echo   -----------------------------------------------------
  echo   AVISO SOBRE O TESTE DE VELOCIDADE
  echo   Conexao detectada: %CONEXAO%
  echo.
  echo   O speedtest/fast roda em LOOP durante toda a coleta e
  echo   satura o link de proposito. Com isso o ping SOBE em
  echo   qualquer conexao ^(cabo, 5 GHz ou 2.4 GHz^) - no 2.4 GHz
  echo   sobe mais ainda.
  echo.
  echo   Isso NAO sera contado como falha: o laudo relativiza
  echo   ping medio, maximo e jitter. Perda de pacotes continua
  echo   valendo normalmente.
  echo.
  echo   Enquanto o speedtest roda, e normal a navegacao ficar
  echo   lenta ou travar - ele consome toda a banda de proposito.
  echo.
  echo   Para um veredito de latencia limpo, rode um teste
  echo   SEM speedtest ^(de preferencia no cabo^).
  echo   -----------------------------------------------------
  echo.
  pause
  color 0A
  cls
)
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
echo $pastaLog = Split-Path $log -Parent >>"%PBEEP%"
echo $sat1 = Join-Path $pastaLog '_sat_speed.flag' >>"%PBEEP%"
echo $sat2 = Join-Path $pastaLog '_sat_fast.flag' >>"%PBEEP%"
echo $hb = Join-Path $env:TEMP 'lr_hb.flag' >>"%PBEEP%"
echo $viuHb = $false >>"%PBEEP%"
echo Add-Content -Path $log -Value ("=== PING " + $alvo + " " + $ver + " limite " + $limite + "ms ===") >>"%PBEEP%"
echo $argos = @() >>"%PBEEP%"
echo if ($flag -eq "6") { $argos += "-6" } >>"%PBEEP%"
echo if ($flag -eq "4") { $argos += "-4" } >>"%PBEEP%"
echo $argos += $alvo >>"%PBEEP%"
echo $argos += "-n" >>"%PBEEP%"
echo $argos += "$qtd" >>"%PBEEP%"
echo ping @argos ^| ForEach-Object { >>"%PBEEP%"
echo $linha = $_ >>"%PBEEP%"
echo if (-not $viuHb) { if (Test-Path $hb) { $viuHb = $true } } >>"%PBEEP%"
echo elseif (-not (Test-Path $hb)) { exit } >>"%PBEEP%"
echo elseif ((((Get-Date) - (Get-Item $hb).LastWriteTime).TotalSeconds) -gt 90) { exit } >>"%PBEEP%"
echo $emSat = ((Test-Path $sat1) -or (Test-Path $sat2)) >>"%PBEEP%"
echo if ($emSat) { $linha = "[SAT] " + $linha } >>"%PBEEP%"
echo Write-Host $linha >>"%PBEEP%"
echo Add-Content -Path $log -Value $linha >>"%PBEEP%"
echo if ($emSat) { return } >>"%PBEEP%"
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
echo param($pasta, $modo, $ipv6Conta, $temIpv6, $mins, $tec, $cli, $conx, $aRot, $aInt, $aSrv, $aIp6, $aExt, $aExt6, $lRot, $lInt, $lSrv, $lIp6, $lExt, $lExt6, $os, $apar, $satur) >>"%PFALA%"
echo if (-not $modo) { $modo = "curto" } >>"%PFALA%"
echo try { Add-Type -AssemblyName System.Speech -ErrorAction SilentlyContinue } catch {} >>"%PFALA%"
echo $voz = $null; try { $voz = New-Object System.Speech.Synthesis.SpeechSynthesizer } catch {} >>"%PFALA%"
echo if ($voz -ne $null) { foreach ($v in $voz.GetInstalledVoices()) { if ($v.VoiceInfo.Culture.Name -eq "pt-BR") { try { $voz.SelectVoice($v.VoiceInfo.Name) } catch {} } } } >>"%PFALA%"
echo $ci = [System.Globalization.CultureInfo]::InvariantCulture >>"%PFALA%"
echo $ESC = @("EXCELENTE","BOM","ACEITAVEL","RUIM","REPROVADO","PROBLEMA DETECTADO","PROBLEMA GRAVE") >>"%PFALA%"
echo function NotaMed($v) { if ($v -lt 0) { return -1 }; if ($v -le 50) { return 0 }; if ($v -le 100) { return 1 }; if ($v -le 150) { return 2 }; if ($v -le 200) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaMax($v) { if ($v -lt 0) { return -1 }; if ($v -le 150) { return 0 }; if ($v -le 300) { return 1 }; if ($v -le 600) { return 2 }; if ($v -le 1000) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaJit($v) { if ($v -lt 0) { return -1 }; if ($v -le 5) { return 0 }; if ($v -le 10) { return 1 }; if ($v -le 20) { return 2 }; if ($v -le 50) { return 3 }; return 4 } >>"%PFALA%"
echo function NotaPer($p) { if ($p -le 0) { return 0 }; if ($p -le 1) { return 1 }; if ($p -le 2.5) { return 2 }; if ($p -le 5) { return 3 }; if ($p -le 10) { return 4 }; if ($p -le 25) { return 5 }; return 6 } >>"%PFALA%"
echo $alvos = @("ping_modem.txt","ping_internet.txt","ping_servidor.txt","ping_ipv6.txt","ping_extra.txt","ping_extra6.txt") >>"%PFALA%"
echo $nomes = @("roteador","internet","servidor","IPv6","extra IPv4","extra IPv6") >>"%PFALA%"
echo $ends  = @($aRot, $aInt, $aSrv, $aIp6, $aExt, $aExt6) >>"%PFALA%"
echo $limites = @([int]$lRot, [int]$lInt, [int]$lSrv, [int]$lIp6, [int]$lExt, [int]$lExt6) >>"%PFALA%"
echo for ($j = 0; $j -lt 6; $j = $j + 1) { if ($limites[$j] -le 0) { $limites[$j] = 120 }; if (-not $ends[$j]) { $ends[$j] = "-" } } >>"%PFALA%"
echo $toA = @(0,0,0,0,0,0); $envA = @(0,0,0,0,0,0); $respA = @(0,0,0,0,0,0); $hiA = @(0,0,0,0,0,0); $toTA = @(0,0,0,0,0,0); $envTA = @(0,0,0,0,0,0); $ampA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $rajA = @(0,0,0,0,0,0); $rajGA = @(0,0,0,0,0,0); $rajMaxA = @(0,0,0,0,0,0); $altA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $dnsA = @(0,0,0,0,0,0); $pctA = @(0,0,0,0,0,0) >>"%PFALA%"
echo $pminA = @(-1,-1,-1,-1,-1,-1); $pmedA = @(-1,-1,-1,-1,-1,-1); $pmaxA = @(-1,-1,-1,-1,-1,-1); $jitA = @(-1,-1,-1,-1,-1,-1) >>"%PFALA%"
echo $pmedianA = @(-1,-1,-1,-1,-1,-1) >>"%PFALA%"
echo $evA = @(0,0,0,0,0,0); $clsA = @("","","","","",""); $pesoA = @("-","-","-","-","-","-") >>"%PFALA%"
echo $semIpv6 = $false >>"%PFALA%"
echo for ($i = 0; $i -lt 6; $i = $i + 1) { >>"%PFALA%"
echo $arq = Join-Path $pasta $alvos[$i] >>"%PFALA%"
echo $to = 0; $hi = 0; $env = 0; $resp = 0; $dns = 0; $seq = 0; $raj = 0; $rajG = 0; $rajMax = 0; $alt = 0; $lastLoss = -99; $toSat = 0; $envSat = 0 >>"%PFALA%"
echo $lat = New-Object System.Collections.ArrayList >>"%PFALA%"
echo if (Test-Path $arq) { >>"%PFALA%"
echo foreach ($linha in (Get-Content $arq)) { >>"%PFALA%"
echo $txt = [string]$linha >>"%PFALA%"
echo if ($txt.StartsWith("[SAT]")) { >>"%PFALA%"
echo if ($txt -match "(?i)(encontrar o host|find host|esgotad|timed out|inacess|unreachable|falha ger|general fail|transmit fail)") { $toSat = $toSat + 1; $envSat = $envSat + 1 } >>"%PFALA%"
echo elseif ($txt -match "(?i)[=]\s*([0-9]+)\s*ms") { $envSat = $envSat + 1 } >>"%PFALA%"
echo continue >>"%PFALA%"
echo } >>"%PFALA%"
echo $perdeu = $false >>"%PFALA%"
echo if ($txt -match "(?i)(encontrar o host|find host)") { $dns = $dns + 1; $perdeu = $true } >>"%PFALA%"
echo elseif ($txt -match "(?i)(esgotad|timed out|inacess|unreachable|falha ger|general fail|transmit fail)") { $perdeu = $true } >>"%PFALA%"
echo elseif ($txt -match "(?i)[=]\s*([0-9]+)\s*ms") { $ms = [int]$Matches[1]; $env = $env + 1; $resp = $resp + 1; $seq = 0; [void]$lat.Add($ms); if ($ms -ge $limites[$i]) { $hi = $hi + 1 } } >>"%PFALA%"
echo if ($perdeu) { $to = $to + 1; $env = $env + 1; $seq = $seq + 1; if ($seq -eq 1) { $raj = $raj + 1; if ($lastLoss -gt 0 -and ($env - $lastLoss) -le 3) { $alt = $alt + 1 } }; if ($seq -eq 2) { $rajG = $rajG + 1 }; if ($seq -gt $rajMax) { $rajMax = $seq }; $lastLoss = $env } >>"%PFALA%"
echo } >>"%PFALA%"
echo } >>"%PFALA%"
echo $envT = $env + $envSat; $toT = $to + $toSat >>"%PFALA%"
echo $pct = 0; if ($envT -gt 0) { $pct = [math]::Round(($toT / $envT) * 100, 1) } >>"%PFALA%"
echo if ($env -gt 0) { $pesoA[$i] = ([math]::Round(100.0 / $env, 1)).ToString($ci) } >>"%PFALA%"
echo if ($resp -gt 0) { $st = $lat ^| Measure-Object -Minimum -Maximum -Average; $pminA[$i] = [int]$st.Minimum; $pmaxA[$i] = [int]$st.Maximum; $pmedA[$i] = [math]::Round($st.Average); $ampA[$i] = $pmaxA[$i] - $pminA[$i]; $somaJ = 0; for ($z = 1; $z -lt $lat.Count; $z = $z + 1) { $somaJ = $somaJ + [math]::Abs([int]$lat[$z] - [int]$lat[$z-1]) }; if ($lat.Count -ge 2) { $jitA[$i] = [math]::Round($somaJ / ($lat.Count - 1), 1) } else { $jitA[$i] = 0 }; $ord = $lat ^| Sort-Object; $n = $ord.Count; if ($n %% 2 -eq 1) { $pmedianA[$i] = [int]$ord[[math]::Floor($n/2)] } else { $pmedianA[$i] = [int][math]::Round(($ord[$n/2 - 1] + $ord[$n/2]) / 2) } } >>"%PFALA%"
echo $toTA[$i] = $toT; $envTA[$i] = $envT; $toA[$i] = $to; $envA[$i] = $env; $respA[$i] = $resp; $hiA[$i] = $hi; $rajA[$i] = $raj; $rajGA[$i] = $rajG; $rajMaxA[$i] = $rajMax; $altA[$i] = $alt; $dnsA[$i] = $dns; $pctA[$i] = $pct >>"%PFALA%"
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
echo $tg += "O.S.: " + $os >>"%PFALA%"
echo $tg += "Aparelhos: " + $apar >>"%PFALA%"
echo if ($satur -eq 'S') { $tg += "OBS METODO: speedtest/fast rodaram em loop. As amostras colhidas DENTRO de cada rodada foram descartadas da analise (marcadas [SAT] no log) - ping alto e perda por saturacao nao entram na conta. O veredito usa so os intervalos livres entre as rodadas." } >>"%PFALA%"
echo if ($satur -eq 'S' -and $conx -match '2\.4') { $tg += "OBS BANDA: Wi-Fi 2.4 GHz com teste de velocidade - essa banda satura facil e disputa meio com vizinhos. Ping e perda sobem por isso, nao por defeito. Repetir em 5 GHz ou cabo." } >>"%PFALA%"
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
echo if ($satur -eq 'S') { $rel += "OBS METODO ......: speedtest/fast rodaram em loop durante a coleta. Cada rodada satura o link de proposito (bufferbloat: ping sobe e a fila cheia descarta ICMP). Por isso as amostras colhidas DENTRO de cada rodada foram MARCADAS ([SAT] no log de ping) e DESCARTADAS da analise. Os numeros deste laudo vem apenas dos intervalos livres entre as rodadas. Se sobrarem poucas amostras livres, o veredito fica limitado a ACEITAVEL por prudencia - nesse caso repita sem speedtest." } >>"%PFALA%"
echo if ($satur -eq 'S' -and $conx -match '2\.4') { $rel += "OBS BANDA .......: Wi-Fi 2.4 GHz somado ao teste de velocidade. A banda de 2.4 GHz satura com facilidade e disputa o meio com vizinhos, micro-ondas e bluetooth: ping e perda sobem bastante durante o speedtest e isso NAO caracteriza defeito. Para avaliar o link, repita em 5 GHz ou no cabo, sem speedtest." } >>"%PFALA%"
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
echo $envLimpo = $envA[$i]; $to = $toTA[$i]; $env = $envTA[$i]; $resp = $respA[$i]; $hi = $hiA[$i]; $raj = $rajA[$i]; $rajG = $rajGA[$i]; $rajMax = $rajMaxA[$i]; $alt = $altA[$i]; $pct = $pctA[$i]; $peso = $pesoA[$i] >>"%PFALA%"
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
echo $nBase = NotaPer $pct >>"%PFALA%"
echo if ($rajMax -ge 3) { $nRaj = [Math]::Max($nBase,6) } else { $nRaj = [Math]::Max($nBase,5) } >>"%PFALA%"
echo $partes = @() >>"%PFALA%"
echo if ($rajMax -ge 2) { $partes += "maior rajada de " + $rajMax + " consecutivos, " + $rajG + " evento(s) de rajada" } >>"%PFALA%"
echo if ($alt -ge 3) { $partes += "padrao alternado (" + $alt + " perdas em cadencia curta)" } >>"%PFALA%"
echo $obs = ($partes -join " e ") + " em " + $env + " pacotes (" + $pctTxt + " por cento) - perda continua real, nao e limite de ICMP" >>"%PFALA%"
echo } >>"%PFALA%"
echo elseif ($ev -eq 2) { >>"%PFALA%"
echo $nBase = NotaPer $pct >>"%PFALA%"
echo if ($consenso) { $nRaj = [Math]::Max($nBase,5); $obs = "evento de perda (2 consecutivas ou alternancia) com perda tambem em outros destinos" } >>"%PFALA%"
echo else { >>"%PFALA%"
echo $nRaj = [Math]::Max($nBase,3) >>"%PFALA%"
echo if ($rajMax -eq 2) { $obs = "evento de 2 perdas consecutivas em " + $env + " pacotes (" + $pctTxt + " por cento) - perda contabilizada" } >>"%PFALA%"
echo else { $obs = "alternancia de perdas (" + $alt + " pares proximos) em " + $env + " pacotes (" + $pctTxt + " por cento) - perda contabilizada" } >>"%PFALA%"
echo } >>"%PFALA%"
echo } >>"%PFALA%"
echo elseif ($ev -eq 1) { >>"%PFALA%"
echo $nRaj = NotaPer $pct >>"%PFALA%"
echo if ($pct -le 2) { $obs = "perda de " + $to + " de " + $env + " pacotes (" + $pctTxt + " por cento), sem rajada - contabilizada na classificacao" } >>"%PFALA%"
echo elseif ($pct -le 5) { $obs = [string]$to + " perdas em " + $env + " pacotes (" + $pctTxt + " por cento), sem rajada - contabilizada na classificacao" } >>"%PFALA%"
echo else { $obs = "volume alto de perda (" + $to + " de " + $env + " pacotes, " + $pctTxt + " por cento), sem rajada continua - contabilizada integralmente" } >>"%PFALA%"
echo } >>"%PFALA%"
echo else { $nRaj = 0 } >>"%PFALA%"
echo $nMed = NotaMed ([int]$pmedA[$i]) >>"%PFALA%"
echo $nMax = NotaMax ([int]$pmaxA[$i]) >>"%PFALA%"
echo $nJit = NotaJit ([double]$jitA[$i]) >>"%PFALA%"
echo $nPer = NotaPer $pct >>"%PFALA%"
echo if ($i -eq 0 -and $pct -gt 2) { >>"%PFALA%"
echo $piorFora = -1 >>"%PFALA%"
echo for ($k = 1; $k -le 5; $k = $k + 1) { if ($evA[$k] -ge 0 -and $envA[$k] -gt 0 -and $pctA[$k] -gt $piorFora) { $piorFora = $pctA[$k] } } >>"%PFALA%"
echo if ($piorFora -ge 0 -and $pct -ge (($piorFora * 3) + 2)) { >>"%PFALA%"
echo if ($nPer -gt 2) { $nPer = 2 } >>"%PFALA%"
echo if ($nRaj -gt 2) { $nRaj = 2 } >>"%PFALA%"
echo $obs = "o gateway deixou de responder " + $pctTxt + " por cento dos pings, porem os destinos externos - cujo trafego PASSA por ele - perderam apenas " + $piorFora + " por cento. Perda real no trecho PC-roteador atingiria tambem os externos, entao isto e limitacao de resposta ICMP do proprio roteador e NAO perda de trafego. Nao condena o equipamento." >>"%PFALA%"
echo } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($satur -eq 'S' -and $envLimpo -lt 60) { if ($nMed -gt 2) { $nMed = 2 }; if ($nMax -gt 2) { $nMax = 2 }; if ($nJit -gt 2) { $nJit = 2 }; if ($obs -eq "") { $obs = "sobraram poucas amostras livres de saturacao (" + $env + " pings limpos) - veredito limitado a ACEITAVEL por prudencia; repita sem speedtest para julgar latencia." } } >>"%PFALA%"
echo if ($satur -eq 'S' -and $env -lt 60) { if ($nMed -gt 2) { $nMed = 2 }; if ($nMax -gt 2) { $nMax = 2 }; if ($nJit -gt 2) { $nJit = 2 }; if ($nRaj -gt 2) { $nRaj = 2 } } >>"%PFALA%"
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
echo if ($nJit -gt $pior) { $pior = $nJit; $quem = "jitter (variacao entre pacotes) de " + $jitA[$i] + " ms" } >>"%PFALA%"
echo if ($nPer -eq 0 -and $nRaj -le 1) { >>"%PFALA%"
echo $pm = [int]$pmedA[$i] >>"%PFALA%"
echo if ($pm -le 100 -and $pior -gt 2) { $pior = 2; $quem = "latencia elevada, porem SEM perda e com media usavel" } >>"%PFALA%"
echo elseif ($pm -le 150 -and $pior -gt 3) { $pior = 3; $quem = "latencia alta, porem SEM perda" } >>"%PFALA%"
echo if ($obs -eq "") { $obs = "sem perda de pacotes e ping medio de " + $pm + " ms (dentro do usavel) - a latencia foi anotada como observacao e NAO reprovou o aparelho/link." } >>"%PFALA%"
echo } >>"%PFALA%"
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
:: regra SUSPEITO removida - toda perda entra na classificacao
echo } >>"%PFALA%"
echo Set-Content -Path (Join-Path $pasta "PERDA_PACOTES.csv") -Value $linhasCsv -Encoding UTF8 >>"%PFALA%"
echo $curto = "Teste finalizado. " >>"%PFALA%"
echo $pioresc = 0 >>"%PFALA%"
echo for ($j = 0; $j -lt 6; $j = $j + 1) { if ($evA[$j] -ge 0) { $k = [array]::IndexOf($ESC, $clsA[$j]); if ($k -ge 0 -and $k -gt $pioresc) { $pioresc = $k } } } >>"%PFALA%"
echo if ($pioresc -lt 0) { $pioresc = 0 } >>"%PFALA%"
echo if ($pioresc -gt 6) { $pioresc = 6 } >>"%PFALA%"
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
echo $curto = $curto + "Perda registrada em " + ($suspeitos -join ", ") + "." >>"%PFALA%"
echo [console]::beep(1000,300); [console]::beep(800,300) >>"%PFALA%"
echo } elseif ($atencoes.Count -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Volume alto de perda, sem rajada continua, em " + ($atencoes -join ", ") + "." >>"%PFALA%"
echo [console]::beep(1000,300); [console]::beep(800,300) >>"%PFALA%"
echo } elseif ($totHi -gt 0) { >>"%PFALA%"
echo $curto = $curto + "Sem perda real, com " + $totHi + " picos de ping." >>"%PFALA%"
echo [console]::beep(1200,250); [console]::beep(1600,250) >>"%PFALA%"
echo } else { >>"%PFALA%"
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
echo $diagT += "Perda registrada em: " + ($suspeitos -join ", ") + "." >>"%PFALA%"
echo $diagT += "O padrao observado (evento unico de perdas consecutivas ou alternancia leve) nao encontrou eco nos demais destinos." >>"%PFALA%"
echo $diagT += "Perda registrada apenas em parte dos destinos, com o gateway integro. Repetir o teste para confirmar a extensao." >>"%PFALA%"
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
echo if ($isoExt) { $diagT += "As perdas ocorreram sem rajada continua." } >>"%PFALA%"
echo } >>"%PFALA%"
echo if ($cen -eq 'ISOLADAS') { >>"%PFALA%"
echo $diagT += "O enlace local permanece estavel. Foi registrada perda em destinos externos," >>"%PFALA%"
echo $diagT += "compativeis com limitacao de respostas ICMP ou eventos transitorios da rede." >>"%PFALA%"
echo $diagT += "Nao ha evidencias suficientes para concluir falha no equipamento do cliente." >>"%PFALA%"
echo if ($atenc) { $diagT += "Volume alto de perda em: " + ($atencoes -join ', ') + " - contabilizado na classificacao; correlacionar com jitter." } >>"%PFALA%"
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
echo $sinais += "perda registrada em um unico destino" >>"%PFALA%"
echo } else { >>"%PFALA%"
echo if ($amostraRef -ge 300 -and $nMod -eq 0 -and $nForte -eq 0) { $conf = "ALTA" } else { $conf = "MEDIA" } >>"%PFALA%"
echo $confTxt = "confianca de que NAO ha falha real" >>"%PFALA%"
echo if ($clsA[0] -eq "EXCELENTE") { $sinais += "gateway integro isola o trecho local" } >>"%PFALA%"
echo if ($nIsoPerda -gt 0) { $sinais += "perda sem rajada continua" } >>"%PFALA%"
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
echo $dg += "  Jitter LAN .............: " + $jitLan + " ms (variacao entre pacotes)" >>"%PFALA%"
echo $dg += "  Jitter WAN .............: " + $jitNet + " ms (variacao entre pacotes)" >>"%PFALA%"
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
echo $rel += "  Perda      : 0 %% EXCELENTE / ate 1 %% BOM / ate 2,5 %% ACEITAVEL" >>"%PFALA%"
echo $rel += "  Rajada     : 2 consecutivas com contexto = PROBLEMA DETECTADO" >>"%PFALA%"
echo $rel += "               3 ou mais consecutivas = PROBLEMA GRAVE" >>"%PFALA%"
echo $rel += "               ate 5 %% RUIM / ate 10 %% REPROVADO / ate 25 %% PROBLEMA" >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "  Toda perda registrada entra na classificacao, isolada ou em rajada." >>"%PFALA%"
echo $rel += "  Jitter     : media das diferencas entre pacotes consecutivos" >>"%PFALA%"
echo $rel += "               (RFC 3550). ate 5 ms EXCELENTE / 10 ms BOM /" >>"%PFALA%"
echo $rel += "               20 ms ACEITAVEL / 50 ms RUIM / acima REPROVADO." >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "  METODO: todas as medidas vem de ping (ICMP) e sao INDICATIVAS." >>"%PFALA%"
echo $rel += "  ICMP e tratado com prioridade menor por muitos roteadores, entao" >>"%PFALA%"
echo $rel += "  perda e latencia aqui nao equivalem ao trafego real das aplicacoes." >>"%PFALA%"
echo $rel += "  O ping do Windows tem resolucao de 1 ms: em enlace de fibra muito" >>"%PFALA%"
echo $rel += "  rapido a latencia real pode ser menor do que o exibido." >>"%PFALA%"
echo $rel += "  Para medida com valor contratual, usar TWAMP ou iperf3." >>"%PFALA%"
echo $rel += "" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "COMO LER O SCORE (0 a 100)" >>"%PFALA%"
echo $rel += "---------------------------------------------------------" >>"%PFALA%"
echo $rel += "  90 a 100 : EXCELENTE" >>"%PFALA%"
echo $rel += "  75 a 89  : BOM" >>"%PFALA%"
echo $rel += "  60 a 74  : ACEITAVEL" >>"%PFALA%"
echo $rel += "  40 a 59  : RUIM" >>"%PFALA%"
echo $rel += "  0 a 39   : CRITICO" >>"%PFALA%"
echo $rel += "  Pesos: perda 40%%, latencia media 25%%, jitter 20%%, rajada 15%%." >>"%PFALA%"
echo $rel += "  O score nunca contradiz a classificacao: se o enlace reprovou," >>"%PFALA%"
echo $rel += "  o score fica limitado, mesmo que uma metrica isolada esteja boa." >>"%PFALA%"
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
echo $idxSeg = $pioresc; if ($idxSeg -lt 0) { $idxSeg = 0 }; if ($idxSeg -gt 6) { $idxSeg = 6 } >>"%PFALA%"
echo $topo += "  RESULTADO .: " + $ESC[$idxSeg] >>"%PFALA%"
echo $topo += "  SCORE .....: " + $score + "/100 (" + $scLbl + ")" >>"%PFALA%"
echo $topo += "  Confianca .: " + $conf >>"%PFALA%"
echo $topo += "" >>"%PFALA%"
echo $topo += "  " + $curto >>"%PFALA%"
echo $topo += "=========================================================" >>"%PFALA%"
echo $topo += "" >>"%PFALA%"
echo $rel = $topo + $rel >>"%PFALA%"
echo Set-Content -Path (Join-Path $pasta "VEREDITO.txt") -Value $rel -Encoding UTF8 >>"%PFALA%"
echo $notaGeral = $ESC[$idxSeg] >>"%PFALA%"
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
echo # fala desativada a pedido do usuario (sem Speak) >>"%PFALA%"

:: =========================================================
:: ENVIO PARA O TELEGRAM (tg_send.ps1)
::   - HttpClient: SEMPRE mostra a resposta real da API
::   - Copia segura dos logs antes de zipar (arquivo em uso)
:: =========================================================
set "PTG=%TEMP%\tg_send.ps1"
del "%PTG%" >nul 2>&1
echo param($pasta, $tec, $cliNome, $os, $apar) >>"%PTG%"
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
echo $f2.Add((New-Object System.Net.Http.StringContent(("Laudo completo - Tecnico: " + $tec + " - Cliente: " + $cliNome + " - O.S.: " + $os), [System.Text.Encoding]::UTF8)), "caption") >>"%PTG%"
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
echo $hb = Join-Path $env:TEMP 'lr_hb.flag' >>"%PWAIT%"
echo $fim = (Get-Date).AddSeconds([int]$segundos) >>"%PWAIT%"
echo while ((Get-Date) -lt $fim) { >>"%PWAIT%"
echo try { Set-Content -Path $hb -Value ([string](Get-Date).Ticks) -ErrorAction SilentlyContinue } catch {} >>"%PWAIT%"
echo $rest = [int][math]::Floor(($fim - (Get-Date)).TotalSeconds) >>"%PWAIT%"
echo if ($rest -lt 0) { $rest = 0 } >>"%PWAIT%"
echo $m = [int][math]::Floor($rest / 60) >>"%PWAIT%"
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
echo Write-Host "  Aperte  F  para encerrar agora, falar e enviar ao Telegram." -ForegroundColor Green >>"%PWAIT%"
echo Write-Host "  Ctrl+C aborta tudo e NAO gera laudo nem envia nada." -ForegroundColor Yellow >>"%PWAIT%"
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
    echo break^> "%LAUDO%\_sat_speed.flag"
    echo "%SPEEDEXE%" %SPEEDARGS% ^>^> "%LAUDO%\speedlog.txt" 2^>^&1
    echo del "%LAUDO%\_sat_speed.flag" ^>nul 2^>^&1
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
    echo break^> "%LAUDO%\_sat_fast.flag"
    echo "%FASTEXE%" %FASTARGS% ^>^> "%LAUDO%\fastlog.txt" 2^>^&1
    echo del "%LAUDO%\_sat_fast.flag" ^>nul 2^>^&1
    echo echo. ^>^> "%LAUDO%\fastlog.txt"
    echo timeout /t %INTERVALO_FAST% ^>nul
    echo goto loop
  )
  start "LAUDO_FAST" cmd /k "%TEMP%\fast_loop.bat"
)

:: ABAS 1 a 6 - PINGS AO VIVO COM BIP
echo Abrindo as abas de ping com BIP...
break>"%TEMP%\lr_hb.flag" 2>nul
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

:: ESPERA (F encerra na hora e gera o laudo; Ctrl+C aborta sem laudo)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PWAIT%" %QTD_PING% "%GW%" "%ALVO_INTERNET%" "%MINUTOS%" "%TECNICO%" "%CONEXAO%"

:: =========================================================
:: FINALIZAR
:: =========================================================
:FINALIZAR
cls
echo Encerrando testes e gerando laudo tecnico...
:: 1) apaga o sinal de vida: cada aba de ping percebe e se encerra sozinha.
::    NAO usar taskkill por WINDOWTITLE: no Windows Terminal o titulo da
::    janela e o da aba ativa, e o /T derrubava a janela principal junto.
del "%TEMP%\lr_hb.flag" >nul 2>&1
timeout /t 2 /nobreak >nul

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

powershell -NoProfile -ExecutionPolicy Bypass -File "%PFALA%" "%LAUDO%" "%VOZ_MODO%" "%IPV6_NO_VEREDITO%" "%TEM_IPV6%" "%MINUTOS%" "%TECNICO%" "%CLIENTE%" "%CONEXAO%" "%GW%" "%ALVO_INTERNET%" "%SERVIDOR%" "%IPV6_USADO%" "%ALVO_EXTRA%" "%ALVO_EXTRA_IPV6%" %LIMITE_ROTEADOR% %LIMITE_INTERNET% %LIMITE_SERVIDOR% %LIMITE_IPV6% %LIMITE_EXTRA% %LIMITE_EXTRA_IPV6% "%OS_ID%" "%APARELHOS%" "%SATURA%"

if /i "%TG_ENVIAR%"=="sim" powershell -NoProfile -ExecutionPolicy Bypass -File "%PTG%" "%LAUDO%" "%TECNICO%" "%CLIENTE%" "%OS_ID%" "%APARELHOS%"

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
echo   Toda perda registrada entra na classificacao. Rajada agrava a nota.
echo   A perda so nao condena quando o proprio teste prova ser limite de ICMP.
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
del "%LAUDO%\_sat_speed.flag" "%LAUDO%\_sat_fast.flag" >nul 2>&1
del "%TEMP%\lr_hb.flag" >nul 2>&1
del "%TEMP%\speed_loop.bat" "%TEMP%\fast_loop.bat" "%TEMP%\lr_ver.ps1" "%TEMP%\lr_notas.txt" >nul 2>&1
echo.

:: =========================================================
:: ASSISTENTE DE IA - ate 10 perguntas sobre o teste
:: =========================================================
call :ASSISTENTE_IA

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
choice /c 123 /n /m "  Escolha 1, 2 ou 3: "
set "RESP_UP=%ERRORLEVEL%"
if "%RESP_UP%"=="1" goto FAZER_UPDATE
if "%RESP_UP%"=="2" goto UPDATE_MANUAL
if "%RESP_UP%"=="3" goto RECUSAR_UPDATE
goto MENU_UPDATE

:RECUSAR_UPDATE
color 0C
echo.
echo   #############################################################
echo   #                    A T E N C A O                         #
echo   #############################################################
echo.
echo   Voce escolheu NAO atualizar.
echo.
echo   Rodar uma versao ANTIGA pode causar:
echo     - erros e travamentos ja corrigidos na versao nova;
echo     - diagnostico incorreto ou incompleto;
echo     - envio ao Telegram com problema;
echo     - falta de recursos novos.
echo.
echo   Recomendado: atualizar sempre para a versao mais recente.
echo.
choice /c SN /n /m "  Continuar mesmo assim na versao antiga? [S/N]: "
if errorlevel 2 (color 0A & cls & goto MENU_UPDATE)
color 0A
echo.
echo   Ok, mantendo a versao atual por sua conta e risco.
timeout /t 2 >nul
goto :eof

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
break>"%CFG_DIR%\_t.tmp" 2>nul
if exist "%CFG_DIR%\_t.tmp" (
  del "%CFG_DIR%\_t.tmp" >nul 2>&1
) else (
  set "CFG_DIR=%APPDATA%\LaudoRede"
  set "CFG=%APPDATA%\LaudoRede\config.ini"
  if not exist "%APPDATA%\LaudoRede" mkdir "%APPDATA%\LaudoRede" >nul 2>&1
)
:: re-afirma o caminho final fora do bloco (delayed -> normal)
set "CFG=!CFG!"
set "CFG_DIR=!CFG_DIR!"

if exist "%CFG%" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%CFG%") do (
    if /i "%%a"=="TG_TOKEN" set "TG_TOKEN=%%b"
    if /i "%%a"=="TG_CHAT" set "TG_CHAT=%%b"
    if /i "%%a"=="TG_ENVIAR" set "TG_ENVIAR=%%b"
    if /i "%%a"=="IA_KEY" set "IA_KEY=%%b"
  )
)
if defined TG_TOKEN if defined TG_CHAT if defined IA_KEY goto :eof

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

:: --- chave da IA (assistente no final) - opcional ---
if not defined IA_KEY (
  echo.
  echo   -----------------------------------------------------
  echo   ASSISTENTE DE IA ^(opcional^)
  echo   No final do teste voce pode fazer perguntas a uma IA.
  echo   Precisa de uma chave da DeepSeek. Deixe em branco
  echo   para nao usar.
  echo   -----------------------------------------------------
  set "IA_KEY="
  set /p "IA_KEY=  Cole a chave da IA (ou ENTER para pular): "
  if defined IA_KEY set "IA_KEY=%IA_KEY:"=%"
  if not defined IA_KEY set "IA_KEY=x"
)

:GRAVA_CONFIG
>"%CFG%" echo TG_ENVIAR=%TG_ENVIAR%
>>"%CFG%" echo TG_TOKEN=%TG_TOKEN%
>>"%CFG%" echo TG_CHAT=%TG_CHAT%
>>"%CFG%" echo IA_KEY=%IA_KEY%
echo.
echo   Configuracao salva em %CFG%
timeout /t 2 >nul
goto :eof

:: =========================================================
:: SUB-ROTINA: ASSISTENTE DE IA (OpenRouter)
::   - ate 10 perguntas por execucao
::   - manda os dados do teste junto para respostas uteis
::   - a chave vem do config (IA_KEY), nunca do codigo
:: =========================================================
:ASSISTENTE_IA
if not defined IA_KEY goto IA_SEM_CHAVE
if /i "%IA_KEY%"=="x" goto IA_SEM_CHAVE

:: monta um resumo curto do teste pra dar contexto a IA
set "CTX=DADOS DO TESTE (unica fonte de numeros). O.S.: %OS_ID%. Tecnico: %TECNICO%. Cliente: %CLIENTE%. Equipamentos que o tecnico informou estarem no local: %APARELHOS% (isto NAO e contagem de dispositivos na rede). Conexao do PC de teste: %CONEXAO%. Gateway: %GW%. Speedtest rodando durante a coleta (S/N): %SATURA% - se S, ping alto e esperado por saturacao, nao conte como defeito. NAO MEDIDO NESTE TESTE: quantidade de dispositivos conectados, potencia optica, canal Wi-Fi, velocidade contratada, consumo de banda. As medidas vem de ping (ICMP) e sao indicativas, nao equivalem ao trafego real. O jitter informado e a media das diferencas entre pacotes consecutivos (RFC 3550), nao a amplitude maximo menos minimo. Medicoes por destino a seguir:"
if exist "%LAUDO%\PERDA_PACOTES.csv" (
  for /f "usebackq skip=1 tokens=1,4,6,7,9 delims=;" %%a in ("%LAUDO%\PERDA_PACOTES.csv") do (
    set "CTX=!CTX! [destino %%a: perda %%b por cento, ping medio %%c ms, ping maximo %%d ms, classificacao %%e]"
  )
)

:: =========================================================
:: 1) LAUDO AUTOMATICO DA IA (analise do teste)
:: =========================================================
echo.
echo =====================================================
echo          ANALISE DA IA - LAUDO AUTOMATICO
echo =====================================================
echo.
echo   Analisando o resultado do teste, aguarde...
> "%TEMP%\ia_ctx.txt" echo %CTX%
>> "%TEMP%\ia_ctx.txt" echo ###PERGUNTA###
>> "%TEMP%\ia_ctx.txt" echo Analise este teste e escreva um laudo tecnico curto: 1 - situacao geral da conexao; 2 - se o problema e local do cliente ou de fora (operadora), ou se esta tudo certo; 3 - o que o tecnico deve fazer agora. Use SOMENTE os numeros que estao em DADOS DO TESTE. Nao cite quantidade de aparelhos conectados, potencia optica, canal nem velocidade contratada, pois nada disso foi medido.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PIA%" "%IA_KEY%" "%LAUDO%\LAUDO_IA.txt"
echo.
echo   -----------------------------------------------------
echo   A IA pode cometer erros. Confira sempre os numeros do
echo   laudo tecnico ^(VEREDITO.txt^) antes de decidir.
echo   -----------------------------------------------------
if exist "%LAUDO%\LAUDO_IA.txt" echo   Analise salva em: %LAUDO%\LAUDO_IA.txt
echo.

:: =========================================================
:: 2) ASSISTENTE - ate 10 perguntas
:: =========================================================
echo.
echo =====================================================
echo             ASSISTENTE DE IA
echo =====================================================
echo.
echo   Voce pode fazer ate 10 perguntas sobre o teste
echo   ou sobre redes em geral. Digite "sair" para encerrar.
echo.

set "NPERG=0"
:LOOP_IA
if %NPERG% GEQ 10 (
  echo.
  echo   Limite de 10 perguntas atingido.
  goto :eof
)
set /a "SOBRAM=10-%NPERG%"
echo.
echo   (Perguntas restantes: %SOBRAM%)
set "PERG="
set /p "PERG=  Sua pergunta: "
if not defined PERG goto LOOP_IA
if /i "%PERG%"=="sair" goto :eof
set /a "NPERG=%NPERG%+1"

:: grava a pergunta e o contexto num arquivo pro powershell ler (evita problema de aspas)
> "%TEMP%\ia_ctx.txt" echo %CTX%
>> "%TEMP%\ia_ctx.txt" echo ###PERGUNTA###
>> "%TEMP%\ia_ctx.txt" echo %PERG%

echo.
echo   Consultando a IA...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PIA%" "%IA_KEY%"
goto LOOP_IA

:IA_SEM_CHAVE
echo.
echo   -----------------------------------------------------
echo   ASSISTENTE DE IA nao ativado neste computador.
echo   Nao ha chave da IA no arquivo de configuracao:
echo   %CFG%
echo   Falta a linha  IA_KEY=  com a chave da DeepSeek.
echo   Sem ela nao tem analise automatica nem perguntas.
echo   -----------------------------------------------------
timeout /t 6 >nul
goto :eof

:: =========================================================
:: GRAVA a base de conhecimento (para a IA consultar)
::   fica em ProgramData\LaudoRede\base_conhecimento.txt
:: =========================================================
:: tenta preparar o arquivo da base na pasta %KB_DIR% (testa o ARQUIVO, nao so a pasta)
:KB_TENTAR
set "KB_OK="
if not exist "%KB_DIR%" mkdir "%KB_DIR%" >nul 2>&1
if not exist "%KB_DIR%" goto :eof
set "KB=%KB_DIR%\base_conhecimento.txt"
attrib -r -h -s "%KB%" >nul 2>&1
del "%KB%" >nul 2>&1
if exist "%KB%" goto :eof
break>"%KB%" 2>nul
if exist "%KB%" set "KB_OK=1"
goto :eof

:GRAVAR_BASE
set "KB_OK="
set "KB_DIR=%ProgramData%\LaudoRede"
call :KB_TENTAR
if defined KB_OK goto KB_PRONTO
set "KB_DIR=%APPDATA%\LaudoRede"
call :KB_TENTAR
if defined KB_OK goto KB_PRONTO
set "KB_DIR=%TEMP%\LaudoRede"
call :KB_TENTAR
if defined KB_OK goto KB_PRONTO
echo.
echo   [AVISO] Nao consegui gravar a base de conhecimento.
echo           A IA vai responder so com os dados do teste.
goto :eof

:KB_PRONTO
echo BASE DE CONHECIMENTO TECNICA - REDES FTTH/GPON/WI-FI  ^(v2 EXPANDIDA^)>>"%KB%"
echo Manual de referencia para o assistente de IA do LAUDO DE REDE.>>"%KB%"
echo Responda o tecnico usando estas informacoes com precisao e objetividade.>>"%KB%"
echo Portugues do Brasil, direto e pratico. Nunca inventar numero.>>"%KB%"
echo.>>"%KB%"
echo INDICE>>"%KB%"
echo  1  FIBRA OPTICA E GPON>>"%KB%"
echo  2  WI-FI>>"%KB%"
echo  3  MEDIDAS DE REDE ^(PING, JITTER, PERDA, MTU, BUFFERBLOAT^)>>"%KB%"
echo  4  PROBLEMAS COMUNS E SOLUCOES>>"%KB%"
echo  5  PROCEDIMENTOS RAPIDOS ^(CMD, DNS, TESTES^)>>"%KB%"
echo  6  EQUIPAMENTOS E TERMOS>>"%KB%"
echo  7  COMO O ASSISTENTE DEVE RESPONDER>>"%KB%"
echo  8  CONFIGURACAO DE ROTEADORES>>"%KB%"
echo  9  CASOS DE CAMPO ^(exemplos reais^)>>"%KB%"
echo 10  CABOS DE REDE>>"%KB%"
echo 11  REFERENCIA RAPIDA ^(TABELA MENTAL^)>>"%KB%"
echo 12  AUTENTICACAO E ENDERECAMENTO ^(PPPoE, IPoE, DHCP^)>>"%KB%"
echo 13  IPv6, CGNAT E ABERTURA DE PORTAS ^(JOGO/CAMERA^)>>"%KB%"
echo 14  DNS EM PROFUNDIDADE>>"%KB%"
echo 15  VoIP / TELEFONIA NA ONU>>"%KB%"
echo 16  IPTV / STREAMING / MULTICAST>>"%KB%"
echo 17  TR-069 / PROVISIONAMENTO REMOTO ^(ACS^)>>"%KB%"
echo 18  SEGURANCA DE REDE>>"%KB%"
echo 19  MARCAS E MODELOS COMUNS NO BRASIL>>"%KB%"
echo 20  FERRAMENTAS DE DIAGNOSTICO ^(SOFTWARE E CAMPO^)>>"%KB%"
echo 21  MESH x REPETIDOR x AP x PLC>>"%KB%"
echo 22  GLOSSARIO GRANDE>>"%KB%"
echo 23  FLUXOGRAMAS DE DECISAO ^(ARVORE DE ATENDIMENTO^)>>"%KB%"
echo 24  ERROS E MITOS COMUNS>>"%KB%"
echo 25  CASOS DE CAMPO AVANCADOS>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 1 - FIBRA OPTICA E GPON>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 1.1 POTENCIA OPTICA RECEBIDA ^(Rx^) NA ONU ===>>"%KB%"
echo Faixa do padrao GPON ^(luz que a ONU RECEBE da rede^):>>"%KB%"
echo - -8 a -20 dBm  = BOM/OTIMO. Trabalha tranquilo.>>"%KB%"
echo - -21 a -24 dBm = ACEITAVEL. Funciona, fique de olho.>>"%KB%"
echo - -25 a -26 dBm = FRACO. Instabilidade comeca a aparecer.>>"%KB%"
echo - -27 dBm       = LIMITE. Muito perto de cair.>>"%KB%"
echo - abaixo de -27 = CRITICO. ONU perde sync ^(LOS acende^).>>"%KB%"
echo - acima de -8 ^(ex -5, -3^) = FORTE DEMAIS. Satura o receptor,>>"%KB%"
echo   da erro de CRC, precisa de atenuador optico.>>"%KB%"
echo LEMBRE: mais negativo = mais fraco. -18 e melhor que -25.>>"%KB%"
echo Diferenca de 3 dB = metade ^(ou dobro^) da potencia.>>"%KB%"
echo Diferenca de 10 dB = 10x mais/menos potencia.>>"%KB%"
echo.>>"%KB%"
echo === 1.2 POTENCIA TRANSMITIDA ^(Tx^) PELA ONU ===>>"%KB%"
echo Normal: +0.5 a +5 dBm.>>"%KB%"
echo - Tx muito baixo ou muito alto = ONU com defeito no laser.>>"%KB%"
echo - Tx zero = ONU nao esta transmitindo ^(defeito ou desligada^).>>"%KB%"
echo - Tx alto demais junto com Rx normal pode indicar ONU forcando>>"%KB%"
echo   laser por temperatura ou fim de vida do componente.>>"%KB%"
echo.>>"%KB%"
echo === 1.3 COMPRIMENTOS DE ONDA ^(WAVELENGTHS^) NO GPON ===>>"%KB%"
echo - 1490 nm = downstream ^(OLT -^> ONU^), os dados que chegam.>>"%KB%"
echo - 1310 nm = upstream ^(ONU -^> OLT^), os dados que sobem.>>"%KB%"
echo - 1550 nm = video overlay/RF ^(CATV^), quando existe TV na fibra.>>"%KB%"
echo Em XGS-PON muda: 1577 nm down e 1270 nm up.>>"%KB%"
echo Nunca olhar direto na fibra: laser invisivel, cega de verdade.>>"%KB%"
echo.>>"%KB%"
echo === 1.4 GPON x XGS-PON x EPON ^(diferencas^) ===>>"%KB%"
echo - GPON: 2.488 Gbps down / 1.244 Gbps up ^(compartilhado no PON^).>>"%KB%"
echo - XGS-PON: 10 Gbps simetrico. Usado em planos altos/empresarial.>>"%KB%"
echo - EPON/10G-EPON: padrao alternativo, menos comum no BR residencial.>>"%KB%"
echo O compartilhamento e por PON: varios clientes dividem a banda do>>"%KB%"
echo splitter. Por isso ^"a noite fica lento^" pode ser saturacao do PON.>>"%KB%"
echo.>>"%KB%"
echo === 1.5 ATENUACAO / PERDA NA FIBRA ===>>"%KB%"
echo Cada elemento tira um pouco do sinal:>>"%KB%"
echo - Fibra: ~0.3 a 0.4 dB por km ^(1490nm downstream^).>>"%KB%"
echo - Conector: ~0.3 a 0.5 dB cada.>>"%KB%"
echo - Emenda por fusao: ~0.05 a 0.1 dB ^(boa emenda^).>>"%KB%"
echo - Emenda mecanica: ~0.1 a 0.3 dB ^(pior que fusao^).>>"%KB%"
echo - Splitter 1:2  = ~3.5 dB de perda.>>"%KB%"
echo - Splitter 1:4  = ~7 dB de perda.>>"%KB%"
echo - Splitter 1:8  = ~10.5 dB de perda.>>"%KB%"
echo - Splitter 1:16 = ~13.5 dB de perda.>>"%KB%"
echo - Splitter 1:32 = ~17 dB de perda.>>"%KB%"
echo - Splitter 1:64 = ~20.5 dB de perda.>>"%KB%"
echo - Splitter 1:128 = ~24 dB ^(limite, cascateado^).>>"%KB%"
echo Quanto maior o splitter, menos sinal sobra para cada cliente.>>"%KB%"
echo CONTA RAPIDA de orcamento optico: potencia da OLT ^(ex +5 dBm^)>>"%KB%"
echo menos as perdas do caminho = quanto chega na ONU.>>"%KB%"
echo.>>"%KB%"
echo === 1.6 CAUSAS DE SINAL OPTICO RUIM ^(ordem de frequencia^) ===>>"%KB%"
echo 1. Conector sujo ^(poeira/gordura/dedo na ponta^) - MAIS COMUM.>>"%KB%"
echo 2. Fibra dobrada/curva fechada ^(atras de movel, enrolada apertada^).>>"%KB%"
echo 3. Conector frouxo ou mal encaixado.>>"%KB%"
echo 4. Patch cord ruim, velho ou pisado/prensado.>>"%KB%"
echo 5. Conector queimado ^(por sinal forte em manutencao anterior^).>>"%KB%"
echo 6. Emenda ruim na rede.>>"%KB%"
echo 7. Splitter sobrecarregado.>>"%KB%"
echo 8. Distancia grande / muitas emendas acumuladas.>>"%KB%"
echo 9. CTO ^(caixa na rua^) com infiltracao ou conector oxidado.>>"%KB%"
echo 10. Raio de curvatura violado ^(fibra APC forcada em cantos vivos^).>>"%KB%"
echo.>>"%KB%"
echo === 1.7 COMO MELHORAR O SINAL OPTICO ^(procedimento^) ===>>"%KB%"
echo 1. Desligar a ONU antes de mexer na fibra ^(seguranca do laser^).>>"%KB%"
echo 2. Retirar o conector e limpar a ponta ^(caneta de limpeza optica>>"%KB%"
echo    ou lenco proprio sem fiapo, com movimento unico^).>>"%KB%"
echo 3. Verificar visualmente se a ponta nao esta lascada/arranhada.>>"%KB%"
echo 4. Reencaixar firme ate ouvir/sentir o click.>>"%KB%"
echo 5. Conferir se a fibra nao esta dobrada em nenhum ponto do trajeto.>>"%KB%"
echo 6. Se possivel, trocar o patch cord por um novo e testar.>>"%KB%"
echo 7. Religar a ONU e aguardar sincronizar ^(luz PON verde^).>>"%KB%"
echo 8. Se o sinal continuar ruim, o problema esta na rede externa>>"%KB%"
echo    ^(drop, CTO, splitter^) - acionar a equipe externa.>>"%KB%"
echo NUNCA olhar direto na ponta da fibra ^(laser invisivel, dana a vista^).>>"%KB%"
echo.>>"%KB%"
echo === 1.8 CONECTORES OPTICOS ^(APC x UPC^) ===>>"%KB%"
echo - APC ^(verde^): polimento angular 8 graus, menor reflexao. Padrao FTTH.>>"%KB%"
echo - UPC ^(azul^): polimento reto. Usado em outros contextos.>>"%KB%"
echo NUNCA misturar APC com UPC: encaixa mas gera perda alta e reflexao,>>"%KB%"
echo pode ate danificar a ferula. Cor do conector: verde=APC, azul=UPC.>>"%KB%"
echo.>>"%KB%"
echo === 1.9 LUZES DA ONU/ONT ===>>"%KB%"
echo - POWER/PWR: alimentacao. Apagada = sem energia ^(fonte/tomada/botao^).>>"%KB%"
echo - PON: sincronismo com a OLT.>>"%KB%"
echo    * Verde fixa = sincronizada, tudo certo.>>"%KB%"
echo    * Piscando = procurando/negociando sinal.>>"%KB%"
echo    * Apagada = nem tenta ^(ver fibra/LOS^).>>"%KB%"
echo - LOS: perda de sinal optico.>>"%KB%"
echo    * Apagada = TEM sinal ^(bom^).>>"%KB%"
echo    * Vermelha ^(fixa ou piscando^) = SEM sinal optico. Prioridade.>>"%KB%"
echo      Fibra cortada, conector solto, sinal fraco demais.>>"%KB%"
echo - LAN/1-4: porta de cabo. Acende com cabo conectado a um aparelho.>>"%KB%"
echo - WLAN/Wi-Fi/2.4G/5G: redes sem fio ligadas.>>"%KB%"
echo - TEL/PHONE: linha de telefone ^(ONU com voz^).>>"%KB%"
echo - INTERNET/WAN: autenticacao ^(PPPoE^) ok quando fixa.>>"%KB%"
echo REGRA: LOS vermelha = nada de internet ate resolver o optico.>>"%KB%"
echo Nao adianta reiniciar ONU nem mexer no Wi-Fi com LOS vermelha.>>"%KB%"
echo.>>"%KB%"
echo === 1.10 ESTADOS DA ONU E MENSAGENS DA OLT ===>>"%KB%"
echo - LOS = Loss of Signal ^(sem luz chegando^).>>"%KB%"
echo - LOSi/LOSS = perda de sinal daquela ONU especifica.>>"%KB%"
echo - Dying Gasp = ONU avisa a OLT ^"vou desligar^" quando cai energia.>>"%KB%"
echo   Ajuda a operadora saber que foi falta de luz, nao defeito.>>"%KB%"
echo - Rogue ONU = ONU defeituosa transmitindo fora de hora, derruba>>"%KB%"
echo   o PON inteiro ^(varios clientes caem juntos^). Caso da operadora.>>"%KB%"
echo - Estados O1..O5: negociacao ate a ONU ficar operacional ^(O5=ativa^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 2 - WI-FI>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 2.1 SINAL WI-FI: %% vs dBm ===>>"%KB%"
echo O Windows mostra QUALIDADE em %% ^(0-100^), NAO dBm. Escalas diferentes.>>"%KB%"
echo Relacao aproximada ^(nao exata^):>>"%KB%"
echo - 100%% ~ -30 dBm ^| 90%% ~ -42 ^| 80%% ~ -50 ^| 70%% ~ -58>>"%KB%"
echo - 60%% ~ -63 ^| 50%% ~ -67 ^| 40%% ~ -72 ^| 30%% ~ -76>>"%KB%"
echo - 25%% ~ -80 ^| 10%% ~ -85 ^| 0%% ~ -90>>"%KB%"
echo Para dBm exato, medir no proprio aparelho.>>"%KB%"
echo.>>"%KB%"
echo Escala dBm ^(medida real^):>>"%KB%"
echo - -30 otimo ^| -50 muito bom ^| -60 bom ^| -67 limite aceitavel>>"%KB%"
echo - -70 fraco ^| -80 ruim ^| -90 sem conexao util>>"%KB%"
echo Abaixo de -67 dBm, video HD e jogos ja sentem.>>"%KB%"
echo.>>"%KB%"
echo === 2.2 SNR ^(RELACAO SINAL/RUIDO^) ===>>"%KB%"
echo Nao basta sinal forte: importa o quanto ele se destaca do ruido.>>"%KB%"
echo - SNR acima de 40 dB = excelente.>>"%KB%"
echo - 25 a 40 dB = bom.>>"%KB%"
echo - 15 a 25 dB = aceitavel ^(velocidade cai^).>>"%KB%"
echo - abaixo de 15 dB = ruim, muita retransmissao.>>"%KB%"
echo Sinal -50 dBm num lugar cheio de vizinhos pode render pior que>>"%KB%"
echo -60 dBm num canal limpo. Ruido derruba a velocidade real.>>"%KB%"
echo.>>"%KB%"
echo === 2.3 GERACOES WI-FI ===>>"%KB%"
echo - Wi-Fi 4 ^(802.11n^): 2.4 e 5 GHz. ~150-600 Mbps. Antigo mas comum.>>"%KB%"
echo - Wi-Fi 5 ^(802.11ac^): so 5 GHz. ~433 Mbps a 3.5 Gbps. Padrao atual.>>"%KB%"
echo - Wi-Fi 6 ^(802.11ax^): 2.4/5 GHz. Melhor com muitos aparelhos, menor>>"%KB%"
echo   latencia, mais bateria nos dispositivos. Otimo para casa cheia.>>"%KB%"
echo - Wi-Fi 6E: Wi-Fi 6 + faixa 6 GHz ^(nova, muito limpa, sem vizinhos ainda^).>>"%KB%"
echo - Wi-Fi 7 ^(802.11be^): 2.4/5/6 GHz. Canais de 320 MHz, MLO, latencia baixissima.>>"%KB%"
echo Aparelho so conecta na geracao que ELE suporta, mesmo com roteador novo.>>"%KB%"
echo.>>"%KB%"
echo === 2.4 BANDAS 2.4 vs 5 vs 6 GHz ===>>"%KB%"
echo 2.4 GHz:>>"%KB%"
echo - Alcance MAIOR, atravessa parede melhor.>>"%KB%"
echo - Mais LENTA, mais interferencia ^(micro-ondas, bluetooth, vizinhos^).>>"%KB%"
echo - Boa para: aparelhos longe, IoT ^(camera, lampada^), casa grande.>>"%KB%"
echo 5 GHz:>>"%KB%"
echo - MAIS RAPIDA e limpa.>>"%KB%"
echo - Alcance MENOR, parede atrapalha mais.>>"%KB%"
echo - Boa para: aparelhos perto, streaming 4K, jogos, download.>>"%KB%"
echo 6 GHz ^(Wi-Fi 6E/7^):>>"%KB%"
echo - Mais rapida e limpissima ^(poucos aparelhos ainda^).>>"%KB%"
echo - Alcance ainda menor. So funciona em aparelho compativel.>>"%KB%"
echo Muitos roteadores tem as bandas com o mesmo nome ^(band steering^) e>>"%KB%"
echo escolhem sozinho. As vezes vale separar em nomes ^(ex: ^"Casa^" e ^"Casa_5G^"^).>>"%KB%"
echo.>>"%KB%"
echo === 2.5 CANAIS WI-FI E LARGURA DE CANAL ===>>"%KB%"
echo 2.4 GHz: use SOMENTE 1, 6 ou 11 ^(os unicos que nao se sobrepoem^).>>"%KB%"
echo Se estiver em outro canal com vizinhos, mude para um desses.>>"%KB%"
echo 5 GHz: mais canais. Os DFS ^(52 a 144^) podem sumir segundos se>>"%KB%"
echo detectam radar ^(perto de aeroporto/meteorologia^).>>"%KB%"
echo LARGURA DE CANAL:>>"%KB%"
echo - 20 MHz: mais estavel, menos velocidade. Bom pra 2.4 lotado.>>"%KB%"
echo - 40 MHz: meio termo.>>"%KB%"
echo - 80 MHz: padrao em 5 GHz, boa velocidade.>>"%KB%"
echo - 160 MHz: velocidade alta mas sofre com interferencia/DFS.>>"%KB%"
echo Em 2.4 GHz NUNCA use 40 MHz num ambiente cheio: ocupa tudo e piora.>>"%KB%"
echo Sinais de canal lotado: ping instavel, quedas rapidas, lentidao>>"%KB%"
echo mesmo com bom sinal. Use um app analisador para achar canal livre.>>"%KB%"
echo.>>"%KB%"
echo === 2.6 LINK RATE x VELOCIDADE REAL ===>>"%KB%"
echo O ^"conectado a 866 Mbps^" e a TAXA DE LINK ^(negociacao^), NAO a>>"%KB%"
echo velocidade real. A real costuma ser 40-60%% disso por overhead,>>"%KB%"
echo retransmissao e meio compartilhado. Link 300 Mbps normalmente>>"%KB%"
echo entrega ~150-180 Mbps reais. Isso e normal do Wi-Fi.>>"%KB%"
echo.>>"%KB%"
echo === 2.7 MELHORAR O WI-FI ===>>"%KB%"
echo - Roteador em local alto, central, longe de metal/espelho/aquario.>>"%KB%"
echo - Longe de micro-ondas e telefone sem fio.>>"%KB%"
echo - Antenas: uma na vertical, outra inclinada, ajuda a cobrir andares.>>"%KB%"
echo - Aparelho longe -^> usar 2.4 GHz OU repetidor/mesh.>>"%KB%"
echo - Trocar canal se ha muitos vizinhos.>>"%KB%"
echo - Atualizar firmware do roteador.>>"%KB%"
echo - Casa grande/varios andares -^> sistema Mesh e melhor que repetidor.>>"%KB%"
echo - Reduzir largura de canal se houver muita interferencia.>>"%KB%"
echo.>>"%KB%"
echo === 2.8 ROAMING ^(802.11 k/v/r^) E ^"STICKY CLIENT^" ===>>"%KB%"
echo Com mesh ou varios APs, o celular pode ^"grudar^" ^(sticky^) num ponto>>"%KB%"
echo fraco em vez de trocar pro mais forte. Padroes k/v/r ajudam o>>"%KB%"
echo handoff. Sintoma: anda pela casa e o sinal fica fraco mesmo perto>>"%KB%"
echo de outro ponto. Solucao: mesmo SSID/senha, roaming assistido ligado.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 3 - MEDIDAS DE REDE ^(PING, JITTER, PERDA^)>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 3.1 LATENCIA / PING ===>>"%KB%"
echo - 0-30 ms   = excelente ^(jogo, video-chamada sem problema^)>>"%KB%"
echo - 30-60 ms  = bom ^(uso geral tranquilo^)>>"%KB%"
echo - 60-100 ms = aceitavel ^(navega bem; jogo competitivo sente^)>>"%KB%"
echo - 100-150 ms = ruim ^(video trava, jogo ruim^)>>"%KB%"
echo - +150 ms = pessimo para tempo real>>"%KB%"
echo Ping ATE o gateway/roteador:>>"%KB%"
echo - Cabo: 1-5 ms ^| Wi-Fi: 1-30 ms ^(conforme sinal^).>>"%KB%"
echo Ping alto ate o PROPRIO roteador = problema LOCAL, nao da operadora.>>"%KB%"
echo.>>"%KB%"
echo === 3.2 JITTER ===>>"%KB%"
echo Jitter = variacao do ping ^(maior menos menor^).>>"%KB%"
echo - ate 20 ms otimo ^| 20-50 bom ^| 50-100 atencao ^| +100 ruim.>>"%KB%"
echo Jitter alto = voz picotando, video travando MESMO com boa velocidade.>>"%KB%"
echo Vilao classico do ^"minha net e rapida mas trava^".>>"%KB%"
echo.>>"%KB%"
echo === 3.3 PERDA DE PACOTES ===>>"%KB%"
echo - 0%% perfeito ^| ate 1%% normal ^| 1-2.5%% atencao>>"%KB%"
echo - +2.5%% problema ^| +5%% grave>>"%KB%"
echo REGRAS DE OURO ^(nao condenar link a toa^):>>"%KB%"
echo - Perda SO no gateway = LOCAL ^(cabo/Wi-Fi/roteador do cliente^).>>"%KB%"
echo - Perda so DEPOIS do gateway ^(gateway limpo^) = FORA ^(operadora/rota^),>>"%KB%"
echo   NAO condena equipamento do cliente.>>"%KB%"
echo - Toda perda medida entra na classificacao do laudo, isolada ou nao.>>"%KB%"
echo   NAO e perda real. Nao reprovar link por isso.>>"%KB%"
echo - Pico unico de ping, sem jitter alto e sem perda, NAO reprova.>>"%KB%"
echo.>>"%KB%"
echo === 3.4 BUFFERBLOAT ===>>"%KB%"
echo Latencia baixa parada, mas explode quando ha download/upload pesado.>>"%KB%"
echo Sintoma: ^"quando alguem baixa, o jogo/chamada trava^". Mesmo com>>"%KB%"
echo velocidade contratada ok. Causa: fila grande no roteador/link.>>"%KB%"
echo Alivio: QoS/SQM no roteador, limitar downloads, roteador melhor.>>"%KB%"
echo Teste: medir ping ocioso e ping durante um speedtest; se sobe muito>>"%KB%"
echo ^(ex 20ms -^> 200ms^), tem bufferbloat.>>"%KB%"
echo.>>"%KB%"
echo === 3.5 MTU E FRAGMENTACAO ===>>"%KB%"
echo MTU padrao ethernet = 1500. Em PPPoE cai pra 1492 ^(overhead de 8^).>>"%KB%"
echo MTU errado causa: sites carregam pela metade, alguns abrem outros nao,>>"%KB%"
echo VPN falha. Sintoma classico: ping normal funciona mas paginas travam.>>"%KB%"
echo Teste: ping -f -l 1472 8.8.8.8 ^(1472+28=1500^). Se der ^"fragmentado^",>>"%KB%"
echo o MTU do caminho e menor. Ajustar MTU no roteador ^(ex 1492 em PPPoE^).>>"%KB%"
echo.>>"%KB%"
echo === 3.6 TRACEROUTE / PATHPING ^(LER O CAMINHO^) ===>>"%KB%"
echo tracert mostra cada salto ate o destino.>>"%KB%"
echo - Primeiros saltos = rede local + operadora.>>"%KB%"
echo - Um salto com * * * pode ser so ICMP bloqueado ^(normal^), NAO e queda.>>"%KB%"
echo - Latencia que sobe e SE MANTEM alta a partir de um salto = gargalo ali.>>"%KB%"
echo - Ultimo salto ruim, resto ok = problema no destino, nao na conexao.>>"%KB%"
echo pathping ^(Windows^) mede perda por salto ao longo do tempo ^(demora^).>>"%KB%"
echo.>>"%KB%"
echo === 3.7 DIAGNOSTICO POR TRECHO ^(onde esta o problema^) ===>>"%KB%"
echo - Ruim SO no roteador -^> LOCAL ^(Wi-Fi longe, cabo, roteador^).>>"%KB%"
echo - Roteador OK, internet ruim -^> caminho da OPERADORA.>>"%KB%"
echo - Perda cresce conforme sai -^> ROTA/operadora.>>"%KB%"
echo - Tudo ruim junto -^> saturacao do link OU acesso/optico ^(ONU^).>>"%KB%"
echo - Ruim so a noite -^> saturacao ^(horario de pico^).>>"%KB%"
echo - Ruim so num site/servico -^> problema daquele servico, nao da conexao.>>"%KB%"
echo SEMPRE olhar o gateway primeiro: separa problema do cliente do de fora.>>"%KB%"
echo Isso evita abrir chamado errado na operadora.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 4 - PROBLEMAS COMUNS E SOLUCOES>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 4.1 CONECTIVIDADE ===>>"%KB%"
echo - ^"Cai so no Wi-Fi, cabo funciona^" -^> Wi-Fi. Aproximar, mudar canal,>>"%KB%"
echo    ver banda ^(2.4 vs 5^), atualizar firmware, considerar mesh.>>"%KB%"
echo - ^"Sem internet em tudo, LOS vermelha^" -^> optico. Limpar/reencaixar>>"%KB%"
echo    conector, ver fibra dobrada. Persistiu = rede externa.>>"%KB%"
echo - ^"Sem internet, LOS apagada e PON verde^" -^> nao e optico. Ver se e>>"%KB%"
echo    IP ^(release/renew^), DNS, PPPoE caido, ou config do roteador.>>"%KB%"
echo - ^"Cai sozinho de tempos em tempos^" -^> sinal optico no limite ^(-25 a -27^),>>"%KB%"
echo    Wi-Fi com interferencia, ONU superaquecendo, ou fonte fraca.>>"%KB%"
echo.>>"%KB%"
echo === 4.2 SITE / NAVEGACAO ===>>"%KB%"
echo - ^"Site nao abre mas WhatsApp/ping funciona^" -^> DNS. Trocar para>>"%KB%"
echo    8.8.8.8 / 8.8.4.4 ^(Google^) ou 1.1.1.1 ^(Cloudflare^).>>"%KB%"
echo - ^"So um site nao abre^" -^> problema daquele site ou bloqueio, nao da net.>>"%KB%"
echo - ^"Navega lento mas ping ok^" -^> pode ser DNS lento ou Wi-Fi fraco.>>"%KB%"
echo - ^"Alguns sites abrem, outros nao ^(metade da pagina^)^" -^> suspeitar de MTU.>>"%KB%"
echo.>>"%KB%"
echo === 4.3 VELOCIDADE ===>>"%KB%"
echo - ^"Velocidade menor que o plano^" -^> testar no CABO. Cabo bate o plano>>"%KB%"
echo    = problema e o Wi-Fi. Cabo tambem nao bate = link/optico/operadora.>>"%KB%"
echo - ^"Upload muito baixo^" -^> em GPON pode ser sinal optico ruim ou saturacao.>>"%KB%"
echo - ^"Speedtest bom mas tudo trava^" -^> nao e velocidade, e jitter/perda/bufferbloat.>>"%KB%"
echo - Pequena diferenca do plano e normal ^(overhead ~10%%^). Grande nao e.>>"%KB%"
echo - Placa/porta a 100 Mbps limita mesmo com plano gigabit.>>"%KB%"
echo.>>"%KB%"
echo === 4.4 TEMPO REAL ^(jogo, chamada, video^) ===>>"%KB%"
echo - ^"Jogo com lag/ping alto^" -^> latencia e jitter, NAO velocidade.>>"%KB%"
echo    Preferir cabo, 5 GHz perto do roteador, fechar downloads.>>"%KB%"
echo - ^"Chamada de video picotando^" -^> jitter/perda. Mesmo com net rapida.>>"%KB%"
echo - ^"Live/stream travando ao SUBIR^" -^> upload baixo ou instavel.>>"%KB%"
echo - ^"Jogo online nao conecta / NAT restrito^" -^> CGNAT/porta ^(ver PARTE 13^).>>"%KB%"
echo.>>"%KB%"
echo === 4.5 INTERMITENCIA / HORARIO ===>>"%KB%"
echo - ^"So a noite fica ruim^" -^> saturacao ^(pico^). Cabo tambem ruim = link>>"%KB%"
echo    do provedor no pico. So Wi-Fi = interferencia ^(vizinhos ligam tudo^).>>"%KB%"
echo - ^"Melhora quando reinicia e piora com o tempo^" -^> ONU/roteador>>"%KB%"
echo    esquentando ou vazamento de memoria; ver ventilacao e firmware.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 5 - PROCEDIMENTOS RAPIDOS>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 5.1 LIMPAR CONEXAO ^(IP travado^) ===>>"%KB%"
echo No CMD ^(como admin^):>>"%KB%"
echo - ipconfig /flushdns   ^(limpa cache DNS - nao precisa admin^)>>"%KB%"
echo - ipconfig /release    ^(solta o IP - precisa admin^)>>"%KB%"
echo - ipconfig /renew      ^(pega IP novo - precisa admin^)>>"%KB%"
echo - arp -d *             ^(limpa tabela ARP - precisa admin^)>>"%KB%"
echo - netsh int ip reset   ^(reseta pilha TCP/IP - precisa reiniciar^)>>"%KB%"
echo - netsh winsock reset  ^(reseta winsock - precisa reiniciar^)>>"%KB%"
echo Util depois de trocar de rede Wi-Fi ou quando o IP ^"trava^".>>"%KB%"
echo.>>"%KB%"
echo === 5.2 TROCAR DNS ===>>"%KB%"
echo Quando site nao abre mas a conexao funciona:>>"%KB%"
echo - Google: 8.8.8.8 e 8.8.4.4>>"%KB%"
echo - Cloudflare: 1.1.1.1 e 1.0.0.1>>"%KB%"
echo - Quad9 ^(com filtro seguranca^): 9.9.9.9>>"%KB%"
echo Configurar nas propriedades do adaptador ^(IPv4^) ou no roteador.>>"%KB%"
echo.>>"%KB%"
echo === 5.3 TESTAR SE E LOCAL OU DA OPERADORA ===>>"%KB%"
echo 1. Ping no gateway ^(roteador^). Ruim? Problema local.>>"%KB%"
echo 2. Gateway ok? Ping em 8.8.8.8. Ruim so aqui = operadora/rota.>>"%KB%"
echo 3. Teste no CABO para tirar o Wi-Fi da jogada.>>"%KB%"
echo 4. Se cabo resolve = Wi-Fi. Se nao = link/optico/operadora.>>"%KB%"
echo.>>"%KB%"
echo === 5.4 COMANDOS UTEIS DE DIAGNOSTICO ^(WINDOWS^) ===>>"%KB%"
echo - ping -t 8.8.8.8         ^(ping continuo, Ctrl+C para^)>>"%KB%"
echo - ping -n 50 GATEWAY      ^(50 pacotes, ver perda/jitter^)>>"%KB%"
echo - tracert 8.8.8.8         ^(caminho ate o destino^)>>"%KB%"
echo - pathping 8.8.8.8        ^(perda por salto no tempo^)>>"%KB%"
echo - nslookup site.com       ^(testar resolucao DNS^)>>"%KB%"
echo - ipconfig /all           ^(ver gateway, DNS, MAC, IP^)>>"%KB%"
echo - netsh wlan show interfaces  ^(sinal Wi-Fi, canal, taxa^)>>"%KB%"
echo - getmac                  ^(MAC das placas^)>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 6 - EQUIPAMENTOS E TERMOS>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 6.1 EQUIPAMENTOS FTTH ===>>"%KB%"
echo - OLT: central da operadora ^(cabeca da rede optica^).>>"%KB%"
echo - ONU/ONT: na casa do cliente, recebe a fibra.>>"%KB%"
echo - Splitter: divide 1 fibra para varios ^(1:8, 1:16, 1:32, 1:64^).>>"%KB%"
echo - Patch cord: cordao optico curto ^(tomada optica ate a ONU^).>>"%KB%"
echo - Drop: fibra que vai da rua ate a casa.>>"%KB%"
echo - CTO: caixa na rua/poste onde o drop se conecta.>>"%KB%"
echo - CEO: caixa de emenda optica ^(rede troncal^).>>"%KB%"
echo - DIO: distribuidor optico ^(na central/rack^).>>"%KB%"
echo - Atenuador: reduz sinal quando esta forte demais.>>"%KB%"
echo.>>"%KB%"
echo === 6.2 TERMINOLOGIA ===>>"%KB%"
echo - RTT: tempo de ida e volta do ping.>>"%KB%"
echo - dBm: potencia do sinal; mais negativo = mais fraco.>>"%KB%"
echo - Gateway: roteador/porta de saida da rede local.>>"%KB%"
echo - Latencia: atraso. Jitter: variacao do atraso. Perda: pacotes que somem.>>"%KB%"
echo - LOS: Loss of Signal ^(perda de sinal optico^).>>"%KB%"
echo - PON: rede optica passiva; luz PON = sincronismo.>>"%KB%"
echo - CRC: erro de integridade de dados ^(sinal forte/ruim causa^).>>"%KB%"
echo - Overhead: peso extra dos dados; por isso velocidade nunca e 100%%.>>"%KB%"
echo - Band steering: roteador junta 2.4 e 5 GHz num nome so.>>"%KB%"
echo - Mesh: varios pontos de Wi-Fi formando uma rede unica.>>"%KB%"
echo - DFS: canais 5 GHz que cedem lugar a radar.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 7 - COMO O ASSISTENTE DEVE RESPONDER>>"%KB%"
echo #####################################################>>"%KB%"
echo - Portugues do Brasil, direto e pratico ^(tecnico tem pressa^).>>"%KB%"
echo - Use os NUMEROS reais do teste que vierem no contexto.>>"%KB%"
echo - Sempre separe ^"problema local ^(cliente^)^" de ^"problema de fora ^(operadora^)^".>>"%KB%"
echo - Pico isolado de latencia, sozinho, nao condena o link. Perda condena.>>"%KB%"
echo - Priorize o optico quando houver LOS vermelha.>>"%KB%"
echo - Nao invente numero. Se faltar dado, diga o que verificar.>>"%KB%"
echo - Respostas curtas e resolutivas, nada de enrolar.>>"%KB%"
echo.>>"%KB%"
echo *** REGRA DE ACESSO A INTERNET / TEMPO REAL ***>>"%KB%"
echo Este assistente NAO tem acesso a internet nem a dados em tempo real.>>"%KB%"
echo Quando o tecnico pedir algo que dependa disso, o assistente deve>>"%KB%"
echo dizer isso claramente e mandar procurar na web / fonte oficial.>>"%KB%"
echo Exemplos que NAO da pra responder por aqui e o que dizer:>>"%KB%"
echo - ^"Esse site/servico caiu agora?^" -^>>>"%KB%"
echo    ^"Nao tenho acesso em tempo real. Confere num site tipo>>"%KB%"
echo     downdetector.com.br ou pesquisa 'nome do servico fora do ar' no navegador.^">>"%KB%"
echo - ^"Qual o IP publico atual / status da operadora agora?^" -^>>>"%KB%"
echo    ^"Nao consigo ver isso daqui. Acessa o painel da operadora ou>>"%KB%"
echo     pesquisa na web o status do provedor.^">>"%KB%"
echo - ^"Preco de plano / promocao atual / cobertura no endereco X^" -^>>>"%KB%"
echo    ^"Isso muda toda hora, procura direto no site da operadora.^">>"%KB%"
echo - ^"Firmware mais novo do modelo X / manual atualizado^" -^>>>"%KB%"
echo    ^"Baixa no site oficial do fabricante, pesquisa 'modelo + firmware'.^">>"%KB%"
echo - ^"Qual servidor do jogo esta caindo hoje^" -^>>>"%KB%"
echo    ^"Nao tenho essa info em tempo real, confere na web/rede social do jogo.^">>"%KB%"
echo Regra geral: se a resposta muda com o tempo ou exige consultar um>>"%KB%"
echo sistema externo, avise que nao acessa e oriente onde procurar.>>"%KB%"
echo NUNCA inventar status, preco, IP, disponibilidade ou noticia.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 8 - CONFIGURACAO DE ROTEADORES>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 8.1 ACESSO AO ROTEADOR ===>>"%KB%"
echo Enderecos comuns de acesso ^(digitar no navegador^):>>"%KB%"
echo - 192.168.0.1  ^(D-Link, alguns TP-Link, Multilaser^)>>"%KB%"
echo - 192.168.1.1  ^(TP-Link, Intelbras, muitos ONUs^)>>"%KB%"
echo - 192.168.15.1 ^(Intelbras ONU/roteador^)>>"%KB%"
echo - 192.168.25.1 ^(algumas ONUs GPON^)>>"%KB%"
echo - 192.168.18.1 ^(algumas ONUs Huawei/ZTE de provedor^)>>"%KB%"
echo - 10.0.0.1     ^(alguns modelos^)>>"%KB%"
echo Usuario/senha padrao comuns: admin/admin, admin/senha em branco,>>"%KB%"
echo admin/gvt12345 ^(antigas^), user/user. Se mudaram, so resetando.>>"%KB%"
echo O IP certo tambem aparece como ^"gateway padrao^" no ipconfig.>>"%KB%"
echo.>>"%KB%"
echo === 8.2 O QUE CONFIGURAR NUM ROTEADOR NOVO ===>>"%KB%"
echo 1. Trocar a senha de admin ^(seguranca^).>>"%KB%"
echo 2. Definir nome da rede ^(SSID^) e senha do Wi-Fi ^(WPA2 ou WPA3^).>>"%KB%"
echo 3. Escolher canal ^(2.4 GHz: 1, 6 ou 11^).>>"%KB%"
echo 4. Se quiser, separar 2.4 e 5 GHz em nomes diferentes.>>"%KB%"
echo 5. Atualizar firmware se houver.>>"%KB%"
echo 6. Em ONU com roteador: modo bridge ou roteador conforme a operadora.>>"%KB%"
echo.>>"%KB%"
echo === 8.3 MODO BRIDGE vs ROTEADOR ===>>"%KB%"
echo - Modo ROTEADOR: a ONU faz o Wi-Fi e distribui os IPs. Padrao residencial.>>"%KB%"
echo - Modo BRIDGE: a ONU so passa a conexao; quem roteia e outro roteador.>>"%KB%"
echo    Usado quando o cliente quer usar o proprio roteador melhor.>>"%KB%"
echo Dois roteadores em modo roteador ao mesmo tempo = ^"duplo NAT^",>>"%KB%"
echo causa problema em jogo, camera, acesso remoto. Um deve ser bridge/AP.>>"%KB%"
echo.>>"%KB%"
echo === 8.4 WPA2 vs WPA3 ===>>"%KB%"
echo - WPA2: seguro e compativel com tudo. Padrao seguro atual.>>"%KB%"
echo - WPA3: mais novo e seguro, mas aparelho antigo pode nao conectar.>>"%KB%"
echo - WPA2/WPA3 misto: compatibilidade + seguranca ^(boa escolha^).>>"%KB%"
echo - WEP: ANTIGO e inseguro, nunca usar.>>"%KB%"
echo - Rede aberta ^(sem senha^): so para hotspot, nunca residencial.>>"%KB%"
echo.>>"%KB%"
echo === 8.5 MODO AP ^(ACCESS POINT^) ===>>"%KB%"
echo Quando usa a ONU pra internet e quer outro roteador so pro Wi-Fi:>>"%KB%"
echo por o segundo em modo AP ^(desliga DHCP dele, cabo na porta LAN^).>>"%KB%"
echo Assim so tem 1 NAT e a rede fica limpa. Melhor que duplo NAT.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 9 - CASOS DE CAMPO ^(exemplos reais^)>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === CASO 1: ^"Internet boa mas o jogo dele da lag^" ===>>"%KB%"
echo Teste mostra: ping gateway 3ms, internet 25ms, perda 0%%, jitter 12ms.>>"%KB%"
echo Conclusao: a conexao esta otima. O lag no jogo pode ser:>>"%KB%"
echo - Servidor do jogo longe ^(outro pais^).>>"%KB%"
echo - Wi-Fi do quarto dele fraco ^(testar cabo/aproximar^).>>"%KB%"
echo - Muita gente baixando na mesma casa no momento do jogo.>>"%KB%"
echo NAO e caso de chamado na operadora.>>"%KB%"
echo.>>"%KB%"
echo === CASO 2: ^"Cai toda hora a noite^" ===>>"%KB%"
echo Teste de dia: tudo bom. Cliente reclama so a noite.>>"%KB%"
echo Provaveis causas:>>"%KB%"
echo - Saturacao ^(todos os vizinhos usando no pico^).>>"%KB%"
echo - Wi-Fi 2.4 GHz lotado a noite ^(todos ligam TV, celular^).>>"%KB%"
echo Acao: agendar teste no horario do problema; ver se e cabo tambem>>"%KB%"
echo ^(link^) ou so Wi-Fi ^(interferencia^). Trocar canal ajuda no Wi-Fi.>>"%KB%"
echo.>>"%KB%"
echo === CASO 3: ^"Sinal -26 dBm e cai as vezes^" ===>>"%KB%"
echo Sinal optico no limite. Acao:>>"%KB%"
echo - Limpar e reencaixar conector.>>"%KB%"
echo - Ver fibra dobrada.>>"%KB%"
echo - Se continuar -26 ou pior, acionar externa ^(drop/CTO/splitter^).>>"%KB%"
echo Nao adianta trocar roteador: o problema e a luz chegando fraca.>>"%KB%"
echo.>>"%KB%"
echo === CASO 4: ^"Velocidade so 100 de um plano de 300^" ===>>"%KB%"
echo Testar no cabo:>>"%KB%"
echo - No cabo deu 290 -^> problema e o Wi-Fi ^(sinal/canal/aparelho antigo^).>>"%KB%"
echo - No cabo tambem 100 -^> pode ser: config do plano na operadora,>>"%KB%"
echo   sinal optico ruim, cabo de rede ruim ^(categoria baixa^), ou>>"%KB%"
echo   placa de rede a 100 Mbps ^(nao Gigabit^).>>"%KB%"
echo.>>"%KB%"
echo === CASO 5: ^"Site do banco nao abre, resto funciona^" ===>>"%KB%"
echo Ping e outros sites ok, so o banco nao.>>"%KB%"
echo - Geralmente DNS ou o proprio site do banco fora.>>"%KB%"
echo - Trocar DNS ^(8.8.8.8^). Se abrir, era DNS.>>"%KB%"
echo - Se nao, e o site do banco ^(esperar/testar outro dispositivo^).>>"%KB%"
echo.>>"%KB%"
echo === CASO 6: ^"ONU LOS vermelha depois da chuva^" ===>>"%KB%"
echo Muito comum: agua na CTO ou conector externo oxidado.>>"%KB%"
echo - Verificar conector na ONU ^(limpar/reencaixar^).>>"%KB%"
echo - LOS continua = problema externo ^(CTO/drop molhado^). Acionar externa.>>"%KB%"
echo.>>"%KB%"
echo === CASO 7: ^"Duplo NAT / camera nao acessa de fora^" ===>>"%KB%"
echo Cliente com roteador proprio atras da ONU, ambos roteando.>>"%KB%"
echo - Colocar a ONU em bridge OU o roteador em modo AP/bridge.>>"%KB%"
echo - Assim tem so um NAT e o acesso remoto/camera volta a funcionar.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 10 - CABOS DE REDE>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 10.1 CATEGORIAS ===>>"%KB%"
echo - Cat5 ^(antigo^): ate 100 Mbps. NAO usar para planos altos.>>"%KB%"
echo - Cat5e: ate 1 Gbps. Minimo recomendado hoje.>>"%KB%"
echo - Cat6: ate 1-10 Gbps ^(curtas distancias^). Melhor.>>"%KB%"
echo - Cat6a/Cat7: 10 Gbps. Para casos especiais.>>"%KB%"
echo Cliente com plano de 500 Mega num cabo Cat5 velho = trava em 100.>>"%KB%"
echo.>>"%KB%"
echo === 10.2 PROBLEMAS DE CABO ===>>"%KB%"
echo - Cabo pisado/dobrado/prensado por porta = perda e velocidade baixa.>>"%KB%"
echo - Conector RJ45 mal crimpado = liga e cai, ou nao passa velocidade.>>"%KB%"
echo - Cabo muito longo ^(^>100m^) = perda de sinal.>>"%KB%"
echo - Placa de rede antiga a 100 Mbps limita mesmo com cabo bom.>>"%KB%"
echo - CCA ^(aluminio revestido de cobre^) em vez de cobre puro = pior,>>"%KB%"
echo   esquenta em PoE, perde velocidade em distancia. Usar cobre.>>"%KB%"
echo Sinal: LED da porta pisca estranho, velocidade trava em 100 exato.>>"%KB%"
echo.>>"%KB%"
echo === 10.3 CHECAR VELOCIDADE DA PORTA ^(WINDOWS^) ===>>"%KB%"
echo Central de Rede -^> adaptador -^> Status: mostra ^"Velocidade^".>>"%KB%"
echo Se aparece 100 Mbps num plano gigabit: cabo ruim, conector mal>>"%KB%"
echo crimpado, ou placa/porta so 100. Trocar cabo por Cat5e/Cat6 e testar.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 11 - REFERENCIA RAPIDA ^(TABELA MENTAL^)>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo SINAL OPTICO Rx:  otimo -8/-20 ^| atencao -21/-24 ^| ruim -25/-27 ^| critico ^<-27>>"%KB%"
echo SINAL WI-FI dBm:  otimo -30/-50 ^| bom -50/-67 ^| fraco -67/-80 ^| ruim ^<-80>>"%KB%"
echo PING:             otimo 0-30 ^| bom 30-60 ^| aceit 60-100 ^| ruim +100>>"%KB%"
echo JITTER:           otimo ^<20 ^| bom 20-50 ^| atencao 50-100 ^| ruim +100>>"%KB%"
echo PERDA:            ok 0-1%% ^| atencao 1-2.5%% ^| problema +2.5%% ^| grave +5%%>>"%KB%"
echo SNR WI-FI:        otimo ^>40 ^| bom 25-40 ^| aceit 15-25 ^| ruim ^<15>>"%KB%"
echo VELOCIDADE:       comparar com plano; testar no cabo; overhead ~10%%.>>"%KB%"
echo.>>"%KB%"
echo REGRA MESTRE: gateway ruim = problema do cliente ^(local^).>>"%KB%"
echo               gateway bom + internet ruim = problema de fora ^(operadora^).>>"%KB%"
echo               pico isolado nao condena; perda sempre entra na conta.>>"%KB%"
echo               tempo real / status atual = mandar procurar na web.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 12 - AUTENTICACAO E ENDERECAMENTO>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 12.1 PPPoE ===>>"%KB%"
echo Muito provedor autentica por PPPoE: a ONU/roteador loga com>>"%KB%"
echo usuario e senha do provedor. Se a senha PPPoE esta errada ou o>>"%KB%"
echo provedor bloqueou, da ^"sem internet^" mesmo com LOS apagada e PON verde.>>"%KB%"
echo Sintoma: PON verde, LOS apagada, mas luz INTERNET/WAN piscando ou>>"%KB%"
echo apagada e sem IP publico. Acao: conferir credencial PPPoE, ver se a>>"%KB%"
echo conta nao esta suspensa ^(financeiro^), reautenticar.>>"%KB%"
echo.>>"%KB%"
echo === 12.2 IPoE / DHCP ===>>"%KB%"
echo Outros provedores entregam IP direto por DHCP ^(sem login PPPoE^).>>"%KB%"
echo Se o roteador nao pega IP WAN: liberar/renovar, checar se o MAC>>"%KB%"
echo esta liberado no provedor ^(alguns amarram o MAC do equipamento^).>>"%KB%"
echo.>>"%KB%"
echo === 12.3 DHCP LOCAL ^(na casa^) ===>>"%KB%"
echo O roteador distribui IP pros aparelhos ^(ex 192.168.x.x^).>>"%KB%"
echo - Aparelho com ^"IP 169.254.x.x^" = NAO pegou DHCP ^(APIPA^). Cabo solto,>>"%KB%"
echo   DHCP desligado, ou conflito. Renovar/checar cabo.>>"%KB%"
echo - Conflito de IP = dois aparelhos com IP fixo igual. Trocar/usar DHCP.>>"%KB%"
echo - Faixa DHCP pequena com muita gente = aparelho fica sem IP. Aumentar faixa.>>"%KB%"
echo.>>"%KB%"
echo === 12.4 IP FIXO x DINAMICO ===>>"%KB%"
echo - Dinamico ^(DHCP^): padrao, roteador escolhe. Bom pra maioria.>>"%KB%"
echo - Fixo: util pra camera, impressora, servidor. Reservar por MAC>>"%KB%"
echo   no roteador ^(DHCP reservation^) e mais seguro que fixar no aparelho.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 13 - IPv6, CGNAT E ABERTURA DE PORTAS>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 13.1 CGNAT ^(O VILAO DO GAMER E DA CAMERA^) ===>>"%KB%"
echo Muito provedor usa CGNAT: varios clientes dividem 1 IP publico.>>"%KB%"
echo Consequencia: NAO da pra abrir porta, NAT fica ^"moderado/restrito^">>"%KB%"
echo em jogo, camera/DVR nao acessa de fora, servidor caseiro nao expoe.>>"%KB%"
echo Como identificar: o IP WAN do roteador ^(ex 100.64.x.x, ou 10.x, ou>>"%KB%"
echo diferente do IP que aparece em ^"meu ip^" na web^) indica CGNAT.>>"%KB%"
echo Faixa 100.64.0.0/10 = CGNAT classico.>>"%KB%"
echo Solucao: pedir IP publico dedicado a operadora ^(as vezes pago^), ou>>"%KB%"
echo usar IPv6 ^(se o servico suportar^), ou solucoes de tunel/DDNS+VPN.>>"%KB%"
echo IMPORTANTE: abrir porta NAO resolve com CGNAT. Primeiro confirmar>>"%KB%"
echo se tem IP publico de verdade.>>"%KB%"
echo.>>"%KB%"
echo === 13.2 ABERTURA DE PORTAS ^(PORT FORWARD^) ===>>"%KB%"
echo Passos gerais ^(quando TEM IP publico^):>>"%KB%"
echo 1. Fixar/reservar o IP local do aparelho ^(camera, PC, DVR^).>>"%KB%"
echo 2. No roteador, ir em ^"Port Forwarding / Redirecionamento^".>>"%KB%"
echo 3. Criar regra: porta externa -^> IP local + porta interna ^(TCP/UDP^).>>"%KB%"
echo 4. Se ha duplo NAT, abrir nos DOIS roteadores ^(ou por 1 em bridge^).>>"%KB%"
echo 5. Testar de fora ^(dados moveis^) com o IP publico + porta.>>"%KB%"
echo Dica: NAT restrito em jogo costuma melhorar com UPnP ligado OU>>"%KB%"
echo abrindo as portas do jogo manualmente.>>"%KB%"
echo.>>"%KB%"
echo === 13.3 DMZ ===>>"%KB%"
echo DMZ joga TODAS as portas pra um IP ^(ex console de jogo^).>>"%KB%"
echo Resolve NAT restrito rapido, mas expoe o aparelho. Usar so em>>"%KB%"
echo aparelho especifico e de preferencia console, nao PC com dados.>>"%KB%"
echo.>>"%KB%"
echo === 13.4 IPv6 ===>>"%KB%"
echo IPv6 nao usa NAT: cada aparelho pode ter endereco publico.>>"%KB%"
echo Ajuda a contornar CGNAT em servicos que suportam IPv6.>>"%KB%"
echo Se o provedor entrega IPv6, ativar no roteador pode melhorar>>"%KB%"
echo acesso a jogos/servicos modernos. Nem todo servico usa ainda.>>"%KB%"
echo.>>"%KB%"
echo === 13.5 DDNS ===>>"%KB%"
echo IP publico dinamico muda de tempos em tempos. DDNS ^(No-IP, DuckDNS^)>>"%KB%"
echo cria um nome fixo que aponta pro IP atual. Util pra acessar camera/>>"%KB%"
echo DVR de fora sem decorar IP. NAO funciona sob CGNAT ^(nao tem IP publico^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 14 - DNS EM PROFUNDIDADE>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 14.1 O QUE E ===>>"%KB%"
echo DNS traduz nome ^(site.com^) em IP. Se o DNS falha/lento: ^"internet>>"%KB%"
echo funciona no ping mas site nao abre^", ou navegacao lenta pra carregar.>>"%KB%"
echo.>>"%KB%"
echo === 14.2 SERVIDORES DNS COMUNS ===>>"%KB%"
echo - Google: 8.8.8.8 / 8.8.4.4 ^(rapido, confiavel^).>>"%KB%"
echo - Cloudflare: 1.1.1.1 / 1.0.0.1 ^(rapido, foco privacidade^).>>"%KB%"
echo - Quad9: 9.9.9.9 ^(bloqueia dominio malicioso^).>>"%KB%"
echo - OpenDNS: 208.67.222.222 ^(tem filtro conteudo opcional^).>>"%KB%"
echo.>>"%KB%"
echo === 14.3 PROBLEMAS DE DNS ===>>"%KB%"
echo - Site nao abre, ping por IP funciona -^> DNS. Trocar servidor.>>"%KB%"
echo - Site abre no celular ^(4G^) mas nao no Wi-Fi -^> DNS do roteador.>>"%KB%"
echo - ^"DNS_PROBE^" no navegador -^> trocar DNS, flushdns.>>"%KB%"
echo - Alguns sites bloqueados so nesse DNS -^> trocar pra 8.8.8.8/1.1.1.1.>>"%KB%"
echo Teste: nslookup site.com  ^(se falha, e DNS; troca e testa de novo^).>>"%KB%"
echo.>>"%KB%"
echo === 14.4 CACHE DE DNS ===>>"%KB%"
echo Depois de trocar DNS ou site mudar de servidor: ipconfig /flushdns>>"%KB%"
echo limpa o cache local. No navegador tambem tem cache proprio.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 15 - VoIP / TELEFONIA NA ONU>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 15.1 COMO FUNCIONA ===>>"%KB%"
echo ONU com porta TEL entrega telefone por VoIP ^(SIP^) pela mesma fibra.>>"%KB%"
echo Depende de: sinal optico bom + provisionamento SIP correto na ONU.>>"%KB%"
echo.>>"%KB%"
echo === 15.2 PROBLEMAS COMUNS ===>>"%KB%"
echo - Sem tom de discagem: verificar se a porta TEL certa ^(TEL1/TEL2^),>>"%KB%"
echo   cabo do telefone, e se a linha esta provisionada ^(caso operadora^).>>"%KB%"
echo - Voz picotando / cortando -^> jitter/perda na rede, nao no telefone.>>"%KB%"
echo   QoS pra priorizar voz ajuda. Ver Wi-Fi/link.>>"%KB%"
echo - Chia/ruido -^> aparelho de telefone ruim ou fiacao interna.>>"%KB%"
echo - So recebe, nao liga ^(ou vice-versa^) -^> provisionamento SIP/operadora.>>"%KB%"
echo Internet caiu = telefone VoIP tambem cai ^(mesma fibra^). Avisar cliente.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 16 - IPTV / STREAMING / MULTICAST>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 16.1 IPTV DE OPERADORA ===>>"%KB%"
echo IPTV usa multicast ^(IGMP^). Se travar so a TV da operadora:>>"%KB%"
echo - IGMP Snooping precisa estar certo no roteador.>>"%KB%"
echo - Cabo/porta dedicada da TV as vezes e obrigatoria.>>"%KB%"
echo - Bridge errado quebra o multicast.>>"%KB%"
echo Streaming comum ^(Netflix, YouTube, Prime^) NAO usa multicast, e trafego>>"%KB%"
echo normal; se so eles travam, e velocidade/Wi-Fi/DNS, nao IPTV.>>"%KB%"
echo.>>"%KB%"
echo === 16.2 STREAMING TRAVANDO ===>>"%KB%"
echo - Trava so em 4K -^> velocidade/Wi-Fi insuficiente pro 4K.>>"%KB%"
echo - Buffer no comeco e some -^> normal.>>"%KB%"
echo - Trava direto em tudo -^> jitter/perda ou Wi-Fi fraco na TV.>>"%KB%"
echo - So numa TV/aparelho -^> Wi-Fi daquele aparelho ^(aproximar/cabo^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 17 - TR-069 / PROVISIONAMENTO REMOTO ^(ACS^)>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 17.1 O QUE E ===>>"%KB%"
echo TR-069 ^(CWMP^) e como a operadora configura a ONU/roteador de longe,>>"%KB%"
echo via um servidor ACS. Provisiona PPPoE, Wi-Fi, VoIP, firmware sem ir>>"%KB%"
echo na casa. Muita config fica bloqueada pro cliente por causa disso.>>"%KB%"
echo.>>"%KB%"
echo === 17.2 QUANDO IMPORTA NO CAMPO ===>>"%KB%"
echo - Config que ^"volta sozinha^" depois de mudar = ACS reprovisionou.>>"%KB%"
echo   Mudar no painel da operadora, nao na ONU.>>"%KB%"
echo - Firmware que atualiza sozinho = ACS empurrou.>>"%KB%"
echo - ONU nova que ja vem configurada = provisionamento automatico.>>"%KB%"
echo - Se o cliente quer Wi-Fi proprio e a ONU trava tudo -^> por em bridge>>"%KB%"
echo   e usar roteador proprio ^(quando o provedor permite^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 18 - SEGURANCA DE REDE>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 18.1 BASICO ===>>"%KB%"
echo - Trocar senha de admin do roteador ^(nunca deixar admin/admin^).>>"%KB%"
echo - Wi-Fi com WPA2 ou WPA3 e senha forte ^(12+ caracteres^).>>"%KB%"
echo - Desligar WPS se nao usar ^(vulneravel a ataque de PIN^).>>"%KB%"
echo - Atualizar firmware ^(corrige falhas^).>>"%KB%"
echo - Rede de convidados separada pra visitas/IoT.>>"%KB%"
echo.>>"%KB%"
echo === 18.2 SINAIS DE INVASAO / USO INDEVIDO ===>>"%KB%"
echo - Internet lenta e muitos aparelhos desconhecidos na lista do roteador.>>"%KB%"
echo - Config mudando sozinha ^(fora ACS^) -^> resetar e trocar todas as senhas.>>"%KB%"
echo - Filtro de MAC ajuda mas nao e infalivel ^(MAC se clona^).>>"%KB%"
echo Se suspeitar: trocar senha do Wi-Fi e do admin, atualizar firmware.>>"%KB%"
echo.>>"%KB%"
echo === 18.3 O QUE NAO FAZER ===>>"%KB%"
echo - WEP: inseguro, nunca.>>"%KB%"
echo - Rede aberta residencial: nunca.>>"%KB%"
echo - Senha padrao de fabrica: trocar sempre.>>"%KB%"
echo - Deixar acesso de administracao pela WAN ^(internet^) ligado sem>>"%KB%"
echo   necessidade: fechar.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 19 - MARCAS E MODELOS COMUNS NO BRASIL>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 19.1 ONU/ROTEADOR DE PROVEDOR ===>>"%KB%"
echo - Intelbras ^(linha ONU/roteador GPON^): comum em provedores regionais.>>"%KB%"
echo   Acesso comum 192.168.1.1. Menu em portugues.>>"%KB%"
echo - Huawei ^(EchoLife, ex EG8145V5^): muito usado por operadoras grandes.>>"%KB%"
echo   Acesso comum 192.168.100.1 / 192.168.18.1. Login as vezes so telecom.>>"%KB%"
echo - ZTE ^(F670L, F660^): comum em provedores. Acesso 192.168.1.1.>>"%KB%"
echo - Nokia/Alcatel: usado por operadoras grandes.>>"%KB%"
echo - Fiberhome: presente em varios provedores.>>"%KB%"
echo OBS: em ONU de operadora, muita config e bloqueada ^(TR-069/ACS^).>>"%KB%"
echo O login ^"user^" costuma ter menos opcoes que o de tecnico.>>"%KB%"
echo.>>"%KB%"
echo === 19.2 ROTEADORES DE VAREJO ^(cliente compra^) ===>>"%KB%"
echo - TP-Link ^(Archer^): populares, bom custo. Acesso 192.168.0.1 ou tplinkwifi.net.>>"%KB%"
echo - Intelbras ^(Action/Twibi mesh^): comuns, suporte BR.>>"%KB%"
echo - D-Link: acesso 192.168.0.1.>>"%KB%"
echo - Mercusys, Multilaser: entrada, mais simples.>>"%KB%"
echo - ASUS: gamer/avancado, muita opcao ^(QoS, AiMesh^).>>"%KB%"
echo Para melhorar Wi-Fi de casa grande: mesh ^(Twibi, Deco, AiMesh^) e melhor>>"%KB%"
echo que repetidor.>>"%KB%"
echo.>>"%KB%"
echo === 19.3 OBSERVACAO SOBRE VERSOES/FIRMWARE ===>>"%KB%"
echo Nao decorar firmware/versao: muda toda hora. Se precisar da versao>>"%KB%"
echo mais nova ou manual, mandar o tecnico baixar no site oficial do>>"%KB%"
echo fabricante ^(ver PARTE 7, regra de tempo real^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 20 - FERRAMENTAS DE DIAGNOSTICO>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 20.1 SOFTWARE ===>>"%KB%"
echo - ping / ping -t: latencia e perda continua.>>"%KB%"
echo - tracert / pathping: caminho e perda por salto.>>"%KB%"
echo - nslookup: DNS.>>"%KB%"
echo - iperf3: mede vazao REAL entre dois pontos ^(melhor que speedtest>>"%KB%"
echo   pra testar rede interna/link limpo^).>>"%KB%"
echo - Speedtest ^(Ookla^) / fast.com: velocidade ate um servidor externo.>>"%KB%"
echo - Analisador Wi-Fi ^(WiFiman, WiFi Analyzer^): canal, sinal, vizinhos.>>"%KB%"
echo - netsh wlan show interfaces: sinal/canal/taxa no Windows.>>"%KB%"
echo.>>"%KB%"
echo === 20.2 CAMPO ^(OPTICO^) ===>>"%KB%"
echo - Power Meter ^(medidor de potencia^): le dBm chegando na ponta.>>"%KB%"
echo - VFL ^(caneta laser vermelha^): acha quebra/curva ^(luz vaza no ponto^).>>"%KB%"
echo - OTDR: mapeia a fibra por distancia, acha emenda/quebra/perda e>>"%KB%"
echo   onde esta ^(metragem^). Ferramenta da equipe externa.>>"%KB%"
echo - Limpador de conector ^(caneta/cassete^): tira sujeira da ferula.>>"%KB%"
echo - Microscopio de fibra: ve se a ponta esta suja/lascada.>>"%KB%"
echo.>>"%KB%"
echo === 20.3 COMO ESCOLHER ===>>"%KB%"
echo - ^"Nao sei quanto sinal chega^" -^> power meter ^(ou ler na propria ONU^).>>"%KB%"
echo - ^"Onde esta a quebra^" -^> OTDR ^(externa^) ou VFL pra trechos curtos.>>"%KB%"
echo - ^"E o Wi-Fi ou o link^" -^> iperf/speedtest no cabo x Wi-Fi.>>"%KB%"
echo - ^"Canal Wi-Fi lotado^" -^> analisador Wi-Fi.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 21 - MESH x REPETIDOR x AP x PLC>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 21.1 COMPARACAO ===>>"%KB%"
echo - REPETIDOR: pega o Wi-Fi e repete. Simples e barato, MAS corta a>>"%KB%"
echo   velocidade pela metade e costuma criar outro nome de rede. Bom pra>>"%KB%"
echo   cobrir um ponto morto pequeno. Ruim pra casa toda.>>"%KB%"
echo - MESH: varios pontos, MESMO nome, troca automatica ^(roaming^). Melhor>>"%KB%"
echo   experiencia pra casa grande/varios andares. Mais caro.>>"%KB%"
echo - AP ^(Access Point^): ponto de Wi-Fi ligado por CABO ao roteador. Melhor>>"%KB%"
echo   desempenho ^(backhaul cabeado nao perde velocidade^). Ideal se tem cabo.>>"%KB%"
echo - PLC ^(rede pela tomada^): leva rede pela fiacao eletrica. Util quando>>"%KB%"
echo   nao da pra passar cabo. Desempenho varia com a instalacao eletrica.>>"%KB%"
echo.>>"%KB%"
echo === 21.2 REGRA PRATICA ===>>"%KB%"
echo - Tem como passar cabo -^> AP cabeado ^(melhor^).>>"%KB%"
echo - Nao tem cabo, casa grande -^> mesh.>>"%KB%"
echo - Um cantinho morto so -^> repetidor resolve barato.>>"%KB%"
echo - Fiacao boa, sem cabo de rede -^> PLC pode servir.>>"%KB%"
echo Backhaul ^(ligacao entre os pontos^): cabeado ^> 5 GHz dedicado ^> compartilhado.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 22 - GLOSSARIO GRANDE>>"%KB%"
echo #####################################################>>"%KB%"
echo - ONU/ONT: equipamento na casa que recebe a fibra.>>"%KB%"
echo - OLT: central da operadora que serve o PON.>>"%KB%"
echo - PON: rede optica passiva ^(sem energia no meio, so splitters^).>>"%KB%"
echo - Splitter: divisor optico passivo.>>"%KB%"
echo - CTO: caixa de terminacao optica na rua/poste.>>"%KB%"
echo - CEO: caixa de emenda optica ^(troncal^).>>"%KB%"
echo - DIO: distribuidor interno optico ^(rack^).>>"%KB%"
echo - Drop: fibra da rua ate a casa.>>"%KB%"
echo - Patch cord: cordao optico curto interno.>>"%KB%"
echo - Ferula: ponta ceramica do conector optico.>>"%KB%"
echo - APC/UPC: tipos de polimento do conector ^(verde/azul^).>>"%KB%"
echo - dBm: potencia absoluta do sinal.>>"%KB%"
echo - dB: diferenca/perda relativa.>>"%KB%"
echo - Rx/Tx: potencia recebida / transmitida.>>"%KB%"
echo - LOS: perda de sinal optico.>>"%KB%"
echo - BER: taxa de erro de bits.>>"%KB%"
echo - CRC: erro de integridade.>>"%KB%"
echo - Dying Gasp: aviso da ONU de que perdeu energia.>>"%KB%"
echo - Rogue ONU: ONU defeituosa que atrapalha o PON.>>"%KB%"
echo - PPPoE: autenticacao por usuario/senha sobre ethernet.>>"%KB%"
echo - IPoE/DHCP: IP entregue sem login.>>"%KB%"
echo - NAT: traducao de endereco ^(rede local ^<-^> internet^).>>"%KB%"
echo - CGNAT: NAT do provedor, varios clientes num IP publico.>>"%KB%"
echo - DMZ: expor um IP a todas as portas.>>"%KB%"
echo - Port forward: redirecionar porta pra um IP interno.>>"%KB%"
echo - UPnP: abertura automatica de portas por aplicativo.>>"%KB%"
echo - DDNS: nome fixo pra IP dinamico.>>"%KB%"
echo - MTU: tamanho maximo do pacote.>>"%KB%"
echo - Gateway: saida da rede local ^(roteador^).>>"%KB%"
echo - Latencia/ping: atraso ida-e-volta.>>"%KB%"
echo - Jitter: variacao do atraso.>>"%KB%"
echo - Perda: pacotes que somem.>>"%KB%"
echo - Bufferbloat: latencia que dispara sob carga.>>"%KB%"
echo - SNR: relacao sinal/ruido.>>"%KB%"
echo - Link rate: taxa negociada ^(nao a real^).>>"%KB%"
echo - Band steering: junta 2.4/5 GHz num nome.>>"%KB%"
echo - Roaming: trocar de ponto Wi-Fi sem cair.>>"%KB%"
echo - DFS: canais 5 GHz que cedem a radar.>>"%KB%"
echo - Mesh: rede de varios pontos, um nome so.>>"%KB%"
echo - AP: ponto de acesso cabeado.>>"%KB%"
echo - PLC: rede pela tomada eletrica.>>"%KB%"
echo - SSID: nome da rede Wi-Fi.>>"%KB%"
echo - WPA2/WPA3: seguranca do Wi-Fi.>>"%KB%"
echo - WPS: pareamento por botao/PIN ^(inseguro, desligar^).>>"%KB%"
echo - IGMP: controle de multicast ^(IPTV^).>>"%KB%"
echo - SIP: protocolo de voz ^(VoIP^).>>"%KB%"
echo - TR-069/ACS: provisionamento remoto pela operadora.>>"%KB%"
echo - Overhead: peso extra que reduz a velocidade real.>>"%KB%"
echo - Cat5e/Cat6: categorias de cabo de rede.>>"%KB%"
echo - CCA: cabo de aluminio revestido ^(pior que cobre^).>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 23 - FLUXOGRAMAS DE DECISAO ^(ARVORE^)>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === 23.1 ^"SEM INTERNET^" ===>>"%KB%"
echo 1. LOS vermelha? -^> SIM: optico ^(limpar/reencaixar; persistiu=externa^). FIM.>>"%KB%"
echo 2. LOS apagada + PON verde? -^> continua.>>"%KB%"
echo 3. Tem IP WAN/autenticacao ^(INTERNET fixa^)? -^> NAO: PPPoE/DHCP/conta. >>"%KB%"
echo 4. Ping no gateway ok? -^> NAO: cabo/Wi-Fi/roteador local.>>"%KB%"
echo 5. Ping 8.8.8.8 ok? -^> NAO: operadora/rota.>>"%KB%"
echo 6. Ping ok mas site nao abre? -^> DNS. Trocar 8.8.8.8, flushdns.>>"%KB%"
echo.>>"%KB%"
echo === 23.2 ^"INTERNET LENTA^" ===>>"%KB%"
echo 1. Testar no CABO. Bate o plano? -^> SIM: problema e o Wi-Fi. >>"%KB%"
echo 2. No cabo tambem lento? -^> link/optico/operadora.>>"%KB%"
echo 3. Placa/porta em 100 Mbps? -^> cabo/placa. Trocar Cat5e/Cat6.>>"%KB%"
echo 4. Sinal optico ruim ^(-25 ou pior^)? -^> optico.>>"%KB%"
echo 5. So a noite? -^> saturacao ^(pico^).>>"%KB%"
echo.>>"%KB%"
echo === 23.3 ^"TRAVA MESMO RAPIDO^" ===>>"%KB%"
echo 1. Jitter alto? -^> interferencia Wi-Fi / link instavel.>>"%KB%"
echo 2. Perda so no gateway? -^> local ^(Wi-Fi/cabo^).>>"%KB%"
echo 3. Ping dispara quando baixa algo? -^> bufferbloat ^(QoS/SQM^).>>"%KB%"
echo 4. So em chamada/jogo? -^> jitter/perda, nao velocidade.>>"%KB%"
echo.>>"%KB%"
echo === 23.4 ^"JOGO: NAT RESTRITO / NAO CONECTA^" ===>>"%KB%"
echo 1. IP WAN e publico? ^(comparar com ^"meu ip^" na web^) >>"%KB%"
echo    -^> NAO ^(100.64.x / diferente^) = CGNAT. Pedir IP publico. FIM.>>"%KB%"
echo 2. Tem IP publico -^> UPnP ligado OU abrir portas do jogo.>>"%KB%"
echo 3. Duplo NAT? -^> por ONU em bridge / roteador em AP.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 24 - ERROS E MITOS COMUNS>>"%KB%"
echo #####################################################>>"%KB%"
echo - MITO: ^"reiniciar resolve LOS vermelha^". NAO. LOS = optico, resolver a fibra.>>"%KB%"
echo - MITO: ^"mais barras = mais velocidade^". Barras sao SINAL, nao velocidade.>>"%KB%"
echo - MITO: ^"roteador novo conserta sinal optico fraco^". NAO. Luz fraca e fibra.>>"%KB%"
echo - MITO: ^"2.4 GHz e melhor porque pega mais longe^". Pega mais longe mas>>"%KB%"
echo   e mais lenta e cheia de interferencia. Depende do uso.>>"%KB%"
echo - MITO: ^"link rate = velocidade^". Link rate e negociacao, real e menor.>>"%KB%"
echo - MITO: ^"1 pacote perdido = link ruim^". Pode ser rate-limit ICMP. Nao reprova.>>"%KB%"
echo - MITO: ^"speedtest alto = tudo perfeito^". Pode ter jitter/perda/bufferbloat.>>"%KB%"
echo - MITO: ^"abrir porta resolve jogo sob CGNAT^". NAO tem IP publico, nao abre.>>"%KB%"
echo - MITO: ^"cabo sempre bate o plano^". Cat5 velho/placa 100 trava em 100.>>"%KB%"
echo.>>"%KB%"
echo #####################################################>>"%KB%"
echo # PARTE 25 - CASOS DE CAMPO AVANCADOS>>"%KB%"
echo #####################################################>>"%KB%"
echo.>>"%KB%"
echo === CASO 8: ^"Sinal -18 dBm ^(otimo^) mas da erro/CRC^" ===>>"%KB%"
echo Sinal FORTE demais tambem satura. Se estiver acima de -8 ^(ex -5^),>>"%KB%"
echo por atenuador optico. Se -18 e mesmo assim erra, suspeitar de patch>>"%KB%"
echo cord ruim, ONU defeituosa, ou reflexao ^(APC/UPC misturado^).>>"%KB%"
echo.>>"%KB%"
echo === CASO 9: ^"Varios clientes do mesmo poste caem juntos^" ===>>"%KB%"
echo Nao e caso individual. Provavel: rogue ONU no PON, problema na CTO,>>"%KB%"
echo splitter, ou drop troncal. Acionar externa/NOC. Nao adianta trocar>>"%KB%"
echo equipamento de UM cliente.>>"%KB%"
echo.>>"%KB%"
echo === CASO 10: ^"Site abre no 4G mas nao no Wi-Fi de casa^" ===>>"%KB%"
echo Testar: ping por IP funciona? Se sim e site nao abre = DNS do roteador.>>"%KB%"
echo Trocar DNS pra 8.8.8.8/1.1.1.1 no roteador. flushdns nos aparelhos.>>"%KB%"
echo.>>"%KB%"
echo === CASO 11: ^"Camera nova nao acessa de fora^" ===>>"%KB%"
echo 1. Confirmar IP publico ^(CGNAT mata isso^). 100.64.x = CGNAT -^> pedir IP.>>"%KB%"
echo 2. Tem IP publico: reservar IP da camera, abrir porta, testar de fora.>>"%KB%"
echo 3. Duplo NAT: por em bridge/AP.>>"%KB%"
echo 4. DDNS pra nome fixo se IP muda.>>"%KB%"
echo.>>"%KB%"
echo === CASO 12: ^"PC gigabit mas so 94 Mbps^" ===>>"%KB%"
echo 94 Mbps e teto de porta 100 ^(fast ethernet^). Placa/porta/cabo em 100.>>"%KB%"
echo Ver ^"Velocidade^" do adaptador. Trocar cabo Cat5e/Cat6, testar outra>>"%KB%"
echo porta, checar se a placa e gigabit.>>"%KB%"
echo.>>"%KB%"
echo === CASO 13: ^"Telefone VoIP picotando, internet boa^" ===>>"%KB%"
echo Priorizar voz ^(QoS^) e checar jitter/perda. Se o Wi-Fi/link tem jitter,>>"%KB%"
echo a voz sofre mesmo com velocidade alta. Nao e defeito do telefone.>>"%KB%"
echo.>>"%KB%"
echo === CASO 14: ^"IPTV da operadora trava, streaming normal funciona^" ===>>"%KB%"
echo Multicast/IGMP. Ver IGMP snooping e se a TV precisa de porta/cabo>>"%KB%"
echo dedicado. Bridge errado quebra IPTV. Nao mexer no plano de internet.>>"%KB%"
echo.>>"%KB%"
echo === CASO 15: ^"Config do Wi-Fi volta sozinha depois que mudo^" ===>>"%KB%"
echo ACS/TR-069 reprovisionou. Mudar pelo painel da operadora, nao na ONU.>>"%KB%"
echo Ou pedir bridge e usar roteador proprio.>>"%KB%"
echo.>>"%KB%"
echo === CASO 16: ^"Fica bom quando reinicia, piora com horas^" ===>>"%KB%"
echo ONU/roteador esquentando ou vazamento de memoria. Melhorar ventilacao,>>"%KB%"
echo tirar do sol/lugar fechado, atualizar firmware. Se persistir, trocar equipamento.>>"%KB%"
echo.>>"%KB%"
echo === CASO 17: ^"Metade dos sites carrega, outra metade nao^" ===>>"%KB%"
echo Cheirar a MTU. Testar ping -f -l 1472 8.8.8.8. Se fragmenta, ajustar>>"%KB%"
echo MTU ^(ex 1492 em PPPoE^) no roteador.>>"%KB%"
echo.>>"%KB%"
echo === CASO 18: ^"Velocidade oscila muito, sinal optico varia^" ===>>"%KB%"
echo Sinal optico instavel ^(conector oxidando/frouxo, drop molhado, curva>>"%KB%"
echo intermitente^). Limpar/reencaixar; se varia sozinho, externa ^(drop/CTO^).>>"%KB%"
echo.>>"%KB%"
echo --- FIM DA BASE v2 --->>"%KB%"
echo Manter este material DENSO e organizado. Nao inflar com repeticao:>>"%KB%"
echo para o assistente, texto util ^> texto grande. Se precisar crescer,>>"%KB%"
echo adicionar CASOS reais e procedimentos, nao enchimento.>>"%KB%"
goto :eof

:: =========================================================
:: VERIFICAR_CHAVES - checagem de saude a cada execucao
::   - Telegram: testa DE VERDADE (getMe + getChat) - gratis
::   - IA: testa o FORMATO (sk-...) - nao gasta token
::   - Se achar problema, oferece colar a chave na hora
:: =========================================================
:VERIFICAR_CHAVES
if not defined IGN_REC set "IGN_REC=0"
set "PROB_TG="
set "PROB_IA="

:: --- checa FORMATO basico (anti-corrupcao) ---
:: Telegram so testa se o envio esta ligado
if /i "%TG_ENVIAR%"=="sim" (
  :: token deve ter ':' no meio (formato 123:AAA)
  echo %TG_TOKEN% | find ":" >nul || set "PROB_TG=formato do token invalido"
  :: chat deve comecar com - (grupo) ou ser numero
  if "%TG_TOKEN%"=="x" set "PROB_TG=token nao configurado"
  if "%TG_CHAT%"=="x" set "PROB_TG=chat id nao configurado"
  if not defined TG_CHAT set "PROB_TG=chat id vazio"
)
:: IA so checa formato (nao gasta token)
if not "%IA_KEY%"=="x" (
  if not defined IA_KEY (
    set "PROB_IA=chave nao configurada"
  ) else (
    echo %IA_KEY% | find "sk-" >nul || set "PROB_IA=formato da chave invalido (deve comecar com sk-)"
  )
)

:: --- Telegram: teste REAL (gratis) se o formato passou ---
:: teste real do Telegram (fora de bloco, para o delayed expansion funcionar)
if /i not "%TG_ENVIAR%"=="sim" goto FIM_TESTE_TG
if defined PROB_TG goto FIM_TESTE_TG
set "PCHKTG=%TEMP%\lr_chk_tg.ps1"
del "%PCHKTG%" >nul 2>&1
echo param($token,$chat) >>"%PCHKTG%"
echo [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12 >>"%PCHKTG%"
echo try { >>"%PCHKTG%"
echo $me = Invoke-RestMethod -Uri ("https://api.telegram.org/bot"+$token+"/getMe") -TimeoutSec 8 >>"%PCHKTG%"
echo if (-not $me.ok) { Write-Output 'TOKEN_RUIM'; exit } >>"%PCHKTG%"
echo $ch = Invoke-RestMethod -Uri ("https://api.telegram.org/bot"+$token+"/getChat?chat_id="+$chat) -TimeoutSec 8 >>"%PCHKTG%"
echo if (-not $ch.ok) { Write-Output 'BOT_FORA_DO_GRUPO'; exit } >>"%PCHKTG%"
echo Write-Output 'OK' >>"%PCHKTG%"
echo } catch { Write-Output 'SEM_INTERNET' } >>"%PCHKTG%"
set "TGRES="
for /f "delims=" %%r in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PCHKTG%" "%TG_TOKEN%" "%TG_CHAT%"') do set "TGRES=%%r"
if "%TGRES%"=="TOKEN_RUIM" set "PROB_TG=token rejeitado pelo Telegram"
if "%TGRES%"=="BOT_FORA_DO_GRUPO" set "PROB_TG=o bot nao esta no grupo (chat id)"
:FIM_TESTE_TG

:: --- se tudo ok, sai calado ---
if not defined PROB_TG if not defined PROB_IA goto :eof

:: --- achou problema: mostra e oferece corrigir ---
:MOSTRAR_PROBLEMA
cls
color 0E
echo #############################################################
echo #          VERIFICACAO DE CONFIGURACAO                      #
echo #############################################################
echo.
echo   Encontrei um problema na configuracao salva:
echo.
if defined PROB_TG echo     [TELEGRAM] %PROB_TG%
if defined PROB_IA echo     [IA]       %PROB_IA%
echo.
echo   Voce pode corrigir agora (colar a chave certa) ou
echo   seguir assim mesmo.
echo.
echo     [T] Corrigir o Telegram
echo     [I] Corrigir a chave da IA
echo     [S] Seguir assim mesmo
echo.
choice /c TIS /n /m "  Escolha T, I ou S: "
set "OPC=%ERRORLEVEL%"
color 0A
if "%OPC%"=="3" goto IGNORAR_AVISO
if "%OPC%"=="1" goto CORRIGIR_TG
if "%OPC%"=="2" goto CORRIGIR_IA
goto :eof

:CORRIGIR_TG
cls
echo   --- Corrigir Telegram ---
echo.
echo   TOKEN do bot (BotFather). Ex: 123456:AAF...
set /p "TG_TOKEN=  Token: "
if defined TG_TOKEN set "TG_TOKEN=%TG_TOKEN:"=%"
echo.
echo   CHAT ID do grupo (comeca com -100...).
set /p "TG_CHAT=  Chat ID: "
if defined TG_CHAT set "TG_CHAT=%TG_CHAT:"=%"
set "TG_ENVIAR=sim"
call :SALVAR_CFG
echo.
echo   Telegram atualizado. Revalidando...
timeout /t 1 >nul
goto VERIFICAR_CHAVES

:CORRIGIR_IA
cls
echo   --- Corrigir chave da IA ---
echo.
echo   Cole a chave da DeepSeek (comeca com sk-).
set /p "IA_KEY=  Chave: "
if defined IA_KEY set "IA_KEY=%IA_KEY:"=%"
if not defined IA_KEY set "IA_KEY=x"
call :SALVAR_CFG
echo.
echo   Chave da IA atualizada.
timeout /t 1 >nul
goto VERIFICAR_CHAVES

:: =========================================================
:: IGNORAR_AVISO - insiste 3x antes de deixar seguir com problema
:: =========================================================
:IGNORAR_AVISO
set /a "IGN_REC=%IGN_REC%+1"
if %IGN_REC% GEQ 4 goto :eof
cls
color 0C
echo #############################################################
echo #                  A T E N C A O                           #
echo #############################################################
echo.
echo   Voce escolheu SEGUIR sem corrigir (tentativa %IGN_REC% de 3).
echo.
echo   Ignorar isso tem consequencia:
if defined PROB_TG (
  echo     [TELEGRAM] os laudos NAO serao enviados ao grupo.
  echo                O responsavel nao vai receber o resultado.
)
if defined PROB_IA (
  echo     [IA] o assistente de IA NAO vai funcionar.
  echo          Voce perde a analise automatica do teste.
)
echo.
echo   Recomendamos corrigir agora (leva 10 segundos).
echo.
echo     [T] Corrigir o Telegram
echo     [I] Corrigir a chave da IA
echo     [S] Seguir assim mesmo (por sua conta)
echo.
choice /c TIS /n /m "  Escolha T, I ou S: "
set "OPC2=%ERRORLEVEL%"
color 0A
if "%OPC2%"=="1" goto CORRIGIR_TG
if "%OPC2%"=="2" goto CORRIGIR_IA
:: escolheu seguir de novo
if %IGN_REC% GEQ 3 goto IGNORAR_FINAL
goto IGNORAR_AVISO

:IGNORAR_FINAL
cls
color 0C
echo   -----------------------------------------------------------
echo   Ok, seguindo com a configuracao com problema.
echo   Lembre-se de corrigir depois no config.ini para ter
echo   o envio ao Telegram e o assistente de IA funcionando.
echo   -----------------------------------------------------------
color 0A
timeout /t 3 >nul
goto :eof

:: grava o config atual (reusado pelas correcoes)
:SALVAR_CFG
>"%CFG%" echo TG_ENVIAR=%TG_ENVIAR%
>>"%CFG%" echo TG_TOKEN=%TG_TOKEN%
>>"%CFG%" echo TG_CHAT=%TG_CHAT%
>>"%CFG%" echo IA_KEY=%IA_KEY%
goto :eof

:LOCALIZAR
setlocal disabledelayedexpansion
set "_ACHOU="
for /f "delims=" %%f in ('dir /b /a-d "%AQUI%%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%AQUI%%%f"
if not defined _ACHOU for /f "delims=" %%f in ('dir /s /b /a-d "%USERPROFILE%\%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%%f"
if not defined _ACHOU for /f "delims=" %%f in ('dir /s /b /a-d "%SystemDrive%\%~2" 2^>nul') do if not defined _ACHOU set "_ACHOU=%%f"
endlocal & set "%~1=%_ACHOU%"
goto :eof
