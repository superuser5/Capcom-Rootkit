function Get-LoadedModules {
<#
.SYNOPSIS
	Use NtQuerySystemInformation::SystemModuleInformation to get a list of
	loaded modules, their base address and size (x32/x64).
	Note: Low integrity only pre 8.1
.DESCRIPTION
	Author: Ruben Boonen (@FuzzySec)
	License: BSD 3-Clause
	Required Dependencies: None
	Optional Dependencies: None
.EXAMPLE
	C:\PS> $Modules = Get-LoadedModules
	C:\PS> $KernelBase = $Modules[0].ImageBase
	C:\PS> $KernelType = ($Modules[0].ImageName -split "\\")[-1]
	C:\PS> ......
#>

	[int]$BuffPtr_Size = 0
	while ($true) {
		[IntPtr]$BuffPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BuffPtr_Size)
		$SystemInformationLength = New-Object Int
	
		# SystemModuleInformation Class = 11
		$CallResult = [Capcom]::NtQuerySystemInformation(11, $BuffPtr, $BuffPtr_Size, [ref]$SystemInformationLength)
		
		# STATUS_INFO_LENGTH_MISMATCH
		if ($CallResult -eq 0xC0000004) {
			[System.Runtime.InteropServices.Marshal]::FreeHGlobal($BuffPtr)
			[int]$BuffPtr_Size = [System.Math]::Max($BuffPtr_Size,$SystemInformationLength)
		}
		# STATUS_SUCCESS
		elseif ($CallResult -eq 0x00000000) {
			break
		}
		# Probably: 0xC0000005 -> STATUS_ACCESS_VIOLATION
		else {
			[System.Runtime.InteropServices.Marshal]::FreeHGlobal($BuffPtr)
			return
		}
	}

	$SYSTEM_MODULE_INFORMATION = New-Object SYSTEM_MODULE_INFORMATION
	$SYSTEM_MODULE_INFORMATION = $SYSTEM_MODULE_INFORMATION.GetType()
	if ([System.IntPtr]::Size -eq 4) {
		$SYSTEM_MODULE_INFORMATION_Size = 284
	} else {
		$SYSTEM_MODULE_INFORMATION_Size = 296
	}

	$BuffOffset = $BuffPtr.ToInt64()
	$HandleCount = [System.Runtime.InteropServices.Marshal]::ReadInt32($BuffOffset)
	$BuffOffset = $BuffOffset + [System.IntPtr]::Size

	$SystemModuleArray = @()
	for ($i=0; $i -lt $HandleCount; $i++){
		$SystemPointer = New-Object System.Intptr -ArgumentList $BuffOffset
		$Cast = [system.runtime.interopservices.marshal]::PtrToStructure($SystemPointer,[type]$SYSTEM_MODULE_INFORMATION)
		
		$HashTable = @{
			ImageName = $Cast.ImageName
			ImageBase = if ([System.IntPtr]::Size -eq 4) {$($Cast.ImageBase).ToInt32()} else {$($Cast.ImageBase).ToInt64()}
			ImageSize = "0x$('{0:X}' -f $Cast.ImageSize)"
		}
		
		$Object = New-Object PSObject -Property $HashTable
		$SystemModuleArray += $Object
	
		$BuffOffset = $BuffOffset + $SYSTEM_MODULE_INFORMATION_Size
	}

	$SystemModuleArray

	# Free SystemModuleInformation array
	[System.Runtime.InteropServices.Marshal]::FreeHGlobal($BuffPtr)
}