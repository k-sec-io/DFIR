function Get-ParsedDNSDebugLog
{
    <#
    .SYNOPSIS
    This cmdlet parses a Windows DNS Debug log with details.

    Author: @ksec_io
    License: GPL-3.0 License
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION
    When a DNS log is converted with this cmdlet it will be turned into objects for further parsing.

    .EXAMPLE 1
    PS C:\> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -force
    PS C:\> . .\windows_dns_debug_log_parser.ps1
    PS C:\> Get-ParsedDNSDebugLog -DNSLogFile ".\dns.log" -debugmode "no"

        DNS_DateTime      : 7/17/2020 3:21:52 PM
        DNS_Remote_IP     : ::1
        DNS_ResponseCode  : NOERROR
        DNS_Question_Type : A
        DNS_Question_Name : www.google.com.hk
        DNS_DATA          : 172.217.24.67

    .EXAMPLE 2
    PS C:\> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -force
    PS C:\> . .\windows_dns_debug_log_parser
    PS C:\> Get-ParsedDNSDebugLog -DNSLogFile ".\dns5.log" -debugmode "no" | Where-Object DNS_Question_Name -like *msedge.api.cdp.microsoft.com* | Format-Table -Property * -Autosize | Out-String -Width 192

        DNS_DateTime         DNS_Remote_IP DNS_ResponseCode DNS_Question_Type DNS_Question_Name            DNS_DATA                                                                           
          
        ------------         ------------- ---------------- ----------------- -----------------            --------   
        7/17/2020 3:06:15 PM ::1           NOERROR          A                 msedge.api.cdp.microsoft.com api.cdp.microsoft.com....                                                          
          
        7/17/2020 3:06:15 PM 127.0.0.1     NOERROR          A                 msedge.api.cdp.microsoft.com api.cdp.microsoft.com....         

    .EXAMPLE 3
    PS C:\> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -force
    PS C:\> . .\windows_dns_debug_log_parser.ps1
    PS C:\> Get-ParsedDNSDebugLog -DNSLogFile ".\dns5.log" -debugmode "no" | Where-Object DNS_Question_Name -like *msedge.api.cdp.microsoft.com* | export-csv -Path dns.csv -NoTypeInformation
    #>

    [CmdletBinding()]
    param(
      [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias('Fullname')]
      [ValidateScript({Test-Path($_)})]
      [string] $DNSLogFile = 'StringMode',
      [string] $debugmode = 'StringMode')


    BEGIN { }

    PROCESS {
        try
        {

            #^(?<DNS_DateTime>\d{1,2}\/\d{1,2}\/\d{4} \d{1,2}:\d{1,2}:\d{1,2} (AM|PM))\s{1}(?<DNS_ThreadID>\w{4})\s{1}(?<DNS_Context>PACKET)\s{2}(?<DNS_Internal_packet_identifier>\w{16})\s{1}(?<DNS_UDP_TCP_indicator>(TCP|UDP))\s{1,2}(?<DNS_Send_Receive_indicator>(Snd|Rcv))\s{1}(?<DNS_Remote_IP>(::1|127.0.0.1|\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}))\s+(?<DNS_Xid_hex>\w{4})\s{1}(?<DNS_Query_Response>(R| ))\s{1}(?<DNS_Opcode>\w{1})\s{1}\[(?<DNS_Flags_hex>\w{4})\s(?<DNS_Flags_char_codes>.*?)(?<DNS_ResponseCode>\w+)]\s{1}(?<DNS_Question_Type>\w+)\s+(?<DNS_Question_Name>.*?)\n(?ms).*?\s{4}QUESTION SECTION:\n(?<QUESTION_SECTION>.*?)\n\s{4}ANSWER SECTION:\n(?<ANSWER_SECTION>.*?)\s{4}AUTHORITY SECTION:\n(?<AUTHORITY_SECTION>.*?)\s{4}ADDITIONAL SECTION:\n(?<ADDITIONAL_SECTION>.*?)\n\n

            #empty array
            $AllObjectsArray = @()
            
            $ALL_DNS_DATA = (Get-Content $DNSLogFile -raw) -split '\r\n\r\n'
            $ALL_DNS_DATA | foreach {
               $data = $_ | Select-String -Pattern '^\d{1,2}\/\d{1,2}\/\d{4} \d{1,2}:\d{1,2}:\d{1,2} (AM|PM)'
   
               $DNS_SECTION = "GENERAL_SECTION"
               $DNS_DATA=""
               ForEach ($dns_row in $($data -split "`r`n"))
                {
                       
                       if ($dns_row -eq "    QUESTION SECTION:") {
                            $DNS_SECTION = "QUESTION_SECTION"
                       } elseif ($dns_row -eq "    ANSWER SECTION:") {
                            $DNS_SECTION = "ANSWER_SECTION"
                       } elseif ($dns_row -eq "    AUTHORITY SECTION:") {
                            $DNS_SECTION = "AUTHORITY_SECTION"
                       } elseif ($dns_row -eq "    ADDITIONAL SECTION:") {
                            $DNS_SECTION = "ADDITIONAL_SECTION"
                       }

                       if ($DNS_SECTION -eq "GENERAL_SECTION") {
                            if($dns_row -match "^\d{1,2}\/\d{1,2}\/\d{4} \d{1,2}:\d{1,2}:\d{1,2} (AM|PM)") {
                                $dns_summary=$($dns_row -split "\[")
                                $dns_summary_part1=$dns_summary[0]
                                $dns_summary=$($dns_summary[1] -split "\]")
                                $dns_summary_part2=$dns_summary[0]
                                $dns_summary_part3=$dns_summary[1]

                                $dns_summary=$($dns_summary_part1 -split "\s+")

                                $DNS_DateTime=$dns_summary[0]+" "+$dns_summary[1]+" "+$dns_summary[2]

                                if ($debugmode -eq "yes") {
                                    $DNS_ThreadID=$dns_summary[3]
                                    $DNS_Context=$dns_summary[4]
                                    $DNS_Internal_packet_identifier=$dns_summary[5]
                                    $DNS_UDP_TCP_indicator=$dns_summary[6]

                                    $DNS_Send_Receive_indicator=$dns_summary[7]
                                }
                                $DNS_Remote_IP=$dns_summary[8]
                                if ($debugmode -eq "yes") {
                                    $DNS_Xid_hex=$dns_summary[9]
                                    $DNS_Query_Response=$dns_summary[10]
                                    $DNS_Opcode=$dns_summary[11]
                                }

                                $dns_summary=$($dns_summary_part2 -split " ")
                                if ($debugmode -eq "yes") {
                                    $DNS_Flags_hex=$dns_summary[0]

                                    $DNS_Flags_char_codes=""
                                    for ($i=1;$i -lt ($dns_summary.Length-1);$i++){
    	                                $DNS_Flags_char_codes+=$dns_summary[$i]+" "
                                    }
                                }
	                            $DNS_ResponseCode=$dns_summary[$dns_summary.Length-1]

                                $dns_summary=$($dns_summary_part3 -split "\s+")

	                            $DNS_Question_Type=$dns_summary[1]
	                            $DNS_Question_Name=$dns_summary[2]
                                #$DNS_Question_Name=((($DNS_Question_Name) -replace "`\(.*?`\)","." -replace "^.","").trim(".")).TRIM()
                                $DNS_Question_Name=((($DNS_Question_Name) -replace "`\(\d+`\)","." -replace "^.","").trim(".")).TRIM()

                                #write-host "DNS_DateTime="$DNS_DateTime
                                #write-host "DNS_ThreadID="$DNS_ThreadID
                                #write-host "DNS_Context="$DNS_Context
                                #write-host "DNS_Internal_packet_identifier="$DNS_Internal_packet_identifier
                                #write-host "DNS_UDP_TCP_indicator="$DNS_UDP_TCP_indicator
                                #write-host "DNS_Send_Receive_indicator="$DNS_Send_Receive_indicator
                                #write-host "DNS_Remote_IP="$DNS_Remote_IP
                                #write-host "DNS_Xid_hex="$DNS_Xid_hex
                                #write-host "DNS_Query_Response="$DNS_Query_Response
                                #write-host "DNS_Opcode="$DNS_Opcode
                                #write-host "DNS_Flags_hex="$DNS_Flags_hex
                                #write-host "DNS_Flags_char_codes="$DNS_Flags_char_codes
                                #write-host "DNS_ResponseCode="$DNS_ResponseCode
                                #write-host "DNS_Question_Type="$DNS_Question_Type
                                #write-host "DNS_Question_Name="$DNS_Question_Name

                            }
                       } elseif ($DNS_SECTION -eq "ANSWER_SECTION") {
                            if ($dns_row -like "      DATA *") {
                                $DNS_DATA_TEMP=$($dns_row -split "\s+",3)[2].Trim()
                                
                                #if (($DNS_DATA_TEMP[0] -eq '[') -and ($DNS_DATA_TEMP[5] -eq ']')) {
                                #    $DNS_DATA_TEMP=$DNS_DATA_TEMP.substring(6)
                                #}
                                $DNS_DATA_TEMP=$DNS_DATA_TEMP -replace "`\[\w+`\]",""
                                $DNS_DATA_TEMP=((($DNS_DATA_TEMP) -replace "`\(\d+`\)",".").trim(".")).TRIM()

                                $DNS_DATA_TEMP=$DNS_DATA_TEMP -replace "\s+Offset = 0x\w{4}, RR count = \d{1,3}",""

                                if (-Not ([string]::IsNullOrWhiteSpace($DNS_DATA_TEMP))){
                                    if ($DNS_DATA) {
                                            $DNS_DATA+="`n"+$DNS_DATA_TEMP
                                    } else {
                                        $DNS_DATA+=$DNS_DATA_TEMP
                                    }
                                }
                            } elseif ($dns_row -eq "      empty") {
                                $DNS_DATA="empty"
                            }
                       } elseif ($DNS_SECTION -eq "QUESTION_SECTION") {
                            if ($dns_row -like "    Name      *") {
                                #write-host $dns_row
                                #$dns_name=((($dns_row.Split("`"")[1]) -replace "`\(\d+`\)","." -replace "^.","").trim("."))
                                #write-host $dns_row
                            }
                       }
                }
    
                #write-host $DNS_DATA
                #if ($DNSLogObject -and $DNS_DATA) {
                #    Add-Member -in $DNSLogObject NoteProperty 'DNS_DATA' $DNS_DATA
                #}

                if ($debugmode -eq "yes") {
                    $DNSLogObject = New-Object PsObject -Property ([ordered]@{
                        DNS_DateTime=$DNS_DateTime
                        DNS_ThreadID=$DNS_ThreadID
                        DNS_Context=$DNS_Context
                        DNS_Internal_packet_identifier=$DNS_Internal_packet_identifier
                        DNS_UDP_TCP_indicator=$DNS_UDP_TCP_indicator
                        DNS_Send_Receive_indicator=$DNS_Send_Receive_indicator
                        DNS_Remote_IP=$DNS_Remote_IP
                        DNS_Xid_hex=$DNS_Xid_hex
                        DNS_Query_Response=$DNS_Query_Response
                        DNS_Opcode=$DNS_Opcode
                        DNS_Flags_hex=$DNS_Flags_hex
                        DNS_Flags_char_codes=$DNS_Flags_char_codes
                        DNS_ResponseCode=$DNS_ResponseCode
                        DNS_Question_Type=$DNS_Question_Type                                                 
                        DNS_Question_Name=$DNS_Question_Name
                        DNS_DATA=$DNS_DATA
                    })
                        $DNS_DateTime=$null
                        $DNS_ThreadID=$null
                        $DNS_Context=$null
                        $DNS_Internal_packet_identifier=$null
                        $DNS_UDP_TCP_indicator=$null
                        $DNS_Send_Receive_indicator=$null
                        $DNS_Remote_IP=$null
                        $DNS_Xid_hex=$null
                        $DNS_Query_Response=$null
                        $DNS_Opcode=$null
                        $DNS_Flags_hex=$null
                        $DNS_Flags_char_codes=$null
                        $DNS_ResponseCode=$null
                        $DNS_Question_Type=$null
                        $DNS_Question_Name=$null
                        $DNS_DATA=$null
                } else {
                    $DNSLogObject = New-Object PsObject -Property ([ordered]@{
                        DNS_DateTime=$DNS_DateTime
                        DNS_Remote_IP=$DNS_Remote_IP
                        DNS_ResponseCode=$DNS_ResponseCode
                        DNS_Question_Type=$DNS_Question_Type                                                 
                        DNS_Question_Name=$DNS_Question_Name
                        DNS_DATA=$DNS_DATA
                    })
                        $DNS_DateTime=$null
                        $DNS_Remote_IP=$null
                        $DNS_ResponseCode=$null
                        $DNS_Question_Type=$null
                        $DNS_Question_Name=$null
                        $DNS_DATA=$null
                }

                if ($DNSLogObject -and $DNS_DateTime) {
                    $AllObjectsArray += $DNSLogObject
                }
                $DNSLogObject=$null

            }
            return $AllObjectsArray
        }
        catch
        {
            Write-Error $_
        }
        finally
        {
        }
    }
    END { }
}
