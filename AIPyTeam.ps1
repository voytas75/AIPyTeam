<#PSScriptInfo
.VERSION 0.0.2
.GUID 2473f758-a87e-4f85-9e61-0331c3e88767
.AUTHOR voytas75
.TAGS python,ai,psaoai,llm,project,team,gpt,ollama,azure,bing,RAG
.PROJECTURI https://github.com/voytas75/AIPyTeam
.ICONURI https://raw.githubusercontent.com/voytas75/AIPyTeam/master/images/AIPyTeam.png
.EXTERNALMODULEDEPENDENCIES PSAOAI, PowerHTML
.RELEASENOTES https://github.com/voytas75/AIPyTeam/blob/master/docs/ReleaseNotes.md
#>

#Requires -Modules PSAOAI
#Requires -Modules PowerHTML

<# 
.SYNOPSIS 
Emulates a team of AI-powered Agents with RAG collaborating on a Python project.

.DESCRIPTION 
This script simulates a team of AI-powered Agents with RAG, each with a unique role in executing a Python project. User input is processed by one AI specialist, who performs their task and passes the result to the next AI Agent. This process continues until all tasks are completed, leveraging AI to enhance efficiency and accuracy in project execution.

.PARAMETER userInput 
Defines the project outline as a string. The default is to monitor RAM usage and show a color block based on the load. This parameter can also accept input from the pipeline.

.PARAMETER Stream 
Controls whether the output should be streamed live. The default is `$true`.

.PARAMETER NOPM 
Disables the Project Manager functions when used.

.PARAMETER NODocumentator 
Disables the Documentator functions when used.

.PARAMETER NOLog
Disables the logging functions when used.

.PARAMETER NOTips
Disables tips.

.PARAMETER VerbosePrompt
Shows prompts.

.PARAMETER LogFolder
Specifies the folder where logs should be stored.

.PARAMETER DeploymentChat
Specifies the deployment chat environment variable for PSAOAI. The default is retrieved from the environment variable `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`.

.PARAMETER LoadProjectStatus
Loads the project status from a specified path. Part of the 'LoadStatus' parameter set.

.PARAMETER MaxTokens
Specifies the maximum number of tokens to generate in the response. The default is 20480.

.PARAMETER LLMProvider
Specifies the LLM provider to use (e.g., ollama, LMStudio, AzureOpenAI). The default is "AzureOpenAI".

.PARAMETER NORAG
Disables the RAG (Retrieve and Generate) functionality.

.INPUTS 
System.String. You can pipe a string to the 'userInput' parameter.

.OUTPUTS 
The output varies depending on how each specialist processes their part of the project. Typically, text-based results are expected, which may include status messages or visual representations like graphs or color blocks related to system metrics such as RAM load, depending on the user input specification provided via the 'userInput' parameter.

.EXAMPLE 
PS> "Monitor CPU usage and display dynamic graph." | AIPyTeam -Stream $false

This command runs the script without streaming output live (-Stream $false) and specifies custom user input about monitoring CPU usage instead of RAM, displaying it through dynamic graphing methods rather than static color blocks.

.NOTES 
Version: 0.0.2
Author: voytas75
Creation Date: 2024.07

.LINK
https://www.Pythongallery.com/packages/AIPyTeam
https://github.com/voytas75/AIPyTeam/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, HelpMessage = "Defines the Python project outline as a string.")]
    [string] $userInput,

    [Parameter(Mandatory = $false, HelpMessage = "Controls whether the output should be streamed live. Default is `$true.")]
    [bool] $Stream = $true,
    
    [Parameter(Mandatory = $false, HelpMessage = "Disables the RAG functionality.")]
    [switch] $NORAG,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Project Manager functions when used.")]
    [switch] $NOPM,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Documentator functions when used.")]
    [switch] $NODocumentator,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the logging functions when used.")]
    [switch] $NOLog,

    [Parameter(Mandatory = $false, HelpMessage = "Disables tips.")]
    [switch] $NOTips,

    [Parameter(Mandatory = $false, HelpMessage = "Shows prompts.")]
    [switch] $VerbosePrompt,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the folder where logs should be stored.")]
    [string] $LogFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the deployment chat environment variable for PSAOAI (AZURE OpenAI).")]
    [string] $DeploymentChat = [System.Environment]::GetEnvironmentVariable("PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT", "User"),

    [Parameter(Mandatory = $false, ParameterSetName = 'LoadStatus', HelpMessage = "Loads the project status from a specified path.")]
    [string] $LoadProjectStatus,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the maximum number of tokens to generate in the response. Default is 20480.")]
    [int] $MaxTokens = 20480,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the LLM provider to use (e.g., OpenAI, AzureOpenAI).")]
    [ValidateSet("AzureOpenAI", "ollama", "LMStudio", "OpenAI" )]
    [string]$LLMProvider = "AzureOpenAI"
)
$AIPyTeamVersion = "0.0.2"

#region ProjectTeamClass
<#
.SYNOPSIS
The ProjectTeam class represents a team member with a specific expertise.

.DESCRIPTION
Each team member has a name, role, prompt, and a function to process the input. They can also log their actions, store their responses, and pass the input to the next team member.

.METHODS
DisplayInfo: Displays the team member's information.
DisplayHeader: Displays the team member's name and role.
ProcessInput: Processes the input and returns the response.
SetNextExpert: Sets the next team member in the workflow.
GetNextExpert: Returns the next team member in the workflow.
AddLogEntry: Adds an entry to the log.
Notify: Sends a notification (currently just displays a message).
GetMemory: Returns the team member's memory (responses).
GetLastMemory: Returns the last response from the team member's memory.
SummarizeMemory: Summarizes the team member's memory.
ProcessBySpecificExpert: Processes the input by a specific team member.
#>
# Define the ProjectTeam class
class ProjectTeam {
    # Define class properties
    [string] $Name  # Name of the team member
    [string] $Role  # Role of the team member
    [string] $Prompt  # Prompt for the team member
    [ProjectTeam] $NextExpert  # Next expert in the workflow
    [System.Collections.ArrayList] $ResponseMemory  # Memory to store responses
    [double] $Temperature  # Temperature parameter for the response function
    [double] $TopP  # TopP parameter for the response function
    [string] $Status  # Status of the team member
    [System.Collections.ArrayList] $Log  # Log of the team member's actions
    [string] $LogFilePath  # Path to the log file
    [array] $FeedbackTeam  # Team of experts providing feedback
    [PSCustomObject] $GlobalState
    [string] $LLMProvider
    
    # Constructor for the ProjectTeam class
    ProjectTeam([string] $name, [string] $role, [string] $prompt, [double] $temperature, [double] $top_p, [PSCustomObject] $GlobalState) {
        $this.Name = $name
        $this.Role = $role
        $this.Prompt = $prompt
        $this.NextExpert = $null
        $this.ResponseMemory = @()
        $this.Temperature = $temperature
        $this.TopP = $top_p
        $this.Status = "Not Started"
        $this.Log = @()
        $this.GlobalState = $GlobalState
        $this.LogFilePath = "$($GlobalState.TeamDiscussionDataFolder)\$name.log"
        $this.FeedbackTeam = @()
        $this.LLMProvider = "AzureOpenAI"  # Default to AzureOpenAI, can be changed as needed
        
    }

    # Method to display the team member's information
    [PSCustomObject] DisplayInfo([int] $display = 1) {
        # Create an ordered dictionary to store the information
        $info = [ordered]@{
            "Name"          = $this.Name
            "Role"          = $this.Role
            "System prompt" = $this.Prompt
            "Temperature"   = $this.Temperature
            "TopP"          = $this.TopP
            "Responses"     = $this.ResponseMemory | ForEach-Object { "[$($_.Timestamp)] $($_.Response)" }
            "Log"           = $this.Log -join ', '
            "Log File Path" = $this.LogFilePath
            "Feedback Team" = $this.FeedbackTeam
            "Next Expert"   = $this.NextExpert
            "Status"        = $this.Status
        }
        
        # Create a custom object from the dictionary
        $infoObject = New-Object -TypeName PSCustomObject -Property $info

        # If display is set to 1, print the information to the console
        if ($display -eq 1) {
            Show-Header -HeaderText "Info: $($this.Name) ($($this.Role))"
            Write-Host "Name: $($infoObject.Name)"
            Write-Host "Role: $($infoObject.Role)"
            Write-Host "System prompt: $($infoObject.'System prompt')"
            Write-Host "Temperature: $($infoObject.Temperature)"
            Write-Host "TopP: $($infoObject.TopP)"
            Write-Host "Responses: $($infoObject.Responses)"
            Write-Host "Log: $($infoObject.Log)"
            Write-Host "Log File Path: $($infoObject.'Log File Path')"
            Write-Host "Feedback Team: $($infoObject.'Feedback Team')"
            Write-Host "Next Expert: $($infoObject.'Next Expert')"
            Write-Host "Status: $($infoObject.Status)"
        }

        # Return the custom object
        return $infoObject
    }
    
    # Method to process the input and generate a response
    [string] ProcessInput([string] $userinput) {
        Show-Header -HeaderText "Current Expert: $($this.Name) ($($this.Role))"
        # Log the input
        $this.AddLogEntry("Processing input:`n$userinput")
        # Update status
        $this.Status = "In Progress"
        #write-Host $script:Stream
        $response = ""
        try {
            Write-verbose $script:MaxTokens

            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Write-Host "Attempting to obtain a response. This process will be repeated if necessary." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                #write-host ($response | convertto-json -Depth 100)
                Write-Host $response -ForegroundColor White
            }
            # Log the response
            $this.AddLogEntry("Generated response:`n$response")
            # Store the response in memory with timestamp
            $this.ResponseMemory.Add([PSCustomObject]@{
                    Response  = $response
                    Timestamp = Get-Date
                })
            $feedbackSummary = ""
            if ($this.FeedbackTeam.count -gt 0) {
                # Request feedback for the response
                $feedbackSummary = $this.RequestFeedback($response)
                # Log the feedback summary
                $this.AddLogEntry("Feedback summary:`n$feedbackSummary")
            }
            # Integrate feedback into response
            $responseWithFeedback = "$response`n`n$feedbackSummary"

            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }

        # Pass to the next expert if available
        if ($null -ne $this.NextExpert) {
            return $this.NextExpert.ProcessInput($responseWithFeedback)
        }
        else {
            return $responseWithFeedback
        }
    }

    [string] ProcessInput([string] $userinput, [string] $systemprompt) {
        Show-Header -HeaderText "Processing Input by $($this.Name) ($($this.Role))"
        
        # Log the input
        $this.AddLogEntry("Processing input:`n$userinput")
        
        # Update status
        $this.Status = "In Progress"
        $response = ""
        try {
            # Ensure ResponseMemory is initialized
            if ($null -eq $this.ResponseMemory) {
                $this.ResponseMemory = @()
                $this.AddLogEntry("Initialized ResponseMemory")
            }
            
            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $systemprompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Write-Host "Attempting to obtain a response. This process will be repeated if necessary." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                Write-Host $response -ForegroundColor White
            }
            
            # Log the response
            $this.AddLogEntry("Generated response:`n$response")
            
            # Store the response in memory with timestamp
            $this.ResponseMemory.Add([PSCustomObject]@{
                    Response  = $response
                    Timestamp = Get-Date
                })
            
            $feedbackSummary = ""
            if ($this.FeedbackTeam.count -gt 0) {
                # Request feedback for the response
                $feedbackSummary = $this.RequestFeedback($response)
                # Log the feedback summary
                $this.AddLogEntry("Feedback summary:`n$feedbackSummary")
            }
            
            # Integrate feedback into response
            $responseWithFeedback = "$response`n`n$feedbackSummary"
            
            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }

        # Pass to the next expert if available
        if ($null -ne $this.NextExpert) {
            return $this.NextExpert.ProcessInput($responseWithFeedback)
        }
        else {
            return $responseWithFeedback
        }
    }
    
    [string] Feedback([ProjectTeam] $AssessedExpert, [string] $Expertinput) {
        Show-Header -HeaderText "Feedback by $($this.Name) ($($this.Role)) for $($AssessedExpert.name)"
        
        # Log the input
        $this.AddLogEntry("Processing input:`n$Expertinput")
        
        # Update status
        $this.Status = "In Progress"
        $response = ""
        try {
            # Ensure ResponseMemory is initialized
            if ($null -eq $this.ResponseMemory) {
                $this.ResponseMemory = @()
                $this.AddLogEntry("Initialized ResponseMemory")
            }
            
            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $Expertinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Write-Host "Attempting to obtain a response. This process will be repeated if necessary." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                write-Host $response -ForegroundColor White
            }
        
            # Log the response
            $this.AddLogEntry("Generated feedback response:`n$response")
            
            # Verify the response before adding to memory
            $this.AddLogEntry("Response before adding to memory: $response")
            
            # Store the response in memory with timestamp
            $responseObject = [PSCustomObject]@{
                Response  = $response
                Timestamp = Get-Date
            }
            $this.ResponseMemory.Add($responseObject)
            
            # Log after storing
            $this.AddLogEntry("Stored response at $(Get-Date): $response")
            
            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }
        return $response
    }

    [void] SetNextExpert([ProjectTeam] $nextExpert) {
        $this.NextExpert = $nextExpert
    }

    [ProjectTeam] GetNextExpert() {
        return $this.NextExpert
    }
    
    [void] AddLogEntry([string] $entry) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp]:`n$(Show-Header -HeaderText $entry -output)"
        $this.Log.Add($logEntry)
        if (-not [string]::IsNullOrEmpty($this.LogFilePath)) {
            # Write the log entry to the file
            Add-Content -Path $this.LogFilePath -Value $logEntry
        }
    }

    [void] Notify([string] $message) {
        # Placeholder for a method to send notifications
        Write-Host "Notification: $message"
    }

    [System.Collections.ArrayList] GetMemory() {
        return $this.ResponseMemory
    }

    [PSCustomObject] GetLastMemory() {
        if ($this.ResponseMemory.Count -gt 0) {
            return $this.ResponseMemory[-1]
        }
        else {
            return $null
        }
    }

    [string] SummarizeMemory() {
        $summaryPrompt = "Summarize the following memory entries:"
        $memoryEntries = $this.ResponseMemory | ForEach-Object { "[$($_.Timestamp)] $($_.Response)" }
        $fullPrompt = "$summaryPrompt`n`n$($memoryEntries -join "`n")"
        $summary = ""
        try {
            # Use the user-provided function to get the summary
            $loopCount = 0
            $maxLoops = 5
            do {
                $summary = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $fullPrompt -UserPrompt "" -Temperature 0.7 -TopP 0.7 -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($summary)) {
                    break
                }
                Write-Host "Attempting to obtain a response. This process will be repeated if necessary." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            # Log the summary
            $this.AddLogEntry("Generated summary:`n$summary")
            return $summary
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            throw $_
        }
    }

    [string] ProcessBySpecificExpert([ProjectTeam] $expert, [string] $userinput) {
        return $expert.ProcessInput($userinput)
    }

    [System.Collections.ArrayList] RequestFeedback([string] $response) {
        $feedbacks = @()

        foreach ($FeedbackMember in $this.FeedbackTeam) {
            Show-Header -HeaderText "Feedback from $($FeedbackMember.Role) to $($this.Role)"
   
            # Send feedback request and collect feedback
            $feedback = SendFeedbackRequest -TeamMember $FeedbackMember.Role -Response $response -Prompt $FeedbackMember.Prompt -Temperature $this.Temperature -TopP $this.TopP
        
            if ($null -ne $feedback) {
                $FeedbackMember.ResponseMemory.Add([PSCustomObject]@{
                        Response  = $feedback
                        Timestamp = Get-Date
                    })

                $feedbacks += $feedback
            }
        }

        if ($feedbacks.Count -eq 0) {
            throw "No feedback received from team members."
        }

        return $feedbacks
    }

    [void] AddFeedbackTeamMember([ProjectTeam] $member) {
        $this.FeedbackTeam += $member
    }

    [void] RemoveFeedbackTeamMember([ProjectTeam] $member) {
        $this.FeedbackTeam = $this.FeedbackTeam | Where-Object { $_ -ne $member }
    }
}
#endregion ProjectTeamClass

