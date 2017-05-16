using namespace System.Collections.Generic
using namespace System.IO

<#
  .SYNOPSIS
    Returns either *all* vcvarsall.bat files, a specific installed product's
    vcvarsall.bat, or the most recently installed vcvarsall.bat
#>
function Find-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any",
    [Alias("l")]
    [Switch]
    $Latest = $false
  )

  $instances = Get-VSSetupInstance | Sort-Object -Property InstallDate
  if ($Latest) { $instances = $instances | Select-Object -Last 1 }

  $instances `
  | ForEach-Object { $_.InstallationPath } `
  | Where-Object { @([Path]::GetFileName($_), "Any") -contains $Product } `
  | ForEach-Object { Get-ChildItem vcvarsall.bat -Path "$_\VC" -Recurse }
}

<#
  .SYNOPSIS
    Returns a list of all installed Windows Kits SDKs
#>
function Find-VCWindowsKitsVersions {
  [CmdletBinding(DefaultParameterSetName="All")]
  param(
    [Alias("l")]
    [Switch]
    $Latest = $false
  )

  $path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
  $10 = (Get-ItemProperty -Path $path).KitsRoot10
  $8 = (Get-ItemProperty -Path $path).KitsRoot81
  $versions = [List[Version]]::new()
  Get-Item $8 `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  Get-ChildItem "$10\Lib" `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  if (-not $Latest) { return $versions }
  $versions.Sort()
  @($versions) | Select-Object -Last 1
}

<#
  .SYNOPSIS
    Executes a vcvarsall.bat with specific host and target settings.
    Passes $Product to Find-VCVars.
    Returns a HashTable representing the difference in environment variables
#>
function Invoke-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("ARM", "ARM64", "x86", "AMD64")]
    [Alias("t")]
    [String]
    $TargetArch = "AMD64",

    [ValidateSet("x86", "AMD64")]
    [Alias("h")]
    [String]
    $HostArch = "AMD64",

    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any",

    [Alias("s")]
    [Version]
    $SDK,

    [Alias("u")]
    [Switch]
    $UWP = $false
  )

  $hst = switch -wildcard ($HostArch) {
    "AMD64" { "amd64" }
    "x86" { "x86" }
  }

  $target = switch -wildcard ($TargetArch) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    "ARM" { "arm" }
    "x86" { "x86" }
  }

  $arch = if ($hst -ne $target) { "{0}_{1}" -f $hst, $target } else { $target }
  $batch = (Find-VCVars $Product | Select-Object -Last 1).FullName
  $environment = @{}
  $current = @{}

  cmd /c set `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $current += $_ }

  if ($UWP -and ($SDK -eq $null)) {
    throw "Cannot use Universal Windows Platform without SDK version"
  }

  if ($UWP) { $platform = "uwp" }

  cmd /c "`"$batch`" $arch $platform $SDK & set" `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $environment += $_ }

  foreach ($entry in $current.GetEnumerator()) {
    if ($entry.Value -ne $environment[$entry.Name]) { continue }
    $environment.Remove($entry.Name)
  }

  return $environment
}

<#
  .SYNOPSIS
    Forces all environment variables given to be set in the current environment
    This does not save the current environment and bypasses the VCVars Stack
    entirely. Most useful when working with a single install and toolchain
#>
function Set-VCVars {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("e")]
    [HashTable]
    $Environment
  )

  foreach ($entry in $Environment.GetEnumerator()) {
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
}

<#
  .SYNOPSIS
    Calls /clean_env on the vcvarsall.bat. If no vcvarsall.bat command was
    run, this will error. Forcibly resets the environment, bypassing the VCVars
    Stack entirely
#>
function Clear-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any"
  )

  $batch = (Find-VCVars $Product | Select-Object -Last 1).FullName
  $environment = @{}
  cmd /c "`"$batch`" /clean_env & set" `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $environment += $_ }

  Set-VCVars $environment
}

<#
  .SYNOPSIS
    Preserves the current environment variables by placing them onto an
    internal stack.
#>
function Push-VCVars {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("e")]
    [HashTable]
    $Environment
  )

  $vars = @{}
  foreach ($entry in $Environment.GetEnumerator()) {
    $current = [Environment]::GetEnvironmentVariable($entry.Name)
    $vars.Add($entry.Name, $current)
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
  $script:VCVarsStack.Push($vars)
}

<#
  .SYNOPSIS
    Resets the environment variables to the previous state that was pushed
    onto the internal stack. It then returns the state that was replaced in
    the form of a HashTable
#>
function Pop-VCVars {
  [CmdletBinding()]
  param()
  trap { throw $_ }

  if (-not $script:VCVarsStack) { return @{} }

  $state = $script:VCVarsStack.Pop()
  $dict = @{}
  foreach ($entry in $state.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($entry.Name)
    $dict.Add($entry.Name, $value)
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
  return $dict
}

function VCSDKArgumentCompletion {
  param($command, $parameter, $word, $ast, $fake)
  Find-VCWindowsKitsVersions `
  | Where-Object { $_ -like "*$word*" } `
  | ForEach-Object { New-Object CompletionResult $_, $_, 'ParameterValue', $_ }
}

Register-ArgumentCompleter `
  -CommandName Invoke-VCVars `
  -ParameterName SDK `
  -ScriptBlock $function:VCSDKArgumentCompletion

$script:VCVarsStack = New-Object Stack[HashTable]

Set-Alias vcvars Invoke-VCVars
Set-Alias pushvc Push-VCVars
Set-Alias popvc Pop-VCVars
Set-Alias setvc Set-VCVars
