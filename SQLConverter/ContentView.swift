//
//  ContentView.swift
//  SQLConverter
//
//  Created by Cameron Graham on 26/02/24.
//

import SwiftUI

struct ContentView: View {
    let qc = QueryConverter()
    @State var mappingString = ""
    @State var sqlQuery = ""
    @State var resultQuery = ""
    
    private func fieldsAreValid() -> Bool {
        return mappingString != "" && sqlQuery != ""
    }
    
    
    private func runConvertion() {
        if fieldsAreValid() {
            resultQuery = qc.convertSqlQueryToTableQuery(mappingTable: mappingString, sqlQuery: sqlQuery)
        }
    }
    
    var body: some View {
        HStack {
            VStack{
                TextField("Mapping Info", text: $mappingString, prompt: Text("Enter the mapping table"), axis: .vertical)
                    .lineLimit(20, reservesSpace: true)
                
                
                TextField("SQL Query", text: $sqlQuery, prompt: Text("Enter your sql query"), axis: .vertical)
                    .lineLimit(20, reservesSpace: true)
            }
            
            Button("Convert") {
                runConvertion()
            }
            .disabled(!fieldsAreValid())
            
            VStack {
                TextField("Converted Query", text: $resultQuery, prompt: Text("Resulting query will appear here"), axis: .vertical)
                    .lineLimit(40, reservesSpace: true)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