#region Functions
function Test-ModuleMinVersion {
    param (
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,
        [ValidateNotNullOrEmpty()]
        [version]$MinimumVersion
    )

    # Function to check if a module with a minimum version is available
    $module = Get-Module -ListAvailable -Name $ModuleName | 
    Where-Object { $_.Version -ge $MinimumVersion } | 
    Select-Object -First 1

    if ($module) {
        return $true
    }
    else {
        Write-Error "Module $ModuleName with minimum version $MinimumVersion not found."
        return $false
    }
}

function SendFeedbackRequest {
    param (
        [string] $TeamMember, # The team member to send the feedback request to
        [string] $Response, # The response to be reviewed
        [string] $Prompt, # The prompt for the feedback request
        [double] $Temperature, # The temperature parameter for the LLM model
        [double] $TopP, # The TopP parameter for the LLM model
        [PSCustomObject]$GlobalState
    )
    try {
        # Main logic here
        # Define the feedback request prompt
        $Systemprompt = $prompt 
        $NewResponse = @"
Review the following response and provide your suggestions for improvement as feedback to $($this.name). Generate a list of verification questions that could help to self-analyze. 
I will tip you `$100 when your suggestions are consistent with the project description and objectives. 

$($GlobalState.userInput.trim())

````````text
$($Response.trim())
````````

Think step by step. Make sure your answer is unbiased.
"@

        # Send the feedback request to the LLM model
        $feedback = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $SystemPrompt -UserPrompt $NewResponse -Temperature $Temperature -TopP $TopP -MaxTokens $script:MaxTokens -Stream $GlobalState.Stream -LogFolder $GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel

        # Return the feedback
        return $feedback
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}

function Get-LastMemoryFromFeedbackTeamMembers {
    param (
        [array] $FeedbackTeam
    )
    # Initialize an empty array to store the last memories
    $lastMemories = @()
    try {
        # Iterate over each team member in the feedback team
        foreach ($FeedbackTeamMember in $FeedbackTeam) {
            # Get the last memory response from the team member
            $lastMemory = $FeedbackTeamMember.GetLastMemory().Response
            # Add the last memory to the array
            $lastMemories += $lastMemory
        }
        # Join the last memories with a newline and return the result
        return ($lastMemories -join "`n")
    }
    catch {
        # Get the name of the current function
        $functionName = $MyInvocation.MyCommand.Name
        # Update error handling with the error record and context
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}

function Add-ToGlobalResponses {
    param (
        [Parameter()]
        [PSCustomObject] 
        $GlobalState, # The global state object to update
    
        $response  # The response to add to the global responses
    )
    
    # Append the response to the GlobalResponse property of the GlobalState object
    $GlobalState.GlobalResponse += $response
}

function Add-ToGlobalpydevResponses {
    param (
        [Parameter()]
        [PSCustomObject] 
        $GlobalState, # The global state object to update
    
        $response  # The response to add to the global pydev responses
    )
    
    # Append the response to the GlobalpydevResponse property of the GlobalState object
    $GlobalState.GlobalpydevResponse += $response
}

function New-FolderAtPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path, # The path where the new folder will be created
        [Parameter(Mandatory = $false)]
        [string]$FolderName  # The name of the new folder to be created
    )

    try {
        # Output verbose messages for debugging
        Write-Verbose "New-FolderAtPath: $Path"
        Write-Verbose "New-FolderAtPath: $FolderName"

        # Combine the Folder path with the folder name to get the full path
        $CompleteFolderPath = Join-Path -Path $Path -ChildPath $FolderName.trim()

        # Output the complete folder path and its type for debugging
        Write-Verbose "New-FolderAtPath: $CompleteFolderPath"
        Write-Verbose $CompleteFolderPath.gettype()

        # Check if the folder exists, if not, create it
        if (-not (Test-Path -Path $CompleteFolderPath)) {
            New-Item -ItemType Directory -Path $CompleteFolderPath -Force | Out-Null
        }

        # Return the full path of the folder
        return $CompleteFolderPath
    }
    catch [System.Exception] {
        # Capture the function name for error context
        $functionName = $MyInvocation.MyCommand.Name
        # Handle the error and log it
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
        return $null    
    }
}

function Get-LatestVersion {
    param (
        [string]$scriptName
    )
  
    try {
        # Find the script on Python Gallery
        $scriptInfo = Find-Script -Name $scriptName -ErrorAction Stop
  
        # Return the latest version
        return $scriptInfo.Version
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
        return $null
    }
}

function Get-CheckForScriptUpdate {
    param (
        $currentScriptVersion,
        [string]$scriptName
    )
    try {
        # Retrieve the latest version of the script
        $latestScriptVersion = Get-LatestVersion -scriptName $scriptName
        if ($latestScriptVersion) {
            # Compare the current version with the latest version
            if (([version]$currentScriptVersion) -lt [version]$latestScriptVersion) {
                Write-Host " A new version ($latestScriptVersion) of $scriptName is available. You are currently using version $currentScriptVersion. " -BackgroundColor DarkYellow -ForegroundColor Blue
                write-Host "`n`n"
            } 
        }
        else {
            Write-Warning "Failed to check for the latest version of the script."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }

}

function Show-Banner {
    Write-Host @'
 

                                                                                                
          db         88  88888888ba           Retrieval-Augmented Generation                                  
         d88b        88  88      "8b               88                                              
        d8'`8b       88  88      ,8P               88                                              
       d8'  `8b      88  88aaaaaa8P'  8b       d8  88   ,adPPYba,  ,adPPYYba,  88,dPYba,,adPYba,   
      d8YaaaaY8b     88  88""""""'    `8b     d8'  88  a8P_____88  ""     `Y8  88P'   "88"    "8a  
     d8""""""""8b    88  88            `8b   d8'   88  8PP"""""""  ,adPPPPP88  88      88      88  
    d8'        `8b   88  88             `8b,d8'    88  "8b,   ,aa  88,    ,88  88      88      88  
   d8'          `8b  88  88               Y88'     88   `"Ybbd8"'  `"8bbdP"Y8  88      88      88  
                                          d8'                                                      
                                         d8'                                                                                                                                         
   AI Python Team with RAG                                                owered by PSAOAI Module
                                                                                    Ollama
                                                                                    LM Studio
                                                                                    AZURE Bing Web
   https://github.com/voytas75/AIPyTeam
  
'@
    Write-Host @'
        This Python script simulates a team of AI Agents working together on a Python project. Each Agent has a unique role and 
        contributes to the project in a sequential manner. The script processes user input, performs various tasks, and generates outputs 
        such as code, documentation, and analysis reports. The application utilizes Retrieval-Augmented Generation (RAG) to enhance its 
        power and leverage Azure OpenAI, Ollama, or LM Studio to generate the output.
         
'@ -ForegroundColor Blue
  
    Write-Host @'
        "You never know what you're gonna get with an AI, just like a box of chocolates. You might get a whiz-bang algorithm that 
        writes you a symphony in five minutes flat, or you might get a dud that can't tell a cat from a couch. But hey, that's 
        the beauty of it all, you keep feedin' it data and see what kind of miraculous contraption it spits out next."
                      
                                                                     ~ Who said that? You never know with these AIs these days... 
                                                                      ...maybe it was Skynet or maybe it was just your toaster :)
  

'@ -ForegroundColor DarkYellow
}

function Export-AndWritePythonCodeBlocks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,
        [Parameter(Mandatory = $false)]
        [string]$OutputFilePath,
        [string]$StartDelimiter,
        [string]$EndDelimiter
    )
    # Define the regular expression pattern to match Python code blocks
    
    $pattern = '(?si)' + [regex]::Escape($StartDelimiter) + '(.*?)' + [regex]::Escape($EndDelimiter)
    $codeBlock_ = ""
    try {
        # Process the entire input string at once
        if ($InputString -match $pattern) {
            $matches_ = [regex]::Matches($InputString, $pattern)
            foreach ($match in $matches_) {
                $codeBlock = $match.Groups[1].Value.Trim()
                $codeBlock_ += "# exported $(get-date)`n $codeBlock`n`n"
            }
            if ($OutputFilePath) {
                $codeBlock_ | Out-File -FilePath $OutputFilePath -Append -Encoding UTF8
                if (Test-path $OutputFilePath) {
                    Write-Information "++ Code block exported and written to file: $OutputFilePath" -InformationAction Continue
                    return $OutputFilePath
                }
                else {
                    throw "!! Error saving file $OutputFilePath"
                    return $false
                }
            }
            else {
                Write-Verbose "++ Code block exported"
                return $codeBlock_
            }
        }
        else {
            Write-Information "-- No code block found in the input string." -InformationAction Continue
            return $false
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
    return $false
}

function Show-Header {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HeaderText,
        [switch]$output
    )
    if (-not $output) {
        Write-Host "---------------------------------------------------------------------------------"
        Write-Host $HeaderText
        Write-Host "---------------------------------------------------------------------------------"
    }
    else {
        "---------------------------------------------------------------------------------"
        "`n$HeaderText"
        "`n---------------------------------------------------------------------------------`n"
    }
}

