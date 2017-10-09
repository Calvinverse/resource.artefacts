Describe 'The firewall' {
    $ufwOutput = & sudo ufw status

    Context 'on the machine' {
        It 'should return a status' {
            $ufwOutput | Should Not Be $null
            $ufwOutput.GetType().FullName | Should Be 'System.Object[]'
            $ufwOutput.Length | Should Be 35
        }

        It 'should be enabled' {
            $ufwOutput[0] | Should Be 'Status: active'
        }
    }

    Context 'should allow SSH' {
        It 'on port 22' {
            ($ufwOutput | Where-Object {$_ -match '(22)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }
    }

    Context 'should allow consul' {
        It 'on port 8300' {
            ($ufwOutput | Where-Object {$_ -match '(8300)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 8301' {
            ($ufwOutput | Where-Object {$_ -match '(8301)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 8500' {
            ($ufwOutput | Where-Object {$_ -match '(8500)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 8600' {
            ($ufwOutput | Where-Object {$_ -match '(8600)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }
    }

    Context 'should allow fabio' {
        It 'on port 80' {
            ($ufwOutput | Where-Object {$_ -match '(80)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 443' {
            ($ufwOutput | Where-Object {$_ -match '(443)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 7080' {
            ($ufwOutput | Where-Object {$_ -match '(7080)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 7443' {
            ($ufwOutput | Where-Object {$_ -match '(7443)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }

        It 'on port 9998' {
            ($ufwOutput | Where-Object {$_ -match '(9998)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }
    }
}
