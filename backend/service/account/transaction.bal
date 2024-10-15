
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
            JOIN account a ON t.account_id = a.id
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

    resource function post add(http:Request req, @http:Payload Account account) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;
        // Parse the incoming JSON request to get the transaction details.
        Transaction transaction = check requestBody.cloneWithType(Transaction);

        // Start a transaction block (to ensure both transaction insertion and account update happen together).
        transaction {
            // Insert the transaction record into the `transaction` table.
            sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
                INSERT INTO transaction (name, transactiontype, amount, account_id)
                VALUES (?, ?, ?, ?)`,
                transaction.name, transaction.transactiontype, transaction.amount, transaction.accountId
            );

            if (insertResult is sql:Error) {
                rollback;
                return {"error": "Error inserting transaction: " + insertResult.message()};
            }

            // Fetch the current `initial_amount` of the account to update.
            stream<record {decimal initial_amount;}, sql:Error?> accountStream = dbClient->query(`
                SELECT initial_amount FROM account WHERE id = ?`, transaction.accountId);

            decimal initialAmount = 0;
            error? e = accountStream.forEach(function(record {decimal initial_amount;} accountRecord) {
                initialAmount = accountRecord.initial_amount;
            });

            if (e is error) {
                rollback;
                return {"error": "Error fetching account initial amount: " + e.message()};
            }

            // Adjust the `initial_amount` based on the transaction type.
            decimal newAmount = initialAmount;

            if (transaction.transactiontype.toLowerAscii() == "expense") {
                newAmount = initialAmount - transaction.amount;
            } else if (transaction.transactiontype.toLowerAscii() == "income") {
                newAmount = initialAmount + transaction.amount;
            } else {
                rollback;
                return {"error": "Invalid transaction type. Must be 'expense' or 'income'."};
            }

            // Update the `initial_amount` of the account.
            sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
                UPDATE account SET initial_amount = ? WHERE id = ?`,
                newAmount, transaction.accountId
            );

            if (updateResult is sql:Error) {
                rollback;
                return {"error": "Error updating account initial amount: " + updateResult.message()};
            }

            // Commit the transaction block.
            commit;

        } on fail error err {
            rollback;
            return {"error": "Transaction failed: " + err.message()};
        }

        // Close the database connection.
        error? closeError = dbClient.close();
        if (closeError is error) {
            return {"error": closeError.message()};
        }

        // Return success message.
        return { "status": "Transaction successfully created and account updated" };
    }
}
