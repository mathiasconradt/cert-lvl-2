# +
*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library           RPA.Browser.Selenium
Library           RPA.HTTP
Library           RPA.Tables
Library           RPA.PDF
Library           RPA.Archive
Library           RPA.Robocorp.Vault
Library           RPA.Dialogs
Library           OperatingSystem
# -

*** Variables ***
# ${URL}      https://robotsparebinindustries.com/#/robot-order # <-- it's now read from the vault
# ${CSV_URL}  https://robotsparebinindustries.com/orders.csv # <-- it's now asked via dialog

# +
*** Keywords ***
Get Secrets    
    ${secret}=    Get Secret    secrets
    [Return]      ${secret}[homepage]

Get CSV URL
    Add heading             Input Required
    Add text input          csv_url    label=Please enter the CSV URL     placeholder=https://...
    ${result}=              Run dialog
    [Return]                ${result.csv_url}

Open the robot order website
    [Arguments]                 ${url}
    Open Available Browser      ${url}    

Download CSV
    [Arguments]                 ${csv_url}
    Download                    url=${csv_url}  target_file=output/orders.csv   overwrite=True

Get Orders
    ${table}=                   Read table from CSV    path=output/orders.csv        
    [Return]                    ${table}
    
Close the annoying modal    
    Wait And Click Button    	//button[@class="btn btn-dark"]
    
Fill the form
    [Arguments]                 ${row}
    Select From List By Value   //*[@id="head"]   ${row}[Head]
    Select Radio Button         body              ${row}[Body]    
    Input Text                  xpath://html/body/div[1]/div/div[1]/div/div[1]/form/div[3]/input    ${row}[Legs]
    Input Text                  //*[@id="address"]  ${row}[Address]
    
Preview the robot
    Wait And Click Button       //*[@id="preview"]

Submit the order
    Mute Run On Failure             Page Should Contain Element
    Wait And Click Button           //*[@id="order"]
    #Wait Until Element Is Visible   //*[@id="receipt"]    
    Page Should Contain Element     //*[@id="receipt"]
    
Store the receipt as a PDF file
    [Arguments]        ${order_number}
    Wait Until Element Is Visible   //*[@id="receipt"]
    ${element_to_print}=            Get Element Attribute               //*[@id="receipt"]  outerHTML
    Html To Pdf                     content=${element_to_print}         output_path=${OUTPUT_DIR}/receipts/${order_number}.pdf
    [Return]                        ${OUTPUT_DIR}/receipts/${order_number}.pdf

Take a screenshot of the robot
    [Arguments]        ${order_number}
    Wait Until Element Is Visible   //*[@id="robot-preview-image"]
    Capture Element Screenshot      //*[@id="robot-preview-image"]      ${OUTPUT_DIR}/images/${order_number}.png
    [Return]           ${OUTPUT_DIR}/images/${order_number}.png

Embed the robot screenshot to the receipt PDF file
    [Arguments]     ${img}           ${pdf}
    Open PDF        ${pdf}
    @{images}=      Create List      ${img}:x=0,y=0
    Add Files To PDF    ${images}    ${pdf}     ${True}
    Close PDF     ${pdf}

Go to order another robot    
    Wait And Click Button           //*[@id="order-another"]
    
Create a ZIP file of the receipts
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/PDFs.zip
    Archive Folder With ZIP     ${OUTPUT_DIR}/receipts  ${zip_file_name}   recursive=True  include=*.pdf
# -

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${homepage}=    Get Secrets
    ${csv_url}=     Get CSV URL
    Open the robot order website    ${homepage}
    Download CSV                    ${csv_url}
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
         Close the annoying modal
         Fill the form    ${row}
         Preview the robot
         Wait Until Keyword Succeeds     8x     1s    Submit The Order
         
         ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
         ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
         Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
         Go to order another robot
    END
    Create a ZIP file of the receipts

