Describe 'On the system' {
    Context 'the machine name' {
        It 'should not be the test name' {
            hostname | Should Not Be '${ImageNameWithoutSpaces}'
        }
    }

    Context 'the time zone' {
        It 'should be on UTC time' {
            (timedatectl status | grep "Time zone") | Should Match '(Etc\/UTC\s\(UTC,\s\+0000\))'
        }
    }

    Context 'the administrator rights' {
        It 'should have default sudo settings' {
            (Get-FileHash -Path /etc/sudoers -Algorithm SHA256).Hash | Should Be '1DA6E2BCBBA35669C9EB62370C88F4017686309C9AC4E6458D963321EAD42439'
        }

        It 'should not have additional sudo files' {
            '/etc/sudoers.d' | Should Exist
            @( (Get-ChildItem -Path /etc/sudoers.d -File) ).Length | Should Be 1
        }
    }

    Context 'system updates' {
        # split the output which should contain the names of the packages that have not been updated.
        # We allow the following list:
        # linux-headers-generic
        # linux-signed-image-generic
        # linux-signed-image-4.4.0-81-generic
        # linux-image-4.4.0-81-generic
        # linux-signed-generic
        # linux-headers-4.4.0-81
        # linux-image-extra-4.4.0-81-generic
        # linux-headers-4.4.0-81-generic
        #
        # If we update these packages the Hyper-V drivers will be updated to the Ubuntu 16.04.2 level which
        # breaks the drivers and makes them not start on machine start-up. That means that Hyper-V cannot
        # connect to the machine to determine the IP address etc. (and that makes Packer etc. fail)
        $allowedPackages = @(
            'linux-headers-generic'
            'linux-signed-image-generic'
            'linux-signed-image-4.4.0-81-generic'
            'linux-image-4.4.0-81-generic'
            'linux-signed-generic'
            'linux-headers-4.4.0-81'
            'linux-image-extra-4.4.0-81-generic'
            'linux-headers-4.4.0-81-generic'
        )

        It 'should have a file with updates' {
            '/test/updates.txt' | Should Exist
        }

        $fileSize = (Get-Item '/test/updates.txt').Length
        if ($fileSize -gt 0)
        {
            $updates = Get-Content /tmp/updates.txt
            $additionalPackages = Compare-Object $allowedPackages $updates | Where-Object { $_.sideindicator -eq '=>' }

            It 'should all be installed' {
                $additionalPackages.Length | Should Be 0
            }
        }

        $systemctlOutput = & systemctl status apt-daily.service
        It 'has disable the apt-daily service' {
            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'apt-daily.service - Daily apt download activities'
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\sstatic;.*\)'
            $systemctlOutput[2] | Should Match 'Active:\sinactive\s\(dead\).*'
        }

        $systemctlOutput = & systemctl status apt-daily.timer
        It 'has disable the apt-daily timer' {
            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should Be 3
            $systemctlOutput[0] | Should Match 'apt-daily.timer - Daily apt download activities'
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\sdisabled;.*\)'
            $systemctlOutput[2] | Should Match 'Active:\sinactive\s\(dead\).*'
        }
    }
}
