
########################################################
# HelloID-Conn-Prov-Source-{connectorName}-Departments
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

function Resolve-{connectorName}NameError {
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
    # $splatParams = @{
    #    UserName = $($config.UserName)
    #    Password = $($config.Password)
    #    BaseUrl  = $($config.BaseUrl)
    # }
    # Invoke-testRestMethod @splatParams

    $departments = @(
        @{
            ExternalId        = "ADMINISTR01"
            DisplayName       = "Administration01"
            Name              = "Administration01"
            ManagerExternalId = "JohnD-0"
        },
        @{
            ExternalId       = "HRM"
            DisplayName      = "Human & Resource management"
            Name             = "Human and Resource"
            ParentExternalId = "ADMINISTR01"
        }
    )
    Write-Verbose 'Importing raw data in HelloID'
    foreach ($department in $departments ) {
        Write-Output $department | ConvertTo-Json -Depth 10
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-testError -ErrorObject $ex
        Write-Verbose "Could not import {connectorName} departments. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Throw "Could not import {connectorName} departments. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import {connectorName} departments. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Throw "Could not import {connectorName} departments. Error: $($errorObj.FriendlyMessage)"
    }
}