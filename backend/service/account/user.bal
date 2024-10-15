import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

// Create the MySQL database configuration.
type User record {|
    string? name;
    string? email;
    string? password;
    string? primary_income_source;
    string? primary_saving_goal;
    string? current_debt_amount;
    int? id;
|};

type DeleteUser record {|
    int id;
|};

service /user on httpListener {
    resource function get .() returns json|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        stream<record {int id; string name; string email; string password; string  primary_income_source; string primary_saving_goal; string current_debt_amount;}, sql:Error?> userStream = dbClient->query(`SELECT id, name, email,password,primary_income_source,primary_saving_goal,current_debt_amount FROM user`);
        json[] user = [];

        error? e = userStream.forEach(function(record {int id; string name; string email; string password; string  primary_income_source; string primary_saving_goal; string current_debt_amount;} userRecord) {
            user.push({
                "id": userRecord.id,
                "name": userRecord.name,
                "email": userRecord.email,
                "password": userRecord.password,
                "primary_income_source": userRecord.primary_income_source,
                "primary_saving_goal": userRecord.primary_saving_goal,
                "current_debt_amount": userRecord.current_debt_amount

            });
        });

        if (e is error) {
            return {"error": e.message()};
        }
        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        return user;
    }

resource function post add(http:Request req, @http:Payload User user) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `INSERT INTO user (name,email,password,primary_income_source,primary_saving_goal,current_debt_amount) VALUES (${user.name}, ${user.email}, ${user.password},${user.primary_income_source},${user.primary_saving_goal},${user.current_debt_amount})`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while adding the user"};
        }
        error? dberror = dbClient.close();

        if (dberror is error) {
            return {"error": dberror.message()};
        }
        return {"status": "Successfully added the user"};
    }

    resource function put update(http:Request req, @http:Payload User user) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `UPDATE user SET name = ${user.name}, email = ${user.email},password = ${user.password}, primary_income_source = ${user.primary_income_source}, primary_saving_goal = ${user.primary_saving_goal}, current_debt_amount = ${user.current_debt_amount} WHERE id = ${user.id}`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while updating the user"};
        }
        error? dberror = dbClient.close();

        if (dberror is error) {
            return {"error": dberror.message()};
        }
        return {"status": "Successfully updated the user"};
    }

    resource function delete remove(http:Request req,@http:Payload DeleteUser user) returns map<json>|error {
        mysql:Client|sql:Error dbClientResult = new (dbHost, dbUsername, dbPassword, dbName, dbPort);

        if (dbClientResult is sql:Error) {
            return {"error": dbClientResult.message()};
        }

       

        mysql:Client dbClient = <mysql:Client>dbClientResult;

        sql:ParameterizedQuery query = `DELETE FROM user WHERE id = ${user.id}`;

        sql:ExecutionResult result = check dbClient->execute(query);

        if (result.affectedRowCount == 0) {
            return {"error": "Error while deleting the user"};
        }

        error? dberror = dbClient.close();
        if (dberror is error) {
            return {"error": dberror.message()};
        }

        return {"status": "Successfully deleted the user"};
    }
}