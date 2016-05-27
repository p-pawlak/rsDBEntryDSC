function Convert-KVPArrayToHashtable {
  param(
      [Parameter(Mandatory = $true)]
      [Microsoft.Management.Infrastructure.CimInstance[]]
      $KeyValuePairs
  )
  $ret = @{}
  ForEach ($pair in $KeyValuePairs){
      Write-Verbose " $($pair.Key) => $($pair.Value)"
      $ret[$pair.Key] = $pair.Value
  }
  $ret
}

function EvalData {
<#
.DESCRIPTION
Evaluates script expressions within passed data. Explicit values will be copied
to the returned hash, entries with key beginning with '%' will be replaced by
the value returned by the expression and the key will be stripped of the '%'.
Use with caution.

.PARAMETER EvalData
A flat hash of values: ColumnName => Value

#>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $EvalData
    )

    $ret = @{}
    $enum = $evaldata.GetEnumerator()
    While($enum.MoveNext()){
        If($enum.Key[0] -eq '%'){
            $script = [scriptblock]::Create($enum.Value)
            $ret[$enum.Key.Substring(1)] = $script.InvokeReturnAsIs()
        } Else {
            $ret[$enum.Key] = $enum.Value
        }
    }
    $ret
}

function Get-SelectQuery {
<#
.DESCRIPTION
Generates a System.Data.SqlClient.SqlCommand that queries for the given resource

.PARAMETER Connection
An open System.Data.SqlClient.SqlConnection

.PARAMETER Table
Table name

.PARAMETER SQLData
A flat hash of values: ColumnName => Value

#>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection] $Connection,

        [Parameter(Mandatory = $true)]
        [string] $Table,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $SQLData
    )

    $regex = "^[a-zA-Z_][a-zA-Z0-9*]"

    if( -not [regex]::Matches($Table, $regex) ){
        throw "I refuse to accept '$Table' as the table name."
    }

    [string[]]$keys = $SQLData.Keys
    if($keys.Count -eq 0){
        throw "SQLData cannot be empty"
    }
    $command = $Connection.CreateCommand()
    [System.Collections.ArrayList]$constraints = @()

    for($i = 0; $i -lt $keys.Count; $i++){
        if( -not [regex]::Matches($keys[$i], $regex)){
            throw "I refuse to accept '$($keys[$i])' as the column name."
        }
        $command.Parameters.AddWithValue("param$i",$SQLData[$keys[$i]]) | Out-Null
        $constraints.Add("$($keys[$i]) = @param$i") | Out-Null
    }

    if($constrains.Count -gt 0){
        throw "Query should have constraints" # This should not happen
    }
    $command.CommandText = "SELECT * FROM $Table WHERE " + ($constraints -join " AND ")
    return $command
}


function Get-InsertQuery {
<#
.DESCRIPTION
Generates a System.Data.SqlClient.SqlCommand that inserts the given data

.PARAMETER Connection
An open System.Data.SqlClient.SqlConnection

.PARAMETER Table
Table name

.PARAMETER SQLData
A flat hash of values: ColumnName => Value

#>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection] $Connection,

        [Parameter(Mandatory = $true)]
        [string] $Table,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $SQLData
    )

    $regex = "^[a-zA-Z_][a-zA-Z0-9*]"

    if( -not [regex]::Matches($Table, $regex) ){
        throw "I refuse to accept '$Table' as the table name."
    }

    [string[]]$keys = $SQLData.Keys
    if($keys.Count -eq 0){
        throw "SQLData cannot be empty"
    }
    $command = $Connection.CreateCommand()
    [System.Collections.ArrayList]$columns = @()
    [System.Collections.ArrayList]$values = @()

    for($i = 0; $i -lt $keys.Count; $i++){
        if( -not [regex]::Matches($keys[$i], $regex)){
            throw "I refuse to accept '$($keys[$i])' as the column name."
        }
        $command.Parameters.AddWithValue("param$i",$SQLData[$keys[$i]]) | Out-Null
        $columns.Add($keys[$i]) | Out-Null
        $values.Add("@param$i") | Out-Null
    }

    $command.CommandText = "INSERT INTO $Table(" + ($columns -join ',')  + ") VALUES(" + ($values -join ',') + ")"
    return $command
}

