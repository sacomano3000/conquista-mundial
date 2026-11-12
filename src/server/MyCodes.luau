-- SEUS CÓDIGOS DE RESGATE.
--
-- O jogador abre as Configurações (a engrenagem), digita o código em "Código de resgate" e toca em
-- RESGATAR. Cada jogador usa cada código uma vez só. Este arquivo fica só no servidor
-- (ServerScriptService): os jogadores não conseguem ler a lista.
--
-- Uma linha por código:
--     ["CODIGO"] = { coroas = 5000 },
--
--   coroas   quantas Coroas o código dá (obrigatório, maior que zero)
--   expira   opcional: o último dia em que vale, "AAAA-MM-DD" (o dia acaba às 21h de Brasília, que é
--            meia-noite no horário universal)
--   ativo    opcional: ponha false para desligar um código sem apagar a linha
--
-- JEITO MAIS FÁCIL: você também cria códigos de dentro do jogo, sem mexer aqui e sem publicar. No
-- chat do jogo, digite  /codigo criar NATAL 5000  ou  /codigo gerar 5000  (veja o GUIA, seção 8).
-- Os códigos criados pelo chat ficam salvos fora deste arquivo; os daqui continuam valendo. Um nome
-- que está nesta lista não pode ser criado pelo chat.
--
-- O código pode ter letras, números, "_" e "-", de 3 a 24 caracteres. Maiúsculas e minúsculas tanto
-- faz ("bemvindo" e "BEMVINDO" são o mesmo), e acentos não entram.
--
-- Para criar um código novo: copie uma linha, troque o nome e a quantia, salve e publique o jogo.
-- Apagar uma linha (ou pôr ativo = false) faz o código parar de valer; quem já resgatou fica com as
-- Coroas.
return {
	["BEMVINDO"] = { coroas = 5000 },
	-- ["LANCAMENTO"] = { coroas = 20000, expira = "2027-01-31" },
	-- ["OBRIGADO10K"] = { coroas = 10000, ativo = false },
}
