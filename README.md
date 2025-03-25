# 🖥️ Gestão de Ativos no Active Directory 
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Active Directory](https://img.shields.io/badge/Active%20Directory-Compatible-green.svg)

Um script poderoso para simplificar a gestão de ativos de TI no seu domínio Active Directory. Com uma interface interativa, este script permite listar equipamentos por setor, usuário, identificar dispositivos associados a usuários inativos e exportar relatórios detalhados em CSV. Ideal para administradores de rede que buscam eficiência e organização.

## 📋 Índice
- [Funcionalidades](#funcionalidades-do-script)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#clonando-o-repositório)
- [Como Usar](#executando-o-script)
- [Exemplos de Uso](#exemplos-de-uso)
- [Solução de Problemas](#solução-de-problemas)
- [Notas e Dicas](#notas)
- [Contribuição](#contribuição)

## ✨ Funcionalidades do Script  
- **Listagem por Setor**: Agrupa equipamentos por departamento ou unidade organizacional (OU).  
- **Associação por Usuário**: Relaciona dispositivos aos usuários com base em logons ou nomes de máquinas.  
- **Filtro de Usuários Inativos**: Identifica e separa equipamentos associados a contas desativadas no AD.  
- **Exportação de Relatórios**: Gera relatórios completos em CSV com informações como nome do computador, sistema operacional, último logon, setor e status do usuário.  
- **Interface Intuitiva**: Menu interativo para facilitar a navegação e execução das tarefas.

## 🛠️ Pré-requisitos  
- **PowerShell**: Versão 5.1 ou superior (padrão no Windows).  
- **Módulo Active Directory**: Instale via `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server) ou `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools---0.0.1.0` (Windows 10/11).  
- **Permissões**: Execute como administrador com acesso ao domínio Active Directory.

## 📥 Clonando o Repositório  
1. Clone este repositório:  
   ```bash
   git clone https://github.com/danielfrade/gestaoativo.git
   ```  

## 🚀 Executando o Script  
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

## 📊 Exemplos de Uso
### Exemplo 1: Gerar relatório completo
```powershell
.\GestaoAtivos.ps1
# Selecione a opção 4 no menu para exportar relatório completo
```

### Exemplo 2: Listar equipamentos de um setor específico
```powershell
.\GestaoAtivos.ps1
# Selecione a opção 1 no menu
# Digite o nome do setor quando solicitado
```

## ❓ Solução de Problemas
| Problema | Solução |
|----------|---------|
| Erro de conexão com AD | Verifique se o computador está conectado ao domínio e se você tem permissões adequadas |
| Módulo AD não encontrado | Execute o comando de instalação listado nos pré-requisitos |
| Script não gera resultados | Confirme se $Domain e $BaseOU estão corretos para seu ambiente |
| Permissão negada | Execute o PowerShell como Administrador e verifique as permissões do usuário no AD |

## 📝 Notas  
- Preencha $Domain e $BaseOU com os valores do seu ambiente.
- Certifique-se de que o ambiente tem conectividade com o controlador de domínio para consultar o Active Directory.  
- Certifique-se de que o usuário tem permissões para WMI remoto e gerenciamento do AD.
- Para redes muito grandes, considere ajustar os filtros de consulta ao AD para melhorar a performance.

## 👥 Contribuição
Contribuições são bem-vindas! Para contribuir:
1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

---