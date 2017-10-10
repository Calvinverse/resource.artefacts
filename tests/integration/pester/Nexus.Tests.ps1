Describe 'The Nexus artefact server' {
    Context 'is installed' {
        It 'with binaries in /opt/nexus' {
            '/opt/nexus' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/nexus.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=consul
Wants=network.target
After=network.target

[Service]
Environment="GOMAXPROCS=2" "PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/consul/0.9.2/consul agent -config-file=/etc/consul/consul.json -config-dir=/etc/consul/conf.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=TERM
User=consul
WorkingDirectory=/var/lib/consul

[Install]
WantedBy=multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status nexus
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'nexus.service - nexus'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        $response = Invoke-WebRequest `
            -Uri http://localhost:8081/service/metrics/ping `
            -UseBasicParsing
        $agentInformation = ConvertFrom-Json $response.Content
        It 'responds to a HTTP ping calls' {
            $response.StatusCode | Should Be 200
            $agentInformation | Should Not Be $null
        }

        $response = Invoke-WebRequest `
            -Uri http://localhost:8081/service/metrics/healthcheck `
            -UseBasicParsing
        $agentInformation = ConvertFrom-Json $response.Content
        It 'responds to a HTTP ping calls' {
            $response.StatusCode | Should Be 200
            $agentInformation | Should Not Be $null
        }
    }
}
