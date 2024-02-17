﻿#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.3.0" }

BeforeAll {
    $script:ModuleRoot = Split-Path $PSScriptRoot -Parent
    $script:ModuleName = 'PSOpenAI'
    $script:TestData = Join-Path $PSScriptRoot 'TestData'
    Import-Module (Join-Path $script:ModuleRoot "$script:ModuleName.psd1") -Force
}

Describe 'ConvertTo-Token' {
    Context 'Unit tests (offline)' -Tag 'Offline' {
        BeforeEach {
            $script:Result = $null
        }

        It 'Encoding: cl100k_base (<Id>)' -ForEach @(
            @{ Id = 1; Text = ''; Token = @() }
            @{ Id = 2; Text = 'a'; Token = , 64 }
            @{ Id = 3; Text = 'Hello, World! How are you today? 🌍'; Token = (9906, 11, 4435, 0, 2650, 527, 499, 3432, 30, 11410, 234, 235) }
            @{ Id = 4; Text = 'こんにちは、世界！お元気ですか？'; Token = (90115, 5486, 3574, 244, 98220, 6447, 33334, 24186, 95221, 38641, 32149, 11571) }
            @{ Id = 5; Text = 'Здравствуйте, это мой первый раз здесь. Что мне делать?'; Token = (36551, 7094, 28086, 20812, 83680, 51627, 11, 68979, 11562, 16742, 77901, 35723, 39479, 11122, 7094, 92691, 13, 1301, 100, 25657, 11562, 79862, 95369, 18482, 30) }
            @{ Id = 6; Text = '🍏🍎🍐🍊🍋🍌🍉🍇🍓🍈🍒🍑'; Token = (9468, 235, 237, 9468, 235, 236, 9468, 235, 238, 9468, 235, 232, 9468, 235, 233, 9468, 235, 234, 9468, 235, 231, 9468, 235, 229, 9468, 235, 241, 9468, 235, 230, 9468, 235, 240, 9468, 235, 239) }
        ) {
            (ConvertTo-Token -Text $Text -Encoding 'cl100k_base') | Should -Be $Token
        }

        It 'From model name (<Model>)' -ForEach @(
            @{Model = 'gpt-3.5-turbo-0613'; Expected = 5584 }
            @{Model = 'gpt-4-unknown'; Expected = 5584 }
            @{Model = 'text-embedding-3-small'; Expected = 5584 }
        ) {
            $Text = Get-Content ($script:TestData + '/lib.rs.txt') -Raw
            { $script:Result = ConvertTo-Token -Text $Text -Model $Model -ErrorAction Stop } | Should -Not -Throw
            $script:Result | Should -HaveCount $Expected
        }

        It 'Input from pipeline' {
            $script:Result = '🍏🍎🍐🍊🍋🍌🍉🍇🍓🍈🍒🍑' | ConvertTo-Token
            $script:Result | Should -HaveCount 36
        }

        It 'Input from pipeline (array of string)' {
            $script:Result = 'Hello my student.', 'How are you today?' | ConvertTo-Token
            $script:Result | Should -HaveCount 2
            $script:Result[0] | Should -Be @(9906, 856, 5575, 13)
            $script:Result[1] | Should -Be @(4438, 527, 499, 3432, 30)
        }
    }
}
