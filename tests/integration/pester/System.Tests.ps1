Describe 'On the system' {
    Context 'the machine name' {
        It 'should be a generated name with containing the version number and random characters' {
            hostname | Should Match '^(cvartefacts.*)-\d{1,2}-\d{1,3}-\d{1,3}-.{16}$'
        }
    }

    Context 'the environment variables' {
        It 'should have a product name environment variable' {
            $env:RESOURCE_NAME | Should Be '${ProductName}'
        }

        It 'should have an environment variable for the major version' {
            $env:RESOURCE_VERSION_MAJOR | Should Be '${VersionMajor}'
        }

        It 'should have an environment variable for the minor version' {
            $env:RESOURCE_VERSION_MINOR | Should Be '${VersionMinor}'
        }

        It 'should have an environment variable for the patch version' {
            $env:RESOURCE_VERSION_PATCH | Should Be '${VersionPatch}'
        }

        It 'should have an environment variable for the semantic version' {
            $env:RESOURCE_VERSION_SEMANTIC | Should Be '${VersionSemantic}'
        }
    }

    Context 'the time zone' {
        It 'should be on UTC time' {
            (timedatectl status | grep "Time zone") | Should Match '(Etc\/UTC\s\(UTC,\s\+0000\))'
        }
    }

    Context 'the administrator rights' {
        It 'should have default sudo settings' {
            (Get-FileHash -Path /etc/sudoers -Algorithm SHA256).Hash | Should Be 'CC61F3AA6C9AF8F9540435AC280D6AD1AD0A734FDCAC6D855527F9944ABB67A3'
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
            '/tmp/updates.txt' | Should Exist
        }

        $fileSize = (Get-Item '/tmp/updates.txt').Length
        if ($fileSize -gt 0)
        {
            $updates = Get-Content /tmp/updates.txt
            $additionalPackages = Compare-Object $allowedPackages $updates | Where-Object { $_.sideindicator -eq '=>' }

            It 'should all be installed' {
                $additionalPackages.Length | Should Be 0
            }
        }
    }
}
