# Script de Gestão de Ativos de Equipamentos no Domínio
# Importar o módulo Active Directory
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Host "Módulo Active Directory não encontrado. Instale o RSAT-AD-PowerShell." -ForegroundColor Red
    exit
}

# Verificar privilégios administrativos
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Este script precisa ser executado como Administrador!" -ForegroundColor Red
    Write-Host "Por favor, reinicie o PowerShell como Administrador e execute o script novamente." -ForegroundColor Yellow
    Pause
    exit
}

# Substituir as configurações iniciais por:
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path -Path $ScriptPath -ChildPath "config.json"

# Carregar ou criar configuração
function Load-Config {
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-Log "Configuração carregada com sucesso." 
            return $config
        } catch {
            Write-Log "Erro ao carregar configuração: $_" -Level "ERROR"
        }
    }
    
    # Criar configuração padrão se não existir
    Write-Host "Configuração não encontrada. Iniciando assistente de configuração..." -ForegroundColor Yellow
    $domain = Read-Host "Digite o nome do domínio (ex: contoso.local)"
    $baseOU = Read-Host "Digite o caminho da OU base (ex: OU=Computadores,DC=contoso,DC=local)"
    $inactiveDays = Read-Host "Digite o número de dias para considerar um computador inativo (padrão: 90)"
    if ([string]::IsNullOrEmpty($inactiveDays)) { $inactiveDays = 90 }
    
    $config = @{
        Domain = $domain
        BaseOU = $baseOU
        LogPath = "C:\Logs\Gestao_Ativos.log"
        ReportPath = "C:\Relatorios"
        MaxThreads = 20
        InactiveDays = [int]$inactiveDays
        Theme = @{
            MenuColor = "Cyan"
            HighlightColor = "Yellow"
            ErrorColor = "Red"
            SuccessColor = "Green"
        }
    }
    
    $config | ConvertTo-Json | Set-Content -Path $ConfigPath
    Write-Log "Nova configuração criada e salva."
    return $config
}

$Config = Load-Config
$Domain = $Config.Domain
$BaseOU = $Config.BaseOU
$LogPath = $Config.LogPath
$ReportPath = $Config.ReportPath
$MaxThreads = $Config.MaxThreads
$InactiveDays = $Config.InactiveDays
$Theme = $Config.Theme
$CacheInventory = $null
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Função para registrar logs
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Write-Host $logMessage -ForegroundColor Gray
    Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue
}

# Criar diretórios de logs e relatórios
function Initialize-Directories {
    if (-not (Test-Path (Split-Path $LogPath -Parent))) { 
        New-Item -Path (Split-Path $LogPath -Parent) -ItemType Directory -Force | Out-Null 
        Write-Log "Diretório de logs criado: $(Split-Path $LogPath -Parent)"
    }
    if (-not (Test-Path $ReportPath)) { 
        New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null 
        Write-Log "Diretório de relatórios criado: $ReportPath"
    }
}

# Interface do menu
function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor $Theme.MenuColor
    Write-Host "       Gestão de Ativos       " -ForegroundColor $Theme.MenuColor
    Write-Host "======================================" -ForegroundColor $Theme.MenuColor
    Write-Host "   _____" -ForegroundColor $Theme.HighlightColor
    Write-Host "  /     \   Gestão de Equipamentos" -ForegroundColor $Theme.HighlightColor
    Write-Host " /_______\" -ForegroundColor $Theme.HighlightColor
    Write-Host " |  AD   |  v1.1 " -ForegroundColor $Theme.HighlightColor
    Write-Host " |_______|" -ForegroundColor $Theme.HighlightColor
    Write-Host "======================================" -ForegroundColor $Theme.MenuColor
    Write-Host "1. Listar equipamentos por setor" -ForegroundColor $Theme.HighlightColor
    Write-Host "2. Listar equipamentos por usuário" -ForegroundColor $Theme.HighlightColor
    Write-Host "3. Listar usuários inativos" -ForegroundColor $Theme.HighlightColor
    Write-Host "4. Listar equipamentos online/offline" -ForegroundColor $Theme.HighlightColor
    Write-Host "5. Listar equipamentos órfãos" -ForegroundColor $Theme.HighlightColor
    Write-Host "6. Pesquisa avançada (filtros múltiplos)" -ForegroundColor $Theme.HighlightColor
    Write-Host "7. Exportar relatório completo (CSV)" -ForegroundColor $Theme.HighlightColor
    Write-Host "8. Exportar relatório completo (HTML)" -ForegroundColor $Theme.HighlightColor
    Write-Host "9. Limpar equipamentos inativos" -ForegroundColor $Theme.HighlightColor
    Write-Host "10. Limpar cache" -ForegroundColor $Theme.HighlightColor
    Write-Host "11. Configurações" -ForegroundColor $Theme.HighlightColor
    Write-Host "12. Sair" -ForegroundColor $Theme.ErrorColor
    Write-Host "======================================" -ForegroundColor $Theme.MenuColor
    $choice = Read-Host "Escolha uma opção (1-12)"
    return $choice
}

