import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

// Create the MySQL database configuration.
type Account record {|
    string? number;
    string? branch;
    string? types;
    int? id;
|};

type DeleteRequest record {|
    int id;
|};
//create new http listner
listener http:Listener httpListener = new(8080);


service /account on httpListener {
    resource function get .() returns json|error {
        mysql:Client|sql:Error dbClientResult = new ("localhost", "root", "KaviskaDilshan12#$", "ballerina-001", 3306);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        stream<record {int id; string number; string branch; string types;}, sql:Error?> accountStream = dbClient->query(`SELECT id, number, branch, types FROM account`);
        json[] account = [];

        error? e = accountStream.forEach(function(record {int id; string number; string branch; string types;} accountRecord) {
            account.push({
                "id": accountRecord.id,
                "number": accountRecord.number,
                "branch": accountRecord.branch,
                "types": accountRecord.types
            });
        });

        if (e is error) {
            return {"error": e.message()};
        }
        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        return account;
    }

    resource function post add(http:Request req, @http:Payload Account account) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new ("localhost", "root", "KaviskaDilshan12#$", "ballerina-001", 3306);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `INSERT INTO account (number, branch, types) VALUES (${account.number}, ${account.branch}, ${account.types})`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while adding the account"};
        }
        error? dberror = dbClient.close();

        if (dberror is error) {
            return {"error": dberror.message()};
        }
        return {"status": "Successfully added the account"};
    }

    resource function put update(http:Request req, @http:Payload Account account) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new ("localhost", "root", "KaviskaDilshan12#$", "ballerina-001", 3306);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `UPDATE account SET branch = ${account.branch}, types = ${account.types} WHERE number = ${account.id}`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while updating the account"};
        }
        error? dberror = dbClient.close();

        if (dberror is error) {
            return {"error": dberror.message()};
        }
        return {"status": "Successfully updated the account"};
    }

    resource function delete remove(http:Request req,@http:Payload DeleteRequest account) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new ("localhost", "root", "KaviskaDilshan12#$", "ballerina-001", 3306);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

       

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `DELETE FROM account WHERE id = ${account.id}`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while deleting the account"};
        }

        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        return {"status": "Successfully deleted the account"};
    }

}
