@echo off
chcp 65001 >nul
setlocal

:: =========================================================
::  CADASTRO DE ROTEADOR v%VER% - por Ronald
::  - Tecnico digita o NOME dele e a O.S.
::  - Captura sozinho o MAC do roteador do cliente
::  - Envia o registro para o Telegram
::  - Guarda copia local em CSV (nada se perde se cair a net)
::
::  DELAYED EXPANSION DESLIGADO DE PROPOSITO:
::  nome com "!" (ex: Joao!) seria comido pelo cmd.
:: =========================================================

:: +=======================================================+
::   >>> UNICO LUGAR PARA MUDAR A VERSAO <<<
:: +=======================================================+
set "VER=1000"

title CADASTRO DE ROTEADOR v%VER% - por Ronald
color 0B
set "AQUI=%~dp0"

:: +=======================================================+
::   ATUALIZACAO AUTOMATICA (GitHub)
::   Precisa existir no repo: versao_cadastro.txt (so o
::   numero), CADASTRO_MAC.bat e novidades_cadastro.txt.
:: +=======================================================+
set "VERSAO_LOCAL=%VER%"
set "RAW_BASE=https://raw.githubusercontent.com/baratavaat-wq/Ronald/main/"
set "URL_VERSAO=%RAW_BASE%versao_cadastro.txt"
set "URL_SCRIPT=%RAW_BASE%CADASTRO_MAC.bat"
set "URL_NOTAS=%RAW_BASE%novidades_cadastro.txt"
set "URL_PAGINA="
set "CHECAR_UPDATE=sim"

:: +=======================================================+
::   TELEGRAM - token e chat ficam no config.ini
::   (mesmo arquivo do LAUDO DE REDE: quem ja configurou
::   la nao precisa digitar de novo)
:: +=======================================================+
set "CFG_DIR=%ProgramData%\LaudoRede"
set "CFG=%CFG_DIR%\config.ini"
set "TG_ENVIAR=sim"
set "TG_TOKEN="
set "TG_CHAT="
set "IA_KEY="
set "ULTIMO_TEC="

cls
echo =====================================================
echo          CADASTRO DE ROTEADOR  v%VER%
echo          Criado por: Ronald
echo =====================================================
echo.

call :CHECAR_ATUALIZACAO
call :CARREGAR_CONFIG

:: =========================================================
:: INICIO DE UM CADASTRO (volta aqui a cada nova O.S.)
:: =========================================================
:NOVO_CADASTRO
set "TECNICO="
set "OS_ID="
set "GW="
set "GW_MAC="
set "IPLOCAL="
set "TIPO="
set "SSID="
set "BSSID="
set "MAC_ORIGEM="

:PEDIR_TECNICO
cls
color 0B
echo =====================================================
echo          CADASTRO DE ROTEADOR  v%VER%
echo =====================================================
echo.
if defined ULTIMO_TEC echo   Ultimo tecnico usado: %ULTIMO_TEC%
if defined ULTIMO_TEC echo   ^(ENTER mantem esse nome^)
if defined ULTIMO_TEC echo.
set "TECNICO="
set /p "TECNICO=  Nome do tecnico: "
if not defined TECNICO set "TECNICO=%ULTIMO_TEC%"
call :LIMPAR TECNICO
if not defined TECNICO (
  echo.
  echo   [!] O nome do tecnico e obrigatorio.
  timeout /t 2 >nul
  goto PEDIR_TECNICO
)

:PEDIR_OS
echo.
set "OS_ID="
set /p "OS_ID=  Numero da O.S.: "
call :LIMPAR OS_ID
if not defined OS_ID (
  echo.
  echo   [!] A O.S. e obrigatoria.
  timeout /t 2 >nul
  goto PEDIR_OS
)

:: =========================================================
:: CAPTURA AUTOMATICA (gateway, MAC, IP local, Wi-Fi)
:: =========================================================
echo.
echo   Procurando o roteador do cliente...

call :DETECTAR_GATEWAY
call :DETECTAR_CONEXAO
call :DETECTAR_MAC

