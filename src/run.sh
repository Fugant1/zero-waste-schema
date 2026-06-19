#!/bin/bash

NOME_CONTAINER="bd-oracle"

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "[+] Variáveis de ambiente carregadas do .env com sucesso!"
else
    echo "[!] ERRO: Arquivo .env não encontrado na pasta atual."
    echo "Crie um arquivo .env contendo: SENHA_BD=sua_senha"
    exit 1
fi

if [ -z "$SENHA_BD" ]; then
    echo "[!] ERRO: A variável SENHA_BD não foi definida no arquivo .env."
    exit 1
fi

echo "===================================================="
echo "🚀 INICIANDO AMBIENTE ORACLE DATABASE NO UBUNTU"
echo "===================================================="

if [ "$(docker ps -aq -f name=$NOME_CONTAINER)" ]; then
    echo "[!] Removendo banco de dados anterior..."
    docker rm -f $NOME_CONTAINER > /dev/null 2>&1
fi

echo "[*] Subindo o contêiner do Oracle XE (pode levar 1-2 minutos)..."
docker run -d --name $NOME_CONTAINER \
  -p 1521:1521 \
  -e ORACLE_PASSWORD=$SENHA_BD \
  gvenzl/oracle-xe:slim > /dev/null

echo "[*] Aguardando o banco de dados inicializar e ficar saudável..."
until docker logs $NOME_CONTAINER 2>&1 | grep -q "DATABASE IS READY TO USE!"; do
  sleep 3
  echo -n "."
done
echo -e "\n[+] Banco de dados ONLINE e pronto para uso!"

echo "----------------------------------------------------"
echo "📦 EXECUTANDO 01: Criação do Esquema (Tabelas e Triggers)"
docker exec -i $NOME_CONTAINER sqlplus system/$SENHA_BD@//localhost/XE < esquema.sql

echo "----------------------------------------------------"
echo "📥 EXECUTANDO 02: Inserção de Dados (Inserts)"
docker exec -i $NOME_CONTAINER sqlplus system/$SENHA_BD@//localhost/XE < dados.sql

echo "----------------------------------------------------"
echo "📊 EXECUTANDO 03: Consultas ao Banco (Queries)"
docker exec -i $NOME_CONTAINER sqlplus system/$SENHA_BD@//localhost/XE < consultas.sql

echo "===================================================="
echo "✅ PROCESSO FINALIZADO COM SUCESSO!"
echo "O banco continua rodando na porta 1521."
echo "Para desligar o banco depois, digite: docker stop $NOME_CONTAINER"
echo "===================================================="