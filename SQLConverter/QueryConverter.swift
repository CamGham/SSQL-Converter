//
//  Converter.swift
//  SQLConverter
//
//  Created by Cameron Graham on 26/02/24.
//

import Foundation

struct SingleRowMappingInfo {
    var table: String
    var sqlColName: String
    var tableName: String
}

struct SqlTableInfo {
    var mappedTableName: String
    var alias: String?
}

// TODO: does not currently support JOIN

class QueryConverter {
    func convertSqlQueryToTableQuery(mappingTable: String, sqlQuery: String) -> String {
        let mappingRows = mappingTable.split(separator: "\n")
        var soupNameDict: [String: SqlTableInfo] = [:]
        var columnNameDict: [String: String] = [:]
        var myConvertedQuery = sqlQuery

        
        // map over each row of mapping info
        let convertedArray: [SingleRowMappingInfo] = mappingRows.map { row in
            let components = row.split(separator: "\t")
            let soupName = String(components[0])
            let columnName = String(components[1])
            let tableName = String(components[2])

            // create dictionary of soupnames mapped to its TABLE name
            if !soupNameDict.keys.contains("{\(soupName)}") {
                guard let indexOfColumnSeparator = tableName.lastIndex(of: "_") else {
                    return SingleRowMappingInfo(
                        table: soupName,
                        sqlColName: columnName,
                        tableName: tableName
                    )
                }

                let extractedTableName = tableName.prefix(upTo: indexOfColumnSeparator)
                soupNameDict["{\(soupName)}"] = SqlTableInfo(mappedTableName: String(extractedTableName), alias: nil)
            }
            
            return SingleRowMappingInfo(
                table: soupName,
                sqlColName: columnName,
                tableName: tableName
            )
        }

        // extract soupnames that exist in query
        let sqlSoupnames = extractSoupnamesFromQuery(currentQuery: myConvertedQuery)

        // extract alias of soupname if exists
        sqlSoupnames.forEach { name in
            var alias = ""
            print(name)
            if let rangeOfAsAlias = name.range(of: "} as ") {
                let remaining = name.suffix(from: rangeOfAsAlias.upperBound)
                alias = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                
            } else if let rangeOfAsAlias = name.range(of: "} AS ") {
                 let remaining = name.suffix(from: rangeOfAsAlias.upperBound)
                 alias = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                
            } else if let lastCharacter = name.trimmingCharacters(in: .whitespacesAndNewlines).last, lastCharacter != "}" {
                guard let aliasStartingIndex = name.range(of: "} ") else { return }
                print("still here")
                alias = String(name.suffix(from: aliasStartingIndex.upperBound)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if alias != "" {
                guard let firstIndex = name.firstIndex(of: "{"), let secondIndex = name.firstIndex(of: "}") else { return }
                let sqlColumnName = name[firstIndex...secondIndex]
                let sqlColString = String(sqlColumnName)
                if let currentData = soupNameDict[sqlColString] {
                    soupNameDict[sqlColString] = SqlTableInfo(mappedTableName: currentData.mappedTableName, alias: alias)
                }
            }
        }
        
        // create map of column names against tablename
        // include alias info if exists
        convertedArray.filter { singleRow in
            sqlSoupnames.contains("{\(singleRow.table)}")
        }.forEach { row in
            if let tableInfo = soupNameDict["{\(row.table)}"], let alias = tableInfo.alias {
                columnNameDict["\(alias).{\(row.table):\(row.sqlColName)}"] = "\(alias).\(row.tableName)"
            } else {
                columnNameDict["{\(row.table):\(row.sqlColName)}"] = row.tableName
            }
        }


        // convert all column names from sql query to table
        let columnArray = Array(columnNameDict.keys)
        for key in columnArray {
            convertSqlName(key: key, value: columnNameDict[key], currentQuery: &myConvertedQuery)
        }

        // convert all soup names from sql query to table
        let soupArray = Array(soupNameDict.keys)
        for key in soupArray {
            guard let tableInfo = soupNameDict[key] else { return myConvertedQuery }
            convertSqlName(key: key, value: tableInfo.mappedTableName, currentQuery: &myConvertedQuery)
        }

        return myConvertedQuery
    }

    private func convertSqlName(key: String, value: String?, currentQuery: inout String) {
        guard let range: Range = currentQuery.range(of: key),
        let tableName = value else { return }
        currentQuery.replaceSubrange(range, with: tableName)
        convertSqlName(key: key, value: value, currentQuery: &currentQuery)
    }

    private func extractSoupnamesFromQuery(currentQuery: String) -> [String]{
        var startingWord = ""
        if currentQuery.contains("FROM") {
            startingWord = "FROM"
        } else {
            startingWord = "from"
        }

        guard let rangeOfStartingWord = currentQuery.range(of: startingWord) else { return [] }
        
        var remainingQuery = currentQuery.suffix(from: rangeOfStartingWord.upperBound)
        
        var endingWord = ""
        if remainingQuery.contains("WHERE"){
            endingWord = "WHERE"
        } else if remainingQuery.contains("where") {
            endingWord = "where"
        } else if remainingQuery.contains("GROUP BY") {
            endingWord = "GROUP BY"
        } else if remainingQuery.contains("group by") {
            endingWord = "group by"
        } else if remainingQuery.contains("ORDER BY") {
            endingWord = "ORDER BY"
        } else if remainingQuery.contains("order by") {
            endingWord = "order by"
        } else if remainingQuery.contains("HAVING") {
            endingWord = "HAVING"
        } else if remainingQuery.contains("having") {
            endingWord = "having"
        } else if remainingQuery.contains("LIMIT") {
            endingWord = "LIMIT"
        } else if remainingQuery.contains("limit") {
            endingWord = "limit"
        } else if remainingQuery.contains("OFFSET") {
            endingWord = "OFFSET"
        } else if remainingQuery.contains("offset") {
            endingWord = "offset"
        } // else there is no filtering

        
        
        if endingWord != "" {
            guard let endOfTableRange = remainingQuery.range(of: endingWord) else { return [] }
            let endOfTableIndex = endOfTableRange.lowerBound
            remainingQuery = remainingQuery.prefix(upTo: endOfTableIndex)
        }


        var arrayOfColumnNames: [String] = []

        // extract multiple tables
        if remainingQuery.contains(",") {
            arrayOfColumnNames = remainingQuery.split(separator: ",").map { subString in
                String(subString).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            arrayOfColumnNames.append(String(remainingQuery).trimmingCharacters(in: .whitespacesAndNewlines))
        }

       return arrayOfColumnNames


    }
}

//let testData = """
//Animal_Treatment__c|id|TABLE_2_0
//Animal_Treatment__c|Start_Date__c|TABLE_2_1
//"""
//let testSqlData = """
//SELECT at.{Animal_Treatment__c:id}, at.{Animal_Treatment__c:Start_Date__c} FROM {Animal_Treatment__c} as at WHERE at.{Animal_Treatment__c:id} = '4001'
//"""
//let qc = QueryConverter()
//let convertedQuery = qc.convertSqlQueryToTableQuery(mappingTable: testData, sqlQuery: testSqlData)
//print("final query: \(convertedQuery)")