# Função para coletar informações do AD
function Get-ADInventory {
    if ($null -ne $script:CacheInventory) {
        Write-Log "Usando dados em cache..."
        return $script:CacheInventory
    }

    Write-Log "Coletando informações do Active Directory no domínio $Domain..."
    $inventory = @()

    try {
        Write-Host "Buscando computadores na OU $BaseOU..." -ForegroundColor Yellow
        $computers = Get-ADComputer -Filter 'Enabled -eq $true' -SearchBase $BaseOU -Properties Name, OperatingSystem, OperatingSystemVersion, LastLogonDate, DistinguishedName, Created -Server $Domain -ErrorAction Stop
        Write-Host "Buscando usuários na OU $BaseOU..." -ForegroundColor Yellow
        $users = Get-ADUser -Filter 'Enabled -eq $true' -SearchBase $BaseOU -Properties SamAccountName, Enabled, Department, LastLogonDate, DistinguishedName, Mail -Server $Domain -ErrorAction Stop

        if (-not $computers) { Write-Log "Nenhum computador encontrado." -Level "WARNING"; return $inventory }
        if (-not $users) { Write-Log "Nenhum usuário encontrado." -Level "WARNING"; return $inventory }

        Write-Log "Encontrados $($computers.Count) computadores e $($users.Count) usuários."

        # Processamento paralelo para verificações online/offline e WMI
        $inventoryJobs = @()
        $computers | ForEach-Object {
            $computer = $_
            while (@(Get-Job -State Running).Count -ge $MaxThreads) {
                Start-Sleep -Milliseconds 100
            }
            $inventoryJobs += Start-Job -ScriptBlock {
                param($computer, $users)
                $user = $null
                $department = "Sem setor"
                $userStatus = "N/A"
                $onlineStatus = "Offline"
                $ipAddress = "N/A"
                $manufacturer = "N/A"
                $model = "N/A"
                $serialNumber = "N/A"
                $osVersion = $computer.OperatingSystemVersion
                $createdDate = $computer.Created

                # Verificar status online/offline
                if (Test-Connection -ComputerName $computer.Name -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                    $onlineStatus = "Online"
                    try {
                        $ipAddress = [System.Net.Dns]::GetHostAddresses($computer.Name) | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1 -ExpandProperty IPAddressToString
                    } catch { $ipAddress = "Erro ao obter IP"; Write-Log "Erro ao obter IP de $($computer.Name): $_" -Level "ERROR" }

                    # Obter fabricante, modelo e número de série via WMI
                    try {
                        $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $computer.Name -ErrorAction Stop
                        $system = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer.Name -ErrorAction Stop
                        $manufacturer = $system.Manufacturer
                        $model = $system.Model
                        $serialNumber = $bios.SerialNumber
                    } catch {
                        Write-Log "Erro ao obter informações WMI de $($computer.Name): $_" -Level "ERROR"
                    }
                }

                # Associar computador a um usuário
                $lastUser = $null
                try {
                    $lastUser = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer.Name -ErrorAction SilentlyContinue).UserName
                    if ($lastUser) {
                        $lastUser = $lastUser.Split('\')[-1]
                        $user = $users | Where-Object { $_.SamAccountName -eq $lastUser }
                    }
                } catch { Write-Log "Erro ao obter usuário do computador $($computer.Name): $_" -Level "ERROR" }

                # Determinar setor
                if ($user -and $user.Department) {
                    $department = $user.Department
                } else {
                    $ou = $computer.DistinguishedName -split ',' | Where-Object { $_ -like "OU=*" }
                    if ($ou) { $department = ($ou[0] -split '=')[1] }
                }

                # Determinar status do usuário
                if ($user) {
                    $userStatus = if ($user.Enabled) { "Ativo" } else { "Inativo" }
                }

                # Criar objeto personalizado
                return [PSCustomObject]@{
                    ComputerName    = $computer.Name
                    OperatingSystem = $computer.OperatingSystem
                    OSVersion       = $osVersion
                    LastLogonDate   = $computer.LastLogonDate
                    CreatedDate     = $createdDate
                    User            = if ($user) { $user.SamAccountName } else { "N/A" }
                    UserEmail       = if ($user -and $user.Mail) { $user.Mail } else { "N/A" }
                    Department      = $department
                    UserStatus      = $userStatus
                    OnlineStatus    = $onlineStatus
                    IPAddress       = $ipAddress
                    Manufacturer    = $manufacturer
                    Model           = $model
                    SerialNumber    = $serialNumber
                    OU              = $computer.DistinguishedName
                }
            } -ArgumentList $computer, $users
        }

        # Aguardar conclusão dos jobs e coletar resultados
        $i = 0
        $total = $inventoryJobs.Count
        $activity = "Processando computadores no Active Directory"
        
        foreach ($job in $inventoryJobs) {
            $i++
            $percentComplete = ($i / $total) * 100
            $status = "Processando $i de $total ($($computer.Name)) - $([math]::Round($percentComplete,2))%"
            
            Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete
            $result = Receive-Job -Job $job -Wait
            if ($result) { $inventory += $result }
            Remove-Job -Job $job
        }
        Write-Progress -Activity $activity -Completed
        $script:CacheInventory = $inventory
        Write-Log "Inventário concluído com $($inventory.Count) itens."
    } catch {
        Write-Log "Erro ao coletar informações do Active Directory: $_" -Level "ERROR"
    }
    return $inventory
}

