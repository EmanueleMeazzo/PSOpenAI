function Request-AudioTranslation {
    [CmdletBinding(DefaultParameterSetName = 'Language')]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$File,

        [Parameter()]
        [Completions('whisper-1')]
        [string][LowerCaseTransformation()]$Model = 'whisper-1',

        [Parameter()]
        [string]$Prompt,

        [Parameter()]
        [Alias('response_format')]
        [ValidateSet('json', 'text', 'srt', 'verbose_json', 'vtt')]
        [string]$Format = 'text',

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Temperature,

        [Parameter()]
        [int]$TimeoutSec = 0,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$MaxRetryCount = 0,

        [Parameter(DontShow = $true)]
        [OpenAIApiType]$ApiType = [OpenAIApiType]::OpenAI,

        [Parameter()]
        [System.Uri]$ApiBase,

        [Parameter(DontShow = $true)]
        [string]$ApiVersion,

        [Parameter(DontShow = $true)]
        [string]$AuthType = 'openai',

        [Parameter()]
        [securestring][SecureStringTransformation()]$ApiKey,

        [Parameter()]
        [Alias('OrgId')]
        [string]$Organization
    )

    begin {
        # Initialize API Key
        [securestring]$SecureToken = Initialize-APIKey -ApiKey $ApiKey

        # Initialize API Base
        $ApiBase = Initialize-APIBase -ApiBase $ApiBase -ApiType $ApiType

        # Initialize Organization ID
        $Organization = Initialize-OrganizationID -OrgId $Organization

        # Get API endpoint
        if ($ApiType -eq [OpenAIApiType]::Azure) {
            $OpenAIParameter = Get-AzureOpenAIAPIEndpoint -EndpointName 'Audio.Translation' -Engine $Model -ApiBase $ApiBase -ApiVersion $ApiVersion
        }
        else {
            $OpenAIParameter = Get-OpenAIAPIEndpoint -EndpointName 'Audio.Translation' -ApiBase $ApiBase
        }
    }

    process {
        $FileInfo = (Get-Item -LiteralPath $File)
        # (Only PS6+)
        # If the filename contains non-ASCII characters,
        # the OpenAI API cannot recognize the file format correctly and returns an error.
        # As a workaround, copy the file to a temporary file and send it.
        # We need to find a better way.
        $IsTempFileCreated = $false
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            if ($FileInfo.Name -match '[^\u0000-\u007F]') {
                Write-Warning 'File name contains non-ASCII characters. It is strongly recommended that file name only contains ASCII characters.'
                $FileInfo = Copy-TempFile -SourceFile $FileInfo -ErrorAction Stop
                $IsTempFileCreated = $true
            }
        }

        #region Construct parameters for API request
        $PostBody = [System.Collections.Specialized.OrderedDictionary]::new()
        $PostBody.model = $Model
        $PostBody.file = $FileInfo
        if ($Format) {
            $PostBody.response_format = $Format
        }
        if ($PSBoundParameters.ContainsKey('Prompt')) {
            $PostBody.prompt = $Prompt
        }
        if ($PSBoundParameters.ContainsKey('Temperature')) {
            $PostBody.temperature = $Temperature
        }

        #region Send API Request
        try {
            $Response = Invoke-OpenAIAPIRequest `
                -Method $OpenAIParameter.Method `
                -Uri $OpenAIParameter.Uri `
                -ContentType $OpenAIParameter.ContentType `
                -TimeoutSec $TimeoutSec `
                -MaxRetryCount $MaxRetryCount `
                -ApiKey $SecureToken `
                -AuthType $AuthType `
                -Organization $Organization `
                -Body $PostBody
        }
        finally {
            if ($IsTempFileCreated -and (Test-Path $FileInfo -PathType Leaf)) {
                Remove-Item $FileInfo -Force -ErrorAction SilentlyContinue
            }
        }
        # error check
        if ($null -eq $Response) {
            return
        }
        #endregion

        #region Output
        Write-Output $Response
        #endregion
    }

    end {

    }
}