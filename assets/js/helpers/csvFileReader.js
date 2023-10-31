import Papa from "papaparse"; //documentation: https://www.papaparse.com/docs

function csvFileReader() 
{
    //configurations
    const conf = {
        sadworker: true,
        header: true,
        download: true,
        skipEmptyLines: true,
        transformHeader: function(h) {
            return h.trim(); //remove spaces
          }
        //delimeter: ';' default
    }

    const loadFile = (csvFile, ProcessRowRecord) => {
        
        //now we are processing 1 file
        //if we need to parse multiple files it need to update
        let rowCounter = 0; // first row is the header
        //NOTE: This library is just loading CSV files doesn't validate it's content!
        Papa.parse(csvFile.accepted[0], {
            ...conf,
            step: ({ data, meta }, parser) =>
            {
                meta.fileName = csvFile.name;
                rowCounter++;

                //processing the record
                if(!ProcessRowRecord(data, meta.fields, rowCounter))
                {
                    //stop the processing if it's got any critical errors like header missmatch
                    parser.abort();
                }
                
            },
            complete: (results, file) => {
               
                console.log("Parsing complete on file:", file);
                
            }
        });
        
    }

    //more methods here in the future like upload, writing...



    //returning the functions
    return {
        loadFile
    }
}

export default csvFileReader();
