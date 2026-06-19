SET LINESIZE 200;
SET PAGESIZE 100;
SET COLSEP ' | ';

PROMPT =======================================================================
PROMPT CONSULTA 1: DIVISAO RELACIONAL
PROMPT Objetivo: Admins que ja moderaram TODOS os Doadores do sistema.
PROMPT =======================================================================

SELECT 
    U.NOME AS NOME_ADMINISTRADOR,
    U.EMAIL
FROM 
    ADMIN A
JOIN 
    USUARIO U ON A.USUARIO_ADM = U.CPF_CNPJ
WHERE 
    NOT EXISTS (
        SELECT D.USUARIO_DOA
        FROM DOADOR D
        WHERE NOT EXISTS (
            SELECT M.DOADOR
            FROM MODERACAO M
            WHERE M.ADM = A.USUARIO_ADM
              AND M.DOADOR = D.USUARIO_DOA
        )
    );

PROMPT =======================================================================
PROMPT CONSULTA 2: AGRUPAMENTO E FILTRO DE AGREGACOES (HAVING)
PROMPT Objetivo: Doadores com media de nota >= 4 e mais de 2 lotes doados.
PROMPT =======================================================================

SELECT
    U.NOME AS NOME_DOADOR,
    U.EMAIL,
    COUNT(DISTINCT L.CODIGO_LOTE) AS TOTAL_LOTES_DOADOS,
    ROUND(AVG(F.NOTA), 2) AS MEDIA_AVALIACAO
FROM 
    DOADOR D
JOIN USUARIO U ON D.USUARIO_DOA = U.CPF_CNPJ
JOIN LOTE_ITEM L ON D.USUARIO_DOA = L.DOADOR_
JOIN REQUISICAO R ON L.REQUISICAO_BEN = R.ID
JOIN AVALIACAO A ON R.ID = A.REQUISICAO_
JOIN FEEDBACK F ON A.REQUISICAO_ = F.AVALIACAO_REQ
GROUP BY 
    U.NOME, 
    U.EMAIL
HAVING 
    AVG(F.NOTA) >= 4.0 
    AND COUNT(DISTINCT L.CODIGO_LOTE) >= 2
ORDER BY 
    MEDIA_AVALIACAO DESC;

PROMPT =======================================================================
PROMPT CONSULTA 3: JUNCAO EXTERNA (LEFT JOIN) E CASOS (CASE WHEN)
PROMPT Objetivo: Painel de entregadores, contando entregas e classificando-os.
PROMPT =======================================================================

SELECT
    U.NOME AS NOME_TRANSPORTADOR,
    U.TELEFONE,
    COUNT(E.CODIGO) AS TOTAL_ENTREGAS,
    CASE
        WHEN COUNT(E.CODIGO) > 10 THEN 'Entregador Elite'
        WHEN COUNT(E.CODIGO) BETWEEN 1 AND 10 THEN 'Entregador Ativo'
        ELSE 'Sem Entregas Realizadas'
    END AS CLASSIFICACAO
FROM 
    TRANSPORTADOR T
JOIN 
    USUARIO U ON T.USUARIO_TRA = U.CPF_CNPJ
LEFT JOIN 
    ENTREGA E ON T.USUARIO_TRA = E.TRANSPORTADOR_ 
    AND E.STATUS = 'FINALIZADA'
GROUP BY 
    U.NOME, 
    U.TELEFONE,
    T.USUARIO_TRA
ORDER BY 
    TOTAL_ENTREGAS DESC;

PROMPT =======================================================================
PROMPT CONSULTA 4: OPERADOR DE CONJUNTO (MINUS) OTIMIZADA
PROMPT Objetivo: Doadores que receberam Denuncia, EXCETO os que ja tiveram nota 5.
PROMPT =======================================================================

-- Primeira parte otimizada: Filtra direto pela flag na tabela pai, eliminando um JOIN
SELECT U.CPF_CNPJ, U.NOME
FROM USUARIO U
JOIN DOADOR D ON U.CPF_CNPJ = D.USUARIO_DOA
JOIN LOTE_ITEM L ON D.USUARIO_DOA = L.DOADOR_
JOIN REQUISICAO R ON L.REQUISICAO_BEN = R.ID
JOIN AVALIACAO A ON R.ID = A.REQUISICAO_
WHERE A.EH_DENUNCIA = '1' 
MINUS
SELECT U.CPF_CNPJ, U.NOME
FROM USUARIO U
JOIN DOADOR D ON U.CPF_CNPJ = D.USUARIO_DOA
JOIN LOTE_ITEM L ON D.USUARIO_DOA = L.DOADOR_
JOIN REQUISICAO R ON L.REQUISICAO_BEN = R.ID
JOIN AVALIACAO A ON R.ID = A.REQUISICAO_
JOIN FEEDBACK F ON A.REQUISICAO_ = F.AVALIACAO_REQ
WHERE F.NOTA = 5;

PROMPT =======================================================================
PROMPT CONSULTA 5: SUBCONSULTA CORRELACIONADA E DATAS
PROMPT Objetivo: Requisicoes pendentes contendo itens que vencem em ate 7 dias.
PROMPT =======================================================================

SELECT
    U.NOME AS NOME_BENEFICIARIO,
    R.ID AS NRO_REQUISICAO,
    RR.DATA_RETIRADA,
    SUM(L.PRECO) AS VALOR_TOTAL_REQ
FROM 
    BENEFICIARIO B
JOIN USUARIO U ON B.USUARIO_BEN = U.CPF_CNPJ
JOIN REQUISICAO R ON B.USUARIO_BEN = R.BENEFICIARIO_
JOIN REQ_RETIRADA RR ON R.ID = RR.REQUISICAO_
JOIN LOTE_ITEM L ON R.ID = L.REQUISICAO_BEN
WHERE 
    R.STATUS = 'PENDENTE'
    AND EXISTS (
        SELECT 1
        FROM LOTE_ITEM LI
        WHERE LI.REQUISICAO_BEN = R.ID
          AND LI.VALIDADE <= SYSDATE + 7
    )
GROUP BY 
    U.NOME, 
    R.ID, 
    RR.DATA_RETIRADA;

PROMPT =======================================================================
PROMPT CONSULTA 6: VITRINE DE APP (FILTRO NULL)
PROMPT Objetivo: Mostrar itens disponiveis (sem requisicao) ordenados por validade.
PROMPT =======================================================================

SELECT
    L.CODIGO_LOTE,
    L.NOME AS ITEM_DISPONIVEL,
    L.CATEGORIA,
    L.QUANTIDADE_ITENS,
    U.NOME AS NOME_DOADOR,
    L.VALIDADE
FROM 
    LOTE_ITEM L
JOIN 
    DOADOR D ON L.DOADOR_ = D.USUARIO_DOA
JOIN 
    USUARIO U ON D.USUARIO_DOA = U.CPF_CNPJ
WHERE 
    L.REQUISICAO_BEN IS NULL
ORDER BY 
    L.VALIDADE ASC;

EXIT;