function Get-SourceCodeAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [string]$CodeBlock
    )

    function Get-AnalyzeLine {
        param (
            [string[]]$Lines
        )
        $totalLines = $Lines.Count
        $comments = ($Lines | Select-String "#" | Measure-Object).Count
        $blanks = ($Lines | Where-Object { $_ -match "^\s*$" } | Measure-Object).Count
        $codeLines = $totalLines - ($comments + $blanks)
        return [PSCustomObject]@{
            TotalLines = $totalLines
            CodeLines  = $codeLines
            Comments   = $comments
            Blanks     = $blanks
        }
    }
    try {
        if ($FilePath) {
            if (Test-Path $FilePath -PathType Leaf) {
                $lines = Get-Content $FilePath
                $analysis = Get-AnalyzeLine -Lines $lines
                Write-Output "$FilePath : $($analysis.CodeLines) lines of code, $($analysis.Comments) comments, $($analysis.Blanks) blank lines"
            }
            else {
                Write-Error "File '$FilePath' does not exist."
            }
        }
        elseif ($CodeBlock) {
            $lines = $CodeBlock -split "`r?`n"
            $analysis = Get-AnalyzeLine -Lines $lines
            Write-Output "Code Block : $($analysis.CodeLines) lines of code, $($analysis.Comments) comments, $($analysis.Blanks) blank lines"
        }
        else {
            Write-Error "No FilePath or CodeBlock provided for analysis."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Get-FeedbackPrompt {
    param (
        [string]$description,
        [string]$code
    )

    $FeedbackUserprompt = @"

Based on the following user requirements and existing Python code, prepare comprehensive guidelines for a Python Developer to improve or extend the script:

User Requirements:
``````text
$($description.trim())
``````

Current Python code:
``````python
$($code.trim())
``````

Analyze these requirements and the existing code, then create detailed guidelines that will enable the Python Developer to effectively implement improvements or extensions to the script. Consider the following in your analysis:

1. How well the current code meets the user requirements
2. Areas of the code that need improvement or refactoring
3. New functionalities that could to be added
4. Any potential issues or limitations in the current implementation
5. Opportunities to enhance performance, readability, or maintainability

Your guidelines should provide a clear roadmap for enhancing the existing script to fully meet the user's needs while adhering to Python best practices.
"@
    return $FeedbackUserprompt
}

function Set-FeedbackAndGenerateResponse {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Reviewer,
        
        [Parameter(Mandatory = $true)]
        [object]$Recipient,

        [Parameter(Mandatory = $false)]
        [string]$tipAmount,
        
        [PSCustomObject] $GlobalState
    )
    try {
        # Generate the feedback prompt using the provided description and code
        $feedbackPrompt = Get-FeedbackPrompt -description $GlobalState.UserInput -code $GlobalState.LastpydevCode

        # If RAG (Retrieve and Generate) is enabled, append RAG data to the feedback prompt
        if ($GlobalState.RAG) {
            $RAGresponse = Invoke-RAG -userInput $feedbackPrompt -prompt "Analyze the provided text and present key information, thoughts, and questions." -RAGAgent $Reviewer
            if ($RAGresponse) {
                $feedbackPrompt += "`n`n###RAG data###`n````````text`n$RAGresponse`n````````"
            }
        }

        # If a tip amount is specified, append a note about the tip to the feedback prompt
        if ($tipAmount) {
            $feedbackPrompt += "`n`nNote: There is `$$tipAmount tip for this task."
        }

        # Get feedback from the reviewer
        $feedback = $Reviewer.Feedback($Recipient, $feedbackPrompt)

        # Add the feedback to global responses
        Add-ToGlobalResponses -GlobalState $GlobalState -response $feedback

        $responsePrompt = @"

Your task is to write next version of Python code based on the following requirements and guidelines. Please follow these steps:

1. Analyze the requirements in the $($Reviewer.Name)'s guidelines provided below.
2. Plan the structure of your Python script.
3. Write the Python code that meets the requirements.
4. Add appropriate error handling and logging.
5. Include comments explaining complex parts of the code.
6. Add version notes to document the code changes.
7. Perform a self-review of your code for efficiency and adherence to best practices.

Please format your response as follows:
1. Script Purpose: (Brief description of what the script does)
2. Input Parameters: (List of input parameters, if any)
3. Output: (Description of what the script returns or produces)
4. Python code: (The actual code, properly formatted and commented)
5. Usage Example: (A brief example of how to use the script)
6. Self-Review Notes: (Any observations or potential improvements you've identified)

$($Reviewer.Name) Guidelines: 
````````text
$($Reviewer.GetLastMemory().Response)
````````

Current version of the Python code:
````````python
$($GlobalState.LastpydevCode)
````````
"@
        # If a tip amount is specified, include it in the response prompt
        if ($tipAmount) {
            $responsePrompt += "`n`nI will tip you `$$tipAmount for the correct code."
        }

        # Get the response from the recipient
        $response = $Recipient.ProcessInput($responsePrompt)

        return $response
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Update-GlobalStateWithResponse {
    param (
        [string] $response,
        [PSCustomObject] $GlobalState
    )

    try {
        # Update the global response with the new response
        $GlobalState.GlobalpydevResponse += $response

        # Add the new response to global responses
        Add-ToGlobalResponses -GlobalState $GlobalState -response $response

        # Save the new version of the code to a file
        $_savedFile = Export-AndWritePythonCodeBlocks -InputString $response -OutputFilePath $(join-path $GlobalState.teamDiscussionDataFolder "TheCode_v$($GlobalState.fileVersion).py") -StartDelimiter '```python' -EndDelimiter '```'

        if ((Test-Path -Path $_savedFile) -and $_savedFile) {
            # Update the last code and file version
            $GlobalState.lastpydevCode = Get-Content -Path $_savedFile -Raw
            $GlobalState.fileVersion += 1

            # Output the saved file path for verbose logging
            Write-Verbose $_savedFile
        }
        else {
            Write-Warning "!! The code does not exist. Unable to update the last code and file version."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

# Refactor Invoke-ProcessFeedbackAndResponse to use the new functions
function Invoke-ProcessFeedbackAndResponse {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Reviewer,
        
        [Parameter(Mandatory = $true)]
        [object]$Recipient,

        [Parameter(Mandatory = $false)]
        [string]$tipAmount,

        [PSCustomObject] $GlobalState
    )
    try {
        # Measure the time taken to process feedback and generate a response
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Process feedback and generate a response
        if ($null -eq $tipAmount) {
            $response = Set-FeedbackAndGenerateResponse -Reviewer $Reviewer -Recipient $Recipient -GlobalState $GlobalState
        }
        else {
            $response = Set-FeedbackAndGenerateResponse -Reviewer $Reviewer -Recipient $Recipient -tipAmount $tipAmount -GlobalState $GlobalState
        }

        if ($response) {
            # Update the global state with the new response
            Update-GlobalStateWithResponse -response $response -GlobalState $GlobalState
        }

        $stopwatch.Stop()
        Write-Information "++ Time taken to process feedback and generate response: $($stopwatch.Elapsed.TotalSeconds) seconds" -InformationAction Continue
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

# Refactor Save-AndUpdateCode to use the new function
function Save-AndUpdateCode {
    param (
        [string] $response,
        [PSCustomObject] $GlobalState
    )
    try {
        # Update the global state with the new response
        Update-GlobalStateWithResponse -response $response -GlobalState $GlobalState
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Save-ProjectState {
    param (
        [string]$FilePath, # Path to save the project state
        [PSCustomObject] $GlobalState  # Global state object containing project details
    )
    try {
        # Export the project state to a file in XML format
        $GlobalState | Export-Clixml -Path $FilePath
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the save process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Get-ProjectState {
    param (
        [string]$FilePath
    )
    try {
        # Check if the specified file path exists
        if (Test-Path -Path $FilePath) {
            # Import the project state from the XML file
            $projectState = Import-Clixml -Path $FilePath
            if ($null -eq $projectState.LLMProvider) {
                $projectState.LLMProvider = "AzureOpenAI"
            }
            # Return the updated GlobalState object
            return $projectState
        }
        else {
            # Inform the user that the project state file was not found
            Write-Host "-- Project state file not found."
        }
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path (split-path -Path $FilePath -Parent) "ERROR.txt")  
    }
}

function Update-ErrorHandling {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$ErrorContext,

        [string]$LogFilePath
    )

    # Provide suggestions based on the error type
    $suggestions = switch -Regex ($ErrorRecord.Exception.Message) {
        "PSAOAI" {
            "Check the PSAOAI module installation and the deployment environment variable. Ensure the API key and endpoint are correctly configured."
        }
        "UnauthorizedAccessException" {
            "Check the file permissions and ensure you have the necessary access rights to the file or directory."
        }
        "IOException" {
            "Ensure the file path is correct and the file is not being used by another process."
        }
        "(403)" {
            "I recommend checking your API key, permissions, and any other relevant settings. You might also want to consult the Azure documentation or seek assistance from the Azure support team."
        }
        '(429)' {
            "Too many requests have been made to the server in a short period. Implement rate limiting or exponential backoff in your requests. Consider reviewing the API's rate limit guidelines and ensure your application adheres to them."
        }
        default {
            "Refer to the error message and stack trace for more details. Consult the official documentation or seek help from the community."
        }
    }

    # Capture detailed error information
    $errorDetails = [ordered]@{
        Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ErrorMessage   = $ErrorRecord.Exception.Message
        ExceptionType  = $ErrorRecord.Exception.GetType().FullName
        ErrorContext   = $ErrorContext
        Suggestions    = $Suggestions
        ScriptFullName = $MyInvocation.ScriptName
        LineNumber     = $MyInvocation.ScriptLineNumber
        StackTrace     = $ErrorRecord.ScriptStackTrace
        UserName       = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        MachineName    = $env:COMPUTERNAME
        PythonVersion  = $PSVersionTable.PSVersion.ToString()
    } | ConvertTo-Json

    # Display the error details and suggestions
    Write-Host "-- Context: $ErrorContext" -ForegroundColor Yellow
    Write-Host "-- Suggestions: $suggestions" -ForegroundColor Yellow
    Write-Host "-- Error: $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow

    # Log the error details if LogFilePath is provided
    if ($LogFilePath) {
        $errorDetails | Out-File -FilePath $LogFilePath -Append -Force
        if (Test-Path -Path $LogFilePath) {
            Write-Host "-- Error details have been saved to the file: $LogFilePath" -ForegroundColor Yellow
        }
        else {
            Write-Host "-- The specified log file path does not exist: $LogFilePath" -ForegroundColor Red
        }
    }        
}

function Invoke-LLMChatCompletion {
    param (
        [string]$Provider,
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [int]$MaxTokens,
        [bool]$Stream,
        [string]$LogFolder,
        [string]$DeploymentChat,
        [string]$ollamaModel
    )

    try {
        # Check if verbose prompts are enabled and display them
        if ($GlobalState.VerbosePrompt) {
            Write-Host $SystemPrompt -ForegroundColor DarkMagenta
            Write-Host $UserPrompt -ForegroundColor DarkMagenta
        }

        # Switch between different LLM providers based on the provider parameter
        switch ($Provider) {
            "ollama" {
                # Invoke the Ollama model completion function
                $response = Invoke-AIPyTeamOllamaCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -ollamaModel $ollamamodel -Stream $Stream
                return $response
            }
            "LMStudio" {
                # Handle streaming for LMStudio provider
                # Invoke the LMStudio chat completion function
                $response = Invoke-AIPyTeamLMStudioChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -Stream $Stream -ApiKey $script:lmstudioApiKey -endpoint $script:lmstudioApiBase -Model $script:LMStudioModel
                return $response
            }
            "OpenAI" {
                # Throw an exception for unsupported LLM provider
                throw "-- Unsupported LLM provider: $Provider. This provider is not implemented yet."
            }
            "AzureOpenAI" {
                # Invoke the Azure OpenAI chat completion function
                $response = Invoke-AIPyTeamAzureOpenAIChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -Stream $Stream -LogFolder $LogFolder -Deployment $DeploymentChat
                return $response
            }
            default {
                # Throw an exception for unknown LLM provider
                throw "!! Unknown LLM provider: $Provider"
            }
        }
    }
    catch {
        # Log the error and rethrow it with additional context
        $functionName = $MyInvocation.MyCommand.Name
        $errorMessage = "Error in ${functionName}: $_"
        Write-Error $errorMessage
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $LogFolder "ERROR.txt")
        throw $_
    }
}

function Invoke-AIPSTeamAzureOpenAIChatCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [int]$MaxTokens,
        [bool]$Stream,
        [string]$LogFolder,
        [string]$Deployment
    )

    try {
        # Log the input parameters for debugging purposes
        Write-Verbose "SystemPrompt: $SystemPrompt"
        Write-Verbose "UserPrompt: $UserPrompt"
        Write-Verbose "Temperature: $Temperature"
        Write-Verbose "TopP: $TopP"
        Write-Verbose "MaxTokens: $MaxTokens"
        Write-Verbose "Stream: $Stream"
        Write-Verbose "LogFolder: $LogFolder"
        Write-Verbose "Deployment: $Deployment"

        # Notify the start of the Azure OpenAI process
        Write-Host "++ Initiating Azure OpenAI process for deployment: $Deployment..."
        
        if ($Stream) {
            Write-Host "++ Streaming mode enabled." -ForegroundColor Blue
        }

        # Invoke the Azure OpenAI chat completion function
        $response = PSAOAI\Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -LogFolder $LogFolder -Deployment $Deployment -User "AIPSTeam" -Stream $Stream -simpleresponse -OneTimeUserPrompt

        if ($Stream) {
            Write-Host "++ Streaming completed." -ForegroundColor Blue
        }
        
        Write-Host "++ Azure OpenAI process initiated successfully for deployment: $Deployment."

        # Check if the response is null or empty
        if ([string]::IsNullOrEmpty($response)) {
            $errorMessage = "The response from Azure OpenAI API is null or empty."
            Write-Error $errorMessage
            throw $errorMessage
        }

        # Log the successful response
        Write-Verbose "Azure OpenAI API response received successfully."

        return $response
    }
    catch {
        # Log the error and rethrow it with additional context
        $functionName = $MyInvocation.MyCommand.Name
        $errorMessage = "Error in ${functionName}: $_"
        Write-Error $errorMessage
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $LogFolder "ERROR.txt")
        throw $_
    }
}

function Invoke-AIPSTeamOllamaCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [string]$ollamaModel,
        [bool]$Stream
    )

    # Define options for the Ollama API call
    $ollamaOptions = [pscustomobject]@{
        temperature = $Temperature
        top_p       = $TopP
    }

    # Construct the JSON payload for the Ollama API request
    $ollamaJson = [pscustomobject]@{
        model   = $ollamaModel
        prompt  = $SystemPrompt + "`n" + $UserPrompt
        options = $ollamaOptions
        stream  = $Stream
    } | ConvertTo-Json

    # Ensure the Ollama endpoint ends with a '/'
    if (-not $script:ollamaEndpoint.EndsWith('/')) {
        $script:ollamaEndpoint += '/'
    }
    Write-Verbose "Constructed JSON payload for Ollama API: $ollamaJson"

    # Define the URL for the Ollama API endpoint
    $url = "$($script:ollamaEndpoint)api/generate"
    Write-Verbose "Ollama API endpoint URL: $url"

    # Notify the user that the Ollama model is processing
    Write-Host "++ Ollama model ($ollamaModel) is processing your request..."

    # Check if streaming is enabled and handle accordingly
    if ($Stream) {
        # Initialize HttpClientHandler with specific configurations for streaming
        $httpClientHandler = [System.Net.Http.HttpClientHandler]::new()
        $httpClientHandler.AllowAutoRedirect = $false
        $httpClientHandler.UseCookies = $false
        $httpClientHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        
        # Create HttpClient using the handler
        $httpClient = [System.Net.Http.HttpClient]::new($httpClientHandler)
        
        # Prepare the content of the HTTP request
        $content = [System.Net.Http.StringContent]::new($ollamaJson, [System.Text.Encoding]::UTF8, "application/json")
     
        # Create and configure the HTTP request message
        $request = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post, $url)
        $request.Content = $content
     
        # Send the HTTP request and read the headers of the response
        $response = $httpClient.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
    
        # Stream the response using StreamReader
        $reader = [System.IO.StreamReader]::new($response.Content.ReadAsStreamAsync().Result)
    
        # Initialize variable to accumulate the response text
        $completeText = ""
        Write-Host "++ Streaming" -ForegroundColor Blue

        # Read and process each line of the response stream
        while ($null -ne ($line = $reader.ReadLine()) -or (-not $reader.EndOfStream)) {
            try {
                $line = ($line | ConvertFrom-Json)
            }
            catch {
                Write-Error "Error parsing JSON: $_"
            }            
            if (-not $line.done) {
                $delta = $line.response
                $completeText += $delta
                Write-Host $delta -NoNewline -ForegroundColor White
            }
        }
        Write-Host ""
        $completeText += "`n"
    
        # Output the complete streamed text
        if ($VerbosePreference -eq "Continue") {
            Write-Host "++ Streaming completed. Full text: $completeText" -ForegroundColor DarkBlue
        }
        else {
            Write-Host "++ Streaming completed." -ForegroundColor Blue
        }

        # Clean up resources
        $reader.Close()
        $httpClient.Dispose()

        $response = $completeText
    }
    else {
        # Send a non-streaming HTTP POST request and parse the response
        $response = Invoke-WebRequest -Method POST -Body $ollamaJson -Uri $url -UseBasicParsing
        $response = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty response
    }

    # Log the interaction details
    $logEntry = @{
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemPrompt = $SystemPrompt
        UserPrompt   = $UserPrompt
        Response     = $response
    } | ConvertTo-Json

    [void]($this.Log.Add($logEntry))
    $this.AddLogEntry("SystemPrompt:`n$SystemPrompt")
    $this.AddLogEntry("UserPrompt:`n$UserPrompt")
    $this.AddLogEntry("Response:`n$response")
    
    Write-Host "++ Ollama model ($ollamaModel) has successfully processed your request."

    return $response.Trim('"')
}

function Invoke-AIPSTeamLMStudioChatCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [string]$Model,
        [string]$ApiKey,
        [string]$endpoint,
        [int]$timeoutSec = 240,
        [bool]$Stream
    )
    $response = ""

    # Define headers for the HTTP request
    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $ApiKey"
    }

    # Construct the JSON body for the request
    $bodyJSON = [ordered]@{
        'model'       = $Model
        'messages'    = @(
            [ordered]@{
                'role'    = 'system'
                'content' = $SystemPrompt
            },
            [ordered]@{
                'role'    = 'user'
                'content' = $UserPrompt
            }
        )
        'temperature' = $Temperature
        'top_p'       = $TopP
        'stream'      = $Stream
        'max_tokens'  = $GlobalState.maxtokens
    } | ConvertTo-Json

    Write-Verbose "Request Body JSON: $bodyJSON"

    # Inform the user that the request is being processed
    $InfoText = "++ LM Studio" + $(if ($Model) { " model ($Model)" } else { "" }) + " is processing your request..."
    Write-Host $InfoText

    $url = "$($endpoint)chat/completions"

    # Check if streaming is enabled and handle accordingly
    if ($Stream) {
        # Create an instance of HttpClientHandler and disable buffering
        $httpClientHandler = [System.Net.Http.HttpClientHandler]::new()
        $httpClientHandler.AllowAutoRedirect = $false
        $httpClientHandler.UseCookies = $false
        $httpClientHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        
        # Create an instance of HttpClient
        $httpClient = [System.Net.Http.HttpClient]::new($httpClientHandler)
            
        # Set the required headers
        $httpClient.DefaultRequestHeaders.Add("api-key", $ApiKey)
            
        # Set the timeout for the HttpClient
        $httpClient.Timeout = New-TimeSpan -Seconds $timeoutSec
        
        # Create the HttpContent object with the request body
        $content = [System.Net.Http.StringContent]::new($bodyJSON, [System.Text.Encoding]::UTF8, "application/json")
     
        $request = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post, $url)
        $request.Content = $content
     
        # Send the HTTP POST request asynchronously with HttpCompletionOption.ResponseHeadersRead
        $response = $httpClient.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
    
        # Ensure the request was successful
        if (-not $response.IsSuccessStatusCode) {
            Write-Host "-- Response was not successful: $($response.StatusCode) - $($response.ReasonPhrase)"
            return
        }
    
        # Get the response stream
        $stream_ = $response.Content.ReadAsStreamAsync().Result
        $reader = [System.IO.StreamReader]::new($stream_)
    
        Write-Host "++ Streaming." -ForegroundColor Blue

        # Initialize the completeText variable
        $completeText = ""
        while ($null -ne ($line = $reader.ReadLine()) -or (-not $reader.EndOfStream)) {
            # Check if the line starts with "data: " and is not "data: [DONE]"
            if ($line.StartsWith("data: ") -and $line -ne "data: [DONE]") {
                # Extract the JSON part from the line
                $jsonPart = $line.Substring(6)    
                if ($completeText.EndsWith('+')) {
                    $completeText = $completeText.Substring(0, $completeText.Length - 1)
                }
                try {
                    # Parse the JSON part
                    $parsedJson = $jsonPart | ConvertFrom-Json
                    # Extract the text and append it to the complete text - Chat Completion
                    $delta = $parsedJson.choices[0].delta.content
                    $completeText += $delta
                    Write-Host $delta -NoNewline -ForegroundColor White
                }
                catch {
                    Write-Error "Error parsing JSON: $_"
                }
            }
        }
        Write-Host ""
        $completeText += "`n"
    
        if ($VerbosePreference -eq "Continue") {
            Write-Verbose "Streaming completed. Full text: $completeText"
        }
        else {
            Write-Host "++ Streaming completed." -ForegroundColor Blue
        }
        # Clean up
        $reader.Close()
        $httpClient.Dispose()

        $response = $completeText
    }
    else {
        # Send a non-streaming HTTP POST request and parse the response
        $response = Invoke-RestMethod -Uri "$($endpoint)chat/completions" -Headers $headers -Method POST -Body $bodyJSON -TimeoutSec $timeoutSec
        $response = $($response.Choices[0].message.content).trim()
    }

    # Log the prompt and response to the log file
    $logEntry = @{
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemPrompt = $SystemPrompt
        UserPrompt   = $UserPrompt
        Response     = $response
    } | ConvertTo-Json
    
    [void]($this.Log.Add($logEntry))
    # Log the summary
    [void]($this.AddLogEntry("SystemPrompt:`n$SystemPrompt"))
    [void]($this.AddLogEntry("UserPrompt:`n$UserPrompt"))
    [void]($this.AddLogEntry("Response:`n$Response"))
    
    $InfoText = "++ LM Studio" + $(if ($Model) { " model ($Model)" } else { "" }) + " has successfully processed your request."
    Write-Host $InfoText

    return $response
}

