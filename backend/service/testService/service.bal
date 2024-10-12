import ballerina/http;
import ballerina/log;

type Doctor record {|
    string name;
    string hospital;
    string category;
    string availability;
    decimal fee;
|};

configurable string healthcareBackend = "http://localhost:9090/healthcare";

final http:Client queryDoctorEP = check new (healthcareBackend);

service /healthcare on new http:Listener(8290) {
    resource function get doctors/[string category]() 
            returns Doctor[]|http:NotFound|http:InternalServerError {
        log:printInfo("Retrieving information", specialization = category);
        
        Doctor[]|http:ClientError resp = queryDoctorEP->/[category];
        if resp is Doctor[] {
            return resp;
        }
        
        log:printError("Retrieving doctor information failed", resp);
        if resp is http:ClientRequestError {
            return <http:NotFound> {body: string `category not found: ${category}`};
        }

        return <http:InternalServerError> {body: resp.message()};
    }
}