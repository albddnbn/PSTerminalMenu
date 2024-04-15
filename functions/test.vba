'function to get next empty row in spreadsheet (should be better way)
Function GetNextEmptyRow(ws As Worksheet, cols As Variant) As Long
    Dim i As Long
    For i = 1 To ws.Rows.Count
        If Application.WorksheetFunction.CountA(ws.Range(cols(0) & i & ":" & cols(UBound(cols)) & i)) = 0 Then
            GetNextEmptyRow = i
            Exit Function
        End If
    Next i
End Function

Sub ScanMatch()
    Dim ws As Worksheet
    Dim code As Variant
    Dim cols As Variant
    Dim matchedCell As Range
    Dim matchedCell2 As Range
    Dim status As String
    Dim nextRow As Long
    Dim rng As Range
    Dim cell As Range

    ' Preparation: eliminate any surrounding whitespace from columns B,E,F
    'set worksheet variable
    Set ws = ThisWorkbook.Sheets("tonerinventory")

    ' Loop through each cell in the columns and trim whitespace
    For Each rng In Array(ws.Range("B2:B500"), ws.Range("C2:C500"), ws.Range("F2:F500"))
        For Each cell In rng
            cell.Value = Trim(cell.Value)
        Next cell
    Next rng

    'columns to check when finding next empty row in inventory table:
    cols = Array("A", "B", "E", "F")
    scanType = InputBox("Please enter 1 to scan model/part numbers, or 2 to scan UPC codes.")
    If scanType = 1 Or scanType = 2 Then
        ' Checking columns B and E for matches:
        If scanType = 1 Then
             Do Until status = "done"
                code = InputBox("Please scan a model/part number and hit enter if you need to")
                If code = "done" Or code = "" Then Exit Do

                'look for matching model number in B column:
                Set matchedCell = Range("B2:B500").Find(what:=code, LookIn:=xlValues, lookat:=xlWhole, MatchCase:=False)
                'if theres a match here, increase stock by 1, if not continue to seaarch the other related column - number
                If matchedCell Is Not Nothing Then
                    ' if match found in column B - offset will be +1
                    matchedCell.Offset(0, 1).Value = matchedCell.Offset(0, 1).Value + 1
                Else
                    Set matchedCell2 = Range("E2:E500").Find(what:=code, LookIn:=xlValues, lookat:=xlWhole, MatchCase:=True)
                    'if no match was found here - item isn't already in the list - has to be manually added in.
                    'might as well add a blank entry to end of table with the part/model number
                    If matchedCell2 Is Nothing Then
                        nextRow = GetNextEmptyRow(ws, cols)
                        ' insert data into column B and E
                        ws.Range("B" & nextRow).Value = code
                        ws.Range("E" & nextRow).Value = code
                        ws.Range("C" & nextRow).Value = 1
                    Else
                        ' increment stock column C by 1:
                        matchedCell.Offset(0, -2).Value = matchedCell.Offset(0, -2).Value + 1
                    End If
                End If

            Loop
        ' Checking column F (UPC codes) for matches:
        ElseIf scanType = 2 Then
            Do Until status = "done"
                code = InputBox("Please scan a upc code and hit enter if you need to")
                If code = "done" Or code = "" Then Exit Do
                Set matchedCell = Range("F2:B500").Find(what:=code, LookIn:=xlValues, lookat:=xlWhole, MatchCase:=False)
                If matchedCell Is Nothing Then
                    ' If no match was found for scanned upc code - add it to end of list with stock 1:
                    nextRow = GetNextEmptyRow(ws, cols)
                    ' insert data into column B and E
                    ws.Range("F" & nextRow).Value = code
                    ws.Range("C" & nextRow).Value = 1
                Else
                    ' Increment stock column of matching row by 1 (offset -3, F-C)
                    matchedCell.Offset(0, -3).Value = matchedCell.Offset(0, -3).Value + 1
                End If
            Loop
        End If
    Else
        MsgBox "Neither 1 or 2 was chosen, exiting."
        Exit Sub
    End If
End Sub