function Get-UpdateQuery {
<#
.DESCRIPTION
Generates a System.Data.SqlClient.SqlCommand that queries for the given resource

.PARAMETER Connection
An open System.Data.SqlClient.SqlConnection

.PARAMETER Table
Table name

.PARAMETER SQLData
A flat hash of future values : ColumnName => Value

.PARAMETER WhereData
A flat hash of current values: ColumnName => Value

#>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection] $Connection,

        [Parameter(Mandatory = $true)]
        [string] $Table,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $SQLData,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $WhereData
    )

    $regex = "^[a-zA-Z_][a-zA-Z0-9*]"

    if( -not [regex]::Matches($Table, $regex) ){
        throw "I refuse to accept '$Table' as the table name."
    }

    $command = $Connection.CreateCommand()
    [System.Collections.ArrayList]$constraints = @()
    [System.Collections.ArrayList]$sets = @()

    [string[]]$keys = $SQLData.Keys
    if($keys.Count -eq 0){
        throw "SQLData cannot be empty"
    }

    for($i = 0; $i -lt $keys.Count; $i++){
        if( -not [regex]::Matches($keys[$i], $regex)){
            throw "I refuse to accept '$($keys[$i])' as the column name."
        }
        $command.Parameters.AddWithValue("param$i",$SQLData[$keys[$i]]) | Out-Null
        $sets.Add("$($keys[$i]) = @param$i") | Out-Null
    }

    [string[]]$keys = $WhereData.Keys
    if($keys.Count -eq 0){
        throw "WhereData cannot be empty"
    }

    for($i = 0; $i -lt $keys.Count; $i++){
        if( -not [regex]::Matches($keys[$i], $regex)){
            throw "I refuse to accept '$($keys[$i])' as the column name."
        }
        $command.Parameters.AddWithValue("constraint$i",$WhereData[$keys[$i]]) | Out-Null
        $constraints.Add("$($keys[$i]) = @constraint$i") | Out-Null
    }


    $command.CommandText = "UPDATE $Table SET " + ($sets -join ",") + " WHERE " + ($constraints -join " AND ")
    return $command
}

function Get-DeleteQuery {
<#
.DESCRIPTION
Generates a System.Data.SqlClient.SqlCommand that deletes the given resource

.PARAMETER Connection
An open System.Data.SqlClient.SqlConnection

.PARAMETER Table
Table name

.PARAMETER WhereData
A flat hash of current values: ColumnName => Value

#>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection] $Connection,

        [Parameter(Mandatory = $true)]
        [string] $Table,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $WhereData
    )

    $regex = "^[a-zA-Z_][a-zA-Z0-9*]"

    if( -not [regex]::Matches($Table, $regex) ){
        throw "I refuse to accept '$Table' as the table name."
    }

    $command = $Connection.CreateCommand()
    [System.Collections.ArrayList]$constraints = @()


    [string[]]$keys = $WhereData.Keys
    if($keys.Count -eq 0){
        throw "WhereData cannot be empty"
    }

    [string[]]$keys = $WhereData.Keys
    if($keys.Count -eq 0){
        throw "WhereData cannot be empty"
    }

    for($i = 0; $i -lt $keys.Count; $i++){
        if( -not [regex]::Matches($keys[$i], $regex)){
            throw "I refuse to accept '$($keys[$i])' as the column name."
        }
        $command.Parameters.AddWithValue("constraint$i",$WhereData[$keys[$i]]) | Out-Null
        $constraints.Add("$($keys[$i]) = @constraint$i") | Out-Null
    }


    $command.CommandText = "DELETE FROM $Table WHERE " + ($constraints -join " AND ")
    return $command
}

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [parameter(Mandatory = $true)]
        [System.String]
        $KeyColumn,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConnectionString,

        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SQLData,

        [parameter(Mandatory = $true)]
        [System.String]
        $Table
    )
    $SQLDataHash = Convert-KVPArrayToHashtable $SQLData
    $SQLDataHash[$KeyColumn] = $Key
    $SQLDataHash = EvalData $SQLDataHash

    Write-Debug "data hash $($SQLDataHash | ConvertTo-Json)"

    $connection = [System.Data.SqlClient.SqlClientFactory]::Instance.CreateConnection()
    $connection.ConnectionString = $ConnectionString
    $connection.Open()
    $query = Get-SelectQuery -Connection $connection -Table $Table -SQLData $SQLDataHash
    Write-Debug "query: $($query.CommandText)"
    $reader = $query.ExecuteReader()
    if($reader.HasRows){
        $reader.Read() | Out-Null
        $ret = @{}
        foreach( $i in 0 .. ($reader.FieldCount-1)){
            $ret[$reader.GetName($i)] = $reader.Item($i)
        }
        $reader.Close()
        $connection.Close()
        return $ret
    }else{
        $reader.Close()
        $connection.Close()
        return $null
    }
}