# Função para listar por setor
function List-ByDepartment {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $departments = $inventory | Group-Object Department
    foreach ($dept in $departments) {
        Write-Host "`nSetor: $($dept.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $dept.Group | Format-Table ComputerName, User, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber, IPAddress -AutoSize
    }
    Pause
}

# Função para listar por usuário
function List-ByUser {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $users = $inventory | Group-Object User
    foreach ($user in $users) {
        Write-Host "`nUsuário: $($user.Name)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $user.Group | Format-Table ComputerName, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber, IPAddress -AutoSize
    }
    Pause
}

# Função para listar usuários inativos
function List-InactiveUsers {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $inactiveThreshold = (Get-Date).AddDays(-90)
    $inactiveUsers = $inventory | Where-Object { $_.LastLogonDate -lt $inactiveThreshold -and $_.User -ne "N/A" }
    if ($inactiveUsers) {
        Write-Host "`nUsuários Inativos (último logon há mais de 90 dias)" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $inactiveUsers | Format-Table ComputerName, User, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber -AutoSize
    } else {
        Write-Host "`nNenhum usuário inativo encontrado." -ForegroundColor Yellow
    }
    Pause
}

# Função para listar equipamentos online/offline
function List-OnlineOffline {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    Write-Host "`nEquipamentos Online" -ForegroundColor Cyan
    Write-Host "----------------------------------------"
    $inventory | Where-Object { $_.OnlineStatus -eq "Online" } | Format-Table ComputerName, IPAddress, User, Department, OperatingSystem, SerialNumber -AutoSize
    Write-Host "`nEquipamentos Offline" -ForegroundColor Cyan
    Write-Host "----------------------------------------"
    $inventory | Where-Object { $_.OnlineStatus -eq "Offline" } | Format-Table ComputerName, User, Department, OperatingSystem, SerialNumber -AutoSize
    Pause
}

# Função para listar equipamentos órfãos
function List-OrphanedEquipment {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para listar." -ForegroundColor Yellow; Pause; return }
    $orphaned = $inventory | Where-Object { $_.User -eq "N/A" }
    if ($orphaned) {
        Write-Host "`nEquipamentos sem Usuário Associado" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        $orphaned | Format-Table ComputerName, Department, OperatingSystem, LastLogonDate, OnlineStatus, SerialNumber, IPAddress -AutoSize
    } else {
        Write-Host "`nNenhum equipamento órfão encontrado." -ForegroundColor Yellow
    }
    Pause
}

