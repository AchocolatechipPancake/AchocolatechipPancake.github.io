function Get-ScheduledTaskComHandler {
<#
    .SYNOPSIS
        Author: Matt Nelson (@enigma0x3), Matthew Graeber (@mattifestation)
        License: BSD 3-Clause
        Required Dependencies: None
        Optional Dependencies: None

        Checks all scheduled tasks that execute on user logon & have a "Custom handler" set. This will expose
        tasks that are able to be abused for userland persistence via COM handler hijacking.

    .EXAMPLE

        PS C:\> Get-ScheduledTaskComHandler

        Return all scheduled tasks with COM handlers.

    .PARAMETER OnLogon
        Shows all Tasks that start on logon & associated CLSIDS/DLLs 

    .PARAMETER PersistenceLocations
        Shows all Tasks that are able to be Hijacked for userland persistence.

#>


[CmdletBinding(DefaultParameterSetName = 'OnLogon')]
param(
    [Parameter(ParameterSetName = 'OnLogon')]
    [Switch]
    $OnLogon,
    [Parameter(ParameterSetName = 'PersistenceLocations')]
    [Switch]
    $PersistenceLocations

)

    $ErrorActionPreference = "SilentlyContinue"
    $Path = "$($ENV:windir)\System32\Tasks"
    $null = New-PSDrive -PSProvider registry -root HKEY_CLASSES_ROOT -Name HKCR
    Get-ChildItem -Path $Path -Recurse | Where-Object { ! $_.PSIsContainer } | ForEach-Object {
        $TaskName = $_.Name
        $TaskXML = [xml] (Get-Content $_.FullName)
        if($TaskXML.Task.Actions.ComHandler) {     
            $TaskTrigger = $TaskXML.Task.Triggers.OuterXML
            $TaskXML.Task.Actions.Exec.Command| ForEach-Object {

                $COM = $TaskXML.Task.Actions.ComHandler.ClassID
                $dll = (Get-ItemProperty -LiteralPath HKCR:\CLSID\$COM\InprocServer32).'(default)'
                $Out = New-Object PSObject
                $Out | Add-Member Noteproperty 'TaskName' $TaskName
                $Out | Add-Member Noteproperty 'CLSID' $COM
                $Out | Add-Member Noteproperty 'Dll' $dll
                $Out | Add-Member Noteproperty 'Logon' $False
                $null = $TaskXML.Task.InnerXml -match 'Context="(?<Context>InteractiveUsers|AllUsers|AnyUser)"'

                $IsUserContext = $False
                if ($Matches['Context']) { $IsUserContext = $True }
                $Out | Add-Member Noteproperty 'IsUserContext' $IsUserContext

                if($TaskTrigger.Contains('LogonTrigger')){
                    $Out.Logon = $True
                }
                else{$Out.Logon = $False}
                
                $Context = $null
                              
                if($OnLogon){
                    if ($Out.Logon) {
                        $Out
                    }
                } elseif($PersistenceLocations){
                    if ($Out.IsUserContext -and $Out.Logon -eq "True") {
                        $Out
                    }
                } else { $Out }     
            }
        }
    }
}