set "DTHORA=%date% %time:~0,8%"

:CONFERIR
cls
color 0B
echo =====================================================
echo            CONFIRA ANTES DE ENVIAR
echo =====================================================
echo.
echo   Tecnico   : %TECNICO%
echo   O.S.      : %OS_ID%
echo   ---------------------------------------------------
echo   MAC do rot: %GW_MAC%   %MAC_ORIGEM%
echo   Gateway   : %GW%
echo   Conexao   : %TIPO%
if defined SSID echo   Wi-Fi SSID: %SSID%
if defined BSSID echo   BSSID     : %BSSID%
echo   IP local  : %IPLOCAL%
echo   PC        : %COMPUTERNAME%
echo   Data/hora : %DTHORA%
echo =====================================================
echo.
echo     [1] Enviar para o Telegram
echo     [2] Corrigir nome / O.S.
echo     [3] Digitar o MAC na mao
echo     [4] Cancelar este cadastro
echo.
choice /c 1234 /n /m "  Escolha (1-4): "
if errorlevel 4 goto NOVO_CADASTRO
if errorlevel 3 goto MAC_MANUAL
if errorlevel 2 goto PEDIR_TECNICO

:: =========================================================
:: GRAVA A COPIA LOCAL ANTES DE ENVIAR
:: (se a net cair, o registro NAO se perde)
:: =========================================================
set "CSV=%CFG_DIR%\registros_mac.csv"
if not exist "%CSV%" >"%CSV%" echo DATA_HORA;TECNICO;OS;MAC_ROTEADOR;GATEWAY;CONEXAO;SSID;BSSID;IP_LOCAL;PC
>>"%CSV%" echo %DTHORA%;%TECNICO%;%OS_ID%;%GW_MAC%;%GW%;%TIPO%;%SSID%;%BSSID%;%IPLOCAL%;%COMPUTERNAME%

:: guarda o ultimo tecnico pra proxima O.S.
set "ULTIMO_TEC=%TECNICO%"
call :GRAVA_CONFIG

:: =========================================================
:: ENVIO AO TELEGRAM
:: =========================================================
:ENVIAR
cls
echo =====================================================
echo            ENVIANDO PARA O TELEGRAM
echo =====================================================
echo.
if /i "%TG_ENVIAR%"=="nao" (
  color 0E
  echo   Telegram desligado no config.ini.
  echo   O registro foi salvo so na copia local:
  echo   %CSV%
  echo.
  goto FIM_CADASTRO
)

call :MONTAR_PS_TELEGRAM
powershell -NoProfile -ExecutionPolicy Bypass -File "%PTG%" "%TECNICO%" "%OS_ID%" "%GW_MAC%" "%GW%" "%IPLOCAL%" "%TIPO%" "%SSID%" "%BSSID%" "%COMPUTERNAME%" "%DTHORA%"
if errorlevel 1 goto FALHA_ENVIO

color 0A
echo.
echo   Registro da O.S. %OS_ID% enviado com sucesso.
echo   Copia local: %CSV%
goto FIM_CADASTRO

:FALHA_ENVIO
color 0C
echo.
echo   Nao consegui enviar agora. O registro JA ESTA SALVO em:
echo   %CSV%
echo.
echo     [1] Tentar enviar de novo
echo     [2] Seguir sem enviar
echo.
choice /c 12 /n /m "  Escolha (1-2): "
if errorlevel 2 goto FIM_CADASTRO
goto ENVIAR

:FIM_CADASTRO
echo.
echo =====================================================
echo     [1] Cadastrar outra O.S.
echo     [2] Sair
echo.
choice /c 12 /n /m "  Escolha (1-2): "
if errorlevel 2 goto SAIR
goto NOVO_CADASTRO

:SAIR
cls
color 0B
echo =====================================================
echo   Historico de todos os cadastros deste PC:
echo   %CFG_DIR%\registros_mac.csv
echo =====================================================
echo.
timeout /t 3 >nul
goto :FIM