# Função para exportar relatório completo em CSV
function Export-ReportCSV {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para exportar." -ForegroundColor Yellow; Pause; return }
    $filePath = "$ReportPath\Inventario_Ativos_$Timestamp.csv"
    $inventory | Select-Object ComputerName, OperatingSystem, OSVersion, LastLogonDate, CreatedDate, User, UserEmail, Department, UserStatus, OnlineStatus, IPAddress, Manufacturer, Model, SerialNumber, OU | 
        Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Log "Relatório CSV exportado para $filePath"
    Write-Host "Relatório CSV exportado para $filePath" -ForegroundColor Green
    Pause
}

# Função para exportar relatório completo em HTML
function Export-ReportHTML {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para exportar." -ForegroundColor Yellow; Pause; return }
    $filePath = "$ReportPath\Inventario_Ativos_$Timestamp.html"
    $htmlHeader = @"
    <style>
        table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
    <h1>Relatório de Inventário de Ativos</h1>
"@
    $inventory | Select-Object ComputerName, OperatingSystem, OSVersion, LastLogonDate, CreatedDate, User, UserEmail, Department, UserStatus, OnlineStatus, IPAddress, Manufacturer, Model, SerialNumber, OU | 
        ConvertTo-Html -Head $htmlHeader | Set-Content -Path $filePath
    Write-Log "Relatório HTML exportado para $filePath"
    Write-Host "Relatório HTML exportado para $filePath" -ForegroundColor Green
    Pause
}

# Função para limpar equipamentos inativos
function Clear-InactiveEquipment {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para processar." -ForegroundColor $Theme.HighlightColor; Pause; return }
    
    $threshold = (Get-Date).AddDays(-$InactiveDays)
    $inactive = $inventory | Where-Object { $_.LastLogonDate -and $_.LastLogonDate -lt $threshold }
    
    if ($inactive) {
        Write-Host "`nEquipamentos inativos há mais de $InactiveDays dias" -ForegroundColor $Theme.MenuColor
        Write-Host "----------------------------------------"
        $inactive | Format-Table ComputerName, LastLogonDate, User, Department, SerialNumber, IPAddress -AutoSize
        
        # Criar backup antes de remover
        $backupPath = "$ReportPath\Backup_Inativos_$Timestamp.csv"
        $inactive | Export-Csv -Path $backupPath -NoTypeInformation -Encoding UTF8
        Write-Host "Backup dos equipamentos a serem removidos criado em: $backupPath" -ForegroundColor $Theme.SuccessColor
        
        $confirm = Read-Host "Deseja remover esses equipamentos do Active Directory? (S/N)"
        if ($confirm -eq "S") {
            $successCount = 0
            $errorCount = 0
            foreach ($item in $inactive) {
                try {
                    Remove-ADComputer -Identity $item.ComputerName -Server $Domain -Confirm:$false -ErrorAction Stop
                    Write-Log "Computador $($item.ComputerName) removido do AD."
                    $successCount++
                } catch {
                    Write-Log "Erro ao remover $($item.ComputerName): $_" -Level "ERROR"
                    $errorCount++
                }
            }
            $script:CacheInventory = $null # Limpar cache após remoção
            Write-Host "Remoção concluída: $successCount equipamentos removidos com sucesso, $errorCount falhas." -ForegroundColor $Theme.SuccessColor
        }
    } else {
        Write-Host "`nNenhum equipamento inativo há mais de $InactiveDays dias." -ForegroundColor $Theme.HighlightColor
    }
    Pause
}

# Função para limpar cache
function Clear-Cache {
    $script:CacheInventory = $null
    Get-Job | Remove-Job -Force
    Write-Log "Cache limpo e jobs removidos."
    Write-Host "Cache limpo. O próximo inventário será atualizado." -ForegroundColor Green
    Pause
}

