
import ballerina/sql;
import ballerinax/mysql;

type Transaction record {| 
    string? name;
    string? transactiontype;
    decimal? amount;
    int? id;
|};

type Deletetransaction record {| 
    int id; 
|};

service /vg on httpListener {

    resource function get .() returns json|error {
        // Initialize the MySQL client connection.
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        // Handle any connection errors.
        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        // SQL query to join `transaction` with `account` using `accountId` foreign key.
        stream<record {int id; string name; string transactiontype; decimal amount; string accountName;}, sql:Error?> transactionStream = dbClient->query(`
            SELECT t.id, t.name, t.transactiontype, t.amount, a.name AS accountName 
            FROM transaction t 
            JOIN account a ON t.accountId = a.id
        `);

        // JSON array to store the resulting transactions.
        json[] transactions = [];

        // Process the result stream and build the JSON response.
        error? e = transactionStream.forEach(function(record {int id; string name; string transactiontype; decimal amount; string accountName;} transactionRecord) {
            transactions.push({
                "id": transactionRecord.id,
                "name": transactionRecord.name,
                "transactiontype": transactionRecord.transactiontype,
                "amount": transactionRecord.amount,
                "accountName": transactionRecord.accountName
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

        // Return the array of transaction records as JSON.
        return transactions;
    }
}
