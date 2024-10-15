import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

// Create the MySQL database configuration.
type Account record {|
    string? name;
    string? initial_amount;
    string? types;
    int? id;
|};

type DeleteRequest record {|
    int id;
|};
//create new http listner
listener http:Listener httpListener = new(9001);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://www.m3.com", "http://www.hello.com"],
        allowCredentials: false,
        allowHeaders: ["CORELATION_ID"],
        exposeHeaders: ["X-CUSTOM-HEADER"],
        maxAge: 84900
    }
}

service /account on httpListener {
    resource function get .() returns json|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        stream<record {int id; string name; string initial_amount; string types;}, sql:Error?> accountStream = dbClient->query(`SELECT id, name, initial_amount, types FROM account`);
        json[] account = [];

        error? e = accountStream.forEach(function(record {int id; string name; string initial_amount; string types;} accountRecord) {
            account.push({
                "id": accountRecord.id,
                "name": accountRecord.name,
                "initial_amount": accountRecord.initial_amount,
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
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `INSERT INTO account (name, initial_amount, types) VALUES (${account.name}, ${account.initial_amount}, ${account.types})`;

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
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `UPDATE account SET initial_amount = ${account.initial_amount}, types = ${account.types} WHERE name = ${account.id}`;

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
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

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
