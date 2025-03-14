# Gestão de Ativos no Active Directory 

Um script poderoso para simplificar a gestão de ativos de TI no seu domínio Active Directory. Com uma interface interativa, este script permite listar equipamentos por setor, usuário, identificar dispositivos associados a usuários inativos e exportar relatórios detalhados em CSV. Ideal para administradores de rede que buscam eficiência e organização.

## Funcionalidades do Script  
- **Listagem por Setor**: Agrupa equipamentos por departamento ou unidade organizacional (OU).  
- **Associação por Usuário**: Relaciona dispositivos aos usuários com base em logons ou nomes de máquinas.  
- **Filtro de Usuários Inativos**: Identifica e separa equipamentos associados a contas desativadas no AD.  
- **Exportação de Relatórios**: Gera relatórios completos em CSV com informações como nome do computador, sistema operacional, último logon, setor e status do usuário.  
- **Interface Intuitiva**: Menu interativo para facilitar a navegação e execução das tarefas.

## Pré-requisitos  
- **PowerShell**: Versão 5.1 ou superior (padrão no Windows).  
- **Módulo Active Directory**: Instale via `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server) ou `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools---0.0.1.0` (Windows 10/11).  
- **Permissões**: Execute como administrador com acesso ao domínio Active Directory.

### Clonando o Repositório  
1. Clone este repositório:  
   ```bash
   git clone https://github.com/danielfrade/gestaoativo.git
   ```  

### Executando o Script  
1. Abra o PowerShell como administrador.  
2. Navegue até o diretório do script:  
   ```powershell
   cd caminho\para\gestaoativos
   ```  
3. Execute o script:  
   ```powershell
   .\GestaoAtivos.ps1
   ```  
4. Siga o menu interativo para escolher as opções desejadas (listagem por setor, usuário, usuários inativos ou exportação de relatório).  

## Notas  
- Preencha $Domain e $BaseOU com os valores do seu ambiente.
- Certifique-se de que o ambiente tem conectividade com o controlador de domínio para consultar o Active Directory.  
- Certifique-se de que o usuário tem permissões para WMI remoto e gerenciamento do AD.
- Para redes muito grandes, considere ajustar os filtros de consulta ao AD para melhorar a performance.
