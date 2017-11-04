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
Description=nexus service
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/opt/nexus/bin/nexus start
Type=forking
User=nexus
LimitNOFILE=65536
ExecStop=/opt/nexus/bin/nexus stop
Restart=on-abort

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
            -Uri http://localhost:8081/artefacts/service/metrics/ping `
            -Headers @{ Authorization = 'Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo' } `
            -UseBasicParsing
        It 'responds to a HTTP ping calls' {
            $response.StatusCode | Should Be 200
        }

        $response = Invoke-WebRequest `
            -Uri http://localhost:8081/artefacts/service/metrics/healthcheck `
            -Headers @{ Authorization = 'Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo' } `
            -UseBasicParsing
        $healthInformation = ConvertFrom-Json $response.Content
        It 'responds to a HTTP health check calls' {
            $response.StatusCode | Should Be 200
            $healthInformation | Should Not Be $null
        }
    }
}