:: =========================================================
:: DIGITAR O MAC NA MAO (roteador que nao responde ARP)
:: =========================================================
:MAC_MANUAL
echo.
set "GW_MAC="
set /p "GW_MAC=  Digite o MAC do roteador: "
call :LIMPAR GW_MAC
if not defined GW_MAC goto CONFERIR
call :MAC_MAIUSCULO
set "MAC_ORIGEM=(digitado)"
goto CONFERIR

:: =========================================================
:: SUB: GATEWAY AUTOMATICO (3 planos, nada de IP fixo)
:: =========================================================
:DETECTAR_GATEWAY
set "GW="
for /f "tokens=3" %%g in ('route print -4 ^| findstr /r /c:"^ *0\.0\.0\.0 *0\.0\.0\.0"') do if not defined GW set "GW=%%g"
if not defined GW for /f "delims=" %%g in ('powershell -NoProfile -Command "(Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null } ^| Select-Object -First 1 -ExpandProperty IPv4DefaultGateway).NextHop" 2^>nul') do if not defined GW set "GW=%%g"
if not defined GW for /f "tokens=1,* delims=:" %%a in ('ipconfig ^| findstr /i /c:"Gateway"') do call :TENTAR_GW "%%b"
if not defined GW set "GW=nao encontrado"
goto :eof

:TENTAR_GW
if defined GW goto :eof
set "V=%~1"
call :TIRA_ESPACO V
if not defined V goto :eof
echo %V%| findstr /r /c:"^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul && set "GW=%V%"
goto :eof

:: =========================================================
:: SUB: TIPO DE CONEXAO + IP LOCAL + SSID/BSSID
:: =========================================================
:DETECTAR_CONEXAO
:: primeiro tenta o IP da placa que realmente tem gateway
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null } ^| Select-Object -First 1 -ExpandProperty IPv4Address).IPAddress" 2^>nul') do if not defined IPLOCAL set "IPLOCAL=%%i"
:: plano B: primeiro IPv4 do ipconfig
if not defined IPLOCAL for /f "tokens=1,* delims=:" %%a in ('ipconfig ^| findstr /i /c:"IPv4"') do call :PEGA_IP "%%b"
if not defined IPLOCAL set "IPLOCAL=nao identificado"

for /f "tokens=1,* delims=:" %%a in ('netsh wlan show interfaces 2^>nul ^| findstr /r /c:"^ *SSID *:"') do call :PEGA_SSID "%%b"
call :PEGA_BSSID

if defined SSID (set "TIPO=Wi-Fi") else (set "TIPO=Cabo / Ethernet")
goto :eof

:PEGA_IP
if defined IPLOCAL goto :eof
set "V=%~1"
call :TIRA_ESPACO V
set "IPLOCAL=%V%"
goto :eof

:PEGA_SSID
if defined SSID goto :eof
set "V=%~1"
call :TIRA_ESPACO V
if defined V set "SSID=%V%"
goto :eof

:PEGA_BSSID
:: o MAC tem ":" e o for quebra nele, entao remonta os dois pedacos
for /f "tokens=2,* delims=:" %%x in ('netsh wlan show interfaces 2^>nul ^| findstr /r /c:"^ *BSSID *:"') do if not defined BSSID set "BSSID=%%x:%%y"
if defined BSSID call :TIRA_ESPACO BSSID
goto :eof

:: =========================================================
:: SUB: MAC DO ROTEADOR PELA TABELA ARP
:: =========================================================
:DETECTAR_MAC
set "GW_MAC="
set "MAC_ORIGEM="
if not defined GW goto MAC_NAO
if "%GW%"=="nao encontrado" goto MAC_NAO
call :OBTER_MAC_ARP
if defined GW_MAC goto MAC_ACHOU
:: acorda a entrada ARP e tenta de novo
ping -n 1 -w 800 %GW% >nul 2>&1
call :OBTER_MAC_ARP
if not defined GW_MAC goto MAC_NAO
:MAC_ACHOU
call :MAC_MAIUSCULO
set "MAC_ORIGEM=(ARP)"
goto :eof
:MAC_NAO
set "GW_MAC=NAO ENCONTRADO"
set "MAC_ORIGEM=(use a opcao 3)"
goto :eof

