Describe 'The unbound application' {
    Context 'is installed' {
        It 'with binaries in /usr/sbin' {
            '/usr/sbin/unbound' | Should Exist
        }

        It 'with default configuration in /etc/unbound' {
            '/etc/unbound/unbound.conf' | Should Exist
        }

        It 'with environment configuration in /etc/unbound.d' {
            '/etc/unbound.d/unbound_zones.conf' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/unbound.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Unbound DNS proxy
Requires=multi-user.target
After=multi-user.target
Documentation=http://www.unbound.net

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/sbin/unbound -d -c /etc/unbound/unbound.conf
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status unbound
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 5
            $systemctlOutput[0] | Should Match 'unbound.service - Unbound DNS proxy'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[4] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}
