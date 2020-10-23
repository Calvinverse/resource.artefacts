function Get-IpAddress
{
    $ErrorActionPreference = 'Stop'

    $output = & /sbin/ifconfig eth0
    $line = $output |
        Where-Object { $_.Contains('inet addr:') } |
        Select-Object -First 1

    $line = $line.Trim()
    $line = $line.SubString('inet addr:'.Length)
    return $line.SubString(0, $line.IndexOf(' '))
}

function Initialize-Environment
{
    $ErrorActionPreference = 'Stop'

    try
    {
        Start-TestConsul

        Install-Vault -vaultVersion '0.9.1'
        Start-TestVault

        Write-Output "Waiting for 10 seconds for consul and vault to start ..."
        Start-Sleep -Seconds 10

        Join-Cluster

        Set-VaultSecrets
        Set-ConsulKV

    {
        $currentErrorActionPreference = $ErrorActionPreference

        try
        {
            Write-Error $errorRecord.Exception
            Write-Error $errorRecord.ScriptStackTrace
            Write-Error $errorRecord.InvocationInfo.PositionMessage
        }
        finally
        {
            $ErrorActionPreference = $currentErrorActionPreference
        }

        # rethrow the error
        throw $_.Exception
    }
}

function Install-Vault
{
    [CmdletBinding()]
    param(
        [string] $vaultVersion
    )

    $ErrorActionPreference = 'Stop'

    & wget "https://releases.hashicorp.com/vault/$($vaultVersion)/vault_$($vaultVersion)_linux_amd64.zip" --output-document /test/vault.zip
    & unzip /test/vault.zip -d /test/vault
}

function Join-Cluster
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    Write-Output "Joining the local consul ..."

    # connect to the actual local consul instance
    $ipAddress = Get-IpAddress
    Write-Output "Joining: $($ipAddress):8351"

    Start-Process -FilePath "consul" -ArgumentList "join $($ipAddress):8351"

    Write-Output "Getting members for client"
    & consul members

    Write-Output "Getting members for server"
    & consul members -http-addr=http://127.0.0.1:8550
}

function Set-ConsulKV
{
    $ErrorActionPreference = 'Stop'

    Write-Output "Setting consul key-values ..."

    # Load config/services/backup
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/backups/protocols/read/host 'read.backups'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/nexus/restore/datacenter 'test-integration'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/nexus/restore/environment 'test-integration'

    # Load config/services/consul
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/datacenter 'test-integration'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/domain 'integrationtest'

    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/metrics/statsd/rules '\"consul.*.*.* .measurement.measurement.field\",'

    # Explicitly don't provide a metrics address because that means telegraf will just send the metrics to
    # a black hole
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/databases/system 'system'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/databases/statsd 'services'

    # load config/services/proxy.forwarder
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/proxy.forwarder/metrics/statsd/rules '\"fabio.*.*.* .measurement.measurement.field\",'

    # load config/services/queue
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/protocols/http/host 'http.queue'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/protocols/http/port '15672'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/protocols/amqp/host 'amqp.queue'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/protocols/amqp/port '5672'

    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/username 'testuser'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/vhost 'testlogs'

    # Load config/services/vault
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/secrets/protocols/http/host 'secrets'
    & consul kv put -http-addr=http://127.0.0.1:8550 config/services/secrets/protocols/http/port '8200'
}

function Set-VaultSecrets
{
    $ErrorActionPreference = 'Stop'

    Write-Output 'Setting vault secrets ...'

    # secret/services/queue/logs/syslog
}

function Start-TestConsul
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path /test/consul))
    {
        New-Item -Path /test/consul -ItemType Directory | Out-Null
    }

    Write-Output "Starting consul ..."
    $process = Start-Process `
        -FilePath "consul" `
        -ArgumentList "agent -config-file /test/pester/environment/consul.json" `
        -PassThru `
        -RedirectStandardOutput /test/consul/output.out `
        -RedirectStandardError /test/consul/error.out
}

function Start-TestVault
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    Write-Output "Starting vault ..."
    $process = Start-Process `
        -FilePath "/test/vault/vault" `
        -ArgumentList "-dev" `
        -PassThru `
        -RedirectStandardOutput /test/vault/vaultoutput.out `
        -RedirectStandardError /test/vault/vaulterror.out
}
