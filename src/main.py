import os
import oracledb
from dotenv import load_dotenv

load_dotenv()

DB_USER = "system"
DB_PASSWORD = os.getenv("SENHA_BD")
DB_DSN = "localhost:1521/XE"

def conectar():
    """Estabelece a conexão com o banco de dados Oracle."""
    if not DB_PASSWORD:
        print("Erro: A variável SENHA_BD não foi encontrada no arquivo .env!")
        return None

    try:
        conexao = oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)
        return conexao
    except oracledb.DatabaseError as e:
        error, = e.args
        print(f"Erro ao conectar ao banco de dados: {error.message}")
        return None

def cadastrar_doador(conexao):
    """
    ATENDE AO REQUISITO 4A:
    Insere dados em múltiplas tabelas (USUARIO e DOADOR) respeitando a herança,
    com tratamento de erros e controle de transação (commit/rollback).
    """
    print("\n--- Cadastrar Novo Doador ---")
    # Dados para a tabela USUARIO
    cpf_cnpj = input("Digite o CPF ou CNPJ (até 14 caracteres): ")
    nome = input("Digite o Nome do Doador: ")
    telefone = input("Digite o Telefone: ")
    email = input("Digite o Email: ")
    
    # Dados específicos para a tabela DOADOR
    endereco = input("Digite o Endereço: ")
    horario = input("Digite o Horário de Funcionamento: ")
    intervalo = input("Digite o Intervalo para Retirada (Pressione Enter se não houver): ")
    if not intervalo:
        intervalo = None # Trata valores nulos corretamente para o BD

    cursor = conexao.cursor()
    
    try:
        # Passo 1: Inserir na tabela pai (USUARIO). TIPO é forçado como 'DOADOR'
        sql_usuario = """
            INSERT INTO USUARIO (CPF_CNPJ, NOME, TELEFONE, EMAIL, TIPO)
            VALUES (:1, :2, :3, :4, 'DOADOR')
        """
        cursor.execute(sql_usuario, (cpf_cnpj, nome, telefone, email))

        # Passo 2: Inserir na tabela filha (DOADOR).
        sql_doador = """
            INSERT INTO DOADOR (USUARIO_DOA, ENDERECO, HORARIO_FUNCIONAMENTO, INTERVALO_RETIRADA)
            VALUES (:1, :2, :3, :4)
        """
        cursor.execute(sql_doador, (cpf_cnpj, endereco, horario, intervalo))

        # Se as duas inserções funcionaram, confirmamos as alterações no banco
        conexao.commit()
        print("\n✅ Doador cadastrado com sucesso em ambas as tabelas!")

    except oracledb.DatabaseError as e:
        # Tratamento de erro: se algo falhar, desfaz as operações pendentes
        conexao.rollback()
        error, = e.args

        if error.code == 1: # ORA-00001: Violação de chave única (CPF ou Email repetido)
            print("\n❌ Erro: Este CPF/CNPJ ou E-mail já está cadastrado no sistema.")
        elif error.code == 2290: # ORA-02290: Violação de CHECK (ex: email fora do padrão)
            print("\n❌ Erro: Alguma informação foi digitada fora do padrão (verifique o formato do e-mail).")
        else:
            print("\n❌ Erro inesperado no sistema. Por favor, tente novamente mais tarde.")
    finally:
        cursor.close()

def consultar_doadores_parametrizada(conexao):
    """
    ATENDE AO REQUISITO 4B:
    Consulta ao banco com entrada de dados do usuário como parâmetro.
    Baseado na Consulta 2 do script original.
    """
    print("\n--- Buscar Doadores por Desempenho ---")
    
    # Coleta os parâmetros do usuário
    try:
        nota_min = float(input("Digite a nota média mínima desejada (ex: 4.0): "))
        lotes_min = int(input("Digite a quantidade mínima de lotes doados (ex: 2): "))
    except ValueError:
        print("\n❌ Entrada inválida! Por favor, digite números válidos.")
        return

    try:
        cursor = conexao.cursor()
        
        # A query usa bind variables (:nota_min e :lotes_min) para evitar SQL Injection e receber os parâmetros
        sql = """
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
                AVG(F.NOTA) >= :nota_min 
                AND COUNT(DISTINCT L.CODIGO_LOTE) >= :lotes_min
            ORDER BY 
                MEDIA_AVALIACAO DESC
        """
        
        # Passa os parâmetros na execução
        cursor.execute(sql, nota_min=nota_min, lotes_min=lotes_min)
        linhas = cursor.fetchall()
        
        if linhas:
            print(f"\n{'NOME DO DOADOR':<35} | {'EMAIL':<25} | {'LOTES':<6} | {'NOTA'}")
            print("-" * 80)
            for linha in linhas:
                print(f"{linha[0]:<35} | {linha[1]:<25} | {linha[2]:<6} | {linha[3]}")
        else:
            print(f"\nNenhum doador encontrado com nota >= {nota_min} e mais de {lotes_min} lotes.")

    except oracledb.DatabaseError as e:
        error, = e.args
        print(f"\n❌ Erro ao realizar a consulta parametrizada: {error.message}")
    finally:
        cursor.close()

def consultar_todos_usuarios(conexao):
    """Consulta simples mantida para depuração."""
    print("\n--- Consultar Todos os Usuários ---")
    try:
        cursor = conexao.cursor()
        cursor.execute("SELECT CPF_CNPJ, NOME, TIPO FROM USUARIO")
        linhas = cursor.fetchall()
        if linhas:
            print(f"{'CPF/CNPJ':<15} | {'NOME':<40} | {'TIPO'}")
            print("-" * 70)
            for linha in linhas:
                print(f"{linha[0]:<15} | {linha[1]:<40} | {linha[2]}")
        else:
            print("Nenhum usuário encontrado.")
    except oracledb.DatabaseError as e:
        error, = e.args
        print(f"\nErro ao consultar usuários: {error.message}")
    finally:
        cursor.close()

def menu():
    conexao = conectar()
    if not conexao:
        return

    while True:
        print("\n" + "="*45)
        print(" SISTEMA DE DOAÇÕES - MENU PRINCIPAL")
        print("="*45)
        print("1. Cadastrar Novo Doador")
        print("2. Buscar Doadores por Desempenho")
        print("3. Listar Todos os Usuários Cadastrados")
        print("0. Sair")
        
        opcao = input("\nEscolha uma opção: ")
        
        if opcao == '1':
            cadastrar_doador(conexao)
        elif opcao == '2':
            consultar_doadores_parametrizada(conexao)
        elif opcao == '3':
            consultar_todos_usuarios(conexao)
        elif opcao == '0':
            print("Encerrando a aplicação...")
            conexao.close()
            break
        else:
            print("Opção inválida! Tente novamente.")

if __name__ == "__main__":
    menu()