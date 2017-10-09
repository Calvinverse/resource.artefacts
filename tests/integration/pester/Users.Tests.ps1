Describe 'The users list' {
    Context 'on the machine' {
        $content = Get-Content '/etc/passwd'

        $users = @()
        foreach($line in $content)
        {
            $sections = $line.Split(':')
            $userId = [int]($sections[3])
            if (($userId -ge 1000) -and ($userId -lt 65534))
            {
                $users += $sections[0]
            }
        }

        It 'should contain a default user' {
            $users.Length | Should Be 1
            $users[0] | Should Be '${LocalAdministratorName}'
        }
    }
}