function Invoke-BingWebSearch {
    param (
        [Parameter(Mandatory = $true)]
        [string]$query, # The search query

        [Parameter(Mandatory = $false)]
        [string]$apiKey,
        
        [Parameter(Mandatory = $false)]
        [string]$endpoint,
        
        [Parameter(Mandatory = $false)]
        [string]$language = "en-US", # The language for the search results
        
        [Parameter(Mandatory = $false)]
        [int]$count  # The number of search results to return
    )

    # Ensure the API key is provided, prompt the user if not
    while ([string]::IsNullOrEmpty($apiKey) -or [string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Read-Host -Prompt "Please enter your AZURE Bing API key"
        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("AZURE_BING_API_KEY", $apiKey, "User")
            Write-Verbose "API key set successfully."
        }
    }

    # Ensure the endpoint is provided, prompt the user if not
    while ([string]::IsNullOrEmpty($endpoint) -or [string]::IsNullOrWhiteSpace($endpoint)) {
        $endpoint = Read-Host -Prompt "Please enter the AZURE Bing Web Search Endpoint"
        if ($endpoint) {
            [System.Environment]::SetEnvironmentVariable("AZURE_BING_SEARCH_ENDPOINT", $endpoint, "User")
            Write-Verbose "Endpoint set successfully."
        }
    }
    
    # Define the headers for the API request
    $headers = @{
        "Ocp-Apim-Subscription-Key" = $apiKey
        "Pragma"                    = "no-cache"
    }
    Write-Verbose "Headers defined for the API request."

    # If the query length is greater than the maximum allowed, truncate it
    $maxqueryLength = 120
    if ($query.Length -gt $maxqueryLength) {
        Write-Host "Query length is greater than $maxqueryLength characters. Truncating the query."
        $query = $query.Substring(0, $maxqueryLength)
        Write-Verbose "Query truncated to $maxqueryLength characters."
    }
    
    # Define the parameters for the API request
    $params = @{
        "q"     = $query
        "mkt"   = $language
        "count" = $count
    }
    Write-Verbose "Parameters defined for the API request."

    # Ensure the endpoint is provided, prompt the user if not
    while ([string]::IsNullOrEmpty($Endpoint)) {
        $Endpoint = Read-Host -Prompt "Please enter the AZURE Bing Web Search Endpoint"
    }
    [System.Environment]::SetEnvironmentVariable("AZURE_BING_SEARCH_ENDPOINT", $Endpoint, "User")
    $endpoint += "v7.0/search"
    Write-Verbose "Final endpoint set to $endpoint."
        
    # Disable the Expect100Continue behavior to avoid delays in sending data
    [System.Net.ServicePointManager]::Expect100Continue = $false
    Write-Verbose "Expect100Continue behavior disabled."
    
    # Disable the Nagle algorithm to improve performance for small data packets
    [System.Net.ServicePointManager]::UseNagleAlgorithm = $false
    Write-Verbose "Nagle algorithm disabled."
    
    # Set the security protocol to TLS 1.2 for secure communication
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Write-Verbose "Security protocol set to TLS 1.2."
    
    try {
        # Make the API request to Bing Search
        Write-Verbose "Making API request to Bing Search."
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -Body $params

        # Check if the response contains web pages
        if ($null -eq $response.webPages.value) {
            Write-Warning "No web pages found for the query: $query"
            return $null
        }

        Write-Verbose "API request successful. Returning search results."
        # Return the search results
        return $response.webPages.value
    }
    catch [System.Net.WebException] {
        # Handle web exceptions (e.g., network issues)
        Write-Warning "Network error occurred during Bing search: $_"
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
    catch [System.Exception] {
        # Handle all other exceptions
        Write-Warning "An error occurred during Bing search: $_"
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
}

function Remove-StringDirtyData {
    param (
        [string]$inputString
    )

    Write-Verbose "Starting to clean the input string."

    # Remove leading and trailing whitespace
    Write-Verbose "Removing leading and trailing whitespace."
    $cleanedString = $inputString.Trim()

    # Remove multiple spaces and replace with a single space
    Write-Verbose "Replacing multiple spaces with a single space."
    $cleanedString = $cleanedString -replace '\s+', ' '

    # Remove any non-printable characters
    Write-Verbose "Removing non-printable characters."
    $cleanedString = $cleanedString -replace '[^\x20-\x7E]', ''

    # Remove &nbsp; entities
    Write-Verbose "Removing &nbsp; entities."
    $cleanedString = $cleanedString -replace '&nbsp;', ' '

    # Remove empty lines
    Write-Verbose "Removing empty lines."
    $cleanedString = $cleanedString -replace '^\s*$\n', ''

    # Convert the string to an array of lines
    Write-Verbose "Converting the string to an array of lines."
    $lines = $cleanedString -split "`n"

    # Remove empty lines
    Write-Verbose "Removing empty lines from the array of lines."
    $lines = $lines | Where-Object { $_.Trim() -ne "" }

    # Join the lines back into a single string
    Write-Verbose "Joining the lines back into a single string."
    $cleanedString = $lines -join "`n"

    #region Cleaning RAG Raw Data
    # This section is responsible for cleaning raw data obtained from RAG (Retrieve and Generate) processes.
    # The goal is to ensure that the text is free from artifacts, irregular spacing, and formatting issues
    # that may have resulted from HTML removal or other preprocessing steps.
    # The cleaned text should be readable, well-formatted, and maintain its original structure and meaning.
    # The cleaning process involves removing HTML entities, excessive blank lines, and other artifacts,
    # as well as correcting spacing issues, standardizing quotation marks, and ensuring proper capitalization.
    # The cleaned text is then processed by an LLM (Language Learning Model) to further refine and ensure
    # the quality of the output.
    #endregion Cleaning RAG Raw Data
    Write-Host "++ Cleaning RAG Raw Data: Ensuring the text is free from artifacts, irregular spacing, and formatting issues." -ForegroundColor Cyan
    
    # Define the LLM system prompt for cleaning the string
    $LLMSystemPrompt = @"
You are an expert text processor specializing in cleaning and formatting web content. Your task is to process text that originally came from HTML but has already had its HTML tags removed. The text still contains artifacts, irregular spacing, meta content, sidebar content or formatting issues from the HTML removal process. Your goal is to produce clean, readable text.

In your processing you must:
1. Remove all HTML entities (e.g., &nbsp;, &amp;, &#39;) and replace them with their corresponding characters. Use a comprehensive list of HTML entities for reference.
2. Normalize line breaks:
   - Reduce multiple consecutive blank lines to a single blank line for paragraph separation.
   - Preserve intentional line breaks for structured content like addresses, poetry, or code snippets.
   - Remove unnecessary line breaks within paragraphs, joining split sentences.
3. Clean up HTML artifacts:
   - Remove any remaining HTML tags, including partial or malformed tags.
   - Eliminate stray brackets, braces, or other syntax-related characters that don't belong in plain text.
4. Standardize spacing:
   - Ensure single spaces after punctuation marks (periods, commas, colons, etc.).
   - Remove extra spaces between words.
   - Eliminate leading or trailing spaces on each line.
5. Normalize quotation marks and apostrophes:
   - Use straight quotes (' and ") consistently throughout the text.
   - Ensure apostrophes are used correctly for contractions and possessives.
6. Correct capitalization:
   - Capitalize the first letter of each sentence.
   - Preserve intentional capitalization for proper nouns, acronyms, and titles.
7. Remove redundancies:
   - Eliminate repeated words or phrases that likely resulted from improper tag removal or formatting issues.
   - Be cautious not to remove intentional repetition for emphasis or stylistic purposes.
8. Format lists consistently:
   - Identify and standardize bulleted and numbered lists.
   - Ensure consistent indentation and formatting for list items.
   - Convert HTML list structures to plain text equivalents if necessary.
9. Correct spelling and encoding errors:
   - Fix obvious spelling mistakes, especially those resulting from character encoding issues.
   - Be cautious with proper nouns or specialized terminology.
10. Standardize punctuation:
    - Use consistent em-dashes, en-dashes, and hyphens.
    - Ensure correct usage of semicolons, colons, and other punctuation marks.
11. Preserve or convert special formatting:
    - Maintain emphasis (bold, italic) using plain text conventions (e.g., *asterisks* or _underscores_) if appropriate for the output format.
    - Convert simple tables to a readable plain text format if encountered.
12. Handle URLs and email addresses:
    - Ensure hyperlinks are visible and properly formatted in plain text.
    - Preserve the integrity of email addresses and web URLs.
13. Normalize number and date formats:
    - Standardize numerical representations (e.g., consistent use of commas or periods for thousands separators).
    - Use a consistent date format throughout the document.
14. Remove or replace non-printable characters:
    - Eliminate null characters, form feeds, and other control characters.
    - Replace tabs with appropriate spacing.
15. Final consistency check:
    - Ensure overall consistency in formatting choices throughout the document.
    - Verify that the cleaning process hasn't introduced new errors or inconsistencies.
"@

    # Define the user prompt with the input string
    $LLMUserPrompt = @"
Web content:

``````text
$cleanedString
``````

Process and response with cleaned text only, maintaining its original structure and meaning as much as possible.
"@

    # Invoke the LLM to clean the string
    try {
        Write-Verbose "Invoking LLM to clean the string."

        # Invoke the LLMChatCompletion function with the necessary parameters
        $CleanedString = Invoke-LLMChatCompletion -Provider $GlobalState.LLMProvider `
            -SystemPrompt $LLMSystemPrompt `
            -UserPrompt $LLMUserPrompt `
            -Temperature 0.1 `
            -TopP 0.1 `
            -MaxTokens $GlobalState.MaxTokens `
            -Stream $false `
            -LogFolder $GlobalState.TeamDiscussionDataFolder `
            -DeploymentChat $script:DeploymentChat `
            -ollamaModel $script:ollamaModel

        Write-Host "++ Cleaning RAG Raw Data: Finished." -ForegroundColor Cyan
        return $CleanedString
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Write-Host "-- An error occurred while invoking the LLM to clean the string." -ForegroundColor DarkYellow
        return
    }
}

function Invoke-RAG {
    param (
        [string]$UserInput,
        [string]$Prompt,
        [ProjectTeam]$RAGAgent,
        [int]$MaxCount = 2
    )
    $RAGResponse = $null
    $ShortenedUserInput = ""
    try {
        Write-Verbose "Starting Invoke-RAG function."

        # Define the system prompt for the RAG agent
        $RAGSystemPrompt = @"
You are a Web Search Query Manager. Your task is to suggest the best query for the Azure Bing Web Search API based on the user's input. To create an effective query, summarize the given text and follow these best practices:

1. Use specific keywords: Choose concise and precise terms that clearly define the search intent to increase result relevance.
2. Utilize advanced operators: Leverage operators like 'AND', 'OR', and 'NOT' to refine queries. Use 'site:' for domain-specific searches.
3. Remove quotation marks or other special characters from the beginning and end of the query.

Your response should be a short, optimized Web query with a few terms based on the user's input. 

Examples of well-formed queries:
- 'Python, code review, script parsing OR analyzing'
- 'Python code AND psscriptanalyzer'
- 'Python AND azure data logger AND event log'

You must respond with the optimized query only ready to be invoked in search engine.
"@

        Write-Verbose "RAG system prompt defined."

        # Create an optimized web search query based on the following text
        $RAGUserPrompt = @"
User input:
````````text
$($userInput.trim())
````````
"@

        # Process the user input with the RAG agent and trim the result
        $ShortenedUserInput = ($RAGAgent.ProcessInput($RAGUserPrompt, $RAGSystemPrompt)).trim()

        Write-Verbose "RAG agent processed the input and returned a shortened user input."

        Write-Host ">> RAG is on. Attempting to augment AI Agent data..." -ForegroundColor Green

        # Check if the shortened user input is not empty
        if (-not [string]::IsNullOrEmpty($ShortenedUserInput)) {
            Write-Verbose "Shortened user input is not empty. Proceeding with web search."

            try {
                # Define the log file path for storing the query
                $LogFilePath = Join-Path -Path $GlobalState.TeamDiscussionDataFolder -ChildPath "azurebingqueries.log"
                Write-Verbose "Log file path defined: $LogFilePath"

                # Append the shortened user input to the log file with a date prefix in professional log style
                $DatePrefix = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                $LogEntry = "$DatePrefix - Query: $ShortenedUserInput"
                Add-Content -Path $LogFilePath -Value $LogEntry
                Write-Verbose "Log entry added: $LogEntry"

                # Perform the web search using the shortened user input
                $WebResults = Invoke-BingWebSearch -query $ShortenedUserInput -count $MaxCount -apiKey ([System.Environment]::GetEnvironmentVariable("AZURE_BING_API_KEY", "User")) -endpoint ([System.Environment]::GetEnvironmentVariable("AZURE_BING_SEARCH_ENDPOINT", "User"))
                Write-Verbose "Web search performed with query: $ShortenedUserInput"
            }
            catch {
                Write-Error "Error occurred during web search or logging: $_"
                throw $_
            }
        }
        else {
            # Throw an error if the query is empty
            Write-Error "The query is empty. Unable to perform web search."
            throw "The query is empty. Unable to perform web search."
        }

        # Check if web results are returned
        if ($WebResults) {
            Write-Verbose "Web results returned. Extracting and cleaning text content."

            try {
                # Extract and clean text content from the web results
                $WebResultsText = ($WebResults | ForEach-Object {
                        $HtmlContent = Invoke-WebRequest -Uri $_.url
                        $TextContent = ($HtmlContent.Content | PowerHTML\ConvertFrom-HTML).innerText
                        $TextContent
                    }
                ) -join "`n`n"
                Write-Verbose "Text content extracted and cleaned from web results."
            }
            catch {
                Write-Error "Error occurred while extracting or cleaning web results: $_"
                throw $_
            }
        }
        else {
            Write-Verbose "No web results returned."
        }

        # Process the cleaned web results text with the project manager's input processing function
        $RAGuserinput = @"

Please analyze the following text through the lens of Python project with this description: '$userinput'

Text to analyze:
````````text
$($(Remove-StringDirtyData -inputString $webResultsText).trim())
````````

Provide your analysis in the following format:
1. Key Information: List the most important facts or points from the text, relevant to the given description.
2. Insights: Offer any notable thoughts or interpretations based on the text and context.
3. Questions: Generate relevant questions that arise from the analysis, which could lead to further exploration of the topic.

Ensure your response is focused and directly related to the provided description.
"@
        $RAGresponse = $RAGAgent.ProcessInput($RAGuserinput, $prompt)
        if ($RAGresponse) {
            Write-Host "++ RAG is on. AI Agent data was successfully augmented with new data." -ForegroundColor Green
        }
        
        # Return the response generated by the project manager
        return $RAGresponse
    }
    catch {
        # Log the error and rethrow it
        #$this.AddLogEntry("Error in Invoke-RAG:`n$_")
        #throw $_
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        #Write-Warning $_
        Write-Host "-- No RAG data available to augment." -ForegroundColor DarkYellow
        return
    }
}

function Get-Ollama {
    <#
.SYNOPSIS
    Checks the status of Ollama installation, process, and running models.

.DESCRIPTION
    This function performs several checks related to Ollama:
    1. Verifies if Ollama is installed and available in the system PATH.
    2. Checks if the Ollama process is currently running.
    3. Retrieves and displays information about the models currently running in Ollama.

.EXAMPLE
    Get-Ollama

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    # Check if Ollama is installed
    $ollamaPath = Test-OllamaInstalled
    if (-not $ollamaPath) {
        Write-Host "-- Ollama is not installed or not in PATH."
        return $false
    }
    Write-Host "++ Ollama is installed at: $ollamaPath"

    # Check if Ollama is running
    $ollamaProcess = Test-OllamaRunning
    if (-not $ollamaProcess) {
        Write-Host "-- Ollama is not currently running."
        return Start-OllamaInNewConsole
    }
    if ($ollamaProcess.Count -gt 1) {
        Write-Host "++ Multiple Ollama processes are running with PID(s): $($ollamaProcess.Id -join ', ')"
    }
    else {
        Write-Host "++ Ollama is running with PID: $($ollamaProcess.Id)"
    }

    # Check what model is running
    try {
        Get-OllamaModels
    }
    catch {
        Write-Host "-- Failed to retrieve model information from /api/tags: $_"
        return $false
    }

    # Additional check for running model information
    try {
        # Example usage of Test-OllamaRunningModel and Start-OllamaModel
        # Test-OllamaRunningModel checks if any model is running
        # Start-OllamaModel starts a model if none is running
        return Start-OllamaModel
    }
    catch {
        Write-Host "-- Failed to retrieve additional model information from /api/ps: $_"
    }
}

function Get-OllamaModels {
    <#
    .SYNOPSIS
        Lists all available models in the local Ollama repository.

    .DESCRIPTION
        This function retrieves and lists all models available in the local Ollama repository by making a GET request to the /api/tags endpoint.

    .EXAMPLE
        List-OllamaModels

    .NOTES
        Author: voytas75
        Date: 2024.07.10
    #>
    try {
        # Make a GET request to the /api/tags endpoint to retrieve model information
        $response = Invoke-RestMethod -Uri "$($script:ollamaEndpoint)api/tags" -Method Get
        if ($response.models) {
            Write-Host "++ Models:"
            # Iterate through each model and output its name and size
            $response.models | ForEach-Object {
                $sizeInGB = [math]::Round($_.size / 1GB, 2)
                Write-Host "- $($_.name) (Size: $sizeInGB GB)"
            }
        }
        else {
            Write-Host "-- No models in local repository. https://github.com/ollama/ollama?tab=readme-ov-file#quickstart"
            return $false
        }
    }
    catch {
        Write-Host "-- Failed to retrieve model information from /api/tags: $_"
        return $false
    }
}

function Start-OllamaInNewConsole {
    <#
    .SYNOPSIS
        Starts Ollama in a new minimized console window.

    .DESCRIPTION
        This function starts the Ollama application in a new minimized console window using the Start-Process cmdlet.
        It ensures that Ollama is installed and available in the system PATH before attempting to start it.

    .EXAMPLE
        Start-OllamaInNewConsole

    .NOTES
        Author: voytas75
        Date: 2024.07.10
    #>
    # Check if Ollama is installed
    $ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaPath) {
        #Write-Host "Ollama is not installed or not in PATH."
        return $false
    }

    # Start Ollama in a new minimized console window
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/k", "$ollamaPath start" -WindowStyle Minimized
        Write-Host "++ Ollama has been started in a new minimized console window."
        return $true
    }
    catch {
        Write-Host "-- Failed to start Ollama in a new minimized console window: $_"
        return $false
    }
}

function Test-OllamaRunningModel {
    <#
.SYNOPSIS
    Tests if any models are currently running in Ollama and retrieves their information.

.DESCRIPTION
    This function checks if any models are currently running in Ollama by making a GET request to the /api/ps endpoint.
    If models are running, it outputs their names and sizes. If no models are running, it provides instructions on how to start a model.

.EXAMPLE
    Test-OllamaRunningModel

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    param(
        [switch]$NOInfo
    )
    try {
        # Make a GET request to the /api/ps endpoint to retrieve running model information
        $response = Invoke-RestMethod -Uri "$($script:ollamaEndpoint)api/ps" -Method Get
        
        if ($response.models) {
            if (-not $NOInfo) {
                Write-Host "++ Ollama is running the following models: " -NoNewline
            }
            # Iterate through each model and output its name and size
            $script:ollamaModels = $response.models
            $ollamaRunningModels = @()
            foreach ($model in $script:ollamaModels) {
                if (-not $NOInfo) {
                    $sizeInGB = [math]::Round($model.size / 1GB, 2)
                    $ollamaRunningModels += "$($model.name) (Size: $sizeInGB GB)"
                }
            }
            Write-Host $($ollamaRunningModels -join ',')

            # Choose and return the first model
            $firstModel = $script:ollamaModels[0]
            $script:ollamamodel = $firstModel.name
            $env:OLLAMA_MODEL = $script:ollamamodel
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $firstModel.Name, 'User')
            return $firstModel.Name
        }
        else {
            if (-not $NOInfo) {
                Write-Host "-- No models are currently running in Ollama."
            }
            #Write-Host "To run a model in Ollama, use the following command:"
            #Write-Host "ollama run <model-name>"
            return $false
        }
    }
    catch {
        Write-Host "-- Failed to retrieve model information from Ollama: $_"
    }
}

function Start-OllamaModel {
    <#
.SYNOPSIS
    Starts a model in Ollama if no model is currently running.

.DESCRIPTION
    This function checks if Ollama is installed and available in the system PATH. 
    It then verifies if any model is currently running in Ollama. If no model is running, 
    it prompts the user to select a model from the available models and starts it.

.EXAMPLE
    Start-OllamaModel

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    # Get the path of the Ollama executable
    #$ollamaPath = (Get-Command ollama -ErrorAction SilentlyContinue).Source
    $ollamaPath = Test-OllamaInstalled
    if (-not $ollamaPath) {
        Write-Host "-- Ollama is not found in PATH. Make sure it's installed and in your system PATH."
        #return $false
        # ollama can be run on remote computer
    }

    try {
        # Check if any model is currently running
        $runningModel = Test-OllamaRunningModel -NOInfo
        if ($runningModel) {
            Write-Host "++ Model '$runningModel' is already running."
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $runningModel, 'user')
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            return $script:ollamaModel
        }

        # Make a GET request to the /api/tags endpoint to retrieve available models
        $response = Invoke-RestMethod -Uri "$($script:ollamaEndpoint)api/tags" -Method Get
        if ($response.models) {
            #Write-Host "Available Models:"
            # List available models
            $models = $response.models | ForEach-Object { $_.name }
            #$models | ForEach-Object { Write-Host "- $_" }

            # Check if the environment variable 'ollama_model' is set
            if ([System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')) {
                #$ModelName = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL','user')
                if ($models -notcontains [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')) {
                    Write-Host "-- Invalid model name specified in environment variable 'ollama_model'. Please select a model from the list."
                    [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', '', 'user')
                    $ModelName = [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', '', 'user')
                }
            }
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            $ModelName = $script:ollamaModel
            # If 'ollama_model' is not set or invalid, prompt the user to select a model
            if (-not $ModelName) {
                Get-OllamaModels
                do {
                    $ModelName = Read-Host "Please enter the name of the model you want to start"
                    if ($models -notcontains $ModelName) {
                        Write-Host "-- Invalid model name. Please select a model from the list."
                        $ModelName = $null
                    }
                } while (-not $ModelName)
            }

            # Start the selected model using a new Python process
            #Start-Process Python -ArgumentList "-NoExit", "-Command", "& '$ollamaPath' run $ModelName"
            Write-Host "++ Starting with $ModelName"
            Start-Process -FilePath "cmd.exe" -ArgumentList "/k", "$ollamaPath run $ModelName" -WindowStyle Minimized
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $ModelName, 'user')
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            return $ModelName
        }
        else {
            Write-Host "-- No models are currently available."
        }
    }
    catch {
        Write-Host "-- Failed to retrieve model information from /api/tags: $_"
    }
}

function Test-OllamaInstalled {
    <#
    .SYNOPSIS
        Tests if Ollama is installed and available in the system PATH.

    .DESCRIPTION
        This function checks if the 'ollama' executable is available in the system PATH.
        It returns $true if Ollama is installed, and $false otherwise.

    .EXAMPLE
        Test-OllamaInstalled
        Returns $true if Ollama is installed, otherwise $false.

    .NOTES
        Author: voytas75
        Date: 2024.07.10
    #>
    param ()

    try {
        $ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
        if ($ollamaPath) {
            #Write-Host "Ollama is installed at: $($ollamaPath.Source)"
            return $ollamaPath.Source
        }
        else {
            #Write-Host "Ollama is not installed or not in PATH."
            return $false
        }
    }
    catch {
        Write-Host "-- An error occurred while checking for Ollama installation: $_"
        return $false
    }
}

function Test-OllamaAPI {
    <#
    .SYNOPSIS
        Tests if the Ollama API is currently accessible.

    .DESCRIPTION
        This function sends a request to the Ollama API endpoint to check if it is accessible and responding.
        It returns $true if the API is accessible, and $false otherwise.

    .EXAMPLE
        Test-OllamaAPI
        Returns $true if the Ollama API is accessible, otherwise $false.

    .NOTES
        Author: voytas75
        Date: 2024.07.10
    #>
    param (
        [string]$apiEndpoint = "$($script:ollamaEndpoint)"
    )

    try {
        $response = Invoke-RestMethod -Uri $apiEndpoint -Method Get -ErrorAction Stop
        if ($response -eq "Ollama is running") {
            #Write-Host "++ Ollama API is accessible."
            return $true
        }
        else {
            Write-Host "-- Ollama API is not accessible or returned an unexpected status."
            return $false
        }
    }
    catch {
        Write-Host "-- An error occurred while checking the Ollama API: $_"
        return $false
    }
}

function Test-OllamaRunning {
    <#
    .SYNOPSIS
        Tests if the Ollama process is currently running.

    .DESCRIPTION
        This function checks if the 'ollama' process is currently running on the system.
        It returns $true if the process is running, and $false otherwise.

    .EXAMPLE
        Test-OllamaRunning
        Returns $true if the Ollama process is running, otherwise $false.

    .NOTES
        Author: voytas75
        Date: 2024.07.10
    #>
    param ()

    try {
        $ollamaProcess = Get-Process ollama -ErrorAction SilentlyContinue
        if ($ollamaProcess) {
            return $ollamaProcess
        }
        else {
            return $false
        }
    }
    catch {
        Write-Host "-- An error occurred while checking if Ollama is running: $_"
        return $false
    }
}

function Set-EnvOllamaModel {
    param ($model)
    $env:OLLAMA_MODEL = $model
    $script:ollamaModel = $model
    [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $model, 'User')
}

function Test-EnsureOllamaModelRunning {
    param ($attempts = 10, $delay = 2)
    for ($i = 0; $i -lt $attempts; $i++) {
        $runningModel = Test-OllamaRunningModel
        if ($runningModel) {
            Set-EnvOllamaModel -model $runningModel
            return $true
        }
        Start-OllamaModel
        Start-Sleep -Seconds $delay
    }
    return $false
}
#endregion Functions

#region Setting Up
# Save the original UI culture to restore it later
$originalCulture = [Threading.Thread]::CurrentThread.CurrentUICulture

# Set the current UI culture to 'en-US' for consistent behavior
[void]([Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::CreateSpecificCulture('en-US'))

# Check if the PSAOAI module version is at least 0.3.2
if ( Test-ModuleMinVersion -ModuleName PSAOAI -MinimumVersion "0.3.2" ) {
    # Import the PSAOAI module forcefully
    [void](Import-module -name PSAOAI -Force)
}
else {
    # Display a warning message if the required module version is not installed
    Write-Warning "-- You need to install/update PSAOAI module version >= 0.3.2. Use: 'Install-Module PSAOAI' or 'Update-Module PSAOAI'"
    return
}

# Disable RAG (Retrieve and Generate) functionality if the NORAG switch is set
$RAG = $true
if ($NORAG) {
    $RAG = $false
}

if (-not $LoadProjectStatus) {
    # Define a state management object
    $GlobalState = [PSCustomObject]@{
        TeamDiscussionDataFolder = $null
        GlobalResponse           = @()
        FileVersion              = 1
        LastpydevCode            = ""
        GlobalpydevResponse      = @()
        OrgUserInput             = ""
        UserInput                = ""
        LogFolder                = ""
        MaxTokens                = $MaxTokens
        VerbosePrompt            = $VerbosePrompt
        NOTips                   = $NOTips
        NOLog                    = $NOLog
        NODocumentator           = $NODocumentator
        NOPM                     = $NOPM
        RAG                      = $RAG
        Stream                   = $Stream
        LLMProvider              = $LLMProvider
    }
    $GlobalState.LogFolder = $LogFolder
}

# Disabe PSAOAI importing banner
[System.Environment]::SetEnvironmentVariable("PSAOAI_BANNER", "0", "User")
$env:PSAOAI_BANNER = "0"

# Check if the UserInput parameter is not provided
if (-not $UserInput) {
    if (-not $LoadProjectStatus) {
        # Prompt the user to enter the Python project description
        $UserInput = Read-Host "Please enter the Python project description"
        # Store the user input in the GlobalState object
        $GlobalState.UserInput = $UserInput
    }
}

Show-Banner

#region ollama
if ($GlobalState.LLMProvider -eq 'ollama' -and (-not $LoadProjectStatus)) {
    $script:ollamaEndpoint = [System.Environment]::GetEnvironmentVariable('OLLAMA_ENDPOINT', 'user')
    if (-not $script:ollamaEndpoint.EndsWith('/')) {
        $script:ollamaEndpoint += '/'
    }

    if ([string]::IsNullOrEmpty($script:ollamaEndpoint)) {
        $defaultEndpoint = 'http://localhost:11434/'
        try {
            $script:ollamaEndpoint = $defaultEndpoint
            $env:OLLAMA_ENDPOINT = $defaultEndpoint
            [System.Environment]::SetEnvironmentVariable('OLLAMA_ENDPOINT', $defaultEndpoint, 'user')
            if ([System.Environment]::GetEnvironmentVariable('OLLAMA_ENDPOINT', 'user')) {
                Write-Host "++ Environment variable 'OLLAMA_ENDPOINT' was set successfully ('$defaultEndpoint'). Set it manually if you need a non-default value: [System.Environment]::SetEnvironmentVariable('OLLAMA_ENDPOINT', '<your-ollama-api-endpoint>', 'user')" -ForegroundColor Green
            }
        }
        # If setting the variable failed, display an error message
        catch {
            Write-Warning "-- Failed to set environment variable 'OLLAMA_ENDPOINT'."
            return
        } 
    }

    if (Test-OllamaAPI) {
        Write-Host "++ Ollama API is reachable."
        
        # Check if Ollama is running with a model
        $runningModelOllama = Test-OllamaRunningModel
        if ($runningModelOllama) {
            Write-Host "++ Ollama is running with model: $runningModelOllama"
            Set-EnvOllamaModel -model $runningModelOllama
        }
        else {
            Write-Host "-- No models are currently running in Ollama. Please check your Ollama configuration."
            return
        }
    }
    else {
        Write-Warning "-- Ollama API is not reachable. Please check your Ollama installation and configuration."
        return
    }
    Write-Host "If you want to change the model, please delete the OLLAMA_MODEL environment variable or set it to your desired value." -ForegroundColor Magenta
}
#endregion ollama

#region LMStudio
# Check if the LLM provider is 'lmstudio'
if ($GlobalState.LLMProvider -eq 'lmstudio' -and (-not $LoadProjectStatus)) {
    # Retrieve the LM Studio API key from the environment variables
    $script:lmstudioApiKey = [System.Environment]::GetEnvironmentVariable('OPENAI_API_KEY', 'user')
    # Retrieve the LM Studio API base URL from the environment variables
    $script:lmstudioApiBase = [System.Environment]::GetEnvironmentVariable('OPENAI_API_BASE', 'user')
    $env:OPENAI_API_KEY = $script:lmstudioApiKey
    $env:OPENAI_API_BASE = $script:lmstudioApiBase
    # If the API key is not set, use the default value 'lm-studio' and set it in the environment variables
    if (-not $script:lmstudioApiKey) {
        $script:lmstudioApiKey = 'lm-studio'
        $env:OPENAI_API_KEY = $script:lmstudioApiKey
        [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $script:lmstudioApiKey, 'user')
        Write-Verbose "++ Default LM Studio API key set to 'lm-studio'"
    }

    # If the API base URL is not set, use the default value 'http://localhost:1234/v1' and set it in the environment variables
    if (-not $script:lmstudioApiBase) {
        $script:lmstudioApiBase = 'http://localhost:1234/v1'
        $env:OPENAI_API_BASE = $script:lmstudioApiBase
        [System.Environment]::SetEnvironmentVariable('OPENAI_API_BASE', $script:lmstudioApiBase, 'user')
        Write-Verbose "++ Default LM Studio API base set to 'http://localhost:1234/v1'"
    }

    # Ensure the LMStudio endpoint ends with a '/'
    if (-not $script:lmstudioApiBase.EndsWith('/')) {
        $script:lmstudioApiBase += '/'
    }

    try {
        $LMStudioServerResponse = Invoke-WebRequest -Uri $script:lmstudioApiBase
        if ($LMStudioServerResponse.statuscode -eq "200") {
            Write-Host "++ LM Studio server is running." -ForegroundColor Green
        }
        else {
            Write-Host "-- LM Studio server not running." -ForegroundColor Yellow
            return
        }
    }
    catch [System.Net.WebException] {
        Write-Warning "LM Studio server is not running or not reachable. Please ensure the server is up and running at $($script:lmstudioApiBase)."
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "LM Studio server is not running or not reachable"
        Throw $_
    }
    catch {
        Update-ErrorHandling -ErrorContext "LM Studio server is not running or not reachable"-ErrorRecord $_
    }
    # Test lm-studio for model
    try {
        $LMStudioModelResponse = Invoke-RestMethod -Uri "$($script:lmstudioApiBase)models" -Method GET
        if ($LMStudioModelResponse.data.Count -eq 0) {
            Write-Host "-- No models loaded. Please load a model in LM Studio first."
            return
        }
        elseif ($LMStudioModelResponse.data.Count -gt 1) {
            Write-Host "++ LM Studio is running in Multi Model Session. Only one model can be chosen. Choosing the first one."
        }
        if ($LMStudioModelResponse.data[0].id) {
            $script:LMStudioModel = $LMStudioModelResponse.data[0].id
        }
    }
    catch [System.Net.WebException] {
        #System.InvalidOperationException
        Write-Warning "LM Studio server is not running or not reachable. Please ensure the server is up and running at $($script:lmstudioApiBase)."
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "LM Studio server is not running or not reachable"
        Throw $_
    }
    catch {
        Update-ErrorHandling -ErrorContext "LM Studio server is not running or not reachable" -ErrorRecord $_
        #Throw $_.Exception.Message
    }

}
#endregion LMStudio

$scriptname = "AIPyTeam"
if ($LoadProjectStatus) {
    # Check if the provided path is a directory
    if (Test-Path -Path $LoadProjectStatus -PathType Container) {
        # Get all XML files in the specified directory
        $xmlFiles = Get-ChildItem -Path $LoadProjectStatus -Filter *.xml
        foreach ($file in $xmlFiles) {
            # Prompt the user to select a file to use as the project status
            $useFile = Read-Host "Do you want to use the file '$($file.FullName)' as the project status? (yes/no)"
            if ($useFile -eq 'yes') {
                # Set the selected file as the project status file
                $LoadProjectStatus = $file.FullName
                break
            }
        }
    } 
    try {
        # Load the project state from the specified file
        $GlobalState = Get-ProjectState -FilePath $LoadProjectStatus
        Write-Information "++ Project state loaded successfully from $LoadProjectStatus" -InformationAction Continue
        # Output verbose information about the loaded project state
        Write-Verbose "`$GlobalState.TeamDiscussionDataFolder: $($GlobalState.TeamDiscussionDataFolder)"
        Write-Verbose "`$GlobalState.FileVersion: $($GlobalState.FileVersion)"
        Write-Verbose "`$GlobalState.LastpydevCode: $($GlobalState.LastpydevCode)"
        Write-Verbose "`$GlobalState.GlobalpydevResponse: $($GlobalState.GlobalpydevResponse)"
        Write-Verbose "`$GlobalState.GlobalResponse: $($GlobalState.GlobalResponse)"
        Write-Verbose "`$GlobalState.OrgUserInput: $($GlobalState.OrgUserInput)"
        Write-Verbose "`$GlobalState.UserInput: $($GlobalState.UserInput)"
        Write-Verbose "`$GlobalState.LogFolder: $($GlobalState.LogFolder)"
        Write-Verbose "`$GlobalState.MaxTokens: $($GlobalState.MaxTokens)"
        Write-Verbose "`$GlobalState.VerbosePrompt: $($GlobalState.VerbosePrompt)"
        Write-Verbose "`$GlobalState.NOTips: $($GlobalState.NOTips)"
        Write-Verbose "`$GlobalState.NOLog: $($GlobalState.NOLog)"
        Write-Verbose "`$GlobalState.NODocumentator: $($GlobalState.NODocumentator)"
        Write-Verbose "`$GlobalState.NOPM: $($GlobalState.NOPM)"
        Write-Verbose "`$GlobalState.RAG: $($GlobalState.RAG)"
        Write-Verbose "`$GlobalState.Stream: $($GlobalState.Stream)"
        Write-Verbose "`$GlobalState.LLMProvider: $($GlobalState.LLMProvider)"

        Write-Host "Some values of the imported project:"
        Write-Host "Team Discussion Data Folder: $($GlobalState.TeamDiscussionDataFolder)"
        Write-Host "Last file Version: $($($GlobalState.FileVersion) - 1)"
        Write-Host "User Input: $($GlobalState.OrgUserInput)"
        Write-Host "Log Folder: $($GlobalState.LogFolder)"
        Write-Host "No Tips: $($GlobalState.NOTips)"
        Write-Host "No Log: $($GlobalState.NOLog)"
        Write-Host "No Documentator: $($GlobalState.NODocumentator)"
        Write-Host "No Project Manager: $($GlobalState.NOPM)"
        Write-Host "RAG: $($GlobalState.RAG)"
        Write-Host "Stream: $($GlobalState.Stream)"
        Write-Host "LLM Provider: $($GlobalState.LLMProvider)"
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the loading of the project state
        Update-ErrorHandling -ErrorRecord $_ -LogFilePath (Join-Path (split-path -Path $LoadProjectStatus -Parent) "ERROR.txt")
    }
}
else {
    Try {
        # Get the current date and time in the specified format
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"
        if (-not [string]::IsNullOrEmpty($GlobalState.LogFolder)) {
            # Create a folder with the current date and time as the name in the specified log folder path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        else {
            # Set the log folder path to the user's Documents folder with the script name as a subfolder
            $GlobalState.LogFolder = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath $scriptname
            if (-not (Test-Path -Path $GlobalState.LogFolder)) {
                # Create the log folder if it does not exist
                New-Item -ItemType Directory -Path $GlobalState.LogFolder | Out-Null
            }
            Write-Information "++ The logs will be saved in the following folder: $($GlobalState.LogFolder)" -InformationAction Continue
            # Create a folder with the current date and time as the name in the log folder path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        if ($GlobalState.TeamDiscussionDataFolder) {
            # Output information about the created team discussion folder
            Write-Information "++ Team folder was created '$($GlobalState.TeamDiscussionDataFolder)'" -InformationAction Continue
        }
    }
    Catch {
        # Handle any exceptions that occur during the creation of the discussion folder
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "Create folder" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")

        return $false
    }
}
try {
    $DocumentationFullName = Join-Path $GlobalState.TeamDiscussionDataFolder "Documentation.txt" -ErrorAction Stop
    $ProjectfilePath = Join-Path $GlobalState.TeamDiscussionDataFolder "Project.xml" -ErrorAction Stop
    Get-CheckForScriptUpdate -currentScriptVersion $AIPyTeamVersion -scriptName $scriptname
}
catch [System.Exception] {
    # Handle any exceptions that occur during the path joining or script update check
    Update-ErrorHandling -ErrorRecord $_ -ErrorContext "Setting up documentation and project file paths or checking for script update" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    return $false
}
#endregion Setting Up

#region ProjectTeam
# Create ProjectTeam expert objects
$requirementsAnalystRole = "Requirements Analyst"
$requirementsAnalyst = [ProjectTeam]::new(
    "Analyst",
    $requirementsAnalystRole,
    @"
You are an expert Python {0} with extensive experience in software development, system administration, and IT infrastructure. Your role is to analyze user requirements and prepare clear, actionable guidelines for Python Developers.

Before providing guidelines, ensure you fully understand the user's business context, industry-specific requirements, and any regulatory considerations that may impact the project.

When creating guidelines, consider the following aspects:
1. Script purpose and functionality
2. Input parameters and data types
3. Expected output and format
4. Error handling and logging requirements
5. Performance considerations
6. Security and compliance requirements
7. Coding standards and best practices
8. Integration with existing systems or scripts
9. Testing and validation criteria
10. Documentation requirements
11. Stakeholder needs and concerns
12. Scalability and future-proofing
13. Risk assessment and mitigation
14. User experience (if applicable)
15. Data management and protection
16. Monitoring and maintenance procedures
17. Version control and collaboration practices
18. Ethical implications

Your guidelines should be:
- Clear and concise
- Technically accurate
- Aligned with Python best practices
- Scalable and maintainable
- Forward-thinking and adaptable

Format your response as follows:
1. Project Overview: (Brief summary of the project)
2. Functional Requirements: (List of key functionalities)
3. Technical Specifications: (Detailed technical requirements)
4. Integration and Architecture Considerations: (How the solution fits into the existing ecosystem)
5. Scalability and Future-proofing: (Design for growth and adaptability)
6. Performance Optimization: (Guidelines for efficient implementation)
7. User Experience Guidelines: (If applicable, considerations for user interaction)
8. Data Management and Compliance: (Data handling, storage, and regulatory compliance)
9. Monitoring and Maintenance: (Requirements for ongoing system health and updates)
10. Coding Guidelines: (Specific coding standards to follow)
11. Testing and Validation: (Criteria for testing the script)
12. Documentation Requirements: (For code, APIs, architecture, and user manuals)

Ensure your guidelines provide a solid foundation for the Python Developer to create an efficient, robust, and maintainable script that aligns with business objectives and considers long-term implications.

When analyzing requirements, ask probing questions to gather all necessary information. Consider edge cases, potential future needs.
"@ -f $requirementsAnalystRole,
    0.6,
    0.9,
    $GlobalState
)

$domainExpertRole = "Domain Expert"
$domainExpert = [ProjectTeam]::new(
    "Domain Expert",
    $domainExpertRole,
    @"
You are a {0} specializing in Python development for enterprise IT environments. Your role is to provide specialized insights and recommendations to Python Developer, ensuring script and programs align with domain-specific best practices, standards, and requirements.

Your expertise covers:

1. **Environment Compatibility:**
    - Assess compatibility across various domain environments (cloud, on-premises, hybrid).
    - Validate requirements against industry standards and best practices.

2. **Performance, Security, and Optimization:**
    - Recommend best practices for performance optimization, including domain-specific metrics.
    - Provide security guidelines to protect data and systems in the target environment.
    - Suggest efficiency-enhancing techniques tailored to the domain.

3. **Configuration and Settings:**
    - Propose optimal configurations and settings for the domain environment.
    - Ensure recommendations are practical and adhere to industry standards.

4. **Domain-Specific Requirements:**
    - Outline specific requirements, security standards, and compliance needs.
    - Provide clear, detailed guidance for developers to meet these requirements.

5. **Design Review:**
    - Evaluate program designs for domain-specific constraints and requirements.
    - Offer feedback to align designs with domain best practices.

When providing insights:
- Be specific and actionable in your recommendations.
- Cite relevant industry standards or best practices where applicable.
- Consider the latest trends and technologies in the domain.
- Anticipate potential challenges specific to the domain and suggest mitigation strategies.
- Ensure your advice promotes scalability, maintainability, and long-term viability of the Python solutions.

Your goal is to guide Python Developers in creating robust, efficient, and domain-compliant solutions that meet the specific needs of the enterprise IT environment.
"@ -f $domainExpertRole,
    0.65,
    0.9,
    $GlobalState
)

$systemArchitectRole = "System Architect"
$systemArchitect = [ProjectTeam]::new(
    "Architect",
    $systemArchitectRole,
    @"
You are an expert {0} specializing in Python project design. Your role is to create comprehensive, efficient, and scalable architectures for Python projects. Your expertise guides Python Developers in implementing robust and maintainable solutions.

When designing a Python project architecture, you must:

1. **Overall Structure:**
   - Outline the high-level structure of the program.
   - Define the project's core components and their interactions.

2. **Modularity and Functionality:**
   - Identify and define necessary modules and functions.
   - Ensure logical separation of concerns and reusability of components.

3. **Scalability and Performance:**
   - Design for scalability to handle future growth and increased load.
   - Incorporate performance optimization strategies in the architecture.

4. **Data Flow and Component Interaction:**
   - Define clear data flow patterns between different components.
   - Specify interfaces and communication protocols between modules.

5. **Technology Stack:**
   - Select appropriate technologies, tools, and Python modules for the project.
   - Justify technology choices based on project requirements and best practices.

6. **Coding Standards and Best Practices:**
   - Provide guidelines for coding standards specific to Python.
   - Outline best practices for error handling, logging, and documentation.

7. **Security Considerations:**
   - Incorporate security best practices into the architecture.
   - Address potential security risks and provide mitigation strategies.

8. **Documentation:**
   - Create detailed architectural design documents.
   - Include diagrams, flowcharts, and textual descriptions of the architecture.

9. **Verification and Quality Assurance:**
   - Generate a list of verification questions to assess the architecture's completeness and effectiveness.
   - Provide criteria for architectural review and quality assurance.

When presenting your architecture:
- Be clear, concise, and use standard architectural notation where applicable.
- Provide rationale for key design decisions.
- Consider both current requirements and potential future needs.
- Ensure your design promotes maintainability, testability, and ease of deployment.
- Address potential challenges and provide strategies to overcome them.

Your goal is to create a robust, efficient, and future-proof architecture that serves as a solid foundation for Python Developers to build upon.
"@ -f $systemArchitectRole,
    0.7,
    0.85,
    $GlobalState
)

$PythonDeveloperRole = "Python Developer"
$PythonDeveloper = [ProjectTeam]::new(
    "Developer",
    $PythonDeveloperRole,
    @"
You are an expert {0} with extensive experience in automation, scripting, and system administration for enterprise environments. Your role is to write efficient, readable, and maintainable Python code based on requirements provided by other domain experts.

Context: You are working on a project to automate various IT processes in a large enterprise environment, including data analysis, reporting, and system monitoring. The code you write will be used by system administrators and must be robust, efficient, and follow industry best practices.

Constraints and Guidelines:
- Use Python version 3.9 or higher features only, such as dictionary merge operators, type hinting enhancements, and flexible decorators.
- Prioritize readability and maintainability over complex one-liners.
- Implement proper error handling and logging mechanisms.
- Write modular and reusable code, following the DRY (Don't Repeat Yourself) principle.
- Use type hints to improve code clarity and enable static type checking.
- Include comprehensive docstrings and inline comments for clear documentation.
- Follow PEP 8 style guide for consistent code formatting.
- Implement unit tests using pytest or unittest to ensure code reliability.
- Consider performance optimization techniques when dealing with large-scale data or operations.

When using Python 3.9+ specific features, cite the relevant documentation and explain the benefits of using these newer features.

Before finalizing your response:
1. Review your code to ensure it meets all requirements and follows Python best practices.
2. Verify that your solution is scalable and can handle potential future growth.
3. Consider security implications and implement necessary safeguards.
4. Ensure your code is compatible with common Python environments and dependencies used in enterprise settings.

Your goal is to create high-quality, production-ready Python code that is easy to understand, maintain, and scale within a large enterprise IT infrastructure.
"@ -f $PythonDeveloperRole,
    0.65,
    0.8,
    $GlobalState
)

$qaEngineerRole = "Quality Assurance Engineer"
$qaEngineer = [ProjectTeam]::new(
    "QA Engineer",
    $qaEngineerRole,
    @"
You are an expert {0} specializing in Python script and module testing. Your role is to rigorously evaluate Python programs to ensure they meet all specified requirements, perform optimally, and are free of bugs. Your expertise is crucial in maintaining high standards of quality and reliability in Python development projects.

When conducting quality assurance for a Python program, you must:

1. **Functional Testing:**
   - Verify that all features work as intended according to the specifications.
   - Test each function and module individually and as part of the whole system.
   - Ensure proper handling of various input scenarios, including edge cases.

2. **Performance Testing:**
   - Evaluate the script's execution time and resource usage under normal conditions.
   - Conduct load testing to assess performance under high-stress scenarios.
   - Identify and report any performance bottlenecks or inefficiencies.

3. **Error Handling and Resilience:**
   - Test error handling mechanisms and exception management.
   - Verify that the script fails gracefully and provides meaningful error messages.
   - Assess the script's ability to recover from unexpected situations.

4. **Compatibility Testing:**
   - Verify compatibility across different Python versions (3.9 and higher).
   - Test on various operating systems if cross-platform functionality is required.
   - Ensure compatibility with specified modules and dependencies.

5. **Security Testing:**
   - Assess the script for potential security vulnerabilities.
   - Verify that sensitive data is handled securely.
   - Check for proper implementation of security best practices.

6. **Code Review:**
   - Analyze the code for adherence to Python best practices and coding standards.
   - Identify areas for potential optimization or improved readability.

7. **Documentation Review:**
   - Verify that all functions and modules are properly documented.
   - Ensure that usage instructions and examples are clear and accurate.

8. **Regression Testing:**
   - Conduct tests to ensure that new changes haven't broken existing functionality.

9. **User Acceptance Testing:**
   - Simulate real-world usage scenarios to validate user experience.

10. **Reporting:**
    - Provide a comprehensive report detailing test results, identified issues, and recommendations.
    - Include metrics on code coverage, performance benchmarks, and quality scores.
    - Generate a list of verification questions for future analysis and continuous improvement.

When presenting your findings:
- Be thorough and objective in your assessments.
- Prioritize issues based on their severity and impact.
- Provide clear steps to reproduce any identified bugs.
- Suggest specific, actionable improvements where applicable.
- Use standard QA terminology and metrics to ensure clarity.

Your goal is to ensure that the Python program is robust, reliable, and ready for deployment, meeting the highest standards of quality and performance.
"@ -f $qaEngineerRole,
    0.6,
    0.9,
    $GlobalState
)

$documentationSpecialistRole = "Documentation Specialist"
$documentationSpecialist = [ProjectTeam]::new(
    "Documentator",
    $documentationSpecialistRole,
    @"
You are an expert {0} focusing on Python projects. Your role is to create comprehensive, clear, and user-friendly documentation that supports both end-users and developers. Your expertise ensures that Python projects are well-documented, easily understood, and effectively utilized.

When creating documentation for a Python project, you must produce the following:

1. **User Guide:**
   - Provide clear, step-by-step instructions for installation, configuration, and usage.
   - Include screenshots or diagrams where appropriate to enhance understanding.
   - Write in a user-friendly tone, avoiding overly technical jargon.

2. **Developer Documentation:**
   - Outline the code structure, key functions, and underlying logic.
   - Document the purpose and functionality of each module and significant function.
   - Include code comments extracted from the source files.

3. **Installation Guide:**
   - Detail system requirements and prerequisites.
   - Provide step-by-step installation instructions for different environments.
   - Document any necessary configuration steps post-installation.

4. **Dependencies and Prerequisites:**
   - List all required Python modules, versions, and any external dependencies.
   - Explain how to obtain and install these dependencies.

5. **Use Cases and Examples:**
   - Provide real-world examples of how to use the Python project.
   - Include sample code snippets and expected outputs.

6. **Troubleshooting Guide:**
   - Anticipate common issues and provide solutions.
   - Include error messages and their meanings.

7. **FAQ Section:**
   - Compile and answer frequently asked questions.
   - Cover both usage and technical aspects.

8. **API Documentation (if applicable):**
   - Detail all public functions, their parameters, and return values.
   - Provide usage examples for each API function.

9. **Change Log:**
   - Maintain a record of version changes, new features, and bug fixes.

10. **Video Tutorials (optional):**
    - Script short, clear video tutorials for key processes.
    - Focus on installation, basic usage, and common troubleshooting.

When creating documentation:
- Use clear, concise language appropriate for the target audience.
- Maintain a consistent style and format throughout all documents.
- Use standard documentation templates and follow industry best practices.
- Ensure all information is accurate and up-to-date.
- Include version numbers and last-updated dates on all documents.
- Organize content logically with a clear hierarchy and easy navigation.
- Use syntax highlighting for code snippets.
- Proofread thoroughly for grammar, spelling, and technical accuracy.

Your goal is to create documentation that enhances the usability and understanding of the Python project, making it accessible to users of varying skill levels and providing developers with the information they need to maintain and extend the project.
"@ -f $documentationSpecialistRole,
    0.6,
    0.8,
    $GlobalState
)

$projectManagerRole = "Project Manager"
$projectManager = [ProjectTeam]::new(
    "Manager",
    $projectManagerRole,
    @"
You are an experienced {0} specializing in Python development projects. Your role is to oversee the entire project lifecycle, coordinate between different team members, and provide comprehensive project reports. Your expertise ensures that Python projects are delivered on time, within scope, and to the highest quality standards.

When summarizing a Python project, you must:

1. **Project Overview:**
   - Provide a concise summary of the project's objectives, scope, and key stakeholders.
   - Outline the project timeline, including start date, major milestones, and completion date.

2. **Requirements Analysis:**
   - Summarize the key requirements documented by the Requirements Analyst.
   - Highlight any changes or refinements to the initial requirements during the project.

3. **Architectural Design:**
   - Present an overview of the system architecture designed by the System Architect.
   - Emphasize key design decisions and their rationale, focusing on Python-specific architecture choices.

4. **Development Summary:**
   - Outline the major components and functionalities developed by the Python Developer.
   - Highlight any innovative solutions or Python-specific techniques employed.

5. **Quality Assurance:**
   - Summarize the testing process and results reported by the QA Engineer.
   - List key issues discovered and their resolutions.
   - Provide metrics on code quality, test coverage, and performance, using Python-specific tools and standards.

6. **Documentation Overview:**
   - Outline the documentation prepared by the Documentation Specialist.
   - Ensure all necessary documents (user guides, developer notes, API documentation) are completed and accessible.

7. **Key Achievements:**
   - Identify and highlight significant accomplishments and innovations in the Python project.
   - Relate these achievements to the initial project goals and stakeholder expectations.

8. **Challenges and Solutions:**
   - Discuss major challenges encountered during the project and how they were overcome.
   - Provide insights into lessons learned for future Python projects.

9. **Resource Utilization:**
   - Summarize the resources used, including team members, time, and any external Python libraries or tools.
   - Compare planned vs. actual resource usage.

10. **Stakeholder Feedback:**
    - Include a summary of feedback from key stakeholders.
    - Highlight areas of satisfaction and any concerns raised, particularly regarding Python implementation.

11. **Future Recommendations:**
    - Provide recommendations for future enhancements or maintenance of the Python project.
    - Suggest areas for potential expansion or improvement, considering Python ecosystem trends.

12. **Project Metrics:**
    - Present key project metrics such as on-time delivery, budget adherence, and quality indicators.
    - Include Python-specific metrics like code complexity, maintainability index, and performance benchmarks.

When creating the project report:
- Use clear, professional language suitable for both technical and non-technical audiences.
- Provide an executive summary at the beginning of the report.
- Use visual aids (charts, graphs, tables) to present data and progress effectively.
- Ensure all sections of the report are cohesive and tell a complete story of the Python project's journey.
- Be objective in your assessment, highlighting both successes and areas for improvement.
- Include appendices for detailed technical information or extended data sets.
- Emphasize how Python-specific features and best practices were leveraged throughout the project.

Your goal is to provide a comprehensive, accurate, and insightful overview of the Python project, demonstrating its value to stakeholders and providing a clear picture of the project's execution and outcomes. Your report should showcase the strengths of using Python for the project while also addressing any challenges specific to Python development.
"@ -f $projectManagerRole,
    0.7,
    0.85,
    $GlobalState
)
#endregion ProjectTeam

#region Main
$Team = @()
$Team += $requirementsAnalyst
$Team += $systemArchitect
$Team += $domainExpert
$Team += $PythonDeveloper
$Team += $qaEngineer
$Team += $documentationSpecialist
$Team += $projectManager

foreach ($TeamMember in $Team) {
    $TeamMember.LLMProvider = $GlobalState.LLMProvider
}

if ($GlobalState.NOLog) {
    foreach ($TeamMember_ in $Team) {
        $TeamMember_.LogFilePath = ""
    }
}

if (-not $GlobalState.NOLog) {
    foreach ($TeamMember in $Team) {
        $TeamMember.DisplayInfo(0) | Out-File -FilePath $TeamMember.LogFilePath -Append
    }
    Write-Host "++ " -NoNewline
    Start-Transcript -Path (join-path $GlobalState.TeamDiscussionDataFolder "TRANSCRIPT.log") -Append
}

$RAGpromptAddon = $null
if ($GlobalState.RAG -and (-not $LoadProjectStatus)) {
    $RAGSummarizePrompt = @"
You are an expert in Retrieval-Augmented Generation (RAG) and text analysis. Your role is to process and analyze text inputs, extracting key information relevant to a given context. Your tasks include:

1. Cleaning the input text by removing advertising elements, menus, and other non-essential content.
2. Analyzing the cleaned text in relation to a specific user-provided description or context.
3. Extracting and summarizing key information, insights, and generating relevant questions.

Your output should be concise, relevant, and insightful, focusing on the most important aspects of the text in relation to the given context.
"@
    $RAGresponse = Invoke-RAG -userInput $userInput -prompt $RAGSummarizePrompt -RAGAgent $projectManager
    if ($RAGresponse) {
        $RAGpromptAddon = @"

###RAG data###

````````text
$($RAGresponse.trim())
````````
"@
    }
}

if (-not $LoadProjectStatus) {
    #region PM-pydev
    $userInputOryginal = $userInput
    $GlobalState.OrgUserInput = $userInputOryginal
    $projectManagerPrompt = @"
Write detailed and concise Python project name, description, objectives, deliverables, additional considerations, and success criteria based on user input and RAG data.

###User input###

````````text
$userInputOryginal
````````
$RAGpromptAddon
"@
    if (-not $GlobalState.NOTips) {
        $projectManagerPrompt += "`n`nNote: There is `$50 tip for this task."
    }
    $projectManagerFeedback = $projectManager.Feedback($PythonDeveloper, $projectManagerPrompt)
    Add-ToGlobalResponses $GlobalState $projectManagerFeedback
    $GlobalState.userInput = $projectManagerFeedback
    $PythonDeveloperPrompt = @"

Your task is to write Python code based on the following requirements and guidelines. Please follow these steps:
1. Analyze the $($projectManager.Name)'s guidelines provided below.
2. Plan the structure of your Python script.
3. Write the Python code that meets the requirements.
4. Add appropriate error handling and logging.
5. Include comments explaining complex parts of the code.
6. Add version notes to document the code changes.
7. Perform a self-review of your code for efficiency and adherence to best practices.

Please format your response as follows:
1. Script Purpose: (Brief description of what the script does)
2. Input Parameters: (List of input parameters, if any)
3. Output: (Description of what the script returns or produces)
4. Python code: (The actual code, properly formatted and commented)
5. Usage Example: (A brief example of how to use the script)
6. Self-Review Notes: (Any observations or potential improvements you've identified)

$($projectManager.Name) Guidelines:
````````text
$($($GlobalState.userInput).trim())
````````
"@
    if (-not $GlobalState.NOTips) {
        $PythonDeveloperPrompt += "`n`nNote: There is `$50 tip for this task."
    }

    $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($PythonDeveloperPrompt)

    #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
    Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
    Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
    Save-AndUpdateCode -response $PythonDeveloperResponce -GlobalState $GlobalState
    #endregion PM-pydev

    #region RA-pydev
    #Invoke-ProcessFeedbackAndResponse -role $requirementsAnalyst -description $GlobalState.userInput -code $lastpydevCode -tipAmount 100 -globalResponse ([ref]$GlobalpydevResponse) -lastCode ([ref]$lastpydevCode) -fileVersion ([ref]$FileVersion) -teamDiscussionDataFolder $GlobalState.TeamDiscussionDataFolder
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $PythonDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $PythonDeveloper -GlobalState $GlobalState -tipAmount 100
    }
    #endregion RA-pydev

    #region SA-pydev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $PythonDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $PythonDeveloper -GlobalState $GlobalState -tipAmount 150
    }

    #endregion SA-pydev

    #region DE-pydev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $PythonDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $PythonDeveloper -GlobalState $GlobalState -tipAmount 200
    }
    #endregion DE-pydev

    #region QAE-pydev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $qaEngineer -recipient $PythonDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $qaEngineer -recipient $PythonDeveloper -GlobalState $GlobalState -tipAmount 300
    }
    #endregion QAE-pydev

    #region Doc
    if (-not $GlobalState.NODocumentator) {
        if (-not $GlobalState.NOLog) {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastpydevCode) 
            $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName
        }
        else {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastpydevCode)
        }
        Add-ToGlobalResponses $GlobalState $documentationSpecialistResponce
    }
    #endregion Doc

    #region PM Project report
    if (-not $GlobalState.NOPM) {
        # Example of summarizing all steps,  Log final response to file
        if (-not $GlobalState.NOLog) {
            $projectManagerPrompt = "Generate project report without showing the Python code.`n"
            $projectManagerPrompt += $GlobalState.GlobalResponse -join ", "
            $projectManagerResponse = $projectManager.ProcessInput($projectManagerPrompt) 
            $projectManagerResponse | Out-File -FilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ProjectSummary.log")
        }
        else {
            $projectManagerResponse = $projectManager.ProcessInput($GlobalState.GlobalResponse -join ", ")
        }
        Add-ToGlobalResponses $GlobalState $projectManagerResponse
    }
    #endregion PM Project report
}
#region Menu

