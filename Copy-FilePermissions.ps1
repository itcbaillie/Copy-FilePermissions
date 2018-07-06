Import-Module NTFSSecurity

$LogFile = $PSScriptRoot + "\log.txt"
$ChangeFile = $PSScriptRoot + "\changes.txt"

function Log($Message, $Colour)
{
    Write-Host $Message -ForegroundColor $Colour
    $Message | Out-File $LogFile -Append
}

function LogChange($Source, $Destination, $Account, $Rights)
{
    $Message = "{" + $Source + " => " + $Destination + "} += {" + $Account + ", " + $Rights + "}"
    Write-Host "CHANGE: $Message"
    $Message | Out-File $ChangeFile -Append
}

function Copy-FilePermissions($Source, $Destination, $WhatIf)
{
    Log ("Checking permissions on " + $Source) "Yellow"
    if(Test-Path $Destination){

        ForEach($SourceAce in Get-Ace $Source){
            if(-not $SourceAce.IsInherited){
                $Found = $false
                Log ($SourceAce.Name + " has ace for " + $SourceAce.Account + " authorizing " + $SourceAce.AccessRights) "Yellow"
                ForEach($DestAce in Get-Ace $Destination){
                    if(($SourceAce.Account -eq $DestAce.Account) -and ($SourceAce.AccessRights -eq $DestAce.AccessRights)){
                        Log ("Ace match on " + $Source + " for " + $SourceAce.Account) "Green"
                        $Found = $true
                    }
                }
                if(-not $Found){
                    Log ("Missing ace on " + $Source + " for " + $SourceAce.Account + " authorizing " + $SourceAce.AccessRights + ", adding...") "Red"
                    LogChange $Source $Destination $SourceAce.Account $SourceAce.AccessRights

                    if(-not $WhatIf){
                        Add-Ace -Path $Destination -Account $SourceAce.Account -AccessRights $SourceAce.AccessRights
                    }
                }
            } else {
                Log ("" + $SourceAce.Account + " (" + $SourceAce.AccessRights + ") is inherited on " + $Source + ", ignoring...") "Yellow"
            }
        }

    } else {
        Log ($Destination + " is missing!") "Red"
    }
}

function Copy-StructurePermissions
{
    Param(
        [Parameter (Mandatory=$true)][string]$Source,
        [Parameter (Mandatory=$true)][string]$Destination,
        [Parameter (Mandatory=$false)][switch]$WhatIf
    )

    Log "" -Colour "Green"
    Log -Message ("Source is " + $Source) -Colour "Yellow"

    If(Test-Path $Source){

        Copy-FilePermissions $Source $Destination $WhatIf

        $Children = Get-ChildItem $Source

        foreach($Child in $Children){
            $File = $Source + "\" + $Child
            $NewDestination = $Destination + "\" + $Child

            if((Get-Item $File) -is [System.IO.DirectoryInfo]){
                Log -Message ($File + " is a folder, recursing...") -Colour "Yellow"
                if($WhatIf){
                    Copy-StructurePermissions -Source $File -Destination $NewDestination -WhatIf
                } else {
                    Copy-StructurePermissions -Source $File -Destination $NewDestination
                }
            } else {
                #Log ($File + " is a file") "DarkYellow"
                Copy-FilePermissions -Source $File -Destination $NewDestination $WhatIf
            }
        }

    } else {
        Log -Message ("Can't find " + $Source) -Colour "Red"
    }
}

Remove-Item $LogFile
Remove-Item $ChangeFile

# Copy-StructurePermissions -Source "\\dee\shares\FSLTD\Departments\ICT\Shared\PermissionsTest" -Destination "\\don\shares\FSSL\Departments\ICT\Shared\PermissionsTest"