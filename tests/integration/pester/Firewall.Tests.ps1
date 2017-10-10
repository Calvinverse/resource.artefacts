Describe 'The firewall' {
    $ufwOutput = & sudo ufw status

    Context 'on the machine' {
        It 'should return a status' {
            $ufwOutput | Should Not Be $null
            $ufwOutput.GetType().FullName | Should Be 'System.Object[]'
            $ufwOutput.Length | Should Be 27
        }

        It 'should be enabled' {
            $ufwOutput[0] | Should Be 'Status: active'
        }
    }

    Context 'should allow SSH' {
        It 'on port 22' {
            ($ufwOutput | Where-Object {$_ -match '(22)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }
    }

    Context 'should allow consul' {
        It 'on port 8300' {
            ($ufwOutput | Where-Object {$_ -match '(8300)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }

        It 'on port 8301' {
            ($ufwOutput | Where-Object {$_ -match '(8301)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }

        It 'on port 8500' {
            ($ufwOutput | Where-Object {$_ -match '(8500)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }

        It 'on port 8600' {
            ($ufwOutput | Where-Object {$_ -match '(8600)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }
    }

    Context 'should allow nexus' {
        It 'on port 8081' {
            ($ufwOutput | Where-Object {$_ -match '(80)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be $null
        }
    }
}
