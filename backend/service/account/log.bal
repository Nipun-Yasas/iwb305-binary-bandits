import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

type Log record {| 
    string? name;
    int? logtype;
    int? amount;
    int accountId;
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
        stream<record {int id; string name; int logtype; int amount; string accountName;}, sql:Error?> logStream = dbClient->query(`
            SELECT l.id, l.name, l.logtype, l.amount, a.name AS accountName 
            FROM log l 
            JOIN account a ON l.account_id = a.id
        `);

        // JSON array to store the resulting logs.
        json[] log = [];

        // Process the result stream and build the JSON response.
        error? e = logStream.forEach(function(record {int id; string name; int logtype; int amount; string accountName;} logRecord) {
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

    resource function post add(http:Request req, @http:Payload Log log) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        // Fetch the current balance of the account.
        stream<record {int initial_amount;}, sql:Error?> accountStream = dbClient->query(
            `SELECT initial_amount FROM account WHERE id = ${log.accountId}`
        );

        int currentBalance = 0;
        error? e = accountStream.forEach(function(record {int initial_amount;} account) {
            currentBalance =  account.initial_amount;
        });

        if (e is error) {
            return {"error": e.message()};
        }
        // Convert the log amount from string to decimal
        int logAmount = log.amount ?: 0 ;

        // Calculate the new balance based on the log type (expense or income)
        int newBalance = currentBalance;

        if (log.logtype == 0) {
            newBalance -= logAmount;
        } else if (log.logtype == 1) {
            newBalance += logAmount;
        }

        // Update the account's balance in the database.
        sql:ExecutionResult updateResult = check dbClient->execute(
            `UPDATE account SET initial_amount = ${newBalance} WHERE id = ${log.accountId}`
        );

        if (updateResult.affectedRowCount == 0) {
            return {"error": "Failed to update the account balance"};
        }

        // Insert the log entry into the `log` table.
        sql:ParameterizedQuery query = `INSERT INTO log (name, logtype, amount, account_id)
                                                 VALUES (${log.name}, ${log.logtype}, ${log.amount}, ${log.accountId})`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Failed to insert the log"};
        }

        // Close the DB connection.
        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        return {"status": "Log created and account updated successfully"};
   }

   resource function put update(http:Request req, @http:Payload Log log) returns map<json>|error {
    mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

    if (dbClientResult is sql:Error) {
        return {"error": dbClientResult.message()};
    }

    mysql:Client dbClient = <mysql:Client>dbClientResult;

    // Fetch the existing log entry before updating to calculate the difference in amount.
    stream<record {int amount; int logtype;}, sql:Error?> existingLogStream = dbClient->query(
        `SELECT amount, logtype FROM log WHERE id = ${log.id}`
    );

    int oldLogAmount = 0;
    int oldLogType = 0;

    error? e = existingLogStream.forEach(function(record {int amount; int logtype;} existingLog) {
        oldLogAmount = existingLog.amount;
        oldLogType = existingLog.logtype;
    });

    if (e is error) {
        return {"error": e.message()};
    }

    // Fetch the current balance of the account.
    stream<record {int initial_amount;}, sql:Error?> accountStream = dbClient->query(
        `SELECT initial_amount FROM account WHERE id = ${log.accountId}`
    );

    int currentBalance = 0;

    error? balanceError = accountStream.forEach(function(record {int initial_amount;} account) {
        currentBalance = account.initial_amount;
    });

    if (balanceError is error) {
        return {"error": balanceError.message()};
    }

    // Convert the log amount to an integer.
    int newLogAmount = log.amount ?: 0 ;

    // Calculate the new balance based on the difference between old and new log amounts.
    int newBalance = currentBalance;

    // Adjust the balance if the log type is expense or income.
    if (oldLogType == 0) { // Old log was expense
        newBalance += oldLogAmount; // Revert old expense
    } else if (oldLogType == 1) { // Old log was income
        newBalance -= oldLogAmount; // Revert old income
    }

    // Apply new log update
    if (log.logtype == 0) { // New log is expense
        newBalance -= newLogAmount;
    } else if (log.logtype == 1) { // New log is income
        newBalance += newLogAmount;
    }

    // Update the account balance in the database.
    sql:ExecutionResult updateAccountResult = check dbClient->execute(
        `UPDATE account SET initial_amount = ${newBalance} WHERE id = ${log.accountId}`
    );

    if (updateAccountResult.affectedRowCount == 0) {
        return {"error": "Failed to update the account balance"};
    }

    // Update the log entry.
    sql:ParameterizedQuery updateLogQuery = `UPDATE log 
                                                SET name = ${log.name}, 
                                                    logtype = ${log.logtype}, 
                                                    amount = ${log.amount}, 
                                                    account_id = ${log.accountId} 
                                                WHERE id = ${log.id}`;

    sql:ExecutionResult updateLogResult = check dbClient->execute(updateLogQuery);

    if (updateLogResult.affectedRowCount == 0) {
        return {"error": "Failed to update the log entry"};
    }

    // Close the database connection.
    error? dberror = dbClient.close();

    if (dberror is error) {
        return {"error": dberror.message()};
    }

    return {"status": "Log and account updated successfully"};
    }

    resource function delete remove(http:Request req, @http:Payload Deletelog log) returns map<json>|error {
    mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

    if (dbClientResult is sql:Error) {
        return {"error": dbClientResult.message()};
    }

    mysql:Client dbClient = <mysql:Client>dbClientResult;

    // Step 1: Fetch the log entry before deletion to adjust the account balance.
    stream<record {int amount; int logtype; int account_id;}, sql:Error?> existingLogStream = dbClient->query(
        `SELECT amount, logtype, account_id FROM log WHERE id = ${log.id}`
    );

    int logAmount = 0;
    int logType = 0;
    int accountId = 0;

    error? e = existingLogStream.forEach(function(record {int amount; int logtype; int account_id;} existingLog) {
        logAmount = existingLog.amount;
        logType = existingLog.logtype;
        accountId = existingLog.account_id;
    });

    if (e is error) {
        return {"error": e.message()};
    }

    // Step 2: Fetch the current balance of the account.
    stream<record {int initial_amount;}, sql:Error?> accountStream = dbClient->query(
        `SELECT initial_amount FROM account WHERE id = ${accountId}`
    );

    int currentBalance = 0;

    error? balanceError = accountStream.forEach(function(record {int initial_amount;} account) {
        currentBalance = account.initial_amount;
    });

    if (balanceError is error) {
        return {"error": balanceError.message()};
    }

    // Step 3: Adjust the account balance based on the log type.
    int newBalance = currentBalance;

    if (logType == 0) {
        newBalance += logAmount;  // Revert expense by adding it back
    } else if (logType == 1) {
        newBalance -= logAmount;  // Revert income by subtracting it
    }

    // Step 4: Update the account balance in the database.
    sql:ExecutionResult updateAccountResult = check dbClient->execute(
        `UPDATE account SET initial_amount = ${newBalance} WHERE id = ${accountId}`
    );

    if (updateAccountResult.affectedRowCount == 0) {
        return {"error": "Failed to update the account balance"};
    }

    // Step 5: Delete the log entry from the `log` table.
    sql:ParameterizedQuery query = `DELETE FROM log WHERE id = ${log.id}`;

    sql:ExecutionResult result = check dbClient->execute(query);

    if (result.affectedRowCount == 0) {
        return {"error": "Error while deleting the log"};
    }

    // Step 6: Close the database connection.
    error? dberror = dbClient.close();
    if (dberror is error) {
        return {"error": dberror.message()};
    }

    return {"status": "Log deleted and account balance updated successfully"};
}
  

}

