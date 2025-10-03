# Pester Configuration for Agent Sync Tests

$PesterConfig = New-PesterConfiguration

# General settings
$PesterConfig.Run.Path = @('tests')
$PesterConfig.Run.PassThru = $true

# Output settings
$PesterConfig.Output.Verbosity = 'Detailed'
$PesterConfig.Output.StackTraceVerbosity = 'FirstLine'
$PesterConfig.Output.CIFormat = 'Auto'

# Test result settings
$PesterConfig.TestResult.Enabled = $true
$PesterConfig.TestResult.OutputFormat = 'NUnitXml'
$PesterConfig.TestResult.OutputPath = 'TestResults/test-results.xml'

# Code coverage settings
$PesterConfig.CodeCoverage.Enabled = $true
$PesterConfig.CodeCoverage.Path = @('src/**/*.psm1', 'src/**/*.ps1')
$PesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
$PesterConfig.CodeCoverage.OutputPath = 'coverage/coverage.xml'
$PesterConfig.CodeCoverage.OutputEncoding = 'UTF8'

# Should settings (assertion behavior)
$PesterConfig.Should.ErrorAction = 'Stop'

# Debug settings
$PesterConfig.Debug.ShowFullErrors = $false
$PesterConfig.Debug.WriteDebugMessages = $false
$PesterConfig.Debug.WriteDebugMessagesFrom = @()

# Export configuration
Export-ModuleMember -Variable PesterConfig

# Usage:
# Import-Module .\PesterConfiguration.ps1
# Invoke-Pester -Configuration $PesterConfig