function Set-TargetResource {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [parameter(Mandatory = $true)]
        [System.String]
        $KeyColumn,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConnectionString,

        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SQLData,

        [parameter(Mandatory = $true)]
        [System.String]
        $Table,

        [ValidateSet("Absent","Present")]
        [System.String]
        $Ensure
    )
    $SQLDataHash = Convert-KVPArrayToHashtable $SQLData
    $SQLDataHash[$KeyColumn] = $Key
    $SQLDataHash = EvalData $SQLDataHash
    Write-Debug "data hash $($SQLDataHash | ConvertTo-Json)"
    $keyData = EvalData @{$KeyColumn = $Key}
    Write-Debug "keyData $($keyData | ConvertTo-Json)"

    $connection = [System.Data.SqlClient.SqlClientFactory]::Instance.CreateConnection()
    $connection.ConnectionString = $ConnectionString
    $connection.Open()
    $query = Get-SelectQuery -Connection $connection -Table $Table -SQLData $keyData
    Write-Debug "query: $($query.CommandText)"
    $reader = $query.ExecuteReader()
    $currentData = $null
    if($reader.HasRows){
        $reader.Read() | Out-Null
        $currentData = @{}
        foreach( $i in 0 .. ($reader.FieldCount-1)){
            $currentData[$reader.GetName($i)] = $reader.Item($i)
        }
    }
    $reader.Close()
     Write-Debug "current data $($currentData | ConvertTo-Json)"
    if ( $currentData  -eq $null -and $Ensure -eq "Present"){
        Write-Verbose "Resource missing. Attempting to insert."
        $query = Get-InsertQuery -Connection $connection -Table $Table -SQLData $SQLDataHash
        Write-Debug "query: $($query.CommandText)"
        $query.ExecuteNonQuery() | Out-Null
        $connection.Close()
    } elseif( $currentData  -ne $null -and $Ensure -eq "Present" ){
        write-verbose "Resource exists."
        $match = $true
        foreach($entry in $SQLDataHash.GetEnumerator()){
            if(-not $currentData.ContainsKey($entry.Key) -or ($currentData[$entry.Key] -ne $entry.Value)){
                Write-Debug "Wrong value for $($entry.Key): is $($currentData[$entry.Key]), should be $($entry.Value)."
                $match = $false
                break
            }
        }
        if(-not $match){
            write-verbose "Resource values need updating."
            $query = Get-UpdateQuery -Connection $connection -Table $Table -SQLData $SQLDataHash -WhereData $keyData
            $query.ExecuteNonQuery() | Out-Null
            $connection.Close()
        }
    } elseif( $currentData -ne $null -and $Ensure -eq "Absent"){
        write-verbose "Resource needs to be deleted."
        $query = Get-DeleteQuery -Connection $connection -Table $Table -WhereData $keyData
        $query.ExecuteNonQuery() | Out-Null
        $connection.Close()
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [parameter(Mandatory = $true)]
        [System.String]
        $KeyColumn,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConnectionString,

        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SQLData,

        [parameter(Mandatory = $true)]
        [System.String]
        $Table,

        [ValidateSet("Absent","Present")]
        [System.String]
        $Ensure
    )
    $res = Get-TargetResource -Key $Key -KeyColumn $KeyColumn -ConnectionString $ConnectionString -SQLData $SQLData -Table $Table
    $json = $res | ConvertTo-Json
    Write-Debug "json: $json"
    return ( $res -eq $null ) -xor ( $Ensure -eq 'Present')
}


Export-ModuleMember -Function *-TargetResource
