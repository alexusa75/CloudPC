﻿# region Parameters
[CmdletBinding()]
param (
	[Parameter(Position = 0,Mandatory = $True, HelpMessage = "Output path for the csv file ex: c:\temp\wvd.csv")]
    [ValidateNotNullorEmpty()]
    [string]$csvoutput,
    [Parameter(Position = 1, Mandatory = $False, HelpMessage = "Additionally, Compare against previous file",ParameterSetName='compare')]
    [switch]$compare
)

DynamicParam {
    If($compare){
        # Define parameter attributes
        $paramAttributes = New-Object -Type System.Management.Automation.ParameterAttribute
        $paramAttributes.Mandatory = $true
        $paramAttributes.HelpMessage = "Previous File path ex: c:\team\previous.csv"
        $paramAttributes.Position = 2


        # Create collection of the attributes
        $paramAttributesCollect = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $paramAttributesCollect.Add($paramAttributes)

        # Create parameter with name, type, and attributes
        $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("previousFile", [string], $paramAttributesCollect)

        # Add parameter to parameter dictionary and return the object
        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add("previousFile", $dynParam1)
        return $paramDictionary
    }
}
# endregion Parameters

begin{
    $wvd = Invoke-WebRequest -Uri "https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20220711.json" | ConvertFrom-Json
    $wvd = $wvd.values | ?{$_.Name -like '*virtualDesk*'} | Select id,properties
    $wvdcsvtemp = $wvdcsv = $summary = $summarytemp = New-Object system.collections.arraylist
    #$csvoutput = "c:\temp\wvd.csv"
    $previousFilepath = $PSBoundParameters['previousFile']
    $compp = $True
}
process{
    #Region CSV all IPs
    forEach($wv in $wvd){
        #Write-Host $wv.id -ForegroundColor Green
        $wvIps = ($wv.properties).addressPrefixes
        ForEach($wvip in $wvIps){
            #Write-Host $wvip -ForegroundColor Yellow

            #If /32 then present just the IP else keep the CIDR
            if($wvip -match '/32'){$wvip = $wvip.Split("/")[0]}

            #Extract region, if there is not region information then equal Global
            if($wv.id -notmatch 'WindowsVirtualDesktop.'){
                $region = "Global"
            }else{
                $region = ($wv.id).Split(".")[1]
            }
            $wvdcsvtemp = New-Object -TypeName PSObject -Property @{
                Category = ($wv.id).Split(".")[0]
                Region = $region
                IP = $wvip
            }| Select-Object Category, IP, Region
            $wvdcsv += $wvdcsvtemp
        }
    }
    $wvdsumm = $wvdcsv | Group-Object -Property Region | Sort-Object -Property Count -Descending | Select-Object -Property @{ Name = 'Category'; Expression = { $_.Name } },@{ Name = 'IP addresses';Expression = { $_.Count } }
    $wvdcsv | Export-Csv -Path $csvoutput -NoTypeInformation
    #EndRegion
    #Region Compare
    If($compare -and (Test-Path $previousFilepath)){
        Function addiff ($comp){

            If($comp.SideIndicator -eq '=>'){
                $direction = "Removed IP"
            }elseIf($comp.SideIndicator -eq '<='){
                $direction = "New IP"
            }else{
                $direction = ""}

            $difftemp = New-Object -TypeName PSObject -Property @{
                Category = ($comp.InputObject.split(",")[0]).Replace('"','')
                ip = ($comp.InputObject.split(",")[1]).Replace('"','')
                region = ($comp.InputObject.split(",")[2]).Replace('"','')
                changes = $direction
            } | Select-Object Category, ip, region, changes
            Return $difftemp
        }
        $file1 = Get-Content $csvoutput
        $file2 = Get-Content $previousFilepath
        $compared = Compare-Object -ReferenceObject $file1 -DifferenceObject $file2
        $diff = New-Object system.collections.arraylist
        If(!$compared){
            $compp = $False
            Write-Host "Both files are identical" -ForegroundColor Cyan
        }
        else{
            $compp = $True
            ForEach($comp in $compared){
                $diff+= addiff $comp
            }
        }
    }

    #EndRegion

}
end{
    #clear
    Write-Host "`nYou can find the csv file with all IPs information at:" -ForegroundColor Green -NoNewline
    Write-Host " $csvoutput" -ForegroundColor Yellow

    $summaryoutput = $csvoutput -replace '(.*\\)(.*)','$1Summary.txt'
    Write-Host "`nYou can find the Summary results at:" -ForegroundColor Green -NoNewline
    Write-Host " $summaryoutput" -ForegroundColor Yellow
    $wvdsumm | out-file "C:\alex\WVD\Summary.txt"

    If($compp){
        $compareoutput = $csvoutput -replace '(.*\\)(.*)','$1compare.csv'
        $diff | Export-Csv -Path $compareoutput -NoTypeInformation
        Write-Host "`nYou can find the comparation results at:" -ForegroundColor Green -NoNewline
        Write-Host " $compareoutput" -ForegroundColor Yellow
    }else {
        Write-Host "`nBoth files are identical `n"
    }

    $explore = $csvoutput -replace '(.*\\)(.*)','$1'
    explorer $explore
}





