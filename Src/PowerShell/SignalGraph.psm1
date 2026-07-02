# Load the Signal and SignalEntry classes
. "$PSScriptRoot/Classes/SignalEntry.ps1"
. "$PSScriptRoot/Classes/Signal.ps1"
. "$PSScriptRoot/Classes/Graph.ps1"

. "$PSScriptRoot/Utilities/Get-ResolvedValueFromPathSignal.ps1"
. "$PSScriptRoot/Utilities/Convert-JsonToSignalGraph.ps1"
. "$PSScriptRoot/Utilities/Add-PathToDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathHydration.ps1"
. "$PSScriptRoot/Utilities/Resolve-InnerPathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Remove-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-GraphPlanInjectionContext.ps1"
. "$PSScriptRoot/Utilities/Move-PathInDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathGraphForJsonArray.ps1"
. "$PSScriptRoot/Utilities/Invoke-ParseFilterSegment.ps1"

. "$PSScriptRoot/Utilities/Resolve-GraphForJsonArray.ps1"
. "$PSScriptRoot/Utilities/Convert-ToDictionary.ps1"

Export-ModuleMember -Function Get-ResolvedValueFromPathSignal
Export-ModuleMember -Function Convert-JsonToSignalGraph
Export-ModuleMember -Function Add-PathToDictionary
Export-ModuleMember -Function Resolve-PathHydration
Export-ModuleMember -Function Resolve-InnerPathFromDictionary
Export-ModuleMember -Function Resolve-PathFromDictionary
Export-ModuleMember -Function Resolve-GraphPlanInjectionContext
Export-ModuleMember -Function Move-PathInDictionary
Export-ModuleMember -Function Resolve-PathGraphForJsonArray
Export-ModuleMember -Function Convert-ToDictionary
Export-ModuleMember -Function Remove-PathFromDictionary

Export-ModuleMember -Function Resolve-GraphForJsonArray
Export-ModuleMember -Function Start-Signal


