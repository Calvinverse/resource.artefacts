Describe 'The consul-template application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/consul-template' | Should Exist
        }

        It 'with default configuration in /etc/consul-template.d/config/base.hcl' {
            '/etc/consul-template.d/conf/base.hcl' | Should Exist
        }

        It 'with vault configuration in /etc/consul-template.d/config/vault.hcl' {
            '/etc/consul-template.d/conf/vault.hcl' | Should Not Exist
        }

        It 'with a data directory in /etc/consul-template.d/data' {
            '/etc/consul-template.d/data' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/consul-template.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Consul Template
Requires=multi-user.target
After=multi-user.target
Documentation=https://github.com/hashicorp/consul-template

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/local/bin/consul-template -config=/etc/consul-template.d/conf
EnvironmentFile=/etc/environment
KillMode=mixed
KillSignal=SIGQUIT
PIDFile=/etc/consul-template.d/data/pid
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status consul-template
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'consul-template.service - Consul Template'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}