# Adicionar nova função de pesquisa avançada:
function Search-AdvancedFilter {
    $inventory = Get-ADInventory
    if (-not $inventory) { Write-Host "Nenhum dado para filtrar." -ForegroundColor $Theme.HighlightColor; Pause; return }
    
    Write-Host "`nPesquisa Avançada - Filtros Múltiplos" -ForegroundColor $Theme.MenuColor
    Write-Host "----------------------------------------"
    Write-Host "Deixe em branco os campos que não deseja filtrar" -ForegroundColor $Theme.HighlightColor
    
    $computerFilter = Read-Host "Nome do computador contém"
    $userFilter = Read-Host "Nome de usuário contém"
    $deptFilter = Read-Host "Departamento contém"
    $osFilter = Read-Host "Sistema operacional contém"
    $statusFilter = Read-Host "Status (Online/Offline)"
    
    $filtered = $inventory
    
    if (-not [string]::IsNullOrEmpty($computerFilter)) {
        $filtered = $filtered | Where-Object { $_.ComputerName -like "*$computerFilter*" }
    }
    
    if (-not [string]::IsNullOrEmpty($userFilter)) {
        $filtered = $filtered | Where-Object { $_.User -like "*$userFilter*" }
    }
    
    if (-not [string]::IsNullOrEmpty($deptFilter)) {
        $filtered = $filtered | Where-Object { $_.Department -like "*$deptFilter*" }
    }
    
    if (-not [string]::IsNullOrEmpty($osFilter)) {
        $filtered = $filtered | Where-Object { $_.OperatingSystem -like "*$osFilter*" }
    }
    
    if (-not [string]::IsNullOrEmpty($statusFilter)) {
        $filtered = $filtered | Where-Object { $_.OnlineStatus -like "*$statusFilter*" }
    }
    
    if ($filtered.Count -gt 0) {
        Write-Host "`nResultados da pesquisa ($($filtered.Count) itens encontrados):" -ForegroundColor $Theme.SuccessColor
        $filtered | Format-Table ComputerName, User, Department, OperatingSystem, LastLogonDate, OnlineStatus, IPAddress -AutoSize
        
        $exportOption = Read-Host "Deseja exportar estes resultados? (S/N)"
        if ($exportOption -eq "S") {
            $filePath = "$ReportPath\Pesquisa_Avançada_$Timestamp.csv"
            $filtered | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "Resultados exportados para $filePath" -ForegroundColor $Theme.SuccessColor
        }
    } else {
        Write-Host "Nenhum resultado encontrado com os filtros especificados." -ForegroundColor $Theme.ErrorColor
    }
    Pause
}

# Inicialização
Initialize-Directories

# Loop principal
do {
    $choice = Show-Menu
    switch ($choice) {
        "1" { List-ByDepartment }
        "2" { List-ByUser }
        "3" { List-InactiveUsers }
        "4" { List-OnlineOffline }
        "5" { List-OrphanedEquipment }
        "6" { Search-AdvancedFilter }
        "7" { Export-ReportCSV }
        "8" { Export-ReportHTML }
        "9" { Clear-InactiveEquipment }
        "10" { Clear-Cache }
        "11" { Edit-Configuration }
        "12" { Write-Log "Sistema encerrado."; Write-Host "Sair..." -ForegroundColor $Theme.ErrorColor; break }
        default { Write-Host "Opção inválida!" -ForegroundColor $Theme.ErrorColor; Pause }
    }
} while ($true)

# Adicionar no início do script, antes do código principal:
param (
    [Parameter(Mandatory = $false)]
    [switch]$ExportCSV,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportHTML,
    
    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

# Suporte para modo não interativo via parâmetros
if ($NonInteractive) {
    Write-Log "Iniciando em modo não interativo"
    
    # Definir caminho de saída personalizado, se fornecido
    if ($OutputPath) {
        $ReportPath = $OutputPath
        if (-not (Test-Path $ReportPath)) { 
            New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null 
            Write-Log "Criado diretório de saída personalizado: $ReportPath"
        }
    }
    
    if ($ExportCSV) {
        Write-Log "Exportando relatório CSV automaticamente..."
        Export-ReportCSV
    }
    
    if ($ExportHTML) {
        Write-Log "Exportando relatório HTML automaticamente..."
        Export-ReportHTML
    }
    
    Write-Log "Execução em modo não interativo concluída"
    exit
}