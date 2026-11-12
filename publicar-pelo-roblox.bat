@echo off
setlocal
title Publicar Conquista Mundial
rem Envia o ConquistaMundial.rbxl desta pasta para o lugar 93039487176393 (Conquista Mundial),
rem pela API do Roblox (Open Cloud), sem passar pelo Studio. Precisa de uma chave de API da sua conta.
set "PLACE=93039487176393"
pushd "%~dp0"
if exist "ConquistaMundial.rbxl" goto temarquivo
echo.
echo Nao achei o arquivo ConquistaMundial.rbxl nesta pasta.
echo Ponha este arquivo .bat na MESMA pasta do ConquistaMundial.rbxl e abra de novo.
echo.
pause
exit /b 1

:temarquivo
echo.
echo Cole a sua chave de API do Roblox e aperte Enter.
echo (clique com o botao direito do mouse nesta janela para colar)
echo.
set "KEY="
set /p "KEY=Chave: "
if not defined KEY goto semchave
echo.
echo Enviando o arquivo... pode levar um minuto.
echo.
curl.exe --silent --show-error --location --request PATCH "https://apis.roblox.com/assets/v1/assets/%PLACE%" --header "x-api-key: %KEY%" --form "request={\"assetId\": %PLACE%, \"assetType\": \"Place\", \"published\": true}" --form "fileContent=@ConquistaMundial.rbxl;type=application/octet-stream" --output "cm_envio.txt" --write-out "Resposta do Roblox (numero): %%{http_code}\n"
if errorlevel 1 goto semrede
echo Resposta do Roblox (texto):
type "cm_envio.txt"
echo.
echo.
set "OP="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "try { (Get-Content -Raw 'cm_envio.txt' | ConvertFrom-Json).path } catch { }"`) do set "OP=%%A"
if not defined OP goto recusado

echo O Roblox aceitou o arquivo. Esperando ele terminar de processar...
set /a N=0
:espera
set /a N+=1
timeout /t 4 /nobreak >nul
curl.exe --silent --show-error --location "https://apis.roblox.com/assets/v1/%OP%" --header "x-api-key: %KEY%" --output "cm_estado.txt"
set "DONE="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "try { if ((Get-Content -Raw 'cm_estado.txt' | ConvertFrom-Json).done) { 'sim' } } catch { }"`) do set "DONE=%%A"
if defined DONE goto pronto
if %N% lss 45 goto espera
echo.
echo O Roblox ainda nao terminou depois de 3 minutos. Ultima resposta:
type "cm_estado.txt"
echo.
goto fim

:pronto
echo.
echo Resultado final:
type "cm_estado.txt"
echo.
echo.
echo Se a linha acima tem  "isPublished":true  o jogo foi PUBLICADO.
echo Se tem a palavra  error  nao foi: copie a linha inteira e mande para mim.
goto fim

:recusado
echo O Roblox NAO aceitou o envio. Copie as duas respostas acima e mande para mim.
echo (401 = chave errada;  403 = a chave nao tem a permissao de escrever neste jogo)
goto fim

:semrede
echo.
echo Nao consegui falar com o Roblox (sem internet, ou algo bloqueou a conexao).
echo Copie a mensagem acima e mande para mim.
goto fim

:semchave
echo Nenhuma chave foi colada.

:fim
if exist "cm_envio.txt" del "cm_envio.txt"
if exist "cm_estado.txt" del "cm_estado.txt"
set "KEY="
echo.
pause
popd
endlocal
