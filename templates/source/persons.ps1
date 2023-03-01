########################################################
# HelloID-Conn-Prov-Source-{connectorName}-Persons
#
# Version: 1.0.0
########################################################
# Initialize default value's
$config = $Configuration | ConvertFrom-Json

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Invoke-{connectorName}RestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Headers
    )
    process {
        try {
            Write-Verbose "Invoking command '$($MyInvocation.MyCommand)' to endpoint '$Uri'"
            $splatParams = @{
                Uri         = $Uri
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     =  $Headers
            }
            Invoke-RestMethod @splatParams -Verbose:$false
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Resolve-{connectorName}Error {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = ''
            FriendlyMessage  = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -eq $ErrorObject.Exception.Response) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
                $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message
            }
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            $httpErrorObj.ErrorDetails = $streamReaderResponse
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # `$splatParams = @{
    #    UserName = `$(`$config.UserName)
    #    Password = `$(`$config.Password)
    #    BaseUrl  = `$(`$config.BaseUrl)
    # }
    # Invoke-$($Name)RestMethod @splatParams

    $persons = @(
        @{
            Id         = "JohnDoe01"
            FirstName  = "John"
            LastName   = "Doe"
            Convention = "B"
            Contracts  = @(
                @{
                    SequenceNumber = "1"
                    DepartmentName = "Administration 0"
                    DepartmentCode = "ADMINISTR_0"
                    TitleName      = "Manager"
                    TitleCode      = "Man"
                    StartDate      = Get-Date("2018-01-01") -Format "o"
                    EndDate        = $null
                }
            )
        },
        @{
            Id         = "JaneDoe01"
            FirstName  = "Jane"
            LastName   = "Doe"
            Convention = "B"
            Contracts  = @(
                @{
                    SequenceNumber = "1"
                    DepartmentName = "Administration 0"
                    DepartmentCode = "ADMINISTR_0"
                    TitleName      = "Secretary"
                    TitleCode      = "Sec"
                    StartDate      = Get-Date("2015-03-02") -Format "o"
                    EndDate        = $null
                }
            )
        }
    )

    Write-Verbose 'Importing raw data in HelloID'
    foreach ($person in $persons ) {
        $person | Add-Member -NotePropertyMembers @{ ExternalId = $person.Id }
        $person | Add-Member -NotePropertyMembers @{ DisplayName = "$($person.FirstName) $($person.LastName)".trim(' ') }
        # `$person | Add-Member -NotePropertyMembers @{ Contracts = [System.Collections.Generic.List[Object]]::new() }

        Write-Output $person | ConvertTo-Json -Depth 10
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-{connectorName}Error -ErrorObject $ex
        Write-Verbose "Could not import {connectorName} persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import {connectorName} persons. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import {connectorName} persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import {connectorName} persons. Error: $($errorObj.FriendlyMessage)"
    }
}