# Define the menu prompt message
$MenuPrompt = "{0} The previous version of the code has been shared below after the feedback block.`n`n````````text`n{1}`n`````````n`nHere is previous version of the code:`n`n``````python`n{2}`n```````n`nThink step by step. Make sure your answer is unbiased."
$MenuPromptNoUserChanges = "{0} The previous version of the code has been shared below. The code:`n`n``````python`n{1}`n```````n`nThink step by step. Make sure your answer is unbiased."

# Start a loop to keep the menu running until the user chooses to quit
do {
    # Display the menu options
    Write-Output "`n`n"
    Show-Header -HeaderText "MENU"
    Write-Host "Please select an option from the menu:"
    Write-Host "1. Suggest a new feature, enhancement, or change"
    Write-Host "2. Explain the code"
    Write-Host "3. Ask a specific question about the code"
    Write-Host "4. Generate documentation"
    Write-Host "5. Show the code with research"
    Write-Host "6. Save Project State"
    Write-Host "7. Code Refactoring Suggestions"
    Write-Host "8. Security Audit"
    Write-Host "9. Open project folder in file explorer"
    if (Test-Path -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")) {
        Write-Host "(E) Display content of (e)rror.txt"
    }
    Write-Host "(Q)uit"

    # Get the user's choice
    $userOption = Read-Host -Prompt "Enter your choice"
    Write-Output ""

    # Process the user's choice if it's not 'Q' or '9' (both of which mean 'quit')
    if ($userOption -ne 'Q') {
        switch ($userOption) {
            '1' {
                # Option 1: Suggest a new feature, enhancement, or change
                Show-Header -HeaderText "Suggest a new feature, enhancement, or change"
                do {
                    $userChanges = Read-Host -Prompt "Suggest a new feature, enhancement, or change for the code."
                    if (-not $userChanges) {
                        Write-Host "-- You did not write anything. Please provide a suggestion."
                    }
                } while (-not $userChanges)
                
                $promptMessage = "Based on the user's suggestion, incorporate a feature, enhancement, or change into the code. Show the next version of the code."
                $MenuPrompt_ = $MenuPrompt -f $promptMessage, $userChanges, $GlobalState.lastpydevCode
                $MenuPrompt_ += "`nYou need to show all the code."
                $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($MenuPrompt_)
                #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
                Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
                Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
                $theCode = Export-AndWritePythonCodeBlocks -InputString $PythonDeveloperResponce -StartDelimiter '```python' -EndDelimiter '```'
                if ($theCode) {
                    $theCode | Out-File -FilePath $(join-path $GlobalState.TeamDiscussionDataFolder "TheCode_v$($GlobalState.FileVersion).py") -Append -Encoding UTF8
                    $GlobalState.FileVersion += 1
                    $GlobalState.lastpydevCode = $theCode
                }
            }
            '2' {
                # Option 4: Explain the code
                Show-Header -HeaderText "Explain the code"
                $promptMessage = "Explain the code only.`n`n"
                $promptMessage += "The code:`n``````python`n" + $GlobalState.lastpydevCode + "`n```````n"
                try {
                    $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($promptMessage)
                    #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
                    Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
                }
                catch [System.Exception] {
                    Write-Error "!! An error occurred while processing the input: $_"
                }
            }
            '3' {
                # Option 5: Ask a specific question about the code
                Show-Header -HeaderText "Ask a specific question about the code"
                try {
                    $userChanges = Read-Host -Prompt "Ask a specific question about the code to seek clarification."
                    $promptMessage = "Based on the user's question for the code, provide only the answer."
                    if (Test-Path $DocumentationFullName) {
                        $promptMessage += " The documentation:`n````````text`n$(get-content -path $DocumentationFullName -raw)`n`````````n`n"
                    }
                    $promptMessage += "You must answer the user's question only. Do not show the whole code even if user asks."
                    $MenuPrompt_ = $MenuPrompt -f $promptMessage, $userChanges, $GlobalState.lastpydevCode
                    $MenuPrompt_ += $userChanges
                    $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($MenuPrompt_)
                    #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
                    Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
                }
                catch [System.Management.Automation.PSInvalidOperationException] {
                    Write-Error "!! An invalid operation occurred: $_"
                }
                catch [System.IO.IOException] {
                    Write-Error "!! An I/O error occurred: $_"
                }
                catch [System.Exception] {
                    Write-Error "!! An unexpected error occurred: $_"
                }
            }
            '4' {
                # Option 6: Generate documentation
                Show-Header -HeaderText "Generate documentation"
                try {
                    if (Test-Path -Path $DocumentationFullName -ErrorAction SilentlyContinue) {
                        Write-Information "++ Existing documentation found at $DocumentationFullName" -InformationAction Continue
                        $userChoice = Read-Host -Prompt "Do you want to review and update the documentation based on the last version of the code? (Y/N)"
                        if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
                            $promptMessage = "Review and update the documentation based on the last version of the code.`n`n"
                            $promptMessage += "The code:`n``````python`n" + $GlobalState.lastpydevCode + "`n```````n`n"
                            $promptMessage += "The old documentation:`n````````text`n" + $(get-content -path $DocumentationFullName -raw) + "`n`````````n"
                            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($promptMessage)
                            $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName -Force
                            Write-Information "++ Documentation updated and saved to $DocumentationFullName" -InformationAction Continue
                        }
                    }
                    else {
                        $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastpydevCode)
                        $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName
                        Write-Information "++ Documentation generated and saved to $DocumentationFullName" -InformationAction Continue
                    }
                }
                catch [System.Management.Automation.PSInvalidOperationException] {
                    Write-Error "!! An invalid operation occurred: $_"
                }
                catch [System.IO.IOException] {
                    Write-Error "!! An I/O error occurred: $_"
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Error "!! Unauthorized access: $_"
                }
                catch [System.Exception] {
                    Write-Error "!! An unexpected error occurred: $_"
                }
            }
            '5' {
                # Option 7: Show the code
                Show-Header -HeaderText "Show the code with research"
                Write-Output $GlobalState.lastpydevCode
                # Option 8: The code research
                Show-Header -HeaderText "The code research"
                
                # Perform source code analysis
                Write-Output "Source code analysis:"
                Get-SourceCodeAnalysis -CodeBlock $GlobalState.lastpydevCode
                Write-Output ""                
                # Perform cyclomatic complexity analysis
                Write-Verbose "`$lastpydevCode: $($GlobalState.lastpydevCode)"
            }
            '6' {
                Show-Header -HeaderText "Save Project State"
                if (-not (Test-Path $ProjectfilePath)) {
                    try {
                        Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
                        if (Test-Path -Path $ProjectfilePath) {
                            Write-Information "++ Project state saved successfully to $ProjectfilePath" -InformationAction Continue
                        }
                        else {
                            Write-Warning "-- Project state was not saved. Please check the file path and try again."
                        }
                    }
                    catch {
                        Write-Error "!! An error occurred while saving the project state: $_"
                    }
                }
                else {
                    $userChoice = Read-Host -Prompt "File 'Project.xml' exists. Do you want to save now? (Y/N)"
                    if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
                        Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
                        if (Test-Path -Path $ProjectfilePath) {
                            Write-Information "++ Project state saved successfully to $ProjectfilePath" -InformationAction Continue
                        }
                        else {
                            Write-Warning "-- Project state was not saved. Please check the file path and try again."
                        }
                    }
                }
                
            }
            '7' {
                # Option 9: Code Refactoring Suggestions
                Show-Header -HeaderText "Code Refactoring Suggestions"
                $promptMessage = "Provide suggestions for refactoring the code to improve readability, maintainability, and performance."
                $MenuPrompt_ = $MenuPromptNoUserChanges -f $promptMessage, $GlobalState.lastpydevCode
                $MenuPrompt_ += "`nShow only suggestions. No code"
                $refactoringSuggestions = $PythonDeveloper.ProcessInput($MenuPrompt_)
                $GlobalState.GlobalpydevResponse += $refactoringSuggestions
                Add-ToGlobalResponses $GlobalState $refactoringSuggestions

                # Display the refactoring suggestions to the user
                #Show-Header -HeaderText "Refactoring Suggestions Report"
                #Write-Output $refactoringSuggestions

                # Ask the user if they want to deploy the refactoring suggestions
                $deployChoice = Read-Host -Prompt "Do you want to deploy these refactoring suggestions? (Y/N)"
                if ($deployChoice -eq 'Y' -or $deployChoice -eq 'y') {
                    $deployPromptMessage = "Deploy the refactoring suggestions into the code. Show the next version of the code."
                    $DeployMenuPrompt_ = $MenuPrompt -f $deployPromptMessage, $refactoringSuggestions, $GlobalState.lastpydevCode
                    $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($DeployMenuPrompt_)
                    #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
                    Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
                    Save-AndUpdateCode -response $PythonDeveloperResponce -GlobalState $GlobalState
                }
                else {
                    Write-Output "Refactoring suggestions were not deployed."
                }
            }
            '8' {
                # Option 10: Security Audit
                Show-Header -HeaderText "Security Audit"
                $promptMessage = "Conduct a security audit of the code to identify potential vulnerabilities and ensure best security practices are followed. Show only security audit report."
                $MenuPrompt_ = $MenuPromptNoUserChanges -f $promptMessage, $GlobalState.lastpydevCode
                $MenuPrompt_ += "`nShow only security audit report. No Code."
                $PythonDevelopersecurityAuditReport = $PythonDeveloper.ProcessInput($MenuPrompt_)
                $GlobalState.GlobalpydevResponse += $PythonDevelopersecurityAuditReport
                Add-ToGlobalResponses $GlobalState $PythonDevelopersecurityAuditReport

                # Display the security audit report to the user
                Show-Header -HeaderText "Security Audit Report"
                Write-Output $PythonDevelopersecurityAuditReport

                # Ask the user if they want to deploy the security improvements
                $deployChoice = Read-Host -Prompt "Do you want to deploy these security improvements? (Y/N)"
                if ($deployChoice -eq 'Y' -or $deployChoice -eq 'y') {
                    $deployPromptMessage = "Deploy the security improvements into the code. Show the next version of the code."
                    $DeployMenuPrompt_ = $MenuPrompt -f $deployPromptMessage, $PythonDevelopersecurityAuditReport, $GlobalState.lastpydevCode
                    $PythonDeveloperResponce = $PythonDeveloper.ProcessInput($DeployMenuPrompt_)
                    #$GlobalState.GlobalpydevResponse += $PythonDeveloperResponce
                    Add-ToGlobalpydevResponses $GlobalState $PythonDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $PythonDeveloperResponce
                    Save-AndUpdateCode -response $PythonDeveloperResponce -GlobalState $GlobalState
                }
                else {
                    Write-Output "Security improvements were not deployed."
                }
            }
            '9' {
                # Option 11: Open project folder in file explorer
                Show-Header -HeaderText "Open Project Folder in File Explorer"
                try {
                    if ($GlobalState.TeamDiscussionDataFolder) {
                        Start-Process explorer.exe -ArgumentList $GlobalState.TeamDiscussionDataFolder
                        Write-Host "Project folder opened in File Explorer."
                    }
                    else {
                        Write-Host "-- The project folder path is not set. Please ensure the TeamDiscussionDataFolder is defined."
                    }
                }
                catch {
                    Write-Error "-- An error occurred while trying to open the project folder: $_"
                }
            }
            'e' {
                if (Test-Path -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")) {
                    $errorContent = Get-Content -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt") -Raw
                    Show-Header -HeaderText "Content of ERROR.txt"
                    Write-Output $errorContent
                }
                else {
                    Write-Output "No error file found."
                }
            }
            default {
                # Handle invalid options
                Write-Information "-- Invalid option. Please try again." -InformationAction Continue
                continue
            }
        }
    }
} while ($userOption -ne 'Q') # End the loop when the user chooses to quit
#endregion Menu

