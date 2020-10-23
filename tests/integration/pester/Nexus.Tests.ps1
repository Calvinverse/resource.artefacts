Describe 'The Nexus artefact server' {
    Context 'is installed' {
        It 'with binaries in /opt/nexus' {
            '/opt/nexus' | Should Exist
        }
    }

    Context 'the old daemon has been removed' {
        $serviceConfigurationPath = '/etc/systemd/system/nexus3_nexus.service'
        if (Test-Path $serviceConfigurationPath)
        {
            It 'should not have a systemd configuration' {
               $false | Should Be $true
            }
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
[Service]
Type = forking
ExecStart = /bin/sh -c "/opt/nexus/bin/set_jvm_properties.sh && /opt/nexus/bin/nexus start"
ExecStop = /opt/nexus/bin/nexus stop
Restart = on-abort
User = nexus
LimitNOFILE = 65536

[Unit]
Description = nexus service
After = network.target

[Install]
WantedBy = multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status nexus
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should Be 3
            $systemctlOutput[0] | Should Match 'nexus.service - nexus'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\sdisabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sinactive\s\(dead\).*'
        }
    }
}
