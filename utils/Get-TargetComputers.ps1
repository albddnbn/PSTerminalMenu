function Get-TargetComputers {
    <#
    .SYNOPSIS
        Takes user input and returns a list of hostnames.
        Input can be:
            1. Single hostname string, ex: 's-a227-01'
            2. Comma-separated list of hostnames, ex: s-a227-01,s-a227-02
            3. Path to text file containing one hostname per line, ex: 'D:\computers.txt'
            4. First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with s-a227-.

    .NOTES
        Author :    abuddenb
        Date   :    1-14-2024
    #>
    param(
        $TargetComputerInput
    )
    Write-Host "Targetcomputerinput: $TargetComputerInput"
    if (($TargetComputerInput -eq '')) {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No TargetComputer value provided, assigning '127.0.0.1'."
        $TargetComputerInput = @('127.0.0.1')
    }
    ## Deal with TargetComputer input:
    #
    else {
        
        $targetcomputer_typeobj = $TargetComputerInput.gettype()
        $targetcomputer_typename = $targetcomputer_typeobj | select -exp name

        try {
            $ADCheck = Get-ADComputer $TargetComputerInput # TargetComputer is a single hostname string, ex: 'computer-01'
        }
        catch {
            $null
        }
        ## If Targetcomputer is a STRING
        if ($targetcomputer_typename -eq 'string') {
            Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: TargetComputer value determined to be a string."
            # hostname .txt filepath
            if (Test-Path $TargetComputerInput) {
                $TargetComputerInput = Get-Content $TargetComputerInput
                Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Test-Path determined $TargetComputerInput is filepath, used Get-Content to create hostname list."
            }
            # single hostname
            elseif ($ADCheck) {
                $TargetComputerInput = $TargetComputerInput
                Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Get-ADComputer determined $TargetComputerInput is a single hostname string."
            }
            # comma-separated list of hostnames
            elseif ($TargetComputerInput -like "*,*") {
                $TargetComputerInput = $TargetComputerInput -split ',' | sort # split/sort into a list
                Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: TargetComputer value determined to be a comma-separated list of hostnames, since it contained a comma."
            }
            # first section of a hostname
            else {

                $TargetComputerInput = $TargetComputerInput + "x"
                $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                $TargetComputerInput = $TargetComputerInput | Sort-Object

                Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: TargetComputer value determined to be the first section of a hostname, used Get-ADComputer to create hostname list."
            }
        }
    }

    $TargetComputerInput = $TargetComputerInput | Where-object { $_ -ne '' }

    # `a will sound the Windows 'gong' just to get user's attentino so they know they have to enter y/n
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Hosts determined:" -Nonewline
    Write-Host "$($TargetComputerInput -join ', ')" -foregroundcolor green

    # tell user to press enter to accept the list or any other key to deny
    Write-Host "Press 'y' to accept the list, or 'n' to deny it and end the function." -foregroundcolor yellow
    $key = $Host.UI.RawUI.ReadKey()
    [String]$character = $key.Character
    if ($($character.ToLower()) -ne 'y') {
        return $null
    }
    # elseif - they pressed enter 
    elseif ($($character.ToLower()) -eq 'y') {
        return $TargetComputerInput
    }
}