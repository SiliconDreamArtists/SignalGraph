# Load the Signal and SignalEntry classes
. "$PSScriptRoot/Classes/SignalEntry.ps1"
. "$PSScriptRoot/Classes/Signal.ps1"
. "$PSScriptRoot/Classes/Graph.ps1"

. "$PSScriptRoot/Utilities/Get-ResolvedValueFromPathSignal.ps1"
. "$PSScriptRoot/Utilities/Invoke-GSGProcessingRules.ps1"
. "$PSScriptRoot/Utilities/Convert-JsonToSignalGraph.ps1"
. "$PSScriptRoot/Utilities/Add-PathToDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathHydration.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Remove-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-GraphPlanInjectionContext.ps1"
. "$PSScriptRoot/Utilities/Move-PathInDictionary.ps1"
. "$PSScriptRoot/Utilities/Invoke-FormulaGraphCondenser.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathFormulaGraphForJsonArray.ps1"
. "$PSScriptRoot/Utilities/Invoke-GraphPlanOnItem.ps1"
. "$PSScriptRoot/Utilities/Parse-FilterSegment.ps1"

Export-ModuleMember -Function Get-ResolvedValueFromPathSignal
Export-ModuleMember -Function Invoke-GSGProcessingRules
Export-ModuleMember -Function Convert-JsonToSignalGraph
Export-ModuleMember -Function Add-PathToDictionary
Export-ModuleMember -Function Resolve-PathHydration
Export-ModuleMember -Function Resolve-PathFromDictionary
Export-ModuleMember -Function Resolve-PathFromDictionary
Export-ModuleMember -Function Resolve-GraphPlanInjectionContext
Export-ModuleMember -Function Move-PathInDictionary
Export-ModuleMember -Function Invoke-FormulaGraphCondenser
Export-ModuleMember -Function Resolve-PathFormulaGraphForJsonArray
Export-ModuleMember -Function Parse-FilterSegment
Export-ModuleMember -Function Invoke-GraphPlanOnItem