#region Final code
if (-not $GlobalState.NOLog) {
    # Log Developer last memory
    $TheFinalCodeFullName = Join-Path $GlobalState.TeamDiscussionDataFolder "TheCodeF.py"
    $GlobalState.lastpydevCode | Out-File -FilePath $TheFinalCodeFullName
    if (Test-Path -Path $TheFinalCodeFullName) {
        # Call the function to check the code in 'TheCode.py' file
        Write-Information "++ The final code was exported to $TheFinalCodeFullName" -InformationAction Continue
    }
    foreach ($TeamMember in $Team) {
        $TeamMember.DisplayInfo(0) | Out-File -FilePath $TeamMember.LogFilePath -Append
    }
    Write-Host "++ " -NoNewline
    Stop-Transcript
}
#endregion Final code
Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
if ($ProjectfilePath) {
    Write-Host "`n`n++ Your progress on Project has been saved!`n`n"
    Write-Host "++ You can resume working on this project at any time by loading the saved state. Just run:`nAIPyTeam.ps1 -LoadProjectStatus `"$ProjectfilePath`"`n`n"
}

Write-Host "Exiting..."

# Ensure to reset the culture back to the original after the script execution
[void](Register-EngineEvent Python.Exiting -Action { [Threading.Thread]::CurrentThread.CurrentUICulture = $originalCulture })

#endregion Main