:OBTER_MAC_ARP
for /f "tokens=1,2" %%a in ('arp -a 2^>nul') do if "%%a"=="%GW%" set "GW_MAC=%%b"
goto :eof

:MAC_MAIUSCULO
set "M=%GW_MAC%"
set "M=%M:a=A%"
set "M=%M:b=B%"
set "M=%M:c=C%"
set "M=%M:d=D%"
set "M=%M:e=E%"
set "M=%M:f=F%"
set "M=%M::=-%"
set "GW_MAC=%M%"
goto :eof

:: =========================================================
:: SUB: LIMPEZA DE TEXTO DIGITADO
:: (tira o que quebraria o batch ou o PowerShell)
:: =========================================================
:LIMPAR
call set "V=%%%~1%%"
if not defined V goto :eof
set "V=%V:"=%"
set "V=%V:^=%"
set "V=%V:&=%"
set "V=%V:|=%"
set "V=%V:<=%"
set "V=%V:>=%"
set "V=%V:;=,%"
call :TIRA_ESPACO V
set "%~1=%V%"
goto :eof

:TIRA_ESPACO
call set "W=%%%~1%%"
if not defined W goto :eof
for /f "tokens=* delims= " %%x in ("%W%") do set "W=%%x"
:TIRA_FIM
if not defined W goto TIRA_PRONTO
if "%W:~-1%"==" " (set "W=%W:~0,-1%" & goto TIRA_FIM)
:TIRA_PRONTO
set "%~1=%W%"
goto :eof

:: =========================================================
:: SUB: SCRIPT DO TELEGRAM
::   token e chat sao GRAVADOS DENTRO do .ps1 (igual ao
::   LAUDO_REDE.bat), em vez de ir por parametro de linha
::   de comando. Motivo: chat_id de grupo comeca com "-100"
::   e o PowerShell interpreta um argumento posicional que
::   comeca com "-" como se fosse um NOME de parametro, e
::   o bind falha/perde o valor silenciosamente. Gravando
::   $token/$chat direto no arquivo, esse problema some.
:: =========================================================
:MONTAR_PS_TELEGRAM
set "PTG=%TEMP%\cad_tg.ps1"
del "%PTG%" >nul 2>&1
set "TG_TOKEN_ESC=%TG_TOKEN:'=''%"
set "TG_CHAT_ESC=%TG_CHAT:'=''%"
echo param($tec,$os,$mac,$gw,$ip,$tipo,$ssid,$bssid,$pc,$dt) >>"%PTG%"
echo $token = '%TG_TOKEN_ESC%' >>"%PTG%"
echo $chat = '%TG_CHAT_ESC%' >>"%PTG%"
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 >>"%PTG%"
echo Add-Type -AssemblyName System.Net.Http >>"%PTG%"
echo $api = 'https://api.telegram.org/bot' + $token >>"%PTG%"
echo $cli = New-Object System.Net.Http.HttpClient >>"%PTG%"
echo $cli.Timeout = [TimeSpan]::FromMinutes(2) >>"%PTG%"
echo $L = @() >>"%PTG%"
echo $L += 'REGISTRO DE ROTEADOR - O.S. ' + $os >>"%PTG%"
echo $L += '' >>"%PTG%"
echo $L += 'Tecnico  : ' + $tec >>"%PTG%"
echo $L += 'O.S.     : ' + $os >>"%PTG%"
echo $L += 'MAC rot. : ' + $mac >>"%PTG%"
echo $L += 'Gateway  : ' + $gw >>"%PTG%"
echo $L += 'Conexao  : ' + $tipo >>"%PTG%"
echo if ($ssid -ne '') { $L += 'Wi-Fi    : ' + $ssid } >>"%PTG%"
echo if ($bssid -ne '') { $L += 'BSSID    : ' + $bssid } >>"%PTG%"
echo $L += 'IP local : ' + $ip >>"%PTG%"
echo $L += 'PC       : ' + $pc >>"%PTG%"
echo $L += 'Data/hora: ' + $dt >>"%PTG%"
echo $msg = ($L -join [Environment]::NewLine) >>"%PTG%"
echo Write-Host '' >>"%PTG%"
echo Write-Host ('  Enviando para o chat ' + $chat + ' ...') -ForegroundColor Cyan >>"%PTG%"
echo try { >>"%PTG%"
echo   $f = New-Object System.Net.Http.MultipartFormDataContent >>"%PTG%"
echo   $f.Add((New-Object System.Net.Http.StringContent($chat, [System.Text.Encoding]::UTF8)), 'chat_id') >>"%PTG%"
echo   $f.Add((New-Object System.Net.Http.StringContent($msg, [System.Text.Encoding]::UTF8)), 'text') >>"%PTG%"
echo   $r = $cli.PostAsync(($api + '/sendMessage'), $f).Result >>"%PTG%"
echo   $b = $r.Content.ReadAsStringAsync().Result >>"%PTG%"
echo   if ($r.IsSuccessStatusCode) { Write-Host '  [OK] Enviado.' -ForegroundColor Green; exit 0 } >>"%PTG%"
echo   Write-Host ('  [FALHA] HTTP ' + [int]$r.StatusCode) -ForegroundColor Red >>"%PTG%"
echo   Write-Host ('  [TELEGRAM] ' + $b) -ForegroundColor Yellow >>"%PTG%"
echo   Write-Host '  chat not found = ID errado / bot is not a member = poe o bot no grupo' -ForegroundColor DarkGray >>"%PTG%"
echo   exit 1 >>"%PTG%"
echo } catch { Write-Host ('  [ERRO] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } >>"%PTG%"
goto :eof

:: =========================================================
:: SUB: CONFIG.INI (mesmo do LAUDO DE REDE)
:: =========================================================
:CARREGAR_CONFIG
if not exist "%CFG_DIR%" mkdir "%CFG_DIR%" >nul 2>&1
break>"%CFG_DIR%\_t.tmp" 2>nul
if exist "%CFG_DIR%\_t.tmp" (del "%CFG_DIR%\_t.tmp" >nul 2>&1) else (call :USAR_APPDATA)

if exist "%CFG%" for /f "usebackq tokens=1,* delims==" %%a in ("%CFG%") do call :APLICAR_CFG "%%a" "%%b"
if defined TG_TOKEN if defined TG_CHAT goto :eof

cls
echo =====================================================
echo         CONFIGURACAO INICIAL DO TELEGRAM
echo =====================================================
echo.
echo   Primeira execucao neste computador.
echo   Fica salvo e NAO pergunta de novo, nem quando o
echo   script se atualizar pelo GitHub.
echo.
echo   Onde fica: %CFG%
echo.
echo   Enviar os cadastros para o Telegram?
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
if not defined TG_ENVIAR set "TG_ENVIAR=sim"
if not defined IA_KEY set "IA_KEY=x"
>"%CFG%" echo TG_ENVIAR=%TG_ENVIAR%
>>"%CFG%" echo TG_TOKEN=%TG_TOKEN%
>>"%CFG%" echo TG_CHAT=%TG_CHAT%
>>"%CFG%" echo IA_KEY=%IA_KEY%
>>"%CFG%" echo ULTIMO_TEC=%ULTIMO_TEC%
goto :eof

:APLICAR_CFG
if /i "%~1"=="TG_TOKEN" set "TG_TOKEN=%~2"
if /i "%~1"=="TG_CHAT" set "TG_CHAT=%~2"
if /i "%~1"=="TG_ENVIAR" set "TG_ENVIAR=%~2"
if /i "%~1"=="IA_KEY" set "IA_KEY=%~2"
if /i "%~1"=="ULTIMO_TEC" set "ULTIMO_TEC=%~2"
goto :eof

:USAR_APPDATA
set "CFG_DIR=%APPDATA%\LaudoRede"
set "CFG=%APPDATA%\LaudoRede\config.ini"
if not exist "%APPDATA%\LaudoRede" mkdir "%APPDATA%\LaudoRede" >nul 2>&1
goto :eof

:: =========================================================
:: SUB: ATUALIZACAO AUTOMATICA NO GITHUB
:: =========================================================
:CHECAR_ATUALIZACAO
if /i not "%CHECAR_UPDATE%"=="sim" goto :eof
set "VERSAO_REMOTA="
set "PVER=%TEMP%\cad_ver.ps1"
del "%PVER%" >nul 2>&1
echo $ProgressPreference = 'SilentlyContinue' >>"%PVER%"
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 >>"%PVER%"
echo try { >>"%PVER%"
echo $r = Invoke-WebRequest -Uri '%URL_VERSAO%' -UseBasicParsing -TimeoutSec 4 >>"%PVER%"
echo Write-Output ([string]$r.Content).Trim() >>"%PVER%"
echo } catch { Write-Output 'ERRO' } >>"%PVER%"

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
if %VR% EQU %VL% (echo   Voce ja esta na versao publicada ^(v%VERSAO_LOCAL%^). & timeout /t 2 >nul & goto :eof)
set "PALAVRA=atualizacao disponivel"
if %VR% LSS %VL% set "PALAVRA=RETORNO de versao solicitado"

set "NOTAS=%TEMP%\cad_notas.txt"
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
echo     [2] Baixar manualmente (abre o repositorio no navegador)
echo     [3] Continuar na versao atual
echo.
choice /c 123 /n /m "  Escolha 1, 2 ou 3: "
if errorlevel 3 goto RECUSAR_UPDATE
if errorlevel 2 goto UPDATE_MANUAL
goto FAZER_UPDATE

:RECUSAR_UPDATE
color 0C
echo.
echo   Voce escolheu NAO atualizar.
echo   Versao antiga pode ter erro ja corrigido e envio
echo   ao Telegram com problema.
echo.
choice /c SN /n /m "  Continuar mesmo assim na versao antiga? [S/N]: "
if errorlevel 2 (color 0B & cls & goto MENU_UPDATE)
color 0B
timeout /t 2 >nul
goto :eof

:UPDATE_MANUAL
set "URL_PAGINA=%RAW_BASE:raw.githubusercontent.com=github.com%"
set "URL_PAGINA=%URL_PAGINA:/main/=%"
cls
echo =====================================================
echo            DOWNLOAD MANUAL DA ATUALIZACAO
echo =====================================================
echo.
echo   Abrindo o repositorio no navegador...
echo   %URL_PAGINA%
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
set "NOVO=%AQUI%CADASTRO_MAC.new"
del "%NOVO%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { (New-Object System.Net.WebClient).DownloadFile('%URL_SCRIPT%','%NOVO%'); exit 0 } catch { exit 1 }"
if errorlevel 1 (echo   [FALHA] Nao consegui baixar. Seguindo com a versao atual. & del "%NOVO%" >nul 2>&1 & timeout /t 2 >nul & goto :eof)

for %%A in ("%NOVO%") do set "TAM_NOVO=%%~zA"
if not defined TAM_NOVO (del "%NOVO%" >nul 2>&1 & goto :eof)
if %TAM_NOVO% LSS 2000 (echo   [FALHA] Arquivo baixado invalido. Mantendo a versao atual. & del "%NOVO%" >nul 2>&1 & timeout /t 2 >nul & goto :eof)

set "UPD=%TEMP%\cad_update.bat"
set "EU=%~f0"
del "%UPD%" >nul 2>&1
>"%UPD%" echo @echo off
>>"%UPD%" echo chcp 65001 ^>nul
>>"%UPD%" echo title Atualizando CADASTRO DE ROTEADOR...
>>"%UPD%" echo ping 127.0.0.1 -n 4 ^>nul
>>"%UPD%" echo copy /y "%NOVO%" "%EU%" ^>nul
>>"%UPD%" echo if exist "%NOVO%" del "%NOVO%" ^>nul 2^>^&1
>>"%UPD%" echo start "" "%EU%"
>>"%UPD%" echo ^(goto^) 2^>nul ^& del "%%~f0"
echo   Atualizando e reiniciando...
start "" cmd /c "%UPD%"
exit

:FIM
endlocal
