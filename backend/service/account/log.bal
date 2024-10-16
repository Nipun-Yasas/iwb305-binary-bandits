
import ballerina/sql;
import ballerinax/mysql;

type Log record {| 
    string? name;
    string? logtype;
    decimal? amount;
    int? id;
|};

type Deletelog record {| 
    int id; 
|};

service /log on httpListener {

    resource function get .() returns json|error {
        // Initialize the MySQL client connection.
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        // Handle any connection errors.
        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        // SQL query to join `log` with `log` using `accountId` foreign key.
        stream<record {int id; string name; string logtype; decimal amount; string accountName;}, sql:Error?> logStream = dbClient->query(`
            SELECT l.id, l.name, l.logtype, l.amount, a.name AS accountName 
            FROM log l 
            JOIN log a ON l.account_id = a.id
        `);

        // JSON array to store the resulting logs.
        json[] log = [];

        // Process the result stream and build the JSON response.
        error? e = logStream.forEach(function(record {int id; string name; string logtype; decimal amount; string accountName;} logRecord) {
            log.push({
                "id": logRecord.id,
                "name": logRecord.name,
                "logtype": logRecord.logtype,
                "amount": logRecord.amount,
                "accountName": logRecord.accountName
            });
        });

        // Handle any errors encountered while processing the stream.
        if (e is error) {
            return {"error": e.message()};
        }

        // Close the database connection and handle any potential errors.
        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        // Return the array of log records as JSON.
        return log;
    }

